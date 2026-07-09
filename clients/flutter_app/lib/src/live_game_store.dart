import 'dart:async';
import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'animation_speed.dart';
import 'c_engine_action_codec.dart';
import 'c_engine_bridge.dart';
import 'game_constants.dart';
import 'game_ui_state.dart';
import 'online_game_models.dart';
import 'online_table_projection.dart';
import 'policy_model.dart';
import 'render_model.dart';
import 'design_tokens.dart';
import 'saved_game_store.dart';
import 'supabase_config.dart';
import 'table_view_projection.dart';

bool actionCapturesUndoSnapshot(String actionKind) {
  return actionKind == actionAssign;
}

class LiveGameStore extends ChangeNotifier {
  LiveGameStore({
    KolkhozCEngineBridge? bridge,
    KolkhozAutosaveStore? autosaveStore,
    KolkhozNativePolicyModel? mediumPolicy,
    Future<KolkhozNativePolicyModel>? mediumPolicyLoader,
    KolkhozNativePolicyModel? neuralPolicy,
    Future<KolkhozNativePolicyModel>? neuralPolicyLoader,
    this.onlineAccessTokenProvider,
    this.autosaveEnabled = true,
  }) : bridge = bridge ?? KolkhozCEngineBridge(),
       _autosaveStore = autosaveStore ?? KolkhozAutosaveStore.defaultStore(),
       _mediumPolicy = mediumPolicy,
       _mediumPolicyLoader = mediumPolicy == null
           ? mediumPolicyLoader ??
                 KolkhozNativePolicyModel.loadAsset(mediumNeuralPolicyAsset)
           : null,
       _neuralPolicy = neuralPolicy,
       _neuralPolicyLoader = neuralPolicy == null
           ? neuralPolicyLoader ??
                 KolkhozNativePolicyModel.loadAsset(defaultNeuralPolicyAsset)
           : null {
    if (!_restoreAutosave()) {
      newGame(persist: false);
    }
    _startNeuralPolicyLoad();
  }

  final KolkhozCEngineBridge bridge;
  final KolkhozAutosaveStore _autosaveStore;
  KolkhozNativePolicyModel? _mediumPolicy;
  Future<KolkhozNativePolicyModel>? _mediumPolicyLoader;
  KolkhozNativePolicyModel? _neuralPolicy;
  Future<KolkhozNativePolicyModel>? _neuralPolicyLoader;
  final Future<String?> Function()? onlineAccessTokenProvider;
  final bool autosaveEnabled;

  DesignTokens tokens = defaultDesignTokens;
  GameAnimationSpeed animationSpeed = defaultGameAnimationSpeed;
  GameUiState uiState = const GameUiState();
  List<KolkhozPlayerController> controllers = List.of(
    KolkhozPlayerController.defaultControllers,
  );
  KolkhozGameVariants currentVariants = KolkhozGameVariants.kolkhoz;
  int currentSeed = 0;
  List<EngineAction> actionLog = [];
  bool restoredSavedGame = false;
  OnlineGameRuntime? _online;
  Timer? _onlineRefreshTimer;
  RealtimeChannel? _onlineRealtimeChannel;
  bool _onlineRealtimeRefreshInFlight = false;
  bool _onlineActionRefreshInFlight = false;
  Timer? _onlineUpdateQueueTimer;
  final List<OnlineActionUpdate> _onlineUpdateQueue = [];
  Timer? _automaticStepTimer;
  TableViewModel? model;
  Pointer<KCEngine>? _engine;
  final List<GameUndoSnapshot> _undoStack = [];
  int? revealedPlayerID;
  String? error;
  String? _lastSyncedPhase;
  bool _mediumPolicyUnavailable = false;
  bool _neuralPolicyUnavailable = false;
  bool _disposed = false;

  void newGame({
    KolkhozGameVariants variants = KolkhozGameVariants.kolkhoz,
    List<KolkhozPlayerController> controllers =
        KolkhozPlayerController.defaultControllers,
    bool persist = true,
  }) {
    try {
      _clearAutomaticStepTimer();
      final oldEngine = _engine;
      if (oldEngine != null) {
        bridge.freeEngine(oldEngine);
      }
      _clearOnlineSession();
      final normalizedControllers = KolkhozPlayerController.normalized(
        controllers,
      );
      this.controllers = normalizedControllers;
      currentVariants = variants;
      currentSeed = _newSeed();
      actionLog = [];
      _clearUndoStack();
      restoredSavedGame = false;
      uiState = const GameUiState();
      _lastSyncedPhase = null;
      revealedPlayerID = null;
      _engine = bridge.newEngine(
        seed: currentSeed,
        variants: variants,
        controllers: normalizedControllers,
      );
      error = null;
      _sync();
      if (persist) {
        _saveAutosave();
      }
      _scheduleAutomaticStep();
    } catch (exception) {
      error = '$exception';
      model = null;
      notifyListeners();
    }
  }

  void applyLegalAction(LegalAction action) {
    final online = _online;
    if (online != null) {
      unawaited(_submitOnlineAction(online, action));
      return;
    }
    final engine = _engine;
    if (engine == null) {
      return;
    }
    final cAction = cEngineAction(action.engineAction);
    if (cAction == null) {
      return;
    }
    _clearAutomaticStepTimer();
    final capturesUndo = actionCapturesUndoSnapshot(action.kind);
    final undoSnapshot = capturesUndo ? _snapshotForUndo(engine) : null;
    final result = bridge.applyManual(engine, cAction);
    if (result != 0) {
      undoSnapshot?.dispose(bridge);
      error = 'Move rejected ($result)';
    } else {
      error = null;
      if (undoSnapshot != null) {
        _undoStack.add(undoSnapshot);
      } else {
        _clearUndoStack();
      }
      actionLog = [...actionLog, action.engineAction];
      _clearSelectionAfter(action.kind);
    }
    _sync();
    if (result == 0) {
      _saveAutosave();
      _scheduleAutomaticStep();
    }
  }

  void setActivePanel(String panel) {
    uiState = uiState.togglePanel(panel);
    _sync();
  }

  void clearActivePanel() {
    uiState = uiState.clearActivePanel();
    _sync();
  }

  void setAnimationSpeed(GameAnimationSpeed speed) {
    if (animationSpeed == speed) {
      return;
    }
    final shouldResume = _automaticStepTimer != null;
    _clearAutomaticStepTimer();
    animationSpeed = speed;
    notifyListeners();
    if (shouldResume) {
      _scheduleAutomaticStep();
    }
  }

  bool get isOnlineGame => _online != null;
  String? get onlineSessionID => _online?.sessionID;
  String? get onlineInviteCode => _online?.inviteCode;
  int? get onlinePlayerID => _online?.playerID;
  OnlineSessionUpdate? get onlineUpdate => _online?.update;
  bool get onlineWaitingForPlayers {
    final update = _online?.update;
    if (update == null) {
      return false;
    }
    final occupiedHumanSeats = {
      for (final profile in update.playerProfiles)
        if (profile.userID != null) profile.playerID,
    };
    for (var playerID = 0; playerID < update.controllers.length; playerID++) {
      if (update.controllers[playerID] == KolkhozPlayerController.human &&
          !occupiedHumanSeats.contains(playerID)) {
        return true;
      }
    }
    return false;
  }

  bool get canUndo =>
      _online == null &&
      model?.table.phase == phaseAssignment &&
      _undoStack.isNotEmpty;

  void undoLastAction() {
    if (_online != null || _undoStack.isEmpty) {
      return;
    }
    _clearAutomaticStepTimer();
    final snapshot = _undoStack.removeLast();
    final oldEngine = _engine;
    if (oldEngine != null) {
      bridge.freeEngine(oldEngine);
    }
    _engine = snapshot.engine;
    actionLog = snapshot.actionLog;
    uiState = snapshot.uiState;
    revealedPlayerID = snapshot.revealedPlayerID;
    _lastSyncedPhase = snapshot.lastSyncedPhase;
    error = null;
    _sync();
    _saveAutosave();
  }

  Future<String> hostOnlineGame({
    required Uri baseURL,
    required KolkhozGameVariants variants,
    required List<KolkhozPlayerController> controllers,
    required bool ranked,
    required bool browserJoinable,
  }) async {
    try {
      final client = KolkhozOnlineClient(
        baseURL,
        accessTokenProvider: onlineAccessTokenProvider,
      );
      final normalizedControllers = KolkhozPlayerController.normalized(
        controllers,
      );
      final response = await client.createSession(
        variants: variants,
        controllers: normalizedControllers,
        ranked: ranked,
        browserJoinable: browserJoinable,
      );
      await _connectOnline(
        client: client,
        sessionID: response.sessionID,
        inviteCode: response.inviteCode,
        playerID: response.playerID,
        seatToken: response.seatToken,
        update: response.update,
      );
      return response.sessionID;
    } catch (exception) {
      error = '$exception';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> joinOnlineGame({
    required Uri baseURL,
    required String inviteCode,
    int? preferredPlayerID,
  }) async {
    try {
      final client = KolkhozOnlineClient(
        baseURL,
        accessTokenProvider: onlineAccessTokenProvider,
      );
      final response = await client.joinSession(
        sessionID: inviteCode.trim(),
        preferredPlayerID: preferredPlayerID,
      );
      await _connectOnline(
        client: client,
        sessionID: response.sessionID,
        inviteCode: response.inviteCode,
        playerID: response.playerID,
        seatToken: response.seatToken,
        update: response.update,
      );
    } catch (exception) {
      error = '$exception';
      notifyListeners();
      rethrow;
    }
  }

  Future<String> matchmakeOnlineGame({
    required Uri baseURL,
    bool rankedOnly = false,
    bool comradesOnly = false,
  }) async {
    try {
      final client = KolkhozOnlineClient(
        baseURL,
        accessTokenProvider: onlineAccessTokenProvider,
      );
      final response = await client.matchmakeSession(
        rankedOnly: rankedOnly,
        comradesOnly: comradesOnly,
      );
      await _connectOnline(
        client: client,
        sessionID: response.sessionID,
        inviteCode: response.inviteCode,
        playerID: response.playerID,
        seatToken: response.seatToken,
        update: response.update,
      );
      return response.inviteCode;
    } catch (exception) {
      error = '$exception';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refreshOnlineGame() async {
    await _refreshOnlineGame();
  }

  Future<void> kickOnlinePlayer(int playerID) async {
    final online = _online;
    if (online == null) {
      return;
    }
    try {
      final update = await online.client.kickSessionPlayer(
        sessionID: online.sessionID,
        hostPlayerID: online.playerID,
        targetPlayerID: playerID,
        seatToken: online.seatToken,
      );
      online.update = update;
      online.legalActions = update.legalActions;
      error = null;
      _sync();
    } catch (exception) {
      error = '$exception';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _refreshOnlineGame({int? minimumRevision}) async {
    final online = _online;
    if (online == null) {
      return;
    }
    if (minimumRevision != null &&
        _knownOnlineRevision(online) >= minimumRevision) {
      return;
    }
    if (_onlineActionRefreshInFlight) {
      return;
    }
    try {
      final queued = await _fetchAndQueueOnlineUpdates(online);
      if (queued ||
          (minimumRevision != null &&
              _knownOnlineRevision(online) >= minimumRevision)) {
        error = null;
        return;
      }
      final update = await online.client.fetchUpdate(
        sessionID: online.sessionID,
        playerID: online.playerID,
        seatToken: online.seatToken,
      );
      online.update = update;
      online.legalActions = update.legalActions;
      error = null;
      _sync();
    } catch (exception) {
      error = '$exception';
      notifyListeners();
    }
  }

  void leaveOnlineGame() {
    final online = _online;
    if (online != null && model?.table.phase != phaseGameOver) {
      unawaited(_leaveOnlineGame(online));
    }
    _clearOnlineSession();
    _sync();
  }

  void revealLocalPlayer() {
    revealedPlayerID = model?.viewer.seatID;
    _sync();
  }

  void selectSwapHandCard(String cardID) {
    if (model?.table.phase != phaseSwap) {
      return;
    }
    uiState = uiState.selectSwapHandCard(cardID);
    _sync();
  }

  void selectPlotCard(String cardID, String zone) {
    if (model?.table.phase != phaseSwap) {
      return;
    }
    uiState = uiState.selectSwapPlotCard(cardID, zone);
    _sync();
  }

  void selectAssignmentCard(String cardID) {
    if (model?.table.phase != phaseAssignment) {
      return;
    }
    uiState = uiState.selectAssignmentCard(cardID);
    _sync();
  }

  void selectTrickHandCard(String cardID) {
    if (model?.table.phase != phaseTrick) {
      return;
    }
    uiState = uiState.selectTrickHandCard(cardID);
    _sync();
  }

  void _clearSelectionAfter(String actionKind) {
    uiState = uiState.clearSelectionAfterAction(actionKind);
  }

  void _sync() {
    final online = _online;
    TableViewModel? nextModel;
    if (online != null) {
      nextModel = OnlineTableProjection(
        update: online.update,
        playerID: online.playerID,
        legalActions: online.legalActions,
        uiState: uiState,
      ).project();
    } else if (_engine != null) {
      final engine = _engine!;
      nextModel = TableViewProjection(
        bridge: bridge,
        engine: engine,
        controllers: controllers,
        variants: currentVariants,
        uiState: uiState,
        revealedPlayerID: revealedPlayerID,
      ).project();
    }
    if (nextModel != null) {
      final phase = nextModel.table.phase;
      final nextUiState = uiState.clearActivePanelAfterPhaseChange(
        previousPhase: _lastSyncedPhase,
        nextPhase: phase,
      );
      if (nextUiState.activePanel != uiState.activePanel) {
        uiState = nextUiState;
        if (online != null) {
          nextModel = OnlineTableProjection(
            update: online.update,
            playerID: online.playerID,
            legalActions: online.legalActions,
            uiState: uiState,
          ).project();
        } else if (_engine != null) {
          final engine = _engine!;
          nextModel = TableViewProjection(
            bridge: bridge,
            engine: engine,
            controllers: controllers,
            variants: currentVariants,
            uiState: uiState,
            revealedPlayerID: revealedPlayerID,
          ).project();
        }
      }
      _lastSyncedPhase = phase;
      model = nextModel;
    }
    notifyListeners();
  }

  Future<void> _connectOnline({
    required KolkhozOnlineClient client,
    required String sessionID,
    required String inviteCode,
    required int playerID,
    required String seatToken,
    required OnlineSessionUpdate update,
  }) async {
    _clearAutomaticStepTimer();
    final oldEngine = _engine;
    if (oldEngine != null) {
      bridge.freeEngine(oldEngine);
      _engine = null;
    }
    _autosaveStore.clear();
    _clearUndoStack();
    _online = OnlineGameRuntime(
      client: client,
      sessionID: sessionID,
      inviteCode: inviteCode,
      playerID: playerID,
      seatToken: seatToken,
      update: update,
    );
    currentVariants = update.variants;
    controllers = update.controllers;
    restoredSavedGame = false;
    uiState = const GameUiState();
    _lastSyncedPhase = null;
    revealedPlayerID = playerID;
    _startOnlinePolling();
    _startOnlineRealtime();
    error = null;
    _sync();
  }

  void _clearOnlineSession() {
    _onlineRefreshTimer?.cancel();
    _onlineRefreshTimer = null;
    _clearOnlineUpdateQueue();
    _clearOnlineRealtime();
    _online = null;
  }

  void _clearAutomaticStepTimer() {
    _automaticStepTimer?.cancel();
    _automaticStepTimer = null;
  }

  void _scheduleAutomaticStep() {
    if (_online != null || _engine == null || _automaticStepTimer != null) {
      return;
    }
    _automaticStepTimer = Timer(
      _automaticStepDelay(_engine!),
      _runAutomaticStep,
    );
  }

  Duration _automaticStepDelay(Pointer<KCEngine> engine) {
    if (_currentAutomaticStepIsTrumpSelection(engine)) {
      return animationSpeed.automaticTrumpSelectionDelay;
    }
    return animationSpeed.automaticStepDelay;
  }

  bool _currentAutomaticStepIsTrumpSelection(Pointer<KCEngine> engine) {
    if (bridge.phase(engine) != kcPhasePlanning || bridge.isFamine(engine)) {
      return false;
    }
    final playerID = bridge.currentPlayer(engine);
    return playerID >= 0 &&
        playerID < controllers.length &&
        controllers[playerID] != KolkhozPlayerController.human;
  }

  void _runAutomaticStep() {
    _automaticStepTimer = null;
    if (_online != null) {
      return;
    }
    final engine = _engine;
    if (engine == null) {
      return;
    }
    final result = _currentAutomaticSeatUsesNeural(engine)
        ? _stepNeuralAutomatic(engine, _currentAutomaticController(engine))
        : bridge.stepAutomatic(engine);
    if (result < 0) {
      error = 'Automatic move rejected ($result)';
      notifyListeners();
      return;
    }
    if (result == 0) {
      return;
    }
    error = null;
    _sync();
    _saveAutosave();
    _scheduleAutomaticStep();
  }

  int _stepNeuralAutomatic(
    Pointer<KCEngine> engine,
    KolkhozPlayerController? controller,
  ) {
    final policy = _policyForController(controller);
    if (policy != null) {
      final action = bridge.policyAction(engine, policy.native);
      if (action == null) {
        return 0;
      }
      final error = bridge.applyAIAction(engine, action);
      if (error == 0) {
        actionLog = [...actionLog, engineActionFromCValue(action)];
        return 1;
      }
      return -error;
    }
    if (!_policyUnavailableForController(controller)) {
      _scheduleAutomaticStep();
      return 0;
    }
    return bridge.stepAutomatic(engine);
  }

  bool _currentAutomaticSeatUsesNeural(Pointer<KCEngine> engine) {
    final phase = bridge.phase(engine);
    if (phase == kcPhasePlanning && bridge.isFamine(engine)) {
      return false;
    }
    final playerID = _currentAutomaticPlayerID(engine);
    return playerID >= 0 &&
        playerID < controllers.length &&
        (controllers[playerID] == KolkhozPlayerController.mediumAI ||
            controllers[playerID] == KolkhozPlayerController.neuralAI);
  }

  int _currentAutomaticPlayerID(Pointer<KCEngine> engine) {
    return bridge.phase(engine) == kcPhaseAssignment
        ? bridge.lastWinner(engine)
        : bridge.currentPlayer(engine);
  }

  KolkhozPlayerController? _currentAutomaticController(
    Pointer<KCEngine> engine,
  ) {
    final playerID = _currentAutomaticPlayerID(engine);
    if (playerID < 0 || playerID >= controllers.length) {
      return null;
    }
    return controllers[playerID];
  }

  KolkhozNativePolicyModel? _policyForController(
    KolkhozPlayerController? controller,
  ) {
    return switch (controller) {
      KolkhozPlayerController.mediumAI => _mediumPolicy,
      KolkhozPlayerController.neuralAI => _neuralPolicy,
      _ => null,
    };
  }

  bool _policyUnavailableForController(KolkhozPlayerController? controller) {
    return switch (controller) {
      KolkhozPlayerController.mediumAI => _mediumPolicyUnavailable,
      KolkhozPlayerController.neuralAI => _neuralPolicyUnavailable,
      _ => true,
    };
  }

  void _startNeuralPolicyLoad() {
    _startMediumPolicyLoad();
    final loader = _neuralPolicyLoader;
    if (loader == null) {
      return;
    }
    unawaited(
      loader
          .then((policy) {
            _neuralPolicyLoader = null;
            if (_disposed) {
              policy.dispose();
              return;
            }
            _neuralPolicy = policy;
            error = null;
            _scheduleAutomaticStep();
          })
          .catchError((Object exception) {
            _neuralPolicyLoader = null;
            _neuralPolicyUnavailable = true;
            if (_disposed) {
              return;
            }
            error = 'Neural AI unavailable ($exception)';
            notifyListeners();
          }),
    );
  }

  void _startMediumPolicyLoad() {
    final loader = _mediumPolicyLoader;
    if (loader == null) {
      return;
    }
    unawaited(
      loader
          .then((policy) {
            _mediumPolicyLoader = null;
            if (_disposed) {
              policy.dispose();
              return;
            }
            _mediumPolicy = policy;
            error = null;
            _scheduleAutomaticStep();
          })
          .catchError((Object exception) {
            _mediumPolicyLoader = null;
            _mediumPolicyUnavailable = true;
            if (_disposed) {
              return;
            }
            error = 'Medium AI unavailable ($exception)';
            notifyListeners();
          }),
    );
  }

  void _startOnlinePolling() {
    _onlineRefreshTimer?.cancel();
    _onlineRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(refreshOnlineGame());
    });
  }

  void _startOnlineRealtime() {
    _clearOnlineRealtime();
    final online = _online;
    final client = KolkhozSupabaseRuntime.instance.client;
    if (online == null || client == null) {
      return;
    }
    final channel = client.channel('kolkhoz-game-updates-${online.sessionID}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'game_updates',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'session_id',
        value: online.sessionID,
      ),
      callback: (payload) {
        final revision = _revisionFromRealtimePayload(payload);
        unawaited(_refreshOnlineGameFromRealtime(revision));
      },
    );
    channel.subscribe();
    _onlineRealtimeChannel = channel;
  }

  Future<void> _refreshOnlineGameFromRealtime(int? revision) async {
    if (_onlineRealtimeRefreshInFlight) {
      return;
    }
    _onlineRealtimeRefreshInFlight = true;
    try {
      await _refreshOnlineGame(minimumRevision: revision);
    } finally {
      _onlineRealtimeRefreshInFlight = false;
    }
  }

  int? _revisionFromRealtimePayload(PostgresChangePayload payload) {
    final record = payload.newRecord;
    final direct = record['revision'];
    if (direct is int) {
      return direct;
    }
    final nested = record['payload'];
    if (nested is Map) {
      final value = nested['revision'];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
    }
    return null;
  }

  void _clearOnlineRealtime() {
    final channel = _onlineRealtimeChannel;
    _onlineRealtimeChannel = null;
    _onlineRealtimeRefreshInFlight = false;
    if (channel != null) {
      unawaited(KolkhozSupabaseRuntime.instance.client?.removeChannel(channel));
    }
  }

  Future<void> _submitOnlineAction(
    OnlineGameRuntime online,
    LegalAction action,
  ) async {
    final beforeRevision = online.update.actionLogCount;
    try {
      final update = await online.client.submitAction(
        sessionID: online.sessionID,
        playerID: online.playerID,
        seatToken: online.seatToken,
        actionLogCount: online.update.actionLogCount,
        action: action.engineAction,
      );
      error = null;
      _clearSelectionAfter(action.kind);
      final queued = await _fetchAndQueueOnlineUpdates(
        online,
        afterRevision: beforeRevision,
      );
      if (!queued) {
        online.update = update;
        online.legalActions = update.legalActions;
        _sync();
      }
    } catch (exception) {
      error = '$exception';
      notifyListeners();
    }
  }

  Future<bool> _fetchAndQueueOnlineUpdates(
    OnlineGameRuntime online, {
    int? afterRevision,
  }) async {
    if (_onlineActionRefreshInFlight) {
      return false;
    }
    _onlineActionRefreshInFlight = true;
    try {
      final response = await online.client.fetchActionUpdates(
        sessionID: online.sessionID,
        playerID: online.playerID,
        seatToken: online.seatToken,
        afterRevision: afterRevision ?? _knownOnlineRevision(online),
      );
      final known = _knownOnlineRevision(online);
      final updates = response.updates
          .where((update) => update.revision > known)
          .toList(growable: false);
      if (updates.isEmpty) {
        return false;
      }
      _onlineUpdateQueue.addAll(updates);
      _drainNextOnlineUpdate();
      return true;
    } finally {
      _onlineActionRefreshInFlight = false;
    }
  }

  int _knownOnlineRevision(OnlineGameRuntime online) {
    if (_onlineUpdateQueue.isNotEmpty) {
      return _onlineUpdateQueue.last.revision;
    }
    return online.update.actionLogCount;
  }

  void _drainNextOnlineUpdate() {
    final online = _online;
    if (online == null || _onlineUpdateQueueTimer != null) {
      return;
    }
    if (_onlineUpdateQueue.isEmpty) {
      return;
    }
    final next = _onlineUpdateQueue.removeAt(0);
    final hasPendingUpdates = _onlineUpdateQueue.isNotEmpty;
    final update = hasPendingUpdates
        ? next.update.copyWith(legalActions: const [])
        : next.update;
    online.update = update;
    online.legalActions = update.legalActions;
    error = null;
    _sync();
    if (hasPendingUpdates) {
      _onlineUpdateQueueTimer = Timer(_onlineQueueStepDelay, () {
        _onlineUpdateQueueTimer = null;
        _drainNextOnlineUpdate();
      });
    }
  }

  Duration get _onlineQueueStepDelay {
    final flight = animationSpeed.cardFlightDuration;
    if (flight == Duration.zero) {
      return Duration.zero;
    }
    return flight + const Duration(milliseconds: 80);
  }

  void _clearOnlineUpdateQueue() {
    _onlineUpdateQueueTimer?.cancel();
    _onlineUpdateQueueTimer = null;
    _onlineUpdateQueue.clear();
    _onlineActionRefreshInFlight = false;
  }

  Future<void> _leaveOnlineGame(OnlineGameRuntime online) async {
    try {
      await online.client.leaveSession(
        sessionID: online.sessionID,
        playerID: online.playerID,
        seatToken: online.seatToken,
      );
    } catch (_) {
      // Leaving should not trap the player in the local client if the server is gone.
    }
  }

  bool _restoreAutosave() {
    if (!autosaveEnabled) {
      return false;
    }
    final payload = _autosaveStore.load();
    if (payload == null) {
      return false;
    }
    Pointer<KCEngine>? restoredEngine;
    try {
      restoredEngine = bridge.newEngine(
        seed: payload.seed,
        variants: payload.variants,
        controllers: payload.controllers,
      );
      for (final action in payload.actions) {
        final cAction = cEngineAction(action);
        if (cAction == null) {
          throw const FormatException('Saved action cannot be replayed');
        }
        final result = _applyRestoredAction(
          restoredEngine,
          cAction,
          payload.controllers,
        );
        if (result != 0) {
          throw FormatException('Saved action rejected ($result)');
        }
      }
      controllers = KolkhozPlayerController.normalized(payload.controllers);
      currentVariants = payload.variants;
      currentSeed = payload.seed;
      actionLog = List.of(payload.actions);
      _clearUndoStack();
      restoredSavedGame = true;
      uiState = const GameUiState();
      _lastSyncedPhase = null;
      revealedPlayerID = null;
      _engine = restoredEngine;
      error = null;
      _sync();
      if (model?.table.phase == phaseGameOver) {
        _autosaveStore.clear();
        return false;
      }
      _scheduleAutomaticStep();
      return true;
    } catch (_) {
      if (restoredEngine != null) {
        bridge.freeEngine(restoredEngine);
      }
      _engine = null;
      _autosaveStore.clear();
      return false;
    }
  }

  int _applyRestoredAction(
    Pointer<KCEngine> engine,
    CEngineActionValue action,
    List<KolkhozPlayerController> restoredControllers,
  ) {
    if (action.playerID >= 0 &&
        action.playerID < restoredControllers.length &&
        (restoredControllers[action.playerID] ==
                KolkhozPlayerController.mediumAI ||
            restoredControllers[action.playerID] ==
                KolkhozPlayerController.neuralAI)) {
      return bridge.applyAIAction(engine, action);
    }
    return bridge.apply(engine, action);
  }

  void _saveAutosave() {
    if (!autosaveEnabled) {
      return;
    }
    if (model?.table.phase == phaseGameOver) {
      _autosaveStore.clear();
      return;
    }
    _autosaveStore.save(
      KolkhozSavedGamePayload(
        seed: currentSeed,
        variants: currentVariants,
        controllers: controllers,
        actions: actionLog,
      ),
    );
  }

  GameUndoSnapshot _snapshotForUndo(Pointer<KCEngine> engine) {
    return GameUndoSnapshot(
      engine: bridge.cloneEngine(engine),
      actionLog: List.of(actionLog),
      uiState: uiState,
      revealedPlayerID: revealedPlayerID,
      lastSyncedPhase: _lastSyncedPhase,
    );
  }

  void _clearUndoStack() {
    for (final snapshot in _undoStack) {
      snapshot.dispose(bridge);
    }
    _undoStack.clear();
  }

  int _newSeed() => DateTime.now().microsecondsSinceEpoch;

  @override
  void dispose() {
    _disposed = true;
    _clearAutomaticStepTimer();
    _clearUndoStack();
    final engine = _engine;
    if (engine != null) {
      bridge.freeEngine(engine);
      _engine = null;
    }
    _mediumPolicy?.dispose();
    _mediumPolicy = null;
    _neuralPolicy?.dispose();
    _neuralPolicy = null;
    _onlineRefreshTimer?.cancel();
    _onlineRefreshTimer = null;
    _clearOnlineUpdateQueue();
    _clearOnlineRealtime();
    super.dispose();
  }
}

class GameUndoSnapshot {
  const GameUndoSnapshot({
    required this.engine,
    required this.actionLog,
    required this.uiState,
    required this.revealedPlayerID,
    required this.lastSyncedPhase,
  });

  final Pointer<KCEngine> engine;
  final List<EngineAction> actionLog;
  final GameUiState uiState;
  final int? revealedPlayerID;
  final String? lastSyncedPhase;

  void dispose(KolkhozCEngineBridge bridge) {
    bridge.freeEngine(engine);
  }
}

class OnlineGameRuntime {
  OnlineGameRuntime({
    required this.client,
    required this.sessionID,
    required this.inviteCode,
    required this.playerID,
    required this.seatToken,
    required this.update,
  }) : legalActions = update.legalActions;

  final KolkhozOnlineClient client;
  final String sessionID;
  final String inviteCode;
  final int playerID;
  final String seatToken;
  OnlineSessionUpdate update;
  List<OnlineEngineAction> legalActions;
}
