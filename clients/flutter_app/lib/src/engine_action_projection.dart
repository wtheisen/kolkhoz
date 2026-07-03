import 'c_engine_bridge.dart';
import 'game_constants.dart';
import 'game_ui_state.dart';

String cardID(EngineCardValue card) {
  return '${suitName(card.suit) ?? 'unknown'}-${card.value}';
}

bool isSelectedSwapAction(SelectionState selection, CEngineActionValue action) {
  final handCardID = selection.handCardID;
  final plotCardID = selection.plotCardID;
  if (handCardID == null || plotCardID == null) {
    return false;
  }
  final plotZone = selection.plotZone;
  return cardID(action.handCard) == handCardID &&
      cardID(action.plotCard) == plotCardID &&
      (plotZone == null || plotZoneName(action.plotZone) == plotZone);
}

bool shouldExposeActionForViewer({
  required CEngineActionValue action,
  required SelectionState selection,
  required int viewerSeatID,
}) {
  if (action.playerID != viewerSeatID &&
      action.kind != kcActionContinueAfterRequisition) {
    return false;
  }
  return switch (action.kind) {
    kcActionSwap => isSelectedSwapAction(selection, action),
    _ => true,
  };
}

Set<String> handActionCardIDs(List<CEngineActionValue> actions, int playerID) {
  return {
    for (final action in actions)
      if (action.playerID == playerID &&
          action.card.isValid &&
          action.kind == kcActionPlayCard)
        cardID(action.card),
    for (final action in actions)
      if (action.playerID == playerID &&
          action.handCard.isValid &&
          action.kind == kcActionSwap)
        cardID(action.handCard),
  };
}

Set<String> plotActionCardIDs(
  List<CEngineActionValue> actions,
  String zone, {
  int? playerID,
}) {
  return {
    for (final action in actions)
      if (action.kind == kcActionSwap &&
          (playerID == null || action.playerID == playerID) &&
          action.plotCard.isValid &&
          plotZoneName(action.plotZone) == zone)
        cardID(action.plotCard),
  };
}

String rankName(int value) {
  return switch (value) {
    1 => 'A',
    11 => 'J',
    12 => 'Q',
    13 => 'K',
    _ => '$value',
  };
}

String? suitName(int suit) {
  return switch (suit) {
    0 => 'wheat',
    1 => 'sunflower',
    2 => 'potato',
    3 => 'beet',
    _ => null,
  };
}

int? suitCode(String? suit) {
  return switch (suit) {
    'wheat' => 0,
    'sunflower' => 1,
    'potato' => 2,
    'beet' => 3,
    _ => null,
  };
}

String phaseName(int phase) {
  return switch (phase) {
    kcPhasePlanning => phasePlanning,
    kcPhaseSwap => phaseSwap,
    kcPhaseTrick => phaseTrick,
    kcPhaseAssignment => phaseAssignment,
    kcPhaseRequisition => phaseRequisition,
    kcPhaseGameOver => phaseGameOver,
    _ => phaseGameOver,
  };
}

String actionKindName(int kind) {
  return switch (kind) {
    kcActionSetTrump => actionSetTrump,
    kcActionSwap => actionSwap,
    kcActionConfirmSwap => actionConfirmSwap,
    kcActionPlayCard => actionPlayCard,
    kcActionAssign => actionAssign,
    kcActionSubmitAssignments => actionSubmitAssignments,
    kcActionContinueAfterRequisition => actionContinueAfterRequisition,
    kcActionUndoSwap => actionUndoSwap,
    _ => actionUnknown,
  };
}

int? actionKindCode(String kind) {
  return switch (kind) {
    actionSetTrump => kcActionSetTrump,
    actionSwap => kcActionSwap,
    actionConfirmSwap => kcActionConfirmSwap,
    actionPlayCard => kcActionPlayCard,
    actionAssign => kcActionAssign,
    actionSubmitAssignments => kcActionSubmitAssignments,
    actionContinueAfterRequisition => kcActionContinueAfterRequisition,
    actionUndoSwap => kcActionUndoSwap,
    _ => null,
  };
}

String actionLabel(int kind) {
  return switch (kind) {
    kcActionSetTrump => 'Set trump',
    kcActionSwap => 'Swap',
    kcActionConfirmSwap => 'Confirm',
    kcActionPlayCard => 'Play',
    kcActionAssign => 'Assign',
    kcActionSubmitAssignments => 'Confirm',
    kcActionContinueAfterRequisition => 'Continue',
    kcActionUndoSwap => 'Undo',
    _ => 'Action',
  };
}

String? plotZoneName(int zone) {
  return switch (zone) {
    0 => plotZoneHidden,
    1 => plotZoneRevealed,
    _ => null,
  };
}

int? plotZoneCode(String? zone) {
  return switch (zone) {
    plotZoneHidden => 0,
    plotZoneRevealed => 1,
    _ => null,
  };
}

int? nullablePlayerID(int value) => value >= 0 ? value : null;

String requisitionMessage(int kind) {
  return switch (kind) {
    1 => 'Protected from requisition.',
    2 => 'Drunkard exiled.',
    3 => 'Card sent north.',
    4 => 'No matching card found.',
    _ => 'Requisition resolved.',
  };
}
