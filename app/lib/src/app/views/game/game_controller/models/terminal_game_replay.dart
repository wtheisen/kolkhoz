import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_action_codec.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/native_game_engine.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/terminal_game_record.dart';

class TerminalGameReplayValidation {
  const TerminalGameReplayValidation._(this.error);

  const TerminalGameReplayValidation.valid() : this._(null);
  const TerminalGameReplayValidation.invalid(String error) : this._(error);

  final String? error;
  bool get isValid => error == null;
}

class TerminalGameReplayValidator {
  const TerminalGameReplayValidator(this.bridge);

  final KolkhozCEngineBridge bridge;

  TerminalGameReplayValidation validate(TerminalGameRecord record) {
    final engine = NativeGameEngine(
      bridge: bridge,
      seed: record.seed,
      variants: record.variants,
      controllers: record.controllers,
    );
    try {
      for (var index = 0; index < record.actions.length; index += 1) {
        final action = cEngineAction(record.actions[index]);
        if (action == null) {
          return TerminalGameReplayValidation.invalid(
            'Action $index is not an engine action',
          );
        }
        var result = _apply(engine, action, record.controllers);
        var automaticGuard = 0;
        while (result != 0 && automaticGuard < 32) {
          if (engine.stepAutomatic() <= 0) {
            break;
          }
          automaticGuard += 1;
          result = _apply(engine, action, record.controllers);
        }
        if (result != 0) {
          return TerminalGameReplayValidation.invalid(
            'Action $index was rejected ($result)',
          );
        }
      }
      for (
        var guard = 0;
        engine.phase != kcPhaseGameOver && guard < 32;
        guard += 1
      ) {
        if (engine.stepAutomatic() <= 0) {
          break;
        }
      }
      if (engine.phase != kcPhaseGameOver) {
        return const TerminalGameReplayValidation.invalid(
          'Replay did not reach game over',
        );
      }
      if (engine.winnerID != record.result.winnerSeatID) {
        return const TerminalGameReplayValidation.invalid(
          'Replay winner does not match the terminal record',
        );
      }
      final expectedScores = {
        for (final score in record.result.scores) score.seatID: score.score,
      };
      final actualScores = engine.finalScores;
      for (var playerID = 0; playerID < actualScores.length; playerID += 1) {
        if (expectedScores[playerID] != actualScores[playerID]) {
          return TerminalGameReplayValidation.invalid(
            'Replay score for seat $playerID does not match the terminal record',
          );
        }
      }
      return const TerminalGameReplayValidation.valid();
    } finally {
      engine.dispose();
    }
  }

  int _apply(
    NativeGameEngine engine,
    CEngineActionValue action,
    List<KolkhozPlayerController> controllers,
  ) {
    final isAI =
        action.playerID >= 0 &&
        action.playerID < controllers.length &&
        controllers[action.playerID] != KolkhozPlayerController.human;
    return isAI ? engine.applyAIAction(action) : engine.applyManual(action);
  }
}
