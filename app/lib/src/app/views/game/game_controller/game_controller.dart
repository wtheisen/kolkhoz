import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/assignment_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/finished_game_lobby.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_engine.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_lobby.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_serialization.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_ui_state.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/remote_lobby_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_player.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/terminal_game_record.dart';
import 'local_game_engine/local_game_engine.dart';
import 'local_game_engine/local_game_engine_factory.dart';
import 'remote_game_engine/remote_game_engine.dart';
import 'remote_game_engine/remote_game_engine_factory.dart';

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
    LocalGameEngineFactory? localGameEngineFactory,
    RemoteGameEngineFactory? remoteGameEngineFactory,
    bool autosaveEnabled = true,
  }) : _localGameEngineFactory =
           localGameEngineFactory ??
           LocalGameEngineFactory(autosaveEnabled: autosaveEnabled) {
    _remoteGameEngineFactory = remoteGameEngineFactory;
    _replaceLocalPlayers(KolkhozPlayerController.defaultControllers);
    lobby = _buildLobby(KolkhozGameVariants.kolkhoz);
    _restoreAutosave();
    _localGameEngineFactory.startPolicyLoading(
      onReady: () {
        if (_disposed) return;
        error = null;
        _localEngine?.scheduleAutomaticStep();
      },
      onError: (message) {
        if (_disposed) return;
        error = message;
        notifyListeners();
      },
    );
  }

  final LocalGameEngineFactory _localGameEngineFactory;
  late final RemoteGameEngineFactory? _remoteGameEngineFactory;

  RemoteGameEngineFactory get _requiredRemoteGameEngineFactory =>
      _remoteGameEngineFactory ??
      (throw StateError('Online play requires a remote game connection'));

  GameAnimationSpeed animationSpeed = defaultGameAnimationSpeed;
  GameUiState uiState = const GameUiState();
  GameControllerLifecycle lifecycle = GameControllerLifecycle.lobby;
  late GameLobby lobby;
  late List<GamePlayer> _players;
  List<GamePlayer> get players => List.unmodifiable(_players);
  List<KolkhozPlayerController> get controllers =>
      List.unmodifiable(_players.map((player) => player.controller));
  List<EngineAction> get actionLog =>
      List.unmodifiable(_localEngine?.actionLog ?? const []);
  List<EngineAction> get localGameLog =>
      List.unmodifiable(_localEngine?.gameLog ?? const []);
  KolkhozGameVariants currentVariants = KolkhozGameVariants.kolkhoz;
  int currentSeed = 0;
  GameEngine? _engine;
  LocalGameEngine? get _localEngine => switch (_engine) {
    final LocalGameEngine engine => engine,
    _ => null,
  };
  RemoteGameEngine? get _remoteEngine => switch (_engine) {
    final RemoteGameEngine engine => engine,
    _ => null,
  };
  TableViewModel? _model;
  TableViewModel? get model => finishedGameLobby?.model ?? _model;
  FinishedGameLobby? finishedGameLobby;
  bool get hasActiveEngine => _engine != null;
  int? revealedPlayerID;
  String? error;
  String? _lastSyncedPhase;
  bool _disposed = false;
  bool get _hasSession => _engine != null;

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
      _engine = _localGameEngineFactory.create(
        seed: currentSeed,
        variants: currentVariants,
        controllers: normalizedControllers,
        bindings: _localEngineBindings,
      );
      lifecycle = GameControllerLifecycle.playing;
      error = null;
      _sync();
      if (persist) {
        _saveAutosave();
      }
      _localEngine!.scheduleAutomaticStep();
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
    _engine?.sendHumanAction(action);
  }

  void setActivePanel(String panel) {
    uiState = uiState.togglePanel(panel);
    if (panel == panelLog) {
      _remoteEngine?.markReactionsRead();
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
    final local = _localEngine;
    animationSpeed = speed;
    notifyListeners();
    local?.rescheduleAutomaticStep();
  }

  bool get isOnlineGame => _engine?.mode == GameEngineMode.remote;
  bool get isSpectating => _remoteEngine?.spectator ?? false;
  String? get onlineSessionID => _remoteEngine?.sessionID;
  String? get onlineInviteCode => _remoteEngine?.inviteCode;
  int? get onlinePlayerID => _remoteEngine?.playerID;
  OnlineSessionUpdate? get onlineUpdate =>
      finishedGameLobby?.onlineUpdate ?? _remoteEngine?.update;
  int? get presentationRevision => _engine?.presentationRevision;
  List<String> get onlineAssignmentPresentationCardIDs =>
      _remoteEngine?.assignmentPresentationCardIDs ?? const [];
  List<EngineAction> get gameLogActions =>
      finishedGameLobby?.gameLogActions ??
      (_remoteEngine == null
          ? List.unmodifiable(_localEngine?.gameLog ?? const [])
          : [
              for (final action in _remoteEngine!.update.gameLogActions)
                action.engineAction,
            ]);
  List<OnlineReaction> get gameReactions =>
      finishedGameLobby?.reactions ??
      List.unmodifiable(_remoteEngine?.update.reactions ?? const []);
  OnlineReaction? get activeReaction => _remoteEngine?.activeReaction;
  bool get hasUnreadReactions => _remoteEngine?.hasUnreadReactions ?? false;
  bool get canSendReaction => _remoteEngine?.canSendReaction ?? false;

  Future<File> saveGameLog() async {
    final finished = finishedGameLobby;
    final gameRecord = finished?.gameRecord;
    final base = _localGameEngineFactory.dataDirectory;
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
      _remoteEngine == null &&
      (_localEngine?.canUndo(model?.table.phase) ?? false);

  void undoLastAction() {
    if (_remoteEngine == null) {
      _localEngine?.undoLastAction();
    }
  }

  Future<String> startOnlineGame({
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
      final client = _requiredRemoteGameEngineFactory.connection;
      final response = await client.createSession(
        variants: draft.variants,
        controllers: [for (final player in draft.players) player.controller],
        ranked: ranked,
        browserJoinable: browserJoinable,
        bestOf: bestOf,
      );
      await _connectOnline(
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

  Future<void> startDailyChallenge() async {
    final client = _requiredRemoteGameEngineFactory.connection;
    try {
      final response = await client.startDailyChallenge();
      await _connectOnline(
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
    final online = _remoteEngine;
    if (online == null ||
        online.update.ranked ||
        online.update.snapshot.phase != kcPhaseGameOver) {
      throw StateError('Only finished casual games can be rematched');
    }
    try {
      final response = await online.client.createRematch(online.sessionID);
      await _connectOnline(
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

  Future<void> watchOnlineGame({required String sessionID}) async {
    final client = _requiredRemoteGameEngineFactory.connection;
    try {
      final update = await client.fetchSpectatorUpdate(sessionID);
      await _connectOnline(
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
    required String inviteCode,
    int? preferredPlayerID,
  }) async {
    try {
      final client = _requiredRemoteGameEngineFactory.connection;
      final response = await client.joinSession(
        sessionID: inviteCode.trim(),
        preferredPlayerID: preferredPlayerID,
      );
      await _connectOnline(
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
    bool rankedOnly = false,
    bool comradesOnly = false,
  }) async {
    try {
      final client = _requiredRemoteGameEngineFactory.connection;
      final response = await client.matchmakeSession(
        rankedOnly: rankedOnly,
        comradesOnly: comradesOnly,
      );
      await _connectOnline(
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

  Future<void> syncActiveOnlineGame() async {
    final client = _requiredRemoteGameEngineFactory.connection;
    final response = await client.syncActiveSession();
    await _connectOnline(
      sessionID: response.sessionID,
      inviteCode: response.inviteCode,
      playerID: response.playerID,
      seatToken: response.seatToken,
      update: response.update,
    );
  }

  Future<void> kickOnlinePlayer(int playerID) async {
    final online = _remoteEngine;
    if (online == null) {
      return;
    }
    await online.kickPlayer(playerID);
  }

  Future<void> _refreshOnlineGame({int? minimumRevision}) async {
    final online = _remoteEngine;
    if (online == null) {
      return;
    }
    await online.refresh(minimumRevision: minimumRevision);
  }

  void leaveOnlineGame() {
    _remoteEngine?.leave();
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
    await _remoteEngine?.sendReaction(reactionID);
  }

  void _sync() {
    final engine = _engine;
    final online = _remoteEngine;
    final local = _localEngine;
    final finished = finishedGameLobby;
    if (engine == null && finished != null) {
      finishedGameLobby = finished.withUiState(uiState);
      _model = finishedGameLobby!.model;
      notifyListeners();
      return;
    }
    var nextModel = engine?.project();
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
        nextModel = engine!.project();
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
    required String sessionID,
    required String inviteCode,
    required int playerID,
    required String seatToken,
    required OnlineSessionUpdate update,
    bool spectator = false,
  }) async {
    _clearSession();
    finishedGameLobby = null;
    _localGameEngineFactory.clearAutosave();
    _engine = _requiredRemoteGameEngineFactory.create(
      sessionID: sessionID,
      inviteCode: inviteCode,
      playerID: playerID,
      seatToken: seatToken,
      update: update,
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

  void _finishGame(TableViewModel finalModel, RemoteGameEngine? online) {
    lifecycle = GameControllerLifecycle.finishing;
    final update = online?.update;
    final engineActions = online == null
        ? List<EngineAction>.of(_localEngine!.actionLog)
        : [for (final action in update!.gameLogActions) action.engineAction];
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
          ? _localEngine!.gameLog
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
    _players = _localGameEngineFactory.createPlayers(controllers);
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

  void acknowledgeRevisionPresented(int revision) {
    _engine?.acknowledgePresentation(revision);
  }

  void _acceptOnlineUpdate(OnlineSessionUpdate update) {
    final online = _remoteEngine;
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
    final restored = _localGameEngineFactory.restore(_localEngineBindings);
    if (restored == null) {
      return false;
    }
    _players = restored.players;
    currentVariants = restored.variants;
    lobby = _buildLobby(currentVariants);
    currentSeed = restored.seed;
    uiState = const GameUiState();
    _lastSyncedPhase = null;
    revealedPlayerID = null;
    _engine = restored.engine;
    lifecycle = GameControllerLifecycle.playing;
    error = null;
    _sync();
    if (model?.table.phase == phaseGameOver) {
      _localGameEngineFactory.clearAutosave();
      _clearSession();
      _model = null;
      finishedGameLobby = null;
      lifecycle = GameControllerLifecycle.lobby;
      return false;
    }
    _localEngine!.scheduleAutomaticStep();
    return true;
  }

  void _saveAutosave() {
    if (model?.table.phase == phaseGameOver) {
      _localGameEngineFactory.clearAutosave();
      return;
    }
    final engine = _localEngine;
    if (engine == null) return;
    _localGameEngineFactory.save(
      seed: currentSeed,
      variants: currentVariants,
      controllers: controllers,
      engine: engine,
    );
  }

  LocalGameEngineBindings get _localEngineBindings => LocalGameEngineBindings(
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
  );

  void _clearSession() {
    final engine = _engine;
    _engine = null;
    engine?.dispose();
  }

  int _newSeed() => DateTime.now().microsecondsSinceEpoch;

  @override
  void dispose() {
    _disposed = true;
    _clearSession();
    _localGameEngineFactory.dispose();
    super.dispose();
  }
}
