import 'dart:async';

import 'online_game_models.dart';
import 'render_model.dart';

enum GameActionSource { human, centralPlanner, ai }

sealed class GameCommand {
  const GameCommand();
}

class SubmitGameAction extends GameCommand {
  const SubmitGameAction({
    required this.action,
    required this.source,
    this.expectedRevision,
  });

  final EngineAction action;
  final GameActionSource source;
  final int? expectedRevision;
}

class AdvanceAutomaticGame extends GameCommand {
  const AdvanceAutomaticGame();
}

class RefreshGame extends GameCommand {
  const RefreshGame({this.minimumRevision});

  final int? minimumRevision;
}

class AcknowledgeGamePresentation extends GameCommand {
  const AcknowledgeGamePresentation(this.revision);

  final int revision;
}

class SendGameReaction extends GameCommand {
  const SendGameReaction(this.reactionID);

  final String reactionID;
}

class KickGamePlayer extends GameCommand {
  const KickGamePlayer(this.playerID);

  final int playerID;
}

class LeaveGame extends GameCommand {
  const LeaveGame();
}

sealed class GameEvent {
  const GameEvent();
}

class LocalGameCommandResult extends GameEvent {
  const LocalGameCommandResult({
    required this.command,
    required this.accepted,
    required this.stateChanged,
    this.errorCode = 0,
  });

  final GameCommand command;
  final bool accepted;
  final bool stateChanged;
  final int errorCode;
}

class OnlineGameStateReceived extends GameEvent {
  const OnlineGameStateReceived(
    this.update, {
    this.presentationRevision,
    this.assignmentPresentationCardIDs = const [],
  });

  final OnlineSessionUpdate update;
  final int? presentationRevision;
  final List<String> assignmentPresentationCardIDs;
}

class GameCommandFailed extends GameEvent {
  const GameCommandFailed({required this.command, required this.error});

  final GameCommand command;
  final Object error;
}

class GameCommandCompleted extends GameEvent {
  const GameCommandCompleted(this.command);

  final GameCommand command;
}

abstract interface class GameChannel {
  Stream<GameEvent> get events;

  Future<void> send(GameCommand command);

  void dispose();
}

abstract class GameEventChannel implements GameChannel {
  final StreamController<GameEvent> eventController =
      StreamController<GameEvent>.broadcast(sync: true);
  bool _disposed = false;

  @override
  Stream<GameEvent> get events => eventController.stream;

  void publish(GameEvent event) {
    if (!_disposed && !eventController.isClosed) {
      eventController.add(event);
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    scheduleMicrotask(() => unawaited(eventController.close()));
  }
}
