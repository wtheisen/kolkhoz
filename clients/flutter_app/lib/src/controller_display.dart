import 'c_engine_bridge.dart';
import 'game_constants.dart';

int viewerSeatIDForControllers(List<KolkhozPlayerController> controllers) {
  final normalized = KolkhozPlayerController.normalized(controllers);
  return normalized.indexOf(KolkhozPlayerController.human);
}

String renderControllerName(KolkhozPlayerController controller) {
  return switch (controller) {
    KolkhozPlayerController.human => controllerHuman,
    KolkhozPlayerController.heuristicAI => controllerHeuristicAI,
    KolkhozPlayerController.neuralAI => controllerNeuralAI,
  };
}

String seatNameForController({
  required int playerID,
  required KolkhozPlayerController controller,
}) {
  if (controller == KolkhozPlayerController.human) {
    return 'Player ${playerID + 1}';
  }
  return 'Bot $playerID';
}
