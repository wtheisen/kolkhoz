import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_action_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_ui_state.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/table_projection_helpers.dart';

TableViewModel buildTableViewModel({
  required GameUiState uiState,
  required Viewer viewer,
  required int year,
  required String phase,
  required int currentPlayerID,
  required String? trump,
  required bool isFamine,
  required List<Seat> seats,
  required List<Job> jobs,
  required Trick trick,
  required Trick lastTrick,
  required List<RequisitionEvent> requisitionEvents,
  required Map<int, List<TableCard>> exiledByYear,
  required List<Score> scoreboard,
  required int winnerSeatID,
  required List<Score> finalScoreboard,
  required List<LegalAction> legalActions,
  TableCard? finalYearTrumpCard,
}) {
  return TableViewModel(
    viewer: viewer,
    table: TableState(
      year: year,
      phase: phase,
      phasePrompt: phasePromptForPhase(phase, isFamine: isFamine),
      currentPlayerID: currentPlayerID,
      trump: trump,
      isFamine: isFamine,
      maxTricks: isFamine ? 3 : 4,
      seats: seats,
      jobs: jobs,
      trick: trick,
      lastTrick: lastTrick,
      requisitionEvents: requisitionEvents,
      exiledByYear: exiledByYear,
      scoreboard: scoreboard,
      gameResult: gameResultForPhase(
        phase,
        winnerSeatID: winnerSeatID,
        scores: finalScoreboard,
      ),
      finalYearTrumpCard: finalYearTrumpCard,
    ),
    panels: panelsForPhase(
      uiState,
      phase,
      seats: seats,
      lastTrick: lastTrick,
      legalActions: legalActions,
    ),
    selection: uiState.selection,
    legalActions: legalActions,
  );
}

List<Job> buildProjectedJobs({
  required List<LegalAction> legalActions,
  required int? trump,
  required int Function(int suit) hoursForSuit,
  required bool Function(int suit) claimedForSuit,
  required TableCard? Function(int suit) rewardForSuit,
  required List<TableCard> Function(int suit) assignedCardsForSuit,
}) {
  final assignmentTargets = assignmentTargetSuits(legalActions);
  return [
    for (var suit = 0; suit < displaySuitOrder.length; suit += 1)
      Job(
        suit: suitName(suit)!,
        hours: hoursForSuit(suit),
        requiredHours: jobRequiredHours,
        claimed: claimedForSuit(suit),
        reward: rewardForSuit(suit),
        assignedCards: assignedCardsForSuit(suit),
        validAssignmentTarget: assignmentTargets.contains(suitName(suit)),
        highlighted: trump == suit,
      ),
  ];
}

List<Score> buildScoreboard({
  required bool finalScores,
  required int Function(int playerID) visibleScoreForPlayer,
  required int? Function(int playerID) finalScoreForPlayer,
}) {
  return [
    for (var playerID = 0; playerID < kolkhozPlayerCount; playerID += 1)
      Score(
        seatID: playerID,
        visibleScore: visibleScoreForPlayer(playerID),
        finalScore: finalScores ? finalScoreForPlayer(playerID) : null,
      ),
  ];
}

Map<int, List<TableCard>> buildExiledByYear(
  List<TableCard> Function(int year) cardsForYear,
) {
  return {
    for (var year = 1; year <= finalGameYear; year += 1)
      year: cardsForYear(year),
  };
}
