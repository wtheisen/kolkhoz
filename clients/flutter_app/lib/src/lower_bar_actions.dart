import 'app_settings.dart';
import 'app_text.dart';
import 'game_constants.dart';
import 'render_model.dart';

const lowerBarActionKinds = {
  actionSwap,
  actionConfirmSwap,
  actionUndoSwap,
  actionSubmitAssignments,
  actionContinueAfterRequisition,
};

bool isProminentLowerBarAction(LegalAction action) {
  return action.kind == actionConfirmSwap ||
      action.kind == actionSubmitAssignments ||
      action.kind == actionContinueAfterRequisition;
}

int compareLowerBarActions(LegalAction lhs, LegalAction rhs) {
  final lhsRank = lowerBarActionRank(lhs.kind);
  final rhsRank = lowerBarActionRank(rhs.kind);
  if (lhsRank != rhsRank) {
    return lhsRank.compareTo(rhsRank);
  }
  final kindOrder = lhs.kind.compareTo(rhs.kind);
  if (kindOrder != 0) {
    return kindOrder;
  }
  return lowerBarActionSortKey(
    lhs.engineAction,
  ).compareTo(lowerBarActionSortKey(rhs.engineAction));
}

String lowerBarActionSortKey(EngineAction action) {
  return [
    action.kind,
    action.playerID.toString(),
    action.suit ?? '',
    action.card?.id ?? '',
    action.handCard?.id ?? '',
    action.plotCard?.id ?? '',
    action.plotZone ?? '',
    action.targetSuit ?? '',
  ].join('|');
}

int lowerBarActionRank(String kind) {
  return switch (kind) {
    actionSwap => 0,
    actionUndoSwap => 0,
    actionConfirmSwap => 1,
    actionSubmitAssignments => 1,
    actionContinueAfterRequisition => 1,
    _ => 2,
  };
}

String lowerBarActionLabel(
  LegalAction action, {
  required int tableYear,
  KolkhozLanguage? language,
}) {
  final resolvedLanguage = language ?? KolkhozLanguage.en;
  return switch (action.kind) {
    actionSwap => resolvedLanguage.t(KolkhozText.lowerbaractionsSwap),
    actionUndoSwap => resolvedLanguage.t(KolkhozText.lowerbaractionsUndo),
    actionConfirmSwap => resolvedLanguage.t(KolkhozText.lowerbaractionsConfirm),
    actionSubmitAssignments => resolvedLanguage.t(
      KolkhozText.lowerbaractionsConfirm,
    ),
    actionContinueAfterRequisition =>
      tableYear >= finalGameYear
          ? resolvedLanguage.t(KolkhozText.lowerbaractionsFinish)
          : resolvedLanguage.t(KolkhozText.lowerbaractionsYearValue1, {
              'value1': tableYear + 1,
            }),
    _ => action.label,
  };
}

String lowerBarActionIconAsset(LegalAction action) {
  return switch (action.kind) {
    actionSwap => 'icon-toolbar-swap.png',
    actionUndoSwap => 'icon-toolbar-undo.png',
    actionConfirmSwap ||
    actionSubmitAssignments ||
    actionContinueAfterRequisition => 'icon-toolbar-confirm.png',
    _ => 'icon-toolbar-confirm.png',
  };
}
