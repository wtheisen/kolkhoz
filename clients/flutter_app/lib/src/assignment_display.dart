import 'game_constants.dart';
import 'render_model.dart';

List<TableCard> assignmentControlCards(TableViewModel model) {
  if (model.table.phase != phaseAssignment) {
    return const [];
  }
  final assignedIDs = <String>{
    for (final job in model.table.jobs)
      for (final card in job.assignedCards) card.id,
  };
  return model.table.lastTrick.plays
      .map((play) => play.card)
      .where((card) => !assignedIDs.contains(card.id))
      .toList(growable: false);
}

LegalAction? assignmentActionForJob(TableViewModel model, Job job) {
  final selectedCardID = model.selection.assignmentCardID;
  if (selectedCardID == null) {
    return null;
  }
  for (final action in model.legalActions) {
    final engineAction = action.engineAction;
    if (action.kind == actionAssign &&
        engineAction.card?.id == selectedCardID &&
        engineAction.targetSuit == job.suit) {
      return action;
    }
  }
  return null;
}
