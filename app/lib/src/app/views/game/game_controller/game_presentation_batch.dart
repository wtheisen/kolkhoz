import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_ui_state.dart';

/// Builds the visible state at each semantic boundary in one engine dispatch.
///
/// The engine remains authoritative for the final model. Intermediate models
/// only keep later mutations hidden until their event reaches the front of the
/// presentation queue.
List<TableViewModel> projectPresentationBatch({
  required TableViewModel before,
  required TableViewModel after,
  required List<EngineTransitionEvent> events,
}) {
  if (events.isEmpty) {
    return const [];
  }
  final resolvesTrick = events.any(
    (event) => event.kind == kcTransitionTrickResolved,
  );
  if (!resolvesTrick) {
    return [for (final _ in events) after];
  }

  final assignmentCardIDs = {
    for (final event in events)
      if (event.kind == kcTransitionAssignmentTargeted && event.card.isValid)
        _eventCardID(event),
  };
  final assignedSoFar = <String>{};
  var visible = before;
  final projected = <TableViewModel>[];

  for (final event in events) {
    visible = switch (event.kind) {
      kcTransitionCardMoved when event.toZone == kcObjectZoneCurrentTrick =>
        _withPlayedTrickCard(visible, after, event),
      kcTransitionTrickResolved => _withResolvedTrick(
        before: before,
        after: after,
        assignmentCardIDs: assignmentCardIDs,
      ),
      kcTransitionAssignmentOpened => _withVisibleAssignments(
        after,
        assignmentCardIDs: assignmentCardIDs,
        assignedSoFar: assignedSoFar,
      ),
      kcTransitionAssignmentTargeted => _withVisibleAssignments(
        after,
        assignmentCardIDs: assignmentCardIDs,
        assignedSoFar: assignedSoFar..add(_eventCardID(event)),
      ),
      _ => after,
    };
    projected.add(visible);
  }
  return projected;
}

TableViewModel _withPlayedTrickCard(
  TableViewModel visible,
  TableViewModel finalModel,
  EngineTransitionEvent event,
) {
  final cardID = _eventCardID(event);
  final card =
      visible.table.seats
          .expand((seat) => seat.hand)
          .where((card) => card.id == cardID)
          .firstOrNull ??
      finalModel.table.lastTrick.plays
          .where((play) => play.card.id == cardID)
          .map((play) => play.card)
          .firstOrNull;
  if (card == null) {
    return visible;
  }
  final playedCard = TableCard(
    id: card.id,
    suit: card.suit,
    value: card.value,
    rank: card.rank,
    selected: false,
    highlighted: false,
    pending: card.pending,
    assignmentRound: card.assignmentRound,
    nomenclature: card.nomenclature,
    ownerSeatID: card.ownerSeatID,
  );

  final finalSeat = finalModel.table.seats
      .where((seat) => seat.id == event.playerID)
      .firstOrNull;
  final seats = [
    for (final seat in visible.table.seats)
      if (seat.id == event.playerID && finalSeat != null)
        _seatWithHand(
          seat,
          hand: finalSeat.hand,
          hiddenHandCount: finalSeat.hiddenHandCount,
        )
      else
        seat,
  ];
  final plays = [
    for (final play in visible.table.trick.plays)
      if (play.card.id != cardID) play,
    TrickPlay(seatID: event.playerID, card: playedCard),
  ];
  final winnerSeatID = event.trickWinnerID >= 0
      ? event.trickWinnerID
      : finalModel.table.trick.plays.any((play) => play.card.id == cardID)
      ? finalModel.table.trick.winnerSeatID
      : finalModel.table.lastTrick.plays.any((play) => play.card.id == cardID)
      ? finalModel.table.lastTrick.winnerSeatID
      : visible.table.trick.winnerSeatID;
  return _withTable(
    visible,
    table: _copyTable(
      visible.table,
      seats: seats,
      trick: Trick(plays: plays, winnerSeatID: winnerSeatID),
    ),
    panels: Panels(
      active: panelBrigade,
      available: finalModel.panels.available,
    ),
    selection: finalModel.selection,
  );
}

TableViewModel _withResolvedTrick({
  required TableViewModel before,
  required TableViewModel after,
  required Set<String> assignmentCardIDs,
}) {
  final jobs = _jobsWithVisibleAssignments(
    after.table.jobs,
    assignmentCardIDs: assignmentCardIDs,
    assignedSoFar: const {},
  );
  return _withTable(
    after,
    table: _copyTable(
      after.table,
      phase: before.table.phase,
      phasePrompt: before.table.phasePrompt,
      jobs: jobs,
    ),
    panels: Panels(active: panelBrigade, available: after.panels.available),
  );
}

TableViewModel _withVisibleAssignments(
  TableViewModel after, {
  required Set<String> assignmentCardIDs,
  required Set<String> assignedSoFar,
}) => _withTable(
  after,
  table: _copyTable(
    after.table,
    jobs: _jobsWithVisibleAssignments(
      after.table.jobs,
      assignmentCardIDs: assignmentCardIDs,
      assignedSoFar: assignedSoFar,
    ),
  ),
);

List<Job> _jobsWithVisibleAssignments(
  List<Job> jobs, {
  required Set<String> assignmentCardIDs,
  required Set<String> assignedSoFar,
}) => [
  for (final job in jobs)
    Job(
      suit: job.suit,
      hours: job.hours,
      requiredHours: job.requiredHours,
      claimed: job.claimed,
      reward: job.reward,
      assignedCards: [
        for (final card in job.assignedCards)
          if (!assignmentCardIDs.contains(card.id) ||
              assignedSoFar.contains(card.id))
            card,
      ],
      validAssignmentTarget: job.validAssignmentTarget,
      highlighted: job.highlighted,
    ),
];

String _eventCardID(EngineTransitionEvent event) =>
    '${engineSuitName(event.card.suit) ?? 'unknown'}-${event.card.value}';

Seat _seatWithHand(
  Seat seat, {
  required List<TableCard> hand,
  required int hiddenHandCount,
}) => Seat(
  id: seat.id,
  name: seat.name,
  controller: seat.controller,
  portraitAsset: seat.portraitAsset,
  isViewer: seat.isViewer,
  isCurrentTurn: seat.isCurrentTurn,
  isBrigadeLeader: seat.isBrigadeLeader,
  hand: hand,
  hiddenHandCount: hiddenHandCount,
  plot: seat.plot,
  medals: seat.medals,
  visibleScore: seat.visibleScore,
  profileStats: seat.profileStats,
  profileUserID: seat.profileUserID,
  statusText: seat.statusText,
);

TableViewModel _withTable(
  TableViewModel model, {
  required TableState table,
  Panels? panels,
  SelectionState? selection,
}) => TableViewModel(
  viewer: model.viewer,
  table: table,
  panels: panels ?? model.panels,
  selection: selection ?? model.selection,
  legalActions: const [],
  seed: model.seed,
);

TableState _copyTable(
  TableState table, {
  String? phase,
  Prompt? phasePrompt,
  List<Seat>? seats,
  List<Job>? jobs,
  Trick? trick,
}) => TableState(
  year: table.year,
  phase: phase ?? table.phase,
  phasePrompt: phasePrompt ?? table.phasePrompt,
  currentPlayerID: table.currentPlayerID,
  trump: table.trump,
  isFamine: table.isFamine,
  maxTricks: table.maxTricks,
  seats: seats ?? table.seats,
  jobs: jobs ?? table.jobs,
  trick: trick ?? table.trick,
  lastTrick: table.lastTrick,
  requisitionEvents: table.requisitionEvents,
  exiledByYear: table.exiledByYear,
  scoreboard: table.scoreboard,
  gameResult: table.gameResult,
  finalYearTrumpCard: table.finalYearTrumpCard,
);
