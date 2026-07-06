import 'dart:async';
import 'dart:ffi';

import 'package:flutter/foundation.dart';

import 'animation_speed.dart';
import 'c_engine_action_codec.dart';
import 'c_engine_bridge.dart';
import 'engine_action_projection.dart';
import 'game_constants.dart';
import 'game_ui_state.dart';
import 'online_game_models.dart';
import 'online_table_projection.dart';
import 'render_model.dart';
import 'design_tokens.dart';
import 'saved_game_store.dart';
import 'table_view_projection.dart';

class LiveGameStore extends ChangeNotifier {
  LiveGameStore({
    KolkhozCEngineBridge? bridge,
    KolkhozAutosaveStore? autosaveStore,
    this.autosaveEnabled = true,
  }) : bridge = bridge ?? KolkhozCEngineBridge(),
       _autosaveStore = autosaveStore ?? KolkhozAutosaveStore.defaultStore() {
    if (!_restoreAutosave()) {
      newGame(persist: false);
    }
  }

  final KolkhozCEngineBridge bridge;
  final KolkhozAutosaveStore _autosaveStore;
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
  Timer? _automaticStepTimer;
  TableViewModel? model;
  Pointer<KCEngine>? _engine;
  int? revealedPlayerID;
  String? error;

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
      restoredSavedGame = false;
      uiState = const GameUiState();
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
    final result = bridge.applyManual(engine, cAction);
    if (result != 0) {
      error = 'Move rejected ($result)';
    } else {
      error = null;
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
  int? get onlinePlayerID => _online?.playerID;

  Future<String> hostOnlineGame({
    required Uri baseURL,
    required KolkhozGameVariants variants,
    required List<KolkhozPlayerController> controllers,
  }) async {
    try {
      final client = KolkhozOnlineClient(baseURL);
      final normalizedControllers = KolkhozPlayerController.normalized(
        controllers,
      );
      final response = await client.createSession(
        variants: variants,
        controllers: normalizedControllers,
      );
      await _connectOnline(
        client: client,
        sessionID: response.sessionID,
        playerID: response.playerID,
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
      final client = KolkhozOnlineClient(baseURL);
      final response = await client.joinSession(
        sessionID: inviteCode.trim(),
        preferredPlayerID: preferredPlayerID,
      );
      await _connectOnline(
        client: client,
        sessionID: response.sessionID,
        playerID: response.playerID,
        update: response.update,
      );
    } catch (exception) {
      error = '$exception';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refreshOnlineGame() async {
    final online = _online;
    if (online == null) {
      return;
    }
    try {
      final update = await online.client.fetchUpdate(
        sessionID: online.sessionID,
        playerID: online.playerID,
      );
      online.update = update;
      await _refreshOnlineLegalActions(online);
      error = null;
      _sync();
    } catch (exception) {
      error = '$exception';
      notifyListeners();
    }
  }

  void leaveOnlineGame() {
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

  void _clearSelectionAfter(String actionKind) {
    uiState = uiState.clearSelectionAfterAction(actionKind);
  }

  void _sync() {
    final online = _online;
    if (online != null) {
      model = OnlineTableProjection(
        update: online.update,
        playerID: online.playerID,
        legalActions: online.legalActions,
        uiState: uiState,
      ).project();
    } else if (_engine != null) {
      final engine = _engine!;
      model = TableViewProjection(
        bridge: bridge,
        engine: engine,
        controllers: controllers,
        variants: currentVariants,
        uiState: uiState,
        revealedPlayerID: revealedPlayerID,
      ).project();
    }
    notifyListeners();
  }

  Future<void> _connectOnline({
    required KolkhozOnlineClient client,
    required String sessionID,
    required int playerID,
    required OnlineSessionUpdate update,
  }) async {
    _clearAutomaticStepTimer();
    final oldEngine = _engine;
    if (oldEngine != null) {
      bridge.freeEngine(oldEngine);
      _engine = null;
    }
    _autosaveStore.clear();
    _online = OnlineGameRuntime(
      client: client,
      sessionID: sessionID,
      playerID: playerID,
      update: update,
    );
    currentVariants = update.variants;
    controllers = update.controllers;
    restoredSavedGame = false;
    uiState = const GameUiState();
    revealedPlayerID = playerID;
    await _refreshOnlineLegalActions(_online!);
    _startOnlinePolling();
    error = null;
    _sync();
  }

  void _clearOnlineSession() {
    _onlineRefreshTimer?.cancel();
    _onlineRefreshTimer = null;
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
      animationSpeed.automaticStepDelay,
      _runAutomaticStep,
    );
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
    final result = bridge.stepAutomatic(engine);
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

  void _startOnlinePolling() {
    _onlineRefreshTimer?.cancel();
    _onlineRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(refreshOnlineGame());
    });
  }

  Future<void> _submitOnlineAction(
    OnlineGameRuntime online,
    LegalAction action,
  ) async {
    try {
      final update = await online.client.submitAction(
        sessionID: online.sessionID,
        playerID: online.playerID,
        action: action.engineAction,
      );
      online.update = update;
      await _refreshOnlineLegalActions(online);
      error = null;
      _clearSelectionAfter(action.kind);
      _sync();
    } catch (exception) {
      error = '$exception';
      notifyListeners();
    }
  }

  Future<void> _refreshOnlineLegalActions(OnlineGameRuntime online) async {
    final snapshot = online.update.snapshot;
    final phase = phaseName(snapshot.phase);
    final shouldFetch =
        phase != phaseGameOver &&
        (snapshot.currentPlayer == online.playerID ||
            (phase == phaseAssignment &&
                snapshot.lastWinner == online.playerID) ||
            phase == phaseRequisition);
    if (!shouldFetch) {
      online.legalActions = [];
      return;
    }
    online.legalActions = await online.client.fetchLegalActions(
      sessionID: online.sessionID,
      playerID: online.playerID,
    );
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
        final result = bridge.apply(restoredEngine, cAction);
        if (result != 0) {
          throw FormatException('Saved action rejected ($result)');
        }
      }
      controllers = KolkhozPlayerController.normalized(payload.controllers);
      currentVariants = payload.variants;
      currentSeed = payload.seed;
      actionLog = List.of(payload.actions);
      restoredSavedGame = true;
      uiState = const GameUiState();
      revealedPlayerID = null;
      _engine = restoredEngine;
      error = null;
      _sync();
      if (model?.table.phase == phaseGameOver) {
        _autosaveStore.clear();
        return false;
      }
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

  int _newSeed() => DateTime.now().microsecondsSinceEpoch;

  @override
  void dispose() {
    _clearAutomaticStepTimer();
    final engine = _engine;
    if (engine != null) {
      bridge.freeEngine(engine);
      _engine = null;
    }
    _onlineRefreshTimer?.cancel();
    _onlineRefreshTimer = null;
    super.dispose();
  }
}

class OnlineGameRuntime {
  OnlineGameRuntime({
    required this.client,
    required this.sessionID,
    required this.playerID,
    required this.update,
  });

  final KolkhozOnlineClient client;
  final String sessionID;
  final int playerID;
  OnlineSessionUpdate update;
  List<OnlineEngineAction> legalActions = [];
}
