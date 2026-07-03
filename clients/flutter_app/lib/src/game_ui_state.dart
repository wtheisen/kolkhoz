import 'game_constants.dart';

bool isGamePanel(String panel) {
  return availableGamePanels.contains(panel);
}

bool isPlotZone(String zone) {
  return zone == plotZoneHidden || zone == plotZoneRevealed;
}

class SelectionState {
  const SelectionState({
    required this.handCardID,
    required this.plotCardID,
    required this.plotZone,
    required this.assignmentCardID,
  });

  static const empty = SelectionState(
    handCardID: null,
    plotCardID: null,
    plotZone: null,
    assignmentCardID: null,
  );

  final String? handCardID;
  final String? plotCardID;
  final String? plotZone;
  final String? assignmentCardID;

  SelectionState copyWith({
    String? handCardID,
    bool clearHandCardID = false,
    String? plotCardID,
    bool clearPlotCardID = false,
    String? plotZone,
    bool clearPlotZone = false,
    String? assignmentCardID,
    bool clearAssignmentCardID = false,
  }) {
    return SelectionState(
      handCardID: clearHandCardID ? null : handCardID ?? this.handCardID,
      plotCardID: clearPlotCardID ? null : plotCardID ?? this.plotCardID,
      plotZone: clearPlotZone ? null : plotZone ?? this.plotZone,
      assignmentCardID: clearAssignmentCardID
          ? null
          : assignmentCardID ?? this.assignmentCardID,
    );
  }
}

class GameUiState {
  const GameUiState({this.activePanel, this.selection = SelectionState.empty});

  final String? activePanel;
  final SelectionState selection;

  GameUiState copyWith({
    String? activePanel,
    bool clearActivePanel = false,
    SelectionState? selection,
  }) {
    return GameUiState(
      activePanel: clearActivePanel ? null : activePanel ?? this.activePanel,
      selection: selection ?? this.selection,
    );
  }

  GameUiState activatePanel(String panel) {
    if (!isGamePanel(panel)) {
      return this;
    }
    return copyWith(activePanel: panel);
  }

  GameUiState selectSwapHandCard(String cardID) {
    return copyWith(selection: selection.copyWith(handCardID: cardID));
  }

  GameUiState selectSwapPlotCard(String cardID, String zone) {
    if (!isPlotZone(zone)) {
      return this;
    }
    return copyWith(
      selection: selection.copyWith(plotCardID: cardID, plotZone: zone),
    );
  }

  GameUiState selectAssignmentCard(String cardID) {
    return copyWith(selection: selection.copyWith(assignmentCardID: cardID));
  }

  GameUiState clearSelectionAfterAction(String actionKind) {
    final nextSelection = switch (actionKind) {
      actionSwap || actionUndoSwap || actionConfirmSwap => selection.copyWith(
        clearHandCardID: true,
        clearPlotCardID: true,
        clearPlotZone: true,
      ),
      actionAssign => selection.copyWith(clearAssignmentCardID: true),
      actionPlayCard ||
      actionSubmitAssignments ||
      actionContinueAfterRequisition ||
      actionSetTrump => SelectionState.empty,
      _ => selection,
    };
    return copyWith(selection: nextSelection);
  }
}
