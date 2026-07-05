import 'dart:ffi';

import 'c_engine_action_codec.dart';
import 'c_engine_bridge.dart';
import 'controller_display.dart';
import 'engine_action_projection.dart';
import 'game_constants.dart';
import 'game_ui_state.dart';
import 'render_model.dart';
import 'table_projection_helpers.dart';

class TableViewProjection {
  const TableViewProjection({
    required this.bridge,
    required this.engine,
    this.controllers = KolkhozPlayerController.defaultControllers,
    this.uiState = const GameUiState(),
    this.revealedPlayerID,
  });

  final KolkhozCEngineBridge bridge;
  final Pointer<KCEngine> engine;
  final List<KolkhozPlayerController> controllers;
  final GameUiState uiState;
  final int? revealedPlayerID;

  TableViewModel project() {
    final phase = phaseName(bridge.phase(engine));
    final engineActions = bridge.legalActions(engine);
    final normalizedControllers = KolkhozPlayerController.normalized(
      controllers,
    );
    final viewerSeatID = activeViewerSeatIDForState(
      controllers: normalizedControllers,
      phase: phase,
      currentPlayerID: bridge.currentPlayer(engine),
      assignmentWinnerID: nullablePlayerID(bridge.lastWinner(engine)),
    );
    final privacyMode =
        phase != phaseGameOver &&
            hasMultipleHumanControllers(normalizedControllers) &&
            revealedPlayerID != viewerSeatID
        ? viewerPrivacyHotSeatHidden
        : viewerPrivacyNone;
    final legalActions = projectedLegalActions(engineActions, viewerSeatID);
    return TableViewModel(
      viewer: Viewer(seatID: viewerSeatID, privacyMode: privacyMode),
      table: TableState(
        year: bridge.year(engine),
        phase: phase,
        phasePrompt: phasePromptForPhase(
          phase,
          isFamine: bridge.isFamine(engine),
        ),
        currentPlayerID: bridge.currentPlayer(engine),
        trump: suitName(bridge.trump(engine)),
        isFamine: bridge.isFamine(engine),
        maxTricks: bridge.isFamine(engine) ? 3 : 4,
        seats: seats(
          engineActions: engineActions,
          controllers: normalizedControllers,
          viewerSeatID: viewerSeatID,
        ),
        jobs: jobs(legalActions),
        trick: trick(current: true),
        lastTrick: trick(current: false),
        requisitionEvents: requisitionEvents(),
        exiledByYear: exiledByYear(),
        scoreboard: scoreboard(finalScores: phase == phaseGameOver),
        gameResult: gameResult(phase),
      ),
      panels: panelsForPhase(uiState, phase),
      selection: uiState.selection,
      legalActions: legalActions,
    );
  }

  List<Seat> seats({
    required List<CEngineActionValue> engineActions,
    required List<KolkhozPlayerController> controllers,
    required int viewerSeatID,
  }) {
    return [
      for (var playerID = 0; playerID < kolkhozPlayerCount; playerID++)
        Seat(
          id: playerID,
          name: seatNameForController(
            playerID: playerID,
            controller: controllers[playerID],
          ),
          controller: renderControllerName(controllers[playerID]),
          portraitAsset: 'worker${playerID + 1}',
          isViewer: playerID == viewerSeatID,
          isCurrentTurn: bridge.currentPlayer(engine) == playerID,
          isBrigadeLeader: bridge.playerBrigadeLeader(engine, playerID),
          hand: cards(
            bridge.handCount(engine, playerID),
            (index) => bridge.handCard(engine, playerID, index),
            highlightedIDs: handActionCardIDs(engineActions, playerID),
          ),
          hiddenHandCount: playerID == viewerSeatID
              ? 0
              : bridge.handCount(engine, playerID),
          plot: PlotState(
            revealed: cards(
              bridge.plotRevealedCount(engine, playerID),
              (index) => bridge.plotRevealedCard(engine, playerID, index),
              highlightedIDs: playerID == viewerSeatID
                  ? plotActionCardIDs(
                      engineActions,
                      plotZoneRevealed,
                      playerID: playerID,
                    )
                  : const {},
            ),
            hidden: cards(
              bridge.plotHiddenCount(engine, playerID),
              (index) => bridge.plotHiddenCard(engine, playerID, index),
              highlightedIDs: playerID == viewerSeatID
                  ? plotActionCardIDs(
                      engineActions,
                      plotZoneHidden,
                      playerID: playerID,
                    )
                  : const {},
            ),
            stacks: plotStacks(playerID),
          ),
          medals: bridge.playerMedals(engine, playerID),
          visibleScore: bridge.visibleScore(engine, playerID),
        ),
    ];
  }

  List<PlotStackState> plotStacks(int playerID) {
    return [
      for (
        var stackIndex = 0;
        stackIndex < bridge.plotStackCount(engine, playerID);
        stackIndex += 1
      )
        PlotStackState(
          revealed: cards(
            bridge.plotStackRevealedCount(engine, playerID, stackIndex),
            (cardIndex) => bridge.plotStackRevealedCard(
              engine,
              playerID,
              stackIndex,
              cardIndex,
            ),
          ),
          hidden: cards(
            bridge.plotStackHiddenCount(engine, playerID, stackIndex),
            (cardIndex) => bridge.plotStackHiddenCard(
              engine,
              playerID,
              stackIndex,
              cardIndex,
            ),
          ),
        ),
    ];
  }

  List<Job> jobs(List<LegalAction> legalActions) {
    final assignmentTargets = assignmentTargetSuits(legalActions);
    return [
      for (var suit = 0; suit < displaySuitOrder.length; suit++)
        Job(
          suit: suitName(suit)!,
          hours: bridge.workHours(engine, suit),
          requiredHours: jobRequiredHours,
          claimed: bridge.claimedJob(engine, suit),
          reward: bridge.hasRevealedJob(engine, suit)
              ? projectCard(bridge.revealedJobCard(engine, suit))
              : null,
          assignedCards: [
            ...cards(
              bridge.jobBucketCount(engine, suit),
              (index) => bridge.jobBucketCard(engine, suit, index),
            ),
            ...pendingAssignmentCards(suit),
          ],
          validAssignmentTarget: assignmentTargets.contains(suitName(suit)),
          highlighted: bridge.trump(engine) == suit,
        ),
    ];
  }

  List<TableCard> pendingAssignmentCards(int targetSuit) {
    final result = <TableCard>[];
    for (var index = 0; index < bridge.lastTrickCount(engine); index++) {
      if (bridge.pendingAssignmentTarget(engine, index) == targetSuit) {
        result.add(
          projectCard(bridge.lastTrickCard(engine, index), pending: true),
        );
      }
    }
    return result;
  }

  Trick trick({required bool current}) {
    final count = current
        ? bridge.currentTrickCount(engine)
        : bridge.lastTrickCount(engine);
    final plays = [
      for (var index = 0; index < count; index++)
        TrickPlay(
          seatID: current
              ? bridge.currentTrickPlayer(engine, index)
              : bridge.lastTrickPlayer(engine, index),
          card: projectCard(
            current
                ? bridge.currentTrickCard(engine, index)
                : bridge.lastTrickCard(engine, index),
          ),
        ),
    ];
    return Trick(
      plays: plays,
      winnerSeatID: current
          ? null
          : nullablePlayerID(bridge.lastWinner(engine)),
    );
  }

  List<RequisitionEvent> requisitionEvents() {
    return [
      for (var index = 0; index < bridge.requisitionEventCount(engine); index++)
        RequisitionEvent(
          seatID: nullablePlayerID(
            bridge.requisitionEventPlayer(engine, index),
          ),
          suit: suitName(bridge.requisitionEventSuit(engine, index)) ?? 'wheat',
          card: bridge.requisitionEventCard(engine, index).isValid
              ? projectCard(bridge.requisitionEventCard(engine, index))
              : null,
          message: requisitionMessage(
            bridge.requisitionEventMessageKind(engine, index),
          ),
        ),
    ];
  }

  Map<int, List<TableCard>> exiledByYear() {
    return {
      for (var year = 1; year <= finalGameYear; year++)
        year: cards(
          bridge.exiledCount(engine, year),
          (index) => bridge.exiledCard(engine, year, index),
        ),
    };
  }

  List<Score> scoreboard({required bool finalScores}) {
    return [
      for (var playerID = 0; playerID < kolkhozPlayerCount; playerID++)
        Score(
          seatID: playerID,
          visibleScore: bridge.visibleScore(engine, playerID),
          finalScore: finalScores ? bridge.finalScore(engine, playerID) : null,
        ),
    ];
  }

  GameResult? gameResult(String phase) {
    return gameResultForPhase(
      phase,
      winnerSeatID: bridge.winnerID(engine),
      scores: scoreboard(finalScores: true),
    );
  }

  List<LegalAction> projectedLegalActions(
    List<CEngineActionValue> actions,
    int viewerSeatID,
  ) {
    return [
      for (final action in actions)
        if (shouldExposeActionForViewer(
          action: action,
          selection: uiState.selection,
          viewerSeatID: viewerSeatID,
        ))
          LegalAction(
            kind: actionKindName(action.kind),
            label: actionLabel(action.kind),
            engineAction: engineActionFromCValue(action),
          ),
    ];
  }

  List<TableCard> cards(
    int count,
    EngineCardValue Function(int index) cardAt, {
    Set<String> highlightedIDs = const {},
  }) {
    return [
      for (var index = 0; index < count; index++)
        projectCard(
          cardAt(index),
          highlighted: highlightedIDs.contains(cardID(cardAt(index))),
        ),
    ];
  }
}

TableCard projectCard(
  EngineCardValue card, {
  bool highlighted = false,
  bool pending = false,
}) {
  return TableCard(
    id: cardID(card),
    suit: suitName(card.suit) ?? 'wheat',
    value: card.value,
    rank: rankName(card.value),
    selected: false,
    highlighted: highlighted,
    pending: pending,
  );
}
