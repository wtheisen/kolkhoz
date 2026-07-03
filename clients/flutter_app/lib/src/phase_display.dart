import 'game_constants.dart';
import 'render_model.dart';

String phaseDisplayName(String phase) {
  return switch (phase) {
    phasePlanning => 'Planning',
    phaseSwap => 'Swap',
    phaseTrick => 'Trick',
    phaseAssignment => 'Assignment',
    phaseRequisition => 'Requisition',
    phaseGameOver => 'Game Over',
    _ => phase,
  };
}

String yearPhaseLine({required int year, required String phase}) {
  return 'Year $year - ${phaseDisplayName(phase)}';
}

String hotSeatPhaseLine(TableViewModel model) {
  return yearPhaseLine(year: model.table.year, phase: model.table.phase);
}
