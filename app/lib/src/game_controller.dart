import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'animation_speed.dart';
import 'assignment_display.dart';
import 'c_engine_action_codec.dart';
import 'c_engine_bridge.dart';
import 'engine_action_projection.dart';
import 'finished_game_lobby.dart';
import 'game_channel.dart';
import 'game_channel_local.dart';
import 'game_channel_online.dart';
import 'game_constants.dart';
import 'game_engine.dart';
import 'game_event_queue.dart';
import 'game_lobby.dart';
import 'game_state_snapshot.dart';
import 'game_ui_state.dart';
import 'game_undo_snapshot.dart';
import 'online_game_models.dart';
import 'online_game_client.dart';
import 'online_table_projection.dart';
import 'policy_model.dart';
import 'player.dart';
import 'player_ai_heuristic.dart';
import 'player_ai_neural.dart';
import 'player_human.dart';
import 'render_model.dart';
import 'design_tokens.dart';
import 'saved_game_store.dart';

export 'game_channel_online.dart'
    show
        isStaleOnlineActionError,
        onlineActionMatches,
        onlineActionResultIsSingleRevision,
        onlineGameRealtimeRefreshInterval,
        onlineGameRefreshInterval;

bool actionCapturesUndoSnapshot(String actionKind) {
  return actionKind == actionAssign;
}

enum GameControllerLifecycle { lobby, starting, playing, finishing, finished }

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

class GameController extends ChangeNotifier {
  GameController({
    KolkhozCEngineBridge? bridge,
    KolkhozAutosaveStore? autosaveStore,
    KolkhozNativePolicyModel? mediumPolicy,
    Future<KolkhozNativePolicyModel>? mediumPolicyLoader,
    KolkhozNativePolicyModel? neuralPolicy,
    Future<KolkhozNativePolicyModel>? neuralPolicyLoader,
    this.onlineAccessTokenProvider,
    this.onlineDeviceID,
    this.onlineHttpClient,
    this.onlineWebSocketConnector,
    this.onlineRealtimeReconnectDelay = const Duration(seconds: 1),
    this.autosaveEnabled = true,
  }) : _bridge = bridge ?? KolkhozCEngineBridge(),
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
    _replacePlayers(KolkhozPlayerController.defaultControllers);
    lobby = _buildLobby(KolkhozGameVariants.kolkhoz);
    _restoreAutosave();
    _startNeuralPolicyLoad();
  }

  final KolkhozCEngineBridge _bridge;
  final KolkhozAutosaveStore _autosaveStore;
  KolkhozNativePolicyModel? _mediumPolicy;
  Future<KolkhozNativePolicyModel>? _mediumPolicyLoader;
  KolkhozNativePolicyModel? _neuralPolicy;
  Future<KolkhozNativePolicyModel>? _neuralPolicyLoader;
  final Future<String?> Function()? onlineAccessTokenProvider;
  final String? onlineDeviceID;
  final HttpClient? onlineHttpClient;
  final OnlineWebSocketConnector? onlineWebSocketConnector;
  final Duration onlineRealtimeReconnectDelay;
  final bool autosaveEnabled;

  DesignTokens tokens = defaultDesignTokens;
  GameAnimationSpeed animationSpeed = defaultGameAnimationSpeed;
  GameUiState uiState = const GameUiState();
  GameControllerLifecycle lifecycle = GameControllerLifecycle.lobby;
  late GameLobby lobby;
  late List<GamePlayer> _players;
  List<GamePlayer> get players => List.unmodifiable(_players);
  List<KolkhozPlayerController> get controllers =>
      List.unmodifiable(_players.map((player) => player.controller));
  KolkhozGameVariants currentVariants = KolkhozGameVariants.kolkhoz;
  int currentSeed = 0;
  List<EngineAction> actionLog = [];
  List<EngineAction> localGameLog = [];
  bool restoredSavedGame = false;
  GameChannel? _channel;
  StreamSubscription<GameEvent>? _channelEvents;
  OnlineSessionUpdate? _onlineUpdate;
  List<OnlineEngineAction> _onlineLegalActions = const [];
  final GameEventQueue _eventQueue = GameEventQueue();
  GameUiState? _onlineSelectionBeforeCommand;
  GameUndoSnapshot? _pendingLocalUndoSnapshot;
  int? _automaticPhaseBefore;
  int _automaticRequisitionCountBefore = 0;
  Timer? _reactionFlashTimer;
  OnlineReaction? _activeReaction;
  bool _hasUnreadReactions = false;
  Timer? _automaticStepTimer;
  int _localPresentationSequence = 0;
  int? _awaitingLocalPresentationRevision;
  TableViewModel? _model;
  TableViewModel? get model => finishedGameLobby?.model ?? _model;
  FinishedGameLobby? finishedGameLobby;
  LocalGameChannel? get _localChannel =>
      _channel is LocalGameChannel ? _channel as LocalGameChannel : null;
  OnlineGameChannel? get _onlineChannel =>
      _channel is OnlineGameChannel ? _channel as OnlineGameChannel : null;
  bool get hasActiveEngine => _localChannel != null;
  final List<GameUndoSnapshot> _undoStack = [];
  int? revealedPlayerID;
  String? error;
  String? _lastSyncedPhase;
  bool _mediumPolicyUnavailable = false;
  bool _neuralPolicyUnavailable = false;
  bool _disposed = false;

  void configureLobby({
    required KolkhozGameVariants variants,
    required List<KolkhozPlayerController> controllers,
  }) {
    if (lifecycle != GameControllerLifecycle.lobby || _channel != null) {
      throw StateError(
        'Lobby configuration is frozen after online handoff or game start',
      );
    }
    _replacePlayers(controllers);
    currentVariants = variants;
    lobby = _buildLobby(variants, spectators: lobby.spectators);
    notifyListeners();
  }

  void addSpectator(GameSpectator spectator) {
    final spectators = [
      for (final existing in lobby.spectators)
        if (existing.id != spectator.id) existing,
      spectator,
    ];
    lobby = lobby.copyWith(spectators: spectators);
    notifyListeners();
  }

  void removeSpectator(String spectatorID) {
    final spectators = lobby.spectators
        .where((spectator) => spectator.id != spectatorID)
        .toList(growable: false);
    if (spectators.length == lobby.spectators.length) {
      return;
    }
    lobby = lobby.copyWith(spectators: spectators);
    notifyListeners();
  }

  void startGame({
    KolkhozGameVariants? variants,
    List<KolkhozPlayerController>? controllers,
    bool persist = true,
  }) {
    try {
      _clearAutomaticStepTimer();
      _awaitingLocalPresentationRevision = null;
      _clearChannel();
      final normalizedControllers = KolkhozPlayerController.normalized(
        controllers ?? this.controllers,
      );
      _replacePlayers(normalizedControllers);
      currentVariants = variants ?? lobby.variants;
      lobby = _buildLobby(currentVariants, spectators: lobby.spectators);
      if (!lobby.readyToStart) {
        throw StateError('All four seats must be ready before starting');
      }
      lifecycle = GameControllerLifecycle.starting;
      currentSeed = _newSeed();
      actionLog = [];
      localGameLog = [];
      finishedGameLobby = null;
      _clearUndoStack();
      restoredSavedGame = false;
      uiState = const GameUiState();
      _lastSyncedPhase = null;
      revealedPlayerID = null;
      _setChannel(
        LocalGameChannel(
          GameEngine(
            bridge: _bridge,
            seed: currentSeed,
            variants: currentVariants,
            controllers: normalizedControllers,
          ),
        ),
      );
      lifecycle = GameControllerLifecycle.playing;
      error = null;
      _sync();
      if (persist) {
        _saveAutosave();
      }
      _scheduleAutomaticStep();
    } catch (exception) {
      _clearChannel();
      lifecycle = GameControllerLifecycle.lobby;
      error = '$exception';
      _model = null;
      finishedGameLobby = null;
      notifyListeners();
    }
  }

  void returnToLobby() {
    _clearAutomaticStepTimer();
    _awaitingLocalPresentationRevision = null;
    _clearChannel();
    _clearUndoStack();
    _model = null;
    finishedGameLobby = null;
    actionLog = [];
    localGameLog = [];
    restoredSavedGame = false;
    uiState = const GameUiState();
    _lastSyncedPhase = null;
    revealedPlayerID = null;
    lifecycle = GameControllerLifecycle.lobby;
    error = null;
    notifyListeners();
  }

  void applyLegalAction(LegalAction action) {
    final online = _onlineChannel;
    if (online != null) {
      if (online.commandInFlight) {
        return;
      }
      _onlineSelectionBeforeCommand = uiState;
      _clearSelectionAfter(action.kind);
      _sync();
      unawaited(
        online.send(
          SubmitGameAction(
            action: action.engineAction,
            source:
                action.kind == actionRevealReward ||
                    action.kind == actionRevealTrump
                ? GameActionSource.centralPlanner
                : GameActionSource.human,
            expectedRevision: _onlineUpdate?.actionLogCount,
          ),
        ),
      );
      return;
    }
    final channel = _localChannel;
    if (channel == null) {
      return;
    }
    _clearAutomaticStepTimer();
    final capturesUndo = actionCapturesUndoSnapshot(action.kind);
    _pendingLocalUndoSnapshot = capturesUndo ? _snapshotForUndo(channel) : null;
    unawaited(
      channel.send(
        SubmitGameAction(
          action: action.engineAction,
          source: GameActionSource.human,
        ),
      ),
    );
  }

  void setActivePanel(String panel) {
    uiState = uiState.togglePanel(panel);
    if (panel == panelLog) {
      _hasUnreadReactions = false;
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

  bool get isOnlineGame => _onlineChannel != null;
  bool get isSpectating => _onlineChannel?.spectator ?? false;
  String? get onlineSessionID => _onlineChannel?.sessionID;
  String? get onlineInviteCode => _onlineChannel?.inviteCode;
  int? get onlinePlayerID => _onlineChannel?.playerID;
  OnlineSessionUpdate? get onlineUpdate =>
      finishedGameLobby?.onlineUpdate ?? _onlineUpdate;
  int? get presentationRevision =>
      _eventQueue.awaitingPresentationRevision ??
      _awaitingLocalPresentationRevision;
  List<String> get onlineAssignmentPresentationCardIDs =>
      List.unmodifiable(_eventQueue.assignmentPresentationCardIDs);
  List<EngineAction> get gameLogActions =>
      finishedGameLobby?.gameLogActions ??
      (_onlineChannel == null
          ? List.unmodifiable(localGameLog)
          : [
              for (final action in _onlineUpdate!.gameLogActions)
                action.engineAction,
            ]);
  List<OnlineReaction> get gameReactions =>
      finishedGameLobby?.reactions ??
      List.unmodifiable(_onlineUpdate?.reactions ?? const []);
  OnlineReaction? get activeReaction => _activeReaction;
  bool get hasUnreadReactions => _hasUnreadReactions;
  bool get canSendReaction => _onlineUpdate?.started ?? false;

  Future<File> saveGameLog() async {
    final finished = finishedGameLobby;
    final gameState = finished?.gameState;
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
        'seed': gameState?.seed ?? currentSeed,
        'variants': variantsToJson(gameState?.variants ?? currentVariants),
        'controllers': (gameState?.controllers ?? controllers)
            .map((controller) => controller.name)
            .toList(),
        if (gameState != null) 'gameState': gameState.toJson(),
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
    final update = _onlineUpdate;
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
      _onlineChannel == null &&
      model?.table.phase == phaseAssignment &&
      _undoStack.isNotEmpty;

  void undoLastAction() {
    if (_onlineChannel != null || _undoStack.isEmpty) {
      return;
    }
    _clearAutomaticStepTimer();
    final snapshot = _undoStack.removeLast();
    _clearChannel();
    _setChannel(LocalGameChannel(snapshot.engine));
    actionLog = snapshot.actionLog;
    localGameLog = snapshot.localGameLog;
    uiState = snapshot.uiState;
    revealedPlayerID = snapshot.revealedPlayerID;
    _lastSyncedPhase = snapshot.lastSyncedPhase;
    error = null;
    _beginLocalPresentation();
    _sync();
    _saveAutosave();
  }

  Future<String> startOnlineGame({
    required Uri baseURL,
    required bool ranked,
    required bool browserJoinable,
    int bestOf = 1,
  }) async {
    if (lifecycle != GameControllerLifecycle.lobby || _channel != null) {
      throw StateError('Only a local draft lobby can start an online game');
    }
    final draft = lobby;
    lifecycle = GameControllerLifecycle.starting;
    notifyListeners();
    try {
      final client = KolkhozOnlineClient(
        baseURL,
        httpClient: onlineHttpClient,
        webSocketConnector: onlineWebSocketConnector,
        accessTokenProvider: onlineAccessTokenProvider,
        deviceID: onlineDeviceID,
      );
      final response = await client.createSession(
        variants: draft.variants,
        controllers: [for (final player in draft.players) player.controller],
        ranked: ranked,
        browserJoinable: browserJoinable,
        bestOf: bestOf,
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
      if (_channel == null) {
        lifecycle = GameControllerLifecycle.lobby;
      }
      error = '$exception';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> startDailyChallenge({required Uri baseURL}) async {
    final client = KolkhozOnlineClient(
      baseURL,
      httpClient: onlineHttpClient,
      webSocketConnector: onlineWebSocketConnector,
      accessTokenProvider: onlineAccessTokenProvider,
      deviceID: onlineDeviceID,
    );
    try {
      final response = await client.startDailyChallenge();
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

  Future<void> rematchOnlineGame() async {
    final online = _onlineChannel;
    if (online == null ||
        _onlineUpdate!.ranked ||
        _onlineUpdate!.snapshot.phase != kcPhaseGameOver) {
      throw StateError('Only finished casual games can be rematched');
    }
    try {
      final response = await online.client.createRematch(online.sessionID);
      await _connectOnline(
        client: online.client,
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

  Future<void> watchOnlineGame({
    required Uri baseURL,
    required String sessionID,
  }) async {
    final client = KolkhozOnlineClient(
      baseURL,
      httpClient: onlineHttpClient,
      webSocketConnector: onlineWebSocketConnector,
      accessTokenProvider: onlineAccessTokenProvider,
      deviceID: onlineDeviceID,
    );
    try {
      final update = await client.fetchSpectatorUpdate(sessionID);
      await _connectOnline(
        client: client,
        sessionID: sessionID,
        inviteCode: update.inviteCode,
        playerID: -1,
        seatToken: '',
        update: update,
        spectator: true,
      );
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
        httpClient: onlineHttpClient,
        webSocketConnector: onlineWebSocketConnector,
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
        httpClient: onlineHttpClient,
        webSocketConnector: onlineWebSocketConnector,
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
      httpClient: onlineHttpClient,
      webSocketConnector: onlineWebSocketConnector,
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
    final online = _onlineChannel;
    if (online == null) {
      return;
    }
    await online.send(KickGamePlayer(playerID));
  }

  Future<void> _refreshOnlineGame({int? minimumRevision}) async {
    final online = _onlineChannel;
    if (online == null) {
      return;
    }
    await online.send(RefreshGame(minimumRevision: minimumRevision));
  }

  void leaveOnlineGame() {
    final online = _onlineChannel;
    if (online != null && !online.spectator) {
      unawaited(online.send(const LeaveGame()));
    }
    returnToLobby();
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

  void selectHandCard(String cardID) {
    if (model?.table.phase != phaseTrick && model?.table.phase != phasePass) {
      return;
    }
    uiState = uiState.selectHandCard(cardID);
    _sync();
  }

  Future<void> sendReaction(String reactionID) async {
    final online = _onlineChannel;
    if (online == null || online.spectator || _onlineUpdate?.started != true) {
      return;
    }
    await online.send(SendGameReaction(reactionID));
  }

  void _clearSelectionAfter(String actionKind) {
    uiState = uiState.clearSelectionAfterAction(actionKind);
  }

  void _sync() {
    final online = _onlineChannel;
    final finished = finishedGameLobby;
    if (online == null && _localChannel == null && finished != null) {
      finishedGameLobby = finished.withUiState(uiState);
      _model = finishedGameLobby!.model;
      notifyListeners();
      return;
    }
    TableViewModel? nextModel;
    if (online != null) {
      nextModel = OnlineTableProjection(
        update: _onlineUpdate!,
        playerID: online.playerID,
        legalActions: _onlineLegalActions,
        uiState: uiState,
      ).project();
    } else if (_localChannel case final local?) {
      nextModel = local.project(
        uiState: uiState,
        revealedPlayerID: revealedPlayerID,
      );
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
            update: _onlineUpdate!,
            playerID: online.playerID,
            legalActions: _onlineLegalActions,
            uiState: uiState,
          ).project();
        } else if (_localChannel case final local?) {
          nextModel = local.project(
            uiState: uiState,
            revealedPlayerID: revealedPlayerID,
          );
        }
      }
      _lastSyncedPhase = phase;
      _model = nextModel;
      if (phase == phaseGameOver) {
        _finishGame(nextModel, online);
      } else {
        finishedGameLobby = null;
        lifecycle = online != null && !_onlineUpdate!.started
            ? GameControllerLifecycle.lobby
            : GameControllerLifecycle.playing;
      }
    }
    notifyListeners();
    _scheduleAutomaticStep();
  }

  Future<void> _connectOnline({
    required KolkhozOnlineClient client,
    required String sessionID,
    required String inviteCode,
    required int playerID,
    required String seatToken,
    required OnlineSessionUpdate update,
    bool spectator = false,
  }) async {
    _clearAutomaticStepTimer();
    _awaitingLocalPresentationRevision = null;
    _clearChannel();
    finishedGameLobby = null;
    _autosaveStore.clear();
    _clearUndoStack();
    _onlineUpdate = update;
    _onlineLegalActions = update.legalActions;
    _eventQueue.clear();
    final channel = OnlineGameChannel(
      client: client,
      sessionID: sessionID,
      inviteCode: inviteCode,
      playerID: playerID,
      seatToken: seatToken,
      initialUpdate: update,
      realtimeReconnectDelay: onlineRealtimeReconnectDelay,
      spectator: spectator,
    );
    _setChannel(channel);
    currentVariants = update.variants;
    currentSeed = update.seed ?? currentSeed;
    _replacePlayers(update.controllers);
    lobby = _buildLobby(
      currentVariants,
      spectators: spectator
          ? const [GameSpectator(id: 'local-spectator')]
          : const [],
    );
    restoredSavedGame = false;
    uiState = const GameUiState();
    _lastSyncedPhase = null;
    revealedPlayerID = playerID;
    channel.start();
    error = null;
    _sync();
  }

  void _finishGame(TableViewModel finalModel, OnlineGameChannel? online) {
    lifecycle = GameControllerLifecycle.finishing;
    final update = online == null ? null : _onlineUpdate;
    final gameState = online == null
        ? _localChannel!.snapshot(
            uiState: uiState,
            revealedPlayerID: revealedPlayerID,
          )
        : GameStateSnapshot(
            seed: currentSeed,
            variants: currentVariants,
            controllers: controllers,
            model: finalModel.withSeed(currentSeed),
          );
    finishedGameLobby = FinishedGameLobby(
      lobby: lobby,
      gameState: gameState,
      gameLogActions: online == null
          ? localGameLog
          : [for (final action in update!.gameLogActions) action.engineAction],
      reactions: update?.reactions ?? const [],
      onlineUpdate: update,
      onlinePlayerID: online?.playerID,
      spectator: online?.spectator ?? false,
    );
    _model = gameState.model;
    if (online == null) {
      _clearChannel();
      _clearUndoStack();
    }
    lifecycle = GameControllerLifecycle.finished;
  }

  void _clearAutomaticStepTimer() {
    _automaticStepTimer?.cancel();
    _automaticStepTimer = null;
  }

  void _scheduleAutomaticStep() {
    if (_automaticStepTimer != null || presentationRevision != null) {
      return;
    }
    final online = _onlineChannel;
    if (online != null) {
      if (online.commandInFlight || _forcedProjectedAction() == null) {
        return;
      }
    } else {
      final local = _localChannel;
      if (local == null || !_engineDecisionNeedsRouting(local)) {
        return;
      }
    }
    _automaticStepTimer = Timer(
      _localChannel == null
          ? animationSpeed.automaticStepDelay
          : _automaticStepDelay(_localChannel!),
      _runAutomaticStep,
    );
  }

  bool _engineDecisionNeedsRouting(LocalGameChannel channel) {
    final phase = channel.phase;
    final legalActions = channel.legalActions;
    if (_centralPlannerAction(channel, legalActions) != null ||
        phase == kcPhaseRequisition ||
        (phase == kcPhasePlanning &&
            channel.isFamine &&
            legalActions.isEmpty)) {
      return true;
    }
    return _decisionPlayer(channel)?.waitsForHumanInput == false;
  }

  LegalAction? _forcedProjectedAction() {
    final actions = model?.legalActions ?? const <LegalAction>[];
    if (actions.length != 1) {
      return null;
    }
    final action = actions.single;
    return action.kind == actionRevealReward || action.kind == actionRevealTrump
        ? action
        : null;
  }

  Duration _automaticStepDelay(LocalGameChannel channel) {
    if (_currentAutomaticStepIsTrumpSelection(channel)) {
      return animationSpeed.automaticTrumpSelectionDelay;
    }
    return animationSpeed.automaticStepDelay;
  }

  bool _currentAutomaticStepIsTrumpSelection(LocalGameChannel channel) {
    if (channel.phase != kcPhasePlanning || channel.isFamine) {
      return false;
    }
    final player = _decisionPlayer(channel);
    return player != null &&
        !player.waitsForHumanInput &&
        channel.legalActions.any((action) => action.kind == kcActionSetTrump);
  }

  void _runAutomaticStep() {
    _automaticStepTimer = null;
    final online = _onlineChannel;
    if (online != null) {
      final action = _forcedProjectedAction();
      if (action != null) {
        applyLegalAction(action);
      }
      return;
    }
    final local = _localChannel;
    if (local == null) {
      return;
    }
    _automaticPhaseBefore = local.phase;
    _automaticRequisitionCountBefore = local.phase == kcPhaseRequisition
        ? local.requisitionEventCount
        : 0;
    final command = _automaticCommand(local);
    if (command != null) {
      unawaited(local.send(command));
    }
  }

  void _beginLocalPresentation() {
    _localPresentationSequence += 1;
    _awaitingLocalPresentationRevision = _localPresentationSequence;
  }

  GameCommand? _automaticCommand(LocalGameChannel channel) {
    final phase = channel.phase;
    final legalActions = channel.legalActions;
    final centralPlannerAction = _centralPlannerAction(channel, legalActions);
    if (centralPlannerAction != null) {
      return SubmitGameAction(
        action: engineActionFromCValue(centralPlannerAction),
        source: GameActionSource.centralPlanner,
      );
    }
    if (phase == kcPhaseRequisition ||
        (phase == kcPhasePlanning &&
            channel.isFamine &&
            legalActions.isEmpty)) {
      return const AdvanceAutomaticGame();
    }
    final player = _decisionPlayer(channel);
    final action = player == null ? null : channel.chooseAction(player);
    if (action == null) {
      return null;
    }
    return SubmitGameAction(
      action: engineActionFromCValue(action),
      source: GameActionSource.ai,
    );
  }

  CEngineActionValue? _centralPlannerAction(
    LocalGameChannel channel,
    List<CEngineActionValue> legalActions,
  ) {
    final action = legalActions.length == 1
        ? legalActions.single
        : channel.heuristicAction();
    if (action == null) {
      return null;
    }
    return action.kind == kcActionRevealReward ||
            action.kind == kcActionRevealTrump
        ? action
        : null;
  }

  GamePlayer? _decisionPlayer(LocalGameChannel channel) {
    final playerID = channel.phase == kcPhaseAssignment
        ? channel.lastWinner
        : channel.currentPlayer;
    if (playerID < 0 || playerID >= _players.length) {
      return null;
    }
    return _players[playerID];
  }

  void _replacePlayers(List<KolkhozPlayerController> controllers) {
    final normalized = KolkhozPlayerController.normalized(controllers);
    _players = [
      for (final (seatID, controller) in normalized.indexed)
        switch (controller) {
          KolkhozPlayerController.human => HumanPlayer(seatID: seatID),
          KolkhozPlayerController.heuristicAI => HeuristicAIPlayer(
            seatID: seatID,
          ),
          KolkhozPlayerController.mediumAI => NeuralAIPlayer(
            seatID: seatID,
            controller: controller,
            model: () => _mediumPolicy,
            modelUnavailable: () => _mediumPolicyUnavailable,
          ),
          KolkhozPlayerController.neuralAI => NeuralAIPlayer(
            seatID: seatID,
            controller: controller,
            model: () => _neuralPolicy,
            modelUnavailable: () => _neuralPolicyUnavailable,
          ),
        },
    ];
  }

  GameLobby _buildLobby(
    KolkhozGameVariants variants, {
    List<GameSpectator> spectators = const [],
  }) => GameLobby(
    variants: variants,
    seats: [
      for (final player in _players)
        GameSeat(seatID: player.seatID, player: player),
    ],
    spectators: spectators,
  );

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

  void _handleGameEvent(GameEvent event) {
    switch (event) {
      case LocalGameCommandResult():
        _handleLocalCommandResult(event);
      case OnlineGameStateReceived():
        if (_acceptOrDeferOnlineUpdate(event.update)) {
          error = null;
          _sync();
        }
      case OnlineGameActionsReceived():
        _queueOnlineActionUpdates(event.response);
      case GameCommandCompleted():
        if (event.command is SubmitGameAction) {
          _onlineSelectionBeforeCommand = null;
        }
        error = null;
        _scheduleAutomaticStep();
      case GameCommandFailed():
        if (event.command is SubmitGameAction) {
          final selection = _onlineSelectionBeforeCommand;
          _onlineSelectionBeforeCommand = null;
          if (selection != null) {
            uiState = selection;
          }
        }
        error = '${event.error}';
        _sync();
    }
  }

  void _handleLocalCommandResult(LocalGameCommandResult event) {
    final command = event.command;
    if (command is SubmitGameAction &&
        command.source == GameActionSource.human) {
      final undoSnapshot = _pendingLocalUndoSnapshot;
      _pendingLocalUndoSnapshot = null;
      if (!event.accepted) {
        undoSnapshot?.dispose();
        error = 'Move rejected (${event.errorCode})';
      } else {
        error = null;
        if (undoSnapshot != null) {
          _undoStack.add(undoSnapshot);
        } else {
          _clearUndoStack();
        }
        actionLog = [...actionLog, command.action];
        localGameLog = [...localGameLog, command.action];
        _clearSelectionAfter(command.action.kind);
      }
    } else {
      if (!event.accepted) {
        error = 'Automatic move rejected (${event.errorCode})';
        notifyListeners();
        return;
      }
      if (!event.stateChanged) {
        return;
      }
      error = null;
      if (command case SubmitGameAction(:final action)) {
        actionLog = [...actionLog, action];
        localGameLog = [...localGameLog, action];
      }
      final local = _localChannel;
      if (_automaticPhaseBefore == kcPhaseRequisition &&
          local != null &&
          local.requisitionEventCount > _automaticRequisitionCountBefore) {
        final index = _automaticRequisitionCountBefore;
        final card = local.requisitionEventCard(index);
        localGameLog = [
          ...localGameLog,
          EngineAction(
            kind: actionRequisitionEvent,
            playerID: local.requisitionEventPlayer(index),
            suit: suitName(local.requisitionEventSuit(index)),
            card: card.isValid
                ? EngineCard(
                    suit: suitName(card.suit) ?? wreckerSuit,
                    value: card.value,
                  )
                : null,
            requisitionKind: local.requisitionEventMessageKind(index),
          ),
        ];
      }
    }
    _automaticPhaseBefore = null;
    _automaticRequisitionCountBefore = 0;
    if (event.stateChanged) {
      _beginLocalPresentation();
    }
    _sync();
    if (event.stateChanged) {
      _saveAutosave();
    }
  }

  bool _queueOnlineActionUpdates(OnlineActionUpdatesResponse response) {
    final resyncUpdate = response.resyncUpdate;
    if (resyncUpdate != null) {
      _eventQueue.clear();
      if (resyncUpdate.actionLogCount >= (_onlineUpdate?.actionLogCount ?? 0)) {
        _acceptOnlineUpdate(resyncUpdate);
        _onlineLegalActions = resyncUpdate.legalActions;
        _sync();
      }
      return true;
    }
    final known = _knownOnlineRevision();
    final updates = response.updates
        .where((update) => update.revision > known)
        .toList(growable: false);
    if (updates.isEmpty) {
      return false;
    }
    _eventQueue.addAll(updates);
    _drainNextOnlineUpdate();
    return true;
  }

  int _knownOnlineRevision() =>
      _eventQueue.knownRevision(_onlineUpdate?.actionLogCount ?? 0);

  void _drainNextOnlineUpdate() {
    if (_onlineChannel == null ||
        _eventQueue.awaitingPresentationRevision != null) {
      return;
    }
    final next = _eventQueue.takeNext();
    if (next == null) {
      return;
    }
    final deferred = _eventQueue.deferredUpdate;
    if (deferred != null && deferred.actionLogCount <= next.revision) {
      _eventQueue.deferredUpdate = null;
    }
    final action = next.action;
    if (action.kind == kcActionAssign) {
      final cardID = action.engineAction.card?.id;
      if (cardID != null) {
        _eventQueue.pendingAssignmentCardIDs.add(cardID);
      }
    }
    _eventQueue.assignmentPresentationCardIDs =
        action.kind == kcActionSubmitAssignments
        ? List.of(_eventQueue.pendingAssignmentCardIDs)
        : const [];
    if (action.kind == kcActionSubmitAssignments) {
      _eventQueue.pendingAssignmentCardIDs.clear();
    }
    _eventQueue.awaitingPresentationRevision = next.revision;
    _eventQueue.pendingPresentationLegalActions = next.update.legalActions;
    _acceptOnlineUpdate(next.update.copyWith(legalActions: const []));
    _onlineLegalActions = const [];
    error = null;
    _sync();
  }

  void acknowledgeRevisionPresented(int revision) {
    final online = _onlineChannel;
    if (online == null) {
      if (_awaitingLocalPresentationRevision != revision) {
        return;
      }
      _awaitingLocalPresentationRevision = null;
      _sync();
      _scheduleAutomaticStep();
      return;
    }
    if (_eventQueue.awaitingPresentationRevision != revision) {
      return;
    }
    _eventQueue.awaitingPresentationRevision = null;
    _eventQueue.assignmentPresentationCardIDs = const [];
    if (_eventQueue.isNotEmpty) {
      _drainNextOnlineUpdate();
      return;
    }
    final deferred = _eventQueue.takeDeferred();
    if (deferred != null &&
        deferred.actionLogCount >= (_onlineUpdate?.actionLogCount ?? 0)) {
      _acceptOnlineUpdate(deferred);
      _onlineLegalActions = deferred.legalActions;
      _sync();
      return;
    }
    final legalActions = _eventQueue.pendingPresentationLegalActions;
    _eventQueue.pendingPresentationLegalActions = const [];
    _onlineUpdate = _onlineUpdate!.copyWith(legalActions: legalActions);
    _onlineLegalActions = legalActions;
    _sync();
  }

  void _acceptOnlineUpdate(OnlineSessionUpdate update) {
    final previousRevision = _onlineUpdate?.reactions.isEmpty ?? true
        ? 0
        : _onlineUpdate!.reactions.last.revision;
    _onlineUpdate = update;
    final playerID = _onlineChannel?.playerID;
    final newRemoteReactions = update.reactions.where(
      (reaction) =>
          reaction.revision > previousRevision && reaction.playerID != playerID,
    );
    if (newRemoteReactions.isEmpty) {
      return;
    }
    final latest = newRemoteReactions.last;
    _activeReaction = latest;
    if (uiState.activePanel != panelLog) {
      _hasUnreadReactions = true;
    }
    _reactionFlashTimer?.cancel();
    _reactionFlashTimer = Timer(const Duration(seconds: 3), () {
      _reactionFlashTimer = null;
      _activeReaction = null;
      if (!_disposed && _onlineChannel != null) {
        notifyListeners();
      }
    });
  }

  bool _acceptOrDeferOnlineUpdate(OnlineSessionUpdate update) {
    if (_eventQueue.awaitingPresentationRevision != null) {
      _eventQueue.defer(update);
      return false;
    }
    _acceptOnlineUpdate(update);
    _onlineLegalActions = update.legalActions;
    return true;
  }

  bool _restoreAutosave() {
    if (!autosaveEnabled) {
      return false;
    }
    final payload = _autosaveStore.load();
    if (payload == null) {
      return false;
    }
    GameEngine? restoredEngine;
    try {
      restoredEngine = GameEngine(
        bridge: _bridge,
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
      _replacePlayers(payload.controllers);
      currentVariants = payload.variants;
      lobby = _buildLobby(currentVariants);
      currentSeed = payload.seed;
      actionLog = List.of(payload.actions);
      localGameLog = List.of(
        payload.gameLogActions.isEmpty
            ? payload.actions
            : payload.gameLogActions,
      );
      _clearUndoStack();
      restoredSavedGame = true;
      uiState = const GameUiState();
      _lastSyncedPhase = null;
      revealedPlayerID = null;
      _setChannel(LocalGameChannel(restoredEngine));
      lifecycle = GameControllerLifecycle.playing;
      error = null;
      _sync();
      if (model?.table.phase == phaseGameOver) {
        _autosaveStore.clear();
        _clearChannel();
        _model = null;
        finishedGameLobby = null;
        restoredSavedGame = false;
        lifecycle = GameControllerLifecycle.lobby;
        return false;
      }
      _scheduleAutomaticStep();
      return true;
    } catch (_) {
      restoredEngine?.dispose();
      _clearChannel();
      _model = null;
      finishedGameLobby = null;
      lifecycle = GameControllerLifecycle.lobby;
      _autosaveStore.clear();
      return false;
    }
  }

  int _applyRestoredAction(
    GameEngine engine,
    CEngineActionValue action,
    List<KolkhozPlayerController> restoredControllers,
  ) {
    if (action.playerID >= 0 &&
        action.playerID < restoredControllers.length &&
        restoredControllers[action.playerID] != KolkhozPlayerController.human) {
      return engine.applyAIAction(action);
    }
    return engine.applyManual(action);
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
        gameLogActions: localGameLog,
      ),
    );
  }

  GameUndoSnapshot _snapshotForUndo(LocalGameChannel channel) {
    return GameUndoSnapshot(
      engine: channel.cloneEngine(),
      actionLog: List.of(actionLog),
      localGameLog: List.of(localGameLog),
      uiState: uiState,
      revealedPlayerID: revealedPlayerID,
      lastSyncedPhase: _lastSyncedPhase,
    );
  }

  void _clearUndoStack() {
    for (final snapshot in _undoStack) {
      snapshot.dispose();
    }
    _undoStack.clear();
  }

  void _setChannel(GameChannel channel) {
    _channel = channel;
    _channelEvents = channel.events.listen(_handleGameEvent);
  }

  void _clearChannel() {
    final subscription = _channelEvents;
    _channelEvents = null;
    unawaited(subscription?.cancel());
    final channel = _channel;
    _channel = null;
    channel?.dispose();
    _onlineUpdate = null;
    _onlineLegalActions = const [];
    _eventQueue.clear();
    _onlineSelectionBeforeCommand = null;
    _pendingLocalUndoSnapshot?.dispose();
    _pendingLocalUndoSnapshot = null;
    _automaticPhaseBefore = null;
    _automaticRequisitionCountBefore = 0;
    _reactionFlashTimer?.cancel();
    _reactionFlashTimer = null;
    _activeReaction = null;
    _hasUnreadReactions = false;
  }

  int _newSeed() => DateTime.now().microsecondsSinceEpoch;

  @override
  void dispose() {
    _disposed = true;
    _clearAutomaticStepTimer();
    _clearUndoStack();
    _clearChannel();
    _mediumPolicy?.dispose();
    _mediumPolicy = null;
    _neuralPolicy?.dispose();
    _neuralPolicy = null;
    super.dispose();
  }
}

typedef LiveGameStore = GameController;
