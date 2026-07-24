import 'dart:async';

import 'package:kolkhoz_app/src/app/views/game/game_controller/game_engine.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_lobby.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_ui_state.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/remote_game_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import '../game_commands.dart';
import 'game_remote_commands.dart';
import 'game_remote_connection.dart';

class RemoteGameEngine implements GameEngine {
  RemoteGameEngine({
    required GameRemoteConnection client,
    required String sessionID,
    required String inviteCode,
    required int playerID,
    required String seatToken,
    required OnlineSessionUpdate initialUpdate,
    required Duration realtimeReconnectDelay,
    required this.uiState,
    required this.setUiState,
    required this.lobby,
    required this.onUpdate,
    required this.onGameUpdate,
    required this.onStateChanged,
    required this.onError,
    this.spectator = false,
  }) : _update = initialUpdate,
       _channel = GameRemoteCommands(
         client: client,
         sessionID: sessionID,
         inviteCode: inviteCode,
         playerID: playerID,
         seatToken: seatToken,
         initialUpdate: initialUpdate,
         realtimeReconnectDelay: realtimeReconnectDelay,
         spectator: spectator,
       ) {
    _events = _channel.events.listen(_handleEvent);
    _channel.start();
  }

  final GameUiState Function() uiState;
  final void Function(GameUiState) setUiState;
  final GameLobby Function() lobby;
  final void Function(OnlineSessionUpdate) onUpdate;
  final void Function(GameEngineUpdate) onGameUpdate;
  final void Function() onStateChanged;
  final void Function(String?) onError;
  final bool spectator;

  final GameRemoteCommands _channel;
  StreamSubscription<GameEvent>? _events;
  OnlineSessionUpdate _update;
  GameUiState? _selectionBeforeCommand;
  Timer? _reactionFlashTimer;
  OnlineReaction? _activeReaction;
  bool _hasUnreadReactions = false;
  bool _disposed = false;

  GameRemoteConnection get client => _channel.client;
  String get sessionID => _channel.sessionID;
  String get inviteCode => _channel.inviteCode;
  int get playerID => _channel.playerID;
  OnlineSessionUpdate get update => _update;
  @override
  GameEngineMode get mode => GameEngineMode.remote;

  OnlineReaction? get activeReaction => _activeReaction;
  bool get hasUnreadReactions => _hasUnreadReactions;
  bool get canSendReaction => _update.started;

  @override
  TableViewModel project() => OnlineTableProjection(
    update: _update,
    lobby: lobby(),
    playerID: playerID,
    legalActions: _channel.commandInFlight ? const [] : _update.legalActions,
    uiState: uiState(),
  ).project();

  @override
  void sendHumanAction(LegalAction action) {
    if (_channel.commandInFlight ||
        action.kind == actionRevealReward ||
        action.kind == actionRevealTrump ||
        action.engineAction.playerID != playerID) {
      return;
    }
    _selectionBeforeCommand = uiState();
    setUiState(uiState().clearSelectionAfterAction(action.kind));
    unawaited(
      _channel.send(
        SubmitGameAction(
          action: action.engineAction,
          source: GameActionSource.human,
          expectedRevision: _update.actionLogCount,
        ),
      ),
    );
    onStateChanged();
  }

  Future<void> refresh({int? minimumRevision}) =>
      _channel.send(RefreshGame(minimumRevision: minimumRevision));

  Future<void> kickPlayer(int playerID) =>
      _channel.send(KickGamePlayer(playerID));

  Future<void> sendReaction(String reactionID) {
    if (spectator || !_update.started) {
      return Future.value();
    }
    return _channel.send(SendGameReaction(reactionID));
  }

  void markReactionsRead() {
    _hasUnreadReactions = false;
  }

  void leave() {
    if (!spectator) {
      unawaited(_channel.send(const LeaveGame()));
    }
  }

  void _handleEvent(GameEvent event) {
    switch (event) {
      case OnlineGameStateReceived():
        _acceptUpdate(event.update);
        onError(null);
        if (event.committed) {
          onGameUpdate(
            GameEngineUpdate(
              action: event.action,
              transitions: event.update.snapshot.transitionEvents,
            ),
          );
        } else {
          onStateChanged();
        }
      case GameCommandCompleted():
        if (event.command is SubmitGameAction) {
          _selectionBeforeCommand = null;
          scheduleMicrotask(() {
            if (!_disposed) onStateChanged();
          });
        }
        onError(null);
      case GameCommandFailed():
        if (event.command is SubmitGameAction) {
          final selection = _selectionBeforeCommand;
          _selectionBeforeCommand = null;
          if (selection != null) {
            setUiState(selection);
          }
        }
        onError('${event.error}');
        scheduleMicrotask(() {
          if (!_disposed) onStateChanged();
        });
      case _:
        break;
    }
  }

  void _acceptUpdate(OnlineSessionUpdate update) {
    final previousRevision = _update.reactions.isEmpty
        ? 0
        : _update.reactions.last.revision;
    _update = update;
    onUpdate(update);
    final newRemoteReactions = update.reactions.where(
      (reaction) =>
          reaction.revision > previousRevision && reaction.playerID != playerID,
    );
    if (newRemoteReactions.isEmpty) {
      return;
    }
    _activeReaction = newRemoteReactions.last;
    if (uiState().activePanel != panelLog) {
      _hasUnreadReactions = true;
    }
    _reactionFlashTimer?.cancel();
    _reactionFlashTimer = Timer(const Duration(seconds: 3), () {
      _reactionFlashTimer = null;
      _activeReaction = null;
      if (!_disposed) {
        onStateChanged();
      }
    });
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _reactionFlashTimer?.cancel();
    _reactionFlashTimer = null;
    final events = _events;
    _events = null;
    unawaited(events?.cancel());
    _channel.dispose();
  }
}
