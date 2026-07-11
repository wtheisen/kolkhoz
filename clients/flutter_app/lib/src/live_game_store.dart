import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'animation_speed.dart';
import 'assignment_display.dart';
import 'c_engine_action_codec.dart';
import 'c_engine_bridge.dart';
import 'game_constants.dart';
import 'game_ui_state.dart';
import 'online_game_models.dart';
import 'online_game_client.dart';
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

const onlineGameRefreshInterval = Duration(seconds: 1);
const onlineGameRealtimeRefreshInterval = Duration(seconds: 15);

bool isStaleOnlineActionError(Object error) {
  return error is OnlineRequestException &&
      error.statusCode == HttpStatus.conflict &&
      error.message == 'stale action';
}

bool onlineActionMatches(OnlineEngineAction candidate, EngineAction action) {
  return jsonEncode(candidate.toJson()) ==
      jsonEncode(OnlineEngineAction.fromEngineAction(action).toJson());
}

Duration onlineActionAnimationDelay({
  required GameAnimationSpeed speed,
  required OnlineEngineAction action,
  required int viewerPlayerID,
}) {
  final scale = switch (action.kind) {
    kcActionAssign => jobAssignmentCardFlightDurationScale,
    kcActionContinueAfterRequisition => requisitionCardFlightDurationScale,
    kcActionPlayCard when action.playerID != viewerPlayerID =>
      playerInfoCardFlightDurationScale,
    _ => 1.0,
  };
  final flight = scaledGameAnimationDuration(speed.cardFlightDuration, scale);
  if (flight == Duration.zero) {
    return Duration.zero;
  }
  return flight + const Duration(milliseconds: 80);
}

GameUiState autoSelectCards(GameUiState uiState, TableViewModel model) {
  if (model.table.phase == phaseTrick) {
    final plays = model.legalActions
        .where((action) => action.kind == actionPlayCard)
        .toList(growable: false);
    if (plays.length == 1) {
      final cardID = plays.single.engineAction.card?.id;
      if (cardID != null && uiState.selection.handCardID != cardID) {
        return uiState.copyWith(
          selection: uiState.selection.copyWith(handCardID: cardID),
        );
      }
    }
    return uiState;
  }
  if (model.table.phase == phaseAssignment) {
    final cards = assignmentControlCards(model);
    if (cards.isNotEmpty &&
        !cards.any((card) => card.id == uiState.selection.assignmentCardID)) {
      return uiState.selectAssignmentCard(cards.last.id);
    }
  }
  return uiState;
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
    this.onlineDeviceID,
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
  final String? onlineDeviceID;
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
    if (panel == panelLog) {
      _online?.hasUnreadReactions = false;
    }
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
  List<EngineAction> get gameLogActions => _online == null
      ? List.unmodifiable(actionLog)
      : [
          for (final action in _online!.update.gameLogActions)
            action.engineAction,
        ];
  List<OnlineReaction> get gameReactions =>
      List.unmodifiable(_online?.update.reactions ?? const []);
  OnlineReaction? get activeReaction => _online?.activeReaction;
  bool get hasUnreadReactions => _online?.hasUnreadReactions ?? false;
  bool get canSendReaction => _online?.update.started ?? false;

  Future<File> saveGameLog() async {
    final base = KolkhozAutosaveStore.defaultFile().parent;
    final directory = Directory('${base.path}/match-logs');
    await directory.create(recursive: true);
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      ':',
      '-',
    );
    final file = File('${directory.path}/kolkhoz-match-$timestamp.json');
    final reactions = gameReactions;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'seed': currentSeed,
        'variants': variantsToJson(currentVariants),
        'controllers': controllers
            .map((controller) => controller.name)
            .toList(),
        'actions': gameLogActions.map(engineActionToJson).toList(),
        'reactions': [
          for (final reaction in reactions)
            {
              'revision': reaction.revision,
              'playerID': reaction.playerID,
              'reactionID': reaction.reactionID,
              'year': reaction.year,
              'phase': reaction.phase,
              'createdAt': reaction.createdAt,
            },
        ],
      }),
      flush: true,
    );
    return file;
  }

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
        deviceID: onlineDeviceID,
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
        deviceID: onlineDeviceID,
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
        deviceID: onlineDeviceID,
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

  Future<void> syncActiveOnlineGame({required Uri baseURL}) async {
    final client = KolkhozOnlineClient(
      baseURL,
      accessTokenProvider: onlineAccessTokenProvider,
      deviceID: onlineDeviceID,
    );
    final response = await client.syncActiveSession();
    await _connectOnline(
      client: client,
      sessionID: response.sessionID,
      inviteCode: response.inviteCode,
      playerID: response.playerID,
      seatToken: response.seatToken,
      update: response.update,
    );
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
      _acceptOnlineUpdate(online, update);
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
    if (online.actionRefreshInFlight) {
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
      _acceptOnlineUpdate(online, update);
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

  Future<void> sendReaction(String reactionID) async {
    final online = _online;
    if (online == null || !online.update.started) {
      return;
    }
    try {
      final update = await online.client.submitReaction(
        sessionID: online.sessionID,
        playerID: online.playerID,
        seatToken: online.seatToken,
        reactionID: reactionID,
      );
      _acceptOnlineUpdate(online, update);
      online.legalActions = update.legalActions;
      error = null;
      _sync();
    } catch (exception) {
      error = '$exception';
      notifyListeners();
    }
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
      final nextUiState = autoSelectCards(
        uiState.clearActivePanelAfterPhaseChange(
          previousPhase: _lastSyncedPhase,
          nextPhase: phase,
        ),
        nextModel,
      );
      if (!identical(nextUiState, uiState)) {
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
    currentSeed = update.seed ?? currentSeed;
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
    _online?.dispose();
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
        : _stepHeuristicAutomatic(engine);
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
    return _stepHeuristicAutomatic(engine);
  }

  int _stepHeuristicAutomatic(Pointer<KCEngine> engine) {
    if (bridge.phase(engine) == kcPhasePlanning && bridge.isFamine(engine)) {
      return bridge.stepAutomatic(engine);
    }
    final action = bridge.heuristicAction(engine);
    if (action == null) {
      return 0;
    }
    final error = bridge.applyAIAction(engine, action);
    if (error != 0) {
      return -error;
    }
    actionLog = [...actionLog, engineActionFromCValue(action)];
    return 1;
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

  void _startOnlinePolling({Duration interval = onlineGameRefreshInterval}) {
    final online = _online;
    if (online == null) {
      return;
    }
    online.refreshTimer?.cancel();
    online.refreshTimer = Timer.periodic(interval, (_) {
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
    channel.subscribe((status, _) {
      if (online.realtimeChannel != channel) {
        return;
      }
      _startOnlinePolling(
        interval: status == RealtimeSubscribeStatus.subscribed
            ? onlineGameRealtimeRefreshInterval
            : onlineGameRefreshInterval,
      );
    });
    online.realtimeChannel = channel;
  }

  Future<void> _refreshOnlineGameFromRealtime(int? revision) async {
    final online = _online;
    if (online == null) {
      return;
    }
    if (online.realtimeRefreshInFlight) {
      online.rememberPendingRealtimeRefresh(revision);
      return;
    }
    online.realtimeRefreshInFlight = true;
    var targetRevision = revision;
    try {
      while (!_disposed && identical(_online, online)) {
        await _refreshOnlineGame(minimumRevision: targetRevision);
        if (!online.realtimeRefreshPending) {
          break;
        }
        targetRevision = online.pendingRealtimeRevision;
        online.realtimeRefreshPending = false;
        online.pendingRealtimeRevision = null;
      }
    } finally {
      online.realtimeRefreshInFlight = false;
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
    _online?.clearRealtimeChannel();
  }

  Future<void> _submitOnlineAction(
    OnlineGameRuntime online,
    LegalAction action,
  ) async {
    final selectionBeforeSubmit = uiState;
    _clearSelectionAfter(action.kind);
    _sync();
    try {
      var beforeRevision = online.update.actionLogCount;
      OnlineSessionUpdate update;
      try {
        update = await online.client.submitAction(
          sessionID: online.sessionID,
          playerID: online.playerID,
          seatToken: online.seatToken,
          actionLogCount: beforeRevision,
          action: action.engineAction,
        );
      } catch (exception) {
        if (!isStaleOnlineActionError(exception)) {
          rethrow;
        }
        final refreshed = await online.client.fetchUpdate(
          sessionID: online.sessionID,
          playerID: online.playerID,
          seatToken: online.seatToken,
        );
        _acceptOnlineUpdate(online, refreshed);
        online.legalActions = refreshed.legalActions;
        if (!refreshed.legalActions.any(
          (candidate) => onlineActionMatches(candidate, action.engineAction),
        )) {
          error = null;
          _sync();
          return;
        }
        beforeRevision = refreshed.actionLogCount;
        update = await online.client.submitAction(
          sessionID: online.sessionID,
          playerID: online.playerID,
          seatToken: online.seatToken,
          actionLogCount: beforeRevision,
          action: action.engineAction,
        );
      }
      error = null;
      final queued = await _fetchAndQueueOnlineUpdates(
        online,
        afterRevision: beforeRevision,
      );
      if (!queued) {
        _acceptOnlineUpdate(online, update);
        online.legalActions = update.legalActions;
        _sync();
      }
    } catch (exception) {
      uiState = selectionBeforeSubmit;
      error = '$exception';
      _sync();
    }
  }

  Future<bool> _fetchAndQueueOnlineUpdates(
    OnlineGameRuntime online, {
    int? afterRevision,
  }) async {
    if (online.actionRefreshInFlight) {
      return false;
    }
    online.actionRefreshInFlight = true;
    try {
      final response = await online.client.fetchActionUpdates(
        sessionID: online.sessionID,
        playerID: online.playerID,
        seatToken: online.seatToken,
        afterRevision: afterRevision ?? _knownOnlineRevision(online),
      );
      final known = _knownOnlineRevision(online);
      final resyncUpdate = response.resyncUpdate;
      if (resyncUpdate != null) {
        _clearOnlineUpdateQueue();
        _acceptOnlineUpdate(online, resyncUpdate);
        online.legalActions = resyncUpdate.legalActions;
        _sync();
        return true;
      }
      final updates = response.updates
          .where((update) => update.revision > known)
          .toList(growable: false);
      if (updates.isEmpty) {
        return false;
      }
      online.updateQueue.addAll(updates);
      _drainNextOnlineUpdate();
      return true;
    } finally {
      online.actionRefreshInFlight = false;
    }
  }

  int _knownOnlineRevision(OnlineGameRuntime online) {
    if (online.updateQueue.isNotEmpty) {
      return online.updateQueue.last.revision;
    }
    return online.update.actionLogCount;
  }

  void _drainNextOnlineUpdate() {
    final online = _online;
    if (online == null || online.updateQueueTimer != null) {
      return;
    }
    if (online.updateQueue.isEmpty) {
      return;
    }
    final next = online.updateQueue.removeAt(0);
    final hasPendingUpdates = online.updateQueue.isNotEmpty;
    final update = hasPendingUpdates
        ? next.update.copyWith(legalActions: const [])
        : next.update;
    _acceptOnlineUpdate(online, update);
    online.legalActions = update.legalActions;
    error = null;
    _sync();
    if (hasPendingUpdates) {
      online.updateQueueTimer = Timer(
        onlineActionAnimationDelay(
          speed: animationSpeed,
          action: next.action,
          viewerPlayerID: online.playerID,
        ),
        () {
          online.updateQueueTimer = null;
          _drainNextOnlineUpdate();
        },
      );
    }
  }

  void _clearOnlineUpdateQueue() {
    _online?.clearUpdateQueue();
  }

  void _acceptOnlineUpdate(
    OnlineGameRuntime online,
    OnlineSessionUpdate update,
  ) {
    final previousRevision = online.update.reactions.isEmpty
        ? 0
        : online.update.reactions.last.revision;
    online.update = update;
    final newRemoteReactions = update.reactions.where(
      (reaction) =>
          reaction.revision > previousRevision &&
          reaction.playerID != online.playerID,
    );
    if (newRemoteReactions.isEmpty) {
      return;
    }
    final latest = newRemoteReactions.last;
    online.activeReaction = latest;
    if (uiState.activePanel != panelLog) {
      online.hasUnreadReactions = true;
    }
    online.reactionFlashTimer?.cancel();
    online.reactionFlashTimer = Timer(const Duration(seconds: 3), () {
      online.reactionFlashTimer = null;
      online.activeReaction = null;
      if (!_disposed && identical(_online, online)) {
        notifyListeners();
      }
    });
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
        restoredControllers[action.playerID] != KolkhozPlayerController.human) {
      return bridge.applyAIAction(engine, action);
    }
    return bridge.applyManual(engine, action);
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
    _clearOnlineSession();
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
  Timer? refreshTimer;
  RealtimeChannel? realtimeChannel;
  bool realtimeRefreshInFlight = false;
  bool realtimeRefreshPending = false;
  int? pendingRealtimeRevision;
  bool actionRefreshInFlight = false;
  Timer? updateQueueTimer;
  final List<OnlineActionUpdate> updateQueue = [];
  Timer? reactionFlashTimer;
  OnlineReaction? activeReaction;
  bool hasUnreadReactions = false;

  void rememberPendingRealtimeRefresh(int? revision) {
    if (!realtimeRefreshPending) {
      realtimeRefreshPending = true;
      pendingRealtimeRevision = revision;
      return;
    }
    pendingRealtimeRevision = newestOnlineRevision(
      pendingRealtimeRevision,
      revision,
    );
  }

  void clearUpdateQueue() {
    updateQueueTimer?.cancel();
    updateQueueTimer = null;
    updateQueue.clear();
    actionRefreshInFlight = false;
  }

  void clearRealtimeChannel() {
    final channel = realtimeChannel;
    realtimeChannel = null;
    realtimeRefreshInFlight = false;
    realtimeRefreshPending = false;
    pendingRealtimeRevision = null;
    if (channel != null) {
      unawaited(KolkhozSupabaseRuntime.instance.client?.removeChannel(channel));
    }
  }

  void dispose() {
    refreshTimer?.cancel();
    refreshTimer = null;
    clearUpdateQueue();
    clearRealtimeChannel();
    reactionFlashTimer?.cancel();
    reactionFlashTimer = null;
    activeReaction = null;
    hasUnreadReactions = false;
  }
}

int? newestOnlineRevision(int? current, int? incoming) {
  if (current == null || incoming == null) {
    return null;
  }
  return incoming > current ? incoming : current;
}
