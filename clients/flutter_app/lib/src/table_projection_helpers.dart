import 'game_constants.dart';
import 'game_ui_state.dart';
import 'render_model.dart';

Panels panelsForPhase(
  GameUiState uiState,
  String phase, {
  List<Seat> seats = const [],
  Trick? lastTrick,
}) {
  return Panels(
    active:
        uiState.activePanel ??
        activePanelForPhase(phase, seats: seats, lastTrick: lastTrick),
    available: availableGamePanels,
  );
}

String activePanelForPhase(
  String phase, {
  List<Seat> seats = const [],
  Trick? lastTrick,
}) {
  if (phase == phaseAssignment &&
      assignmentWinnerIsAutomatic(seats: seats, lastTrick: lastTrick)) {
    return panelBrigade;
  }
  return actionPanelForPhase(phase);
}

String actionPanelForPhase(String phase) {
  return switch (phase) {
    phaseAssignment => panelJobs,
    phaseSwap || phaseRequisition => panelPlot,
    _ => panelBrigade,
  };
}

bool assignmentWinnerIsAutomatic({
  required List<Seat> seats,
  required Trick? lastTrick,
}) {
  final winnerID = lastTrick?.winnerSeatID;
  if (winnerID == null) {
    return false;
  }
  for (final seat in seats) {
    if (seat.id == winnerID) {
      return !isHumanAssignmentController(seat.controller);
    }
  }
  return false;
}

bool isHumanAssignmentController(String controller) {
  return controller == controllerHuman || controller == controllerRemoteHuman;
}

Prompt phasePromptForPhase(String phase, {required bool isFamine}) {
  return switch (phase) {
    phasePlanning => Prompt(
      title: isFamine ? 'Famine year' : 'Choose Trump',
      body: isFamine
          ? 'No trump suit is used this year.'
          : 'Pick the trump suit for this year.',
    ),
    phaseSwap => const Prompt(
      title: 'Swap',
      body: 'Confirm to keep your hand.',
    ),
    phaseAssignment => const Prompt(
      title: 'Assign work',
      body: 'Assign the captured cards to valid jobs.',
    ),
    phaseRequisition => const Prompt(
      title: 'Requisition',
      body: 'Review the audit and continue.',
    ),
    phaseGameOver => const Prompt(
      title: 'Game Over!',
      body: 'Final cellar and medal scores.',
    ),
    _ => const Prompt(title: 'Play cards', body: 'Follow suit if able.'),
  };
}

Set<String> assignmentTargetSuits(List<LegalAction> actions) {
  return {
    for (final action in actions)
      if (action.kind == actionAssign && action.engineAction.targetSuit != null)
        action.engineAction.targetSuit!,
  };
}

GameResult? gameResultForPhase(
  String phase, {
  required int winnerSeatID,
  required List<Score> scores,
}) {
  if (phase != phaseGameOver) {
    return null;
  }
  return GameResult(winnerSeatID: winnerSeatID, scores: scores);
}
