import 'c_engine_action_codec.dart';
import 'game_channel.dart';
import 'game_engine.dart';

class LocalGameChannel extends GameEventChannel {
  LocalGameChannel(this._engine);

  final GameEngine _engine;
  GameEngine get engine => _engine;

  @override
  Future<void> send(GameCommand command) {
    switch (command) {
      case SubmitGameAction():
        final action = cEngineAction(command.action);
        if (action == null) {
          publish(
            LocalGameCommandResult(
              command: command,
              accepted: false,
              stateChanged: false,
              errorCode: -1,
            ),
          );
          return Future.value();
        }
        final result = command.source == GameActionSource.ai
            ? _engine.applyAIAction(action)
            : _engine.applyManual(action);
        publish(
          LocalGameCommandResult(
            command: command,
            accepted: result == 0,
            stateChanged: result == 0,
            errorCode: result,
          ),
        );
        return Future.value();
      case AdvanceAutomaticGame():
        final result = _engine.stepAutomatic();
        publish(
          LocalGameCommandResult(
            command: command,
            accepted: result >= 0,
            stateChanged: result > 0,
            errorCode: result < 0 ? -result : 0,
          ),
        );
        return Future.value();
      default:
        publish(
          GameCommandFailed(
            command: command,
            error: UnsupportedError(
              '${command.runtimeType} is not a local game command',
            ),
          ),
        );
        return Future.value();
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}
