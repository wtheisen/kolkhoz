import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_lobby.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_ui_state.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_state_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/controller_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_action_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/profile/models/player_presence.dart';
import 'package:kolkhoz_app/src/app/profile/models/player_profile.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/table_model_assembler.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/table_view_projection.dart';

class OnlineTableProjection {
  const OnlineTableProjection({
    required this.update,
    required this.lobby,
    required this.playerID,
    required this.legalActions,
    this.uiState = const GameUiState(),
  });

  final OnlineSessionUpdate update;
  final GameLobby lobby;
  final int playerID;
  final List<OnlineEngineAction> legalActions;
  final GameUiState uiState;

  OnlineEngineSnapshot get snapshot => update.snapshot;

  TableViewModel project() {
    final phase = phaseName(snapshot.phase);
    final projectedActions = projectedLegalActions();
    return buildTableViewModel(
      uiState: uiState,
      viewer: Viewer(seatID: playerID, privacyMode: viewerPrivacyNone),
      year: snapshot.year,
      phase: phase,
      currentPlayerID: snapshot.currentPlayer,
      trump: suitName(snapshot.trump),
      isFamine: snapshot.isFamine,
      seats: seats(),
      jobs: jobs(projectedActions),
      trick: trick(current: true),
      lastTrick: trick(current: false),
      requisitionEvents: requisitionEvents(),
      exiledByYear: exiledByYear(),
      scoreboard: scoreboard(finalScores: phase == phaseGameOver),
      winnerSeatID: snapshot.winnerID,
      finalScoreboard: scoreboard(finalScores: true),
      legalActions: projectedActions,
      finalYearTrumpCard: snapshot.finalYearTrumpCard.isValid
          ? projectOnlineCard(snapshot.finalYearTrumpCard.valueObject)
          : null,
    );
  }

  List<Seat> seats() {
    final byID = {for (final player in snapshot.players) player.id: player};
    return [
      for (final seat in lobby.seats)
        _seat(
          seat.seatID,
          seat.player.controller,
          byID[seat.seatID],
          seat.profile,
          seat.presence,
        ),
    ];
  }

  Seat _seat(
    int seatID,
    KolkhozPlayerController controller,
    OnlinePlayerSnapshot? player,
    PlayerProfile? profile,
    PlayerPresence? presence,
  ) {
    final remoteHuman =
        controller == KolkhozPlayerController.human && seatID != playerID;
    final hand = player?.hand ?? const <OnlineEngineCard>[];
    final hiddenPlot = player?.hiddenPlot ?? const <OnlineEngineCard>[];
    final profileName = profile?.displayName?.trim();
    return Seat(
      id: seatID,
      name: profileName != null && profileName.isNotEmpty
          ? profileName
          : remoteHuman
          ? 'Remote ${seatID + 1}'
          : seatNameForController(playerID: seatID, controller: controller),
      controller: remoteHuman
          ? controllerRemoteHuman
          : renderControllerName(controller),
      portraitAsset: profile?.portraitAsset ?? 'worker${seatID + 1}',
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
        hiddenCardCount: player?.effectiveHiddenPlotCount ?? 0,
        stacks: [
          for (final stack
              in player?.stacks ?? const <OnlinePlotStackSnapshot>[])
            PlotStackState(
              revealed: cards(stack.revealed),
              hidden: cards(stack.hidden),
              hiddenCardCount: stack.effectiveHiddenCount,
            ),
        ],
      ),
      medals: player?.medals ?? 0,
      visibleScore: scoreFor(seatID).visibleScore,
      profileStats: profile?.stats,
      profileUserID: profile?.userID,
      statusText: _seatStatus(seatID, controller, presence),
    );
  }

  String _seatStatus(
    int seatID,
    KolkhozPlayerController controller,
    PlayerPresence? presence,
  ) {
    if (presence?.abandoned ?? false) {
      return 'LEFT';
    }
    if (presence?.autopilot ?? false) {
      return 'AUTO';
    }
    if (controller == KolkhozPlayerController.human &&
        presence != null &&
        !presence.connected) {
      return 'OFF';
    }
    if (update.turnPlayerID == seatID && update.turnDeadlineAt != null) {
      final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final remaining = (update.turnDeadlineAt! - now).ceil().clamp(0, 999);
      return '${remaining}s';
    }
    return '';
  }

  List<Job> jobs(List<LegalAction> actions) {
    return buildProjectedJobs(
      legalActions: actions,
      trump: snapshot.trump,
      hoursForSuit: workHours,
      claimedForSuit: (suit) => snapshot.claimedJobs.contains(suit),
      rewardForSuit: (suit) => firstCardForSuit(snapshot.revealedJobs, suit),
      assignedCardsForSuit: (suit) => [
        for (final card in cardsForSuit(snapshot.jobBuckets, suit))
          projectOnlineCard(
            card.valueObject,
            assignmentRound: card.assignmentRound,
          ),
        ...pendingAssignmentCards(suit),
      ],
    );
  }

  List<TableCard> pendingAssignmentCards(int targetSuit) {
    return [
      for (final assignment in snapshot.pendingAssignments)
        if (assignment.targetSuit == targetSuit)
          projectOnlineCard(
            assignment.card.valueObject,
            pending: true,
            assignmentRound: snapshot.trickCount,
          ),
    ];
  }

  Trick trick({required bool current}) {
    final plays = current ? snapshot.currentTrick : snapshot.lastTrick;
    return Trick(
      plays: [
        for (final play in plays)
          TrickPlay(
            seatID: play.playerID,
            card: projectOnlineCard(play.card.valueObject),
          ),
      ],
      winnerSeatID: current
          ? nullablePlayerID(snapshot.currentTrickWinner)
          : nullablePlayerID(snapshot.lastWinner),
    );
  }

  List<RequisitionEvent> requisitionEvents() {
    return [
      for (final event in snapshot.requisitionEvents)
        RequisitionEvent(
          seatID: nullablePlayerID(event.playerID),
          suit: suitName(event.suit) ?? 'wheat',
          card: event.card.isValid
              ? projectOnlineCard(event.card.valueObject)
              : null,
          message: event.message,
        ),
    ];
  }

  Map<int, List<TableCard>> exiledByYear() {
    return buildExiledByYear((year) {
      final exiledCards = cardsForSuit(snapshot.exiled, year);
      final owners = exiledPlayersForYear(year);
      return [
        for (final (index, card) in exiledCards.indexed)
          projectOnlineCard(
            card.valueObject,
            ownerSeatID: index < owners.length
                ? nullablePlayerID(owners[index])
                : null,
          ),
      ];
    });
  }

  List<int> exiledPlayersForYear(int year) {
    for (final entry in snapshot.exiledPlayers) {
      if (entry.suit == year) return entry.values;
    }
    return const [];
  }

  List<Score> scoreboard({required bool finalScores}) {
    return buildScoreboard(
      finalScores: finalScores,
      visibleScoreForPlayer: (seatID) => scoreFor(seatID).visibleScore,
      finalScoreForPlayer: (seatID) => scoreFor(seatID).finalScore,
    );
  }

  List<LegalAction> projectedLegalActions() {
    return [
      for (final action in legalActions)
        if (shouldExposeActionForViewer(
          action: action.cValue,
          selection: uiState.selection,
          viewerSeatID: playerID,
        ))
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
        projectOnlineCard(
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
    return cards.isEmpty ? null : projectOnlineCard(cards.first.valueObject);
  }

  TableCard projectOnlineCard(
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
      nomenclature: isNomenclatureFace(card, update.variants, snapshot.trump),
    );
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
