import 'c_engine_bridge.dart';
import 'game_constants.dart';

int viewerSeatIDForControllers(List<KolkhozPlayerController> controllers) {
  final normalized = KolkhozPlayerController.normalized(controllers);
  return normalized.indexOf(KolkhozPlayerController.human);
}

int activeViewerSeatIDForState({
  required List<KolkhozPlayerController> controllers,
  required String phase,
  required int currentPlayerID,
  required int? assignmentWinnerID,
}) {
  final normalized = KolkhozPlayerController.normalized(controllers);
  if (isHumanController(normalized, currentPlayerID)) {
    return currentPlayerID;
  }
  if (phase == phaseAssignment &&
      assignmentWinnerID != null &&
      isHumanController(normalized, assignmentWinnerID)) {
    return assignmentWinnerID;
  }
  return viewerSeatIDForControllers(normalized);
}

bool isHumanController(
  List<KolkhozPlayerController> controllers,
  int playerID,
) {
  return playerID >= 0 &&
      playerID < controllers.length &&
      controllers[playerID] == KolkhozPlayerController.human;
}

bool hasMultipleHumanControllers(List<KolkhozPlayerController> controllers) {
  return KolkhozPlayerController.normalized(controllers)
          .where((controller) => controller == KolkhozPlayerController.human)
          .length >
      1;
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
