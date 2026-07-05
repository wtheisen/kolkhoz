import 'c_engine_bridge.dart';
import 'controller_display.dart';
import 'engine_action_projection.dart';
import 'game_constants.dart';
import 'game_ui_state.dart';
import 'online_game_models.dart';
import 'render_model.dart';
import 'table_view_projection.dart';
import 'table_projection_helpers.dart';

class OnlineTableProjection {
  const OnlineTableProjection({
    required this.update,
    required this.playerID,
    required this.legalActions,
    this.uiState = const GameUiState(),
  });

  final OnlineSessionUpdate update;
  final int playerID;
  final List<OnlineEngineAction> legalActions;
  final GameUiState uiState;

  OnlineEngineSnapshot get snapshot => update.snapshot;

  TableViewModel project() {
    final phase = phaseName(snapshot.phase);
    final projectedActions = projectedLegalActions();
    return TableViewModel(
      viewer: Viewer(seatID: playerID, privacyMode: viewerPrivacyNone),
      table: TableState(
        year: snapshot.year,
        phase: phase,
        phasePrompt: phasePromptForPhase(phase, isFamine: snapshot.isFamine),
        currentPlayerID: snapshot.currentPlayer,
        trump: suitName(snapshot.trump),
        isFamine: snapshot.isFamine,
        maxTricks: snapshot.isFamine ? 3 : 4,
        seats: seats(),
        jobs: jobs(projectedActions),
        trick: trick(current: true),
        lastTrick: trick(current: false),
        requisitionEvents: requisitionEvents(),
        exiledByYear: exiledByYear(),
        scoreboard: scoreboard(finalScores: phase == phaseGameOver),
        gameResult: gameResult(phase),
      ),
      panels: panelsForPhase(uiState, phase),
      selection: uiState.selection,
      legalActions: projectedActions,
    );
  }

  List<Seat> seats() {
    final controllers = KolkhozPlayerController.normalized(update.controllers);
    final byID = {for (final player in snapshot.players) player.id: player};
    return [
      for (var seatID = 0; seatID < kolkhozPlayerCount; seatID += 1)
        _seat(seatID, controllers, byID[seatID]),
    ];
  }

  Seat _seat(
    int seatID,
    List<KolkhozPlayerController> controllers,
    OnlinePlayerSnapshot? player,
  ) {
    final controller = controllers[seatID];
    final remoteHuman =
        controller == KolkhozPlayerController.human && seatID != playerID;
    final hand = player?.hand ?? const <OnlineEngineCard>[];
    final hiddenPlot = player?.hiddenPlot ?? const <OnlineEngineCard>[];
    return Seat(
      id: seatID,
      name: remoteHuman
          ? 'Remote ${seatID + 1}'
          : seatNameForController(playerID: seatID, controller: controller),
      controller: remoteHuman
          ? controllerRemoteHuman
          : renderControllerName(controller),
      portraitAsset: 'worker${seatID + 1}',
      isViewer: seatID == playerID,
      isCurrentTurn: snapshot.currentPlayer == seatID,
      isBrigadeLeader: player?.brigadeLeader ?? false,
      hand: cards(
        hand,
        highlightedIDs: handActionCardIDs(
          legalActions.map((action) => action.cValue).toList(growable: false),
          seatID,
        ),
      ),
      hiddenHandCount: seatID == playerID ? 0 : hand.length,
      plot: PlotState(
        revealed: cards(
          player?.revealedPlot ?? const <OnlineEngineCard>[],
          highlightedIDs: seatID == playerID
              ? plotActionCardIDs(
                  legalActions
                      .map((action) => action.cValue)
                      .toList(growable: false),
                  plotZoneRevealed,
                  playerID: seatID,
                )
              : const {},
        ),
        hidden: cards(
          hiddenPlot,
          highlightedIDs: seatID == playerID
              ? plotActionCardIDs(
                  legalActions
                      .map((action) => action.cValue)
                      .toList(growable: false),
                  plotZoneHidden,
                  playerID: seatID,
                )
              : const {},
        ),
        stacks: [
          for (final stack
              in player?.stacks ?? const <OnlinePlotStackSnapshot>[])
            PlotStackState(
              revealed: cards(stack.revealed),
              hidden: cards(stack.hidden),
            ),
        ],
      ),
      medals: player?.medals ?? 0,
      visibleScore: scoreFor(seatID).visibleScore,
    );
  }

  List<Job> jobs(List<LegalAction> actions) {
    final assignmentTargets = assignmentTargetSuits(actions);
    return [
      for (var suit = 0; suit < displaySuitOrder.length; suit += 1)
        Job(
          suit: suitName(suit)!,
          hours: workHours(suit),
          requiredHours: jobRequiredHours,
          claimed: snapshot.claimedJobs.contains(suit),
          reward: firstCardForSuit(snapshot.revealedJobs, suit),
          assignedCards: [
            ...cards(cardsForSuit(snapshot.jobBuckets, suit)),
            ...pendingAssignmentCards(suit),
          ],
          validAssignmentTarget: assignmentTargets.contains(suitName(suit)),
          highlighted: snapshot.trump == suit,
        ),
    ];
  }

  List<TableCard> pendingAssignmentCards(int targetSuit) {
    return [
      for (final assignment in snapshot.pendingAssignments)
        if (assignment.targetSuit == targetSuit)
          projectCard(assignment.card.valueObject, pending: true),
    ];
  }

  Trick trick({required bool current}) {
    final plays = current ? snapshot.currentTrick : snapshot.lastTrick;
    return Trick(
      plays: [
        for (final play in plays)
          TrickPlay(
            seatID: play.playerID,
            card: projectCard(play.card.valueObject),
          ),
      ],
      winnerSeatID: current ? null : nullablePlayerID(snapshot.lastWinner),
    );
  }

  List<RequisitionEvent> requisitionEvents() {
    return [
      for (final event in snapshot.requisitionEvents)
        RequisitionEvent(
          seatID: nullablePlayerID(event.playerID),
          suit: suitName(event.suit) ?? 'wheat',
          card: event.card.isValid ? projectCard(event.card.valueObject) : null,
          message: event.message,
        ),
    ];
  }

  Map<int, List<TableCard>> exiledByYear() {
    return {
      for (var year = 1; year <= finalGameYear; year += 1)
        year: cards(cardsForSuit(snapshot.exiled, year)),
    };
  }

  List<Score> scoreboard({required bool finalScores}) {
    return [
      for (var seatID = 0; seatID < kolkhozPlayerCount; seatID += 1)
        Score(
          seatID: seatID,
          visibleScore: scoreFor(seatID).visibleScore,
          finalScore: finalScores ? scoreFor(seatID).finalScore : null,
        ),
    ];
  }

  GameResult? gameResult(String phase) {
    return gameResultForPhase(
      phase,
      winnerSeatID: snapshot.winnerID,
      scores: scoreboard(finalScores: true),
    );
  }

  List<LegalAction> projectedLegalActions() {
    return [
      for (final action in legalActions)
        LegalAction(
          kind: actionKindName(action.kind),
          label: actionLabel(action.kind),
          engineAction: action.engineAction,
        ),
    ];
  }

  List<TableCard> cards(
    List<OnlineEngineCard> cards, {
    Set<String> highlightedIDs = const {},
  }) {
    return [
      for (final card in cards)
        projectCard(
          card.valueObject,
          highlighted: highlightedIDs.contains(cardID(card.valueObject)),
        ),
    ];
  }

  List<OnlineEngineCard> cardsForSuit(
    List<OnlineSuitCardsSnapshot> entries,
    int suit,
  ) {
    return entries
        .where((entry) => entry.suit == suit)
        .expand((entry) => entry.cards)
        .toList(growable: false);
  }

  TableCard? firstCardForSuit(List<OnlineSuitCardsSnapshot> entries, int suit) {
    final cards = cardsForSuit(entries, suit);
    return cards.isEmpty ? null : projectCard(cards.first.valueObject);
  }

  int workHours(int suit) {
    for (final entry in snapshot.workHours) {
      if (entry.suit == suit) {
        return entry.value;
      }
    }
    return 0;
  }

  OnlineScoreSnapshot scoreFor(int playerID) {
    for (final score in snapshot.scores) {
      if (score.playerID == playerID) {
        return score;
      }
    }
    return OnlineScoreSnapshot(
      playerID: playerID,
      visibleScore: 0,
      finalScore: 0,
    );
  }
}
