import 'dart:async';

import 'game_channel.dart';
import 'game_channel_online.dart';
import 'game_constants.dart';
import 'game_lobby.dart';
import 'game_ui_state.dart';
import 'online_game_client.dart';
import 'online_game_models.dart';
import 'online_table_projection.dart';
import 'render_model.dart';

class OnlineGameSession {
  OnlineGameSession({
    required KolkhozOnlineClient client,
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
    required this.onStateChanged,
    required this.onError,
    this.spectator = false,
  }) : _update = initialUpdate,
       _channel = OnlineGameChannel(
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
  final void Function() onStateChanged;
  final void Function(String?) onError;
  final bool spectator;

  final OnlineGameChannel _channel;
  StreamSubscription<GameEvent>? _events;
  OnlineSessionUpdate _update;
  int? _presentationRevision;
  List<String> _assignmentPresentationCardIDs = const [];
  GameUiState? _selectionBeforeCommand;
  Timer? _reactionFlashTimer;
  OnlineReaction? _activeReaction;
  bool _hasUnreadReactions = false;
  bool _disposed = false;

  KolkhozOnlineClient get client => _channel.client;
  String get sessionID => _channel.sessionID;
  String get inviteCode => _channel.inviteCode;
  int get playerID => _channel.playerID;
  OnlineSessionUpdate get update => _update;
  int? get presentationRevision => _presentationRevision;
  List<String> get assignmentPresentationCardIDs =>
      List.unmodifiable(_assignmentPresentationCardIDs);
  OnlineReaction? get activeReaction => _activeReaction;
  bool get hasUnreadReactions => _hasUnreadReactions;
  bool get canSendReaction => _update.started;

  TableViewModel project() => OnlineTableProjection(
    update: _update,
    lobby: lobby(),
    playerID: playerID,
    legalActions: _channel.commandInFlight ? const [] : _update.legalActions,
    uiState: uiState(),
  ).project();

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

  void acknowledgePresentation(int revision) {
    if (_presentationRevision != revision) {
      return;
    }
    unawaited(_channel.send(AcknowledgeGamePresentation(revision)));
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
        _presentationRevision = event.presentationRevision;
        _assignmentPresentationCardIDs = event.assignmentPresentationCardIDs;
        _acceptUpdate(event.update);
        onError(null);
        onStateChanged();
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
