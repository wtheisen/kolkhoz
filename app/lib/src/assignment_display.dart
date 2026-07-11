import 'game_constants.dart';
import 'render_model.dart';

List<TableCard> assignmentControlCards(TableViewModel model) {
  if (model.table.phase != phaseAssignment) {
    return const [];
  }
  final assignedIDs = assignedAssignmentCardIDs(model);
  return model.table.lastTrick.plays
      .map((play) => play.card)
      .where((card) => !assignedIDs.contains(card.id))
      .toList(growable: false);
}

Trick visibleAssignmentTrick(TableViewModel model) {
  if (model.table.phase != phaseAssignment) {
    return model.table.trick;
  }
  final assignedIDs = assignedAssignmentCardIDs(model);
  return Trick(
    plays: model.table.lastTrick.plays
        .where((play) => !assignedIDs.contains(play.card.id))
        .toList(growable: false),
    winnerSeatID: model.table.lastTrick.winnerSeatID,
  );
}

Set<String> assignedAssignmentCardIDs(TableViewModel model) {
  return {
    for (final job in model.table.jobs)
      for (final card in job.assignedCards) card.id,
  };
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
