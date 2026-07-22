import 'dart:ffi';

import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_action_codec.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/controller_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_action_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_ui_state.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/table_model_assembler.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

class TableViewProjection {
  const TableViewProjection({
    required this.bridge,
    required this.engine,
    this.controllers = KolkhozPlayerController.defaultControllers,
    this.variants = KolkhozGameVariants.kolkhoz,
    this.uiState = const GameUiState(),
    this.revealedPlayerID,
  });

  final KolkhozCEngineBridge bridge;
  final Pointer<KCEngine> engine;
  final List<KolkhozPlayerController> controllers;
  final KolkhozGameVariants variants;
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
    return buildTableViewModel(
      uiState: uiState,
      viewer: Viewer(seatID: viewerSeatID, privacyMode: privacyMode),
      year: bridge.year(engine),
      phase: phase,
      currentPlayerID: bridge.currentPlayer(engine),
      trump: suitName(bridge.trump(engine)),
      isFamine: bridge.isFamine(engine),
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
      winnerSeatID: bridge.winnerID(engine),
      finalScoreboard: scoreboard(finalScores: true),
      legalActions: legalActions,
      finalYearTrumpCard: bridge.finalYearTrumpCard(engine).isValid
          ? projectEngineCard(bridge.finalYearTrumpCard(engine))
          : null,
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
    return buildProjectedJobs(
      legalActions: legalActions,
      trump: bridge.trump(engine),
      hoursForSuit: (suit) => bridge.workHours(engine, suit),
      claimedForSuit: (suit) => bridge.claimedJob(engine, suit),
      rewardForSuit: (suit) => bridge.hasRevealedJob(engine, suit)
          ? projectEngineCard(bridge.revealedJobCard(engine, suit))
          : null,
      assignedCardsForSuit: (suit) => [
        ...jobBucketCards(suit),
        ...pendingAssignmentCards(suit),
      ],
    );
  }

  List<TableCard> jobBucketCards(int suit) {
    return [
      for (var index = 0; index < bridge.jobBucketCount(engine, suit); index++)
        projectEngineCard(
          bridge.jobBucketCard(engine, suit, index),
          assignmentRound: bridge.jobBucketTrick(engine, suit, index),
        ),
    ];
  }

  List<TableCard> pendingAssignmentCards(int targetSuit) {
    final result = <TableCard>[];
    for (var index = 0; index < bridge.lastTrickCount(engine); index++) {
      if (bridge.pendingAssignmentTarget(engine, index) == targetSuit) {
        result.add(
          projectEngineCard(
            bridge.lastTrickCard(engine, index),
            pending: true,
            assignmentRound: bridge.trickCount(engine),
          ),
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
          card: projectEngineCard(
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
              ? projectEngineCard(bridge.requisitionEventCard(engine, index))
              : null,
          message: requisitionMessage(
            bridge.requisitionEventMessageKind(engine, index),
          ),
        ),
    ];
  }

  Map<int, List<TableCard>> exiledByYear() {
    return buildExiledByYear(
      (year) => [
        for (var index = 0; index < bridge.exiledCount(engine, year); index++)
          projectEngineCard(
            bridge.exiledCard(engine, year, index),
            ownerSeatID: nullablePlayerID(
              bridge.exiledPlayer(engine, year, index),
            ),
          ),
      ],
    );
  }

  List<Score> scoreboard({required bool finalScores}) {
    return buildScoreboard(
      finalScores: finalScores,
      visibleScoreForPlayer: (playerID) =>
          bridge.visibleScore(engine, playerID),
      finalScoreForPlayer: (playerID) => bridge.finalScore(engine, playerID),
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
        projectEngineCard(
          cardAt(index),
          highlighted: highlightedIDs.contains(cardID(cardAt(index))),
        ),
    ];
  }

  TableCard projectEngineCard(
    EngineCardValue card, {
    bool highlighted = false,
    bool pending = false,
    int? assignmentRound,
    int? ownerSeatID,
  }) {
    return projectCard(
      card,
      highlighted: highlighted,
      pending: pending,
      assignmentRound: assignmentRound,
      ownerSeatID: ownerSeatID,
      nomenclature: isNomenclatureFace(card, variants, bridge.trump(engine)),
    );
  }
}

TableCard projectCard(
  EngineCardValue card, {
  bool highlighted = false,
  bool pending = false,
  int? assignmentRound,
  int? ownerSeatID,
  bool nomenclature = false,
}) {
  return TableCard(
    id: cardID(card),
    suit: suitName(card.suit) ?? 'wheat',
    value: card.value,
    rank: rankName(card.value),
    selected: false,
    highlighted: highlighted,
    pending: pending,
    assignmentRound: assignmentRound,
    nomenclature: nomenclature,
    ownerSeatID: ownerSeatID,
  );
}

bool isNomenclatureFace(
  EngineCardValue card,
  KolkhozGameVariants variants,
  int trump,
) {
  return variants.nomenclature &&
      trump >= 0 &&
      card.suit == trump &&
      card.value >= 11 &&
      card.value <= 13;
}
