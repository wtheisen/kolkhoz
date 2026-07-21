import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'animation_speed.dart';
import 'assignment_display.dart';
import 'c_engine_action_codec.dart';
import 'c_engine_bridge.dart';
import 'finished_game_lobby.dart';
import 'game_constants.dart';
import 'game_engine.dart';
import 'game_lobby.dart';
import 'game_ui_state.dart';
import 'local_game_session.dart';
import 'online_game_models.dart';
import 'online_game_client.dart';
import 'online_game_session.dart';
import 'online_lobby_projection.dart';
import 'policy_model.dart';
import 'player.dart';
import 'player_ai_heuristic.dart';
import 'player_ai_neural.dart';
import 'player_human.dart';
import 'render_model.dart';
import 'design_tokens.dart';
import 'saved_game_store.dart';
import 'terminal_game_record.dart';

bool actionCapturesUndoSnapshot(String actionKind) =>
    actionKind == actionAssign;

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
    _replaceLocalPlayers(KolkhozPlayerController.defaultControllers);
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
  List<EngineAction> get actionLog =>
      List.unmodifiable(_localSession?.actionLog ?? const []);
  List<EngineAction> get localGameLog =>
      List.unmodifiable(_localSession?.gameLog ?? const []);
  KolkhozGameVariants currentVariants = KolkhozGameVariants.kolkhoz;
  int currentSeed = 0;
  LocalGameSession? _localSession;
  OnlineGameSession? _onlineSession;
  TableViewModel? _model;
  TableViewModel? get model => finishedGameLobby?.model ?? _model;
  FinishedGameLobby? finishedGameLobby;
  bool get hasActiveEngine => _localSession != null;
  int? revealedPlayerID;
  String? error;
  String? _lastSyncedPhase;
  bool _mediumPolicyUnavailable = false;
  bool _neuralPolicyUnavailable = false;
  bool _disposed = false;
  bool get _hasSession => _localSession != null || _onlineSession != null;

  void configureLobby({
    required KolkhozGameVariants variants,
    required List<KolkhozPlayerController> controllers,
  }) {
    if (lifecycle != GameControllerLifecycle.lobby || _hasSession) {
      throw StateError(
        'Lobby configuration is frozen after online handoff or game start',
      );
    }
    _replaceLocalPlayers(controllers);
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
      _clearSession();
      final normalizedControllers = KolkhozPlayerController.normalized(
        controllers ?? this.controllers,
      );
      _replaceLocalPlayers(normalizedControllers);
      currentVariants = variants ?? lobby.variants;
      lobby = _buildLobby(currentVariants, spectators: lobby.spectators);
      if (!lobby.readyToStart) {
        throw StateError('All four seats must be ready before starting');
      }
      lifecycle = GameControllerLifecycle.starting;
      currentSeed = _newSeed();
      finishedGameLobby = null;
      uiState = const GameUiState();
      _lastSyncedPhase = null;
      revealedPlayerID = null;
      _localSession = _buildLocalSession(
        GameEngine(
          bridge: _bridge,
          seed: currentSeed,
          variants: currentVariants,
          controllers: normalizedControllers,
        ),
      );
      lifecycle = GameControllerLifecycle.playing;
      error = null;
      _sync();
      if (persist) {
        _saveAutosave();
      }
      _localSession!.scheduleAutomaticStep();
    } catch (exception) {
      _clearSession();
      lifecycle = GameControllerLifecycle.lobby;
      error = '$exception';
      _model = null;
      finishedGameLobby = null;
      notifyListeners();
    }
  }

  void returnToLobby() {
    final localControllers = controllers;
    _clearSession();
    _model = null;
    finishedGameLobby = null;
    uiState = const GameUiState();
    _lastSyncedPhase = null;
    revealedPlayerID = null;
    _replaceLocalPlayers(localControllers);
    lobby = _buildLobby(currentVariants);
    lifecycle = GameControllerLifecycle.lobby;
    error = null;
    notifyListeners();
  }

  void applyLegalAction(LegalAction action) {
    final online = _onlineSession;
    if (online != null) {
      online.sendHumanAction(action);
      return;
    }
    _localSession?.sendHumanAction(action);
  }

  void setActivePanel(String panel) {
    uiState = uiState.togglePanel(panel);
    if (panel == panelLog) {
      _onlineSession?.markReactionsRead();
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
    final local = _localSession;
    animationSpeed = speed;
    notifyListeners();
    local?.rescheduleAutomaticStep();
  }

  bool get isOnlineGame => _onlineSession != null;
  bool get isSpectating => _onlineSession?.spectator ?? false;
  String? get onlineSessionID => _onlineSession?.sessionID;
  String? get onlineInviteCode => _onlineSession?.inviteCode;
  int? get onlinePlayerID => _onlineSession?.playerID;
  OnlineSessionUpdate? get onlineUpdate =>
      finishedGameLobby?.onlineUpdate ?? _onlineSession?.update;
  int? get presentationRevision =>
      _onlineSession?.presentationRevision ??
      _localSession?.presentationRevision;
  List<String> get onlineAssignmentPresentationCardIDs =>
      _onlineSession?.assignmentPresentationCardIDs ?? const [];
  List<EngineAction> get gameLogActions =>
      finishedGameLobby?.gameLogActions ??
      (_onlineSession == null
          ? List.unmodifiable(_localSession?.gameLog ?? const [])
          : [
              for (final action in _onlineSession!.update.gameLogActions)
                action.engineAction,
            ]);
  List<OnlineReaction> get gameReactions =>
      finishedGameLobby?.reactions ??
      List.unmodifiable(_onlineSession?.update.reactions ?? const []);
  OnlineReaction? get activeReaction => _onlineSession?.activeReaction;
  bool get hasUnreadReactions => _onlineSession?.hasUnreadReactions ?? false;
  bool get canSendReaction => _onlineSession?.canSendReaction ?? false;

  Future<File> saveGameLog() async {
    final finished = finishedGameLobby;
    final gameRecord = finished?.gameRecord;
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
        'seed': gameRecord?.seed ?? currentSeed,
        'variants': variantsToJson(gameRecord?.variants ?? currentVariants),
        'controllers': (gameRecord?.controllers ?? controllers)
            .map((controller) => controller.name)
            .toList(),
        if (gameRecord != null) 'terminalGame': gameRecord.toJson(),
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

  bool get canUndo =>
      _onlineSession == null &&
      (_localSession?.canUndo(model?.table.phase) ?? false);

  void undoLastAction() {
    if (_onlineSession == null) {
      _localSession?.undoLastAction();
    }
  }

  Future<String> startOnlineGame({
    required Uri baseURL,
    required bool ranked,
    required bool browserJoinable,
    int bestOf = 1,
  }) async {
    if (lifecycle != GameControllerLifecycle.lobby || _hasSession) {
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
      if (!_hasSession) {
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
    final online = _onlineSession;
    if (online == null ||
        online.update.ranked ||
        online.update.snapshot.phase != kcPhaseGameOver) {
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
    final online = _onlineSession;
    if (online == null) {
      return;
    }
    await online.kickPlayer(playerID);
  }

  Future<void> _refreshOnlineGame({int? minimumRevision}) async {
    final online = _onlineSession;
    if (online == null) {
      return;
    }
    await online.refresh(minimumRevision: minimumRevision);
  }

  void leaveOnlineGame() {
    _onlineSession?.leave();
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
    await _onlineSession?.sendReaction(reactionID);
  }

  void _sync() {
    final online = _onlineSession;
    final local = _localSession;
    final finished = finishedGameLobby;
    if (online == null && local == null && finished != null) {
      finishedGameLobby = finished.withUiState(uiState);
      _model = finishedGameLobby!.model;
      notifyListeners();
      return;
    }
    TableViewModel? nextModel;
    if (online != null) {
      nextModel = online.project();
    } else if (local != null) {
      nextModel = local.project();
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
          nextModel = online.project();
        } else if (local != null) {
          nextModel = local.project();
        }
      }
      _lastSyncedPhase = phase;
      _model = nextModel;
      if (phase == phaseGameOver) {
        _finishGame(nextModel, online);
      } else {
        finishedGameLobby = null;
        lifecycle = online != null && !online.update.started
            ? GameControllerLifecycle.lobby
            : GameControllerLifecycle.playing;
      }
    }
    notifyListeners();
    local?.scheduleAutomaticStep();
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
    _clearSession();
    finishedGameLobby = null;
    _autosaveStore.clear();
    _onlineSession = OnlineGameSession(
      client: client,
      sessionID: sessionID,
      inviteCode: inviteCode,
      playerID: playerID,
      seatToken: seatToken,
      initialUpdate: update,
      realtimeReconnectDelay: onlineRealtimeReconnectDelay,
      spectator: spectator,
      uiState: () => uiState,
      setUiState: (value) => uiState = value,
      lobby: () => lobby,
      onUpdate: _acceptOnlineUpdate,
      onStateChanged: _sync,
      onError: (value) => error = value,
    );
    currentVariants = update.variants;
    currentSeed = update.seed ?? currentSeed;
    lobby = gameLobbyFromOnlineUpdate(
      update,
      viewerSeatID: spectator ? null : playerID,
      spectators: spectator
          ? const [GameSpectator(id: 'local-spectator')]
          : const [],
    );
    _players = lobby.players;
    uiState = const GameUiState();
    _lastSyncedPhase = null;
    revealedPlayerID = playerID;
    error = null;
    _sync();
  }

  void _finishGame(TableViewModel finalModel, OnlineGameSession? online) {
    lifecycle = GameControllerLifecycle.finishing;
    final update = online?.update;
    final engineActions = online == null
        ? List<EngineAction>.of(_localSession!.actionLog)
        : [
            for (final action in update!.gameLogActions)
              if (cEngineAction(action.engineAction) != null)
                action.engineAction,
          ];
    final terminalModel = finalModel.withSeed(currentSeed);
    final gameRecord = TerminalGameRecord(
      seed: currentSeed,
      variants: currentVariants,
      controllers: controllers,
      participants: [
        for (final seat in terminalModel.table.seats)
          TerminalGameParticipant(
            seatID: seat.id,
            name: seat.name,
            controller: controllers[seat.id],
            userID: seat.profileUserID,
          ),
      ],
      actions: engineActions,
      result: TerminalGameResult.fromTableResult(
        terminalModel.table.gameResult!,
      ),
    );
    finishedGameLobby = FinishedGameLobby(
      lobby: lobby,
      gameRecord: gameRecord,
      model: terminalModel,
      gameLogActions: online == null
          ? _localSession!.gameLog
          : [for (final action in update!.gameLogActions) action.engineAction],
      reactions: update?.reactions ?? const [],
      onlineUpdate: update,
      onlinePlayerID: online?.playerID,
      spectator: online?.spectator ?? false,
    );
    _model = terminalModel;
    if (online == null) {
      _clearSession();
    }
    lifecycle = GameControllerLifecycle.finished;
  }

  void _replaceLocalPlayers(List<KolkhozPlayerController> controllers) {
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
            _localSession?.scheduleAutomaticStep();
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
            _localSession?.scheduleAutomaticStep();
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

  void acknowledgeRevisionPresented(int revision) {
    final online = _onlineSession;
    if (online != null) {
      online.acknowledgePresentation(revision);
    } else {
      _localSession?.acknowledgePresentation(revision);
    }
  }

  void _acceptOnlineUpdate(OnlineSessionUpdate update) {
    final online = _onlineSession;
    final playerID = online?.playerID;
    lobby = gameLobbyFromOnlineUpdate(
      update,
      viewerSeatID: online?.spectator == true ? null : playerID,
      spectators: lobby.spectators,
    );
    _players = lobby.players;
    currentVariants = update.variants;
    currentSeed = update.seed ?? currentSeed;
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
      _replaceLocalPlayers(payload.controllers);
      currentVariants = payload.variants;
      lobby = _buildLobby(currentVariants);
      currentSeed = payload.seed;
      uiState = const GameUiState();
      _lastSyncedPhase = null;
      revealedPlayerID = null;
      _localSession = _buildLocalSession(
        restoredEngine,
        actionLog: payload.actions,
        gameLog: payload.gameLogActions.isEmpty
            ? payload.actions
            : payload.gameLogActions,
      );
      restoredEngine = null;
      lifecycle = GameControllerLifecycle.playing;
      error = null;
      _sync();
      if (model?.table.phase == phaseGameOver) {
        _autosaveStore.clear();
        _clearSession();
        _model = null;
        finishedGameLobby = null;
        lifecycle = GameControllerLifecycle.lobby;
        return false;
      }
      _localSession!.scheduleAutomaticStep();
      return true;
    } catch (_) {
      restoredEngine?.dispose();
      _clearSession();
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
        actions: _localSession?.actionLog ?? const [],
        gameLogActions: _localSession?.gameLog ?? const [],
      ),
    );
  }

  LocalGameSession _buildLocalSession(
    GameEngine engine, {
    List<EngineAction> actionLog = const [],
    List<EngineAction> gameLog = const [],
  }) => LocalGameSession(
    engine: engine,
    players: () => _players,
    animationSpeed: () => animationSpeed,
    uiState: () => uiState,
    setUiState: (value) => uiState = value,
    revealedPlayerID: () => revealedPlayerID,
    setRevealedPlayerID: (value) => revealedPlayerID = value,
    lastSyncedPhase: () => _lastSyncedPhase,
    setLastSyncedPhase: (value) => _lastSyncedPhase = value,
    onStateChanged: _sync,
    onError: (value) => error = value,
    onPersist: _saveAutosave,
    actionLog: actionLog,
    gameLog: gameLog,
  );

  void _clearSession() {
    final local = _localSession;
    _localSession = null;
    local?.dispose();
    final online = _onlineSession;
    _onlineSession = null;
    online?.dispose();
  }

  int _newSeed() => DateTime.now().microsecondsSinceEpoch;

  @override
  void dispose() {
    _disposed = true;
    _clearSession();
    _mediumPolicy?.dispose();
    _mediumPolicy = null;
    _neuralPolicy?.dispose();
    _neuralPolicy = null;
    super.dispose();
  }
}
