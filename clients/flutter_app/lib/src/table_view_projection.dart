import 'dart:ffi';

import 'c_engine_bridge.dart';
import 'controller_display.dart';
import 'engine_action_projection.dart';
import 'game_constants.dart';
import 'game_ui_state.dart';
import 'render_model.dart';

class TableViewProjection {
  const TableViewProjection({
    required this.bridge,
    required this.engine,
    this.controllers = KolkhozPlayerController.defaultControllers,
    this.uiState = const GameUiState(),
  });

  final KolkhozCEngineBridge bridge;
  final Pointer<KCEngine> engine;
  final List<KolkhozPlayerController> controllers;
  final GameUiState uiState;

  TableViewModel project() {
    final phase = phaseName(bridge.phase(engine));
    final engineActions = bridge.legalActions(engine);
    final normalizedControllers = KolkhozPlayerController.normalized(
      controllers,
    );
    final viewerSeatID = viewerSeatIDForControllers(normalizedControllers);
    final legalActions = projectedLegalActions(engineActions, viewerSeatID);
    return TableViewModel(
      viewer: Viewer(seatID: viewerSeatID, privacyMode: viewerPrivacyNone),
      table: TableState(
        year: bridge.year(engine),
        phase: phase,
        phasePrompt: phasePrompt(phase),
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
      panels: Panels(
        active: uiState.activePanel ?? actionPanelForPhase(phase),
        available: availableGamePanels,
      ),
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
          ),
          medals: bridge.playerMedals(engine, playerID),
          visibleScore: bridge.visibleScore(engine, playerID),
        ),
    ];
  }

  List<Job> jobs(List<LegalAction> legalActions) {
    final assignmentTargets = {
      for (final action in legalActions)
        if (action.kind == actionAssign &&
            action.engineAction.targetSuit != null)
          action.engineAction.targetSuit!,
    };
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
    if (phase != phaseGameOver) {
      return null;
    }
    return GameResult(
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
            engineAction: engineAction(action),
          ),
    ];
  }

  EngineAction engineAction(CEngineActionValue action) {
    return EngineAction(
      kind: actionKindName(action.kind),
      playerID: action.playerID,
      suit: suitName(action.suit),
      card: engineCard(action.card),
      handCard: engineCard(action.handCard),
      plotCard: engineCard(action.plotCard),
      plotZone: plotZoneName(action.plotZone),
      targetSuit: suitName(action.targetSuit),
    );
  }

  Prompt phasePrompt(String phase) {
    return switch (phase) {
      phasePlanning => Prompt(
        title: bridge.isFamine(engine) ? 'Famine year' : 'Choose Trump',
        body: bridge.isFamine(engine)
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

EngineCard? engineCard(EngineCardValue card) {
  if (!card.isValid) {
    return null;
  }
  return EngineCard(suit: suitName(card.suit) ?? 'wheat', value: card.value);
}

String actionPanelForPhase(String phase) {
  return switch (phase) {
    phaseAssignment => panelJobs,
    phaseSwap || phaseRequisition => panelPlot,
    _ => panelBrigade,
  };
}
