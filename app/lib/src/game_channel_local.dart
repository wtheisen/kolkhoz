import 'c_engine_action_codec.dart';
import 'c_engine_bridge.dart';
import 'game_channel.dart';
import 'game_engine.dart';
import 'game_state_snapshot.dart';
import 'game_ui_state.dart';
import 'player.dart';
import 'render_model.dart';

class LocalGameChannel extends GameEventChannel {
  LocalGameChannel(this._engine);

  final GameEngine _engine;

  int get phase => _engine.phase;
  bool get isFamine => _engine.isFamine;
  int get currentPlayer => _engine.currentPlayer;
  int get lastWinner => _engine.lastWinner;
  List<CEngineActionValue> get legalActions => _engine.legalActions;
  int get requisitionEventCount => _engine.requisitionEventCount;

  @override
  bool get commandInFlight => false;

  CEngineActionValue? heuristicAction() => _engine.heuristicAction();

  CEngineActionValue? chooseAction(LocalGamePlayer player) =>
      player.chooseAction(_engine);

  EngineCardValue requisitionEventCard(int index) =>
      _engine.requisitionEventCard(index);

  int requisitionEventPlayer(int index) =>
      _engine.requisitionEventPlayer(index);

  int requisitionEventSuit(int index) => _engine.requisitionEventSuit(index);

  int requisitionEventMessageKind(int index) =>
      _engine.requisitionEventMessageKind(index);

  TableViewModel project({
    required GameUiState uiState,
    required int? revealedPlayerID,
  }) => _engine.project(uiState: uiState, revealedPlayerID: revealedPlayerID);

  GameStateSnapshot snapshot({
    required GameUiState uiState,
    required int? revealedPlayerID,
  }) => _engine.snapshot(uiState: uiState, revealedPlayerID: revealedPlayerID);

  GameEngine cloneEngine() => _engine.clone();

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
