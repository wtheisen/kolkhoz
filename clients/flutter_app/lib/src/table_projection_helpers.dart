import 'game_constants.dart';
import 'game_ui_state.dart';
import 'render_model.dart';

Panels panelsForPhase(GameUiState uiState, String phase) {
  return Panels(
    active: uiState.activePanel ?? actionPanelForPhase(phase),
    available: availableGamePanels,
  );
}

String actionPanelForPhase(String phase) {
  return switch (phase) {
    phaseAssignment => panelJobs,
    phaseSwap || phaseRequisition => panelPlot,
    _ => panelBrigade,
  };
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
