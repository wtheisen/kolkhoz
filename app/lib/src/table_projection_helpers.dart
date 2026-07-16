import 'art_direction.dart';
import 'game_constants.dart';
import 'game_ui_state.dart';
import 'render_model.dart';

Panels panelsForPhase(
  GameUiState uiState,
  String phase, {
  List<Seat> seats = const [],
  Trick? lastTrick,
  List<LegalAction>? legalActions,
}) {
  return Panels(
    active:
        uiState.activePanel ??
        activePanelForPhase(
          phase,
          seats: seats,
          lastTrick: lastTrick,
          legalActions: legalActions,
        ),
    available: availableGamePanels,
  );
}

String activePanelForPhase(
  String phase, {
  List<Seat> seats = const [],
  Trick? lastTrick,
  List<LegalAction>? legalActions,
}) {
  if (legalActions != null &&
      phaseRequiresViewerAction(phase) &&
      !viewerHasPhaseAction(phase, legalActions)) {
    return panelBrigade;
  }
  if (phase == phaseAssignment &&
      assignmentWinnerIsAutomatic(seats: seats, lastTrick: lastTrick)) {
    return panelBrigade;
  }
  return actionPanelForPhase(phase);
}

String actionPanelForPhase(String phase) {
  return switch (phase) {
    phaseAssignment => panelJobs,
    phaseSwap || phaseRequisition =>
      configuredKolkhozArtStyle.usesNewArt ? panelBrigade : panelPlot,
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

bool phaseRequiresViewerAction(String phase) {
  return phase == phaseSwap ||
      phase == phaseAssignment ||
      phase == phaseRequisition;
}

bool viewerHasPhaseAction(String phase, List<LegalAction> legalActions) {
  return legalActions.any((action) {
    return switch (phase) {
      phaseSwap =>
        action.kind == actionSwap ||
            action.kind == actionUndoSwap ||
            action.kind == actionConfirmSwap,
      phaseAssignment =>
        action.kind == actionAssign || action.kind == actionSubmitAssignments,
      phaseRequisition => action.kind == actionContinueAfterRequisition,
      _ => true,
    };
  });
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
