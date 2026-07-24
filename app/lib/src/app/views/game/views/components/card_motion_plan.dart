import 'package:flutter/widgets.dart';
import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'card_motion_geometry.dart';

export 'card_motion_geometry.dart';

@immutable
class CardFlight {
  const CardFlight({
    required this.id,
    required this.card,
    required this.from,
    required this.to,
    required this.destinationZone,
    this.durationScale = 1,
    this.audiencePanel,
    this.reportsJobArrival = true,
    this.faceDown = false,
    this.revealBeforeFlight = false,
    this.requisitioned = false,
  });

  final int id;
  final TableCard card;
  final Rect from;
  final Rect to;
  final MotionZone destinationZone;
  final double durationScale;
  final String? audiencePanel;
  final bool reportsJobArrival;
  final bool faceDown;
  final bool revealBeforeFlight;
  final bool requisitioned;
}

@immutable
class JobCardArrival {
  const JobCardArrival({required this.cardID, required this.suit});

  final String cardID;
  final String suit;
}

/// Immutable playback instructions produced from one presented game revision.
///
/// Flights within a stage run together. Stages run in list order.
@immutable
class CardMotionPlan {
  CardMotionPlan({
    required this.transitionID,
    required List<List<CardFlight>> stages,
    required List<JobCardArrival> immediateJobArrivals,
    required Set<String> presentedAssignmentCardIDs,
    required this.nextFlightID,
  }) : stages = List.unmodifiable([
         for (final stage in stages) List<CardFlight>.unmodifiable(stage),
       ]),
       immediateJobArrivals = List.unmodifiable(immediateJobArrivals),
       presentedAssignmentCardIDs = Set.unmodifiable(
         presentedAssignmentCardIDs,
       );

  final int? transitionID;
  final List<List<CardFlight>> stages;
  final List<JobCardArrival> immediateJobArrivals;
  final Set<String> presentedAssignmentCardIDs;
  final int nextFlightID;

  Iterable<CardFlight> get flights => stages.expand((stage) => stage);
}

@immutable
class CardMotionChanges {
  CardMotionChanges({
    required Map<String, MotionZone> nextZones,
    required Map<String, TableCard> nextCards,
    required Set<String> exiledCardIDs,
    required Set<String> suppressedCardIDs,
    required Set<String> presentedAssignmentCardIDs,
    required this.leavingAssignment,
  }) : nextZones = Map.unmodifiable(nextZones),
       nextCards = Map.unmodifiable(nextCards),
       exiledCardIDs = Set.unmodifiable(exiledCardIDs),
       suppressedCardIDs = Set.unmodifiable(suppressedCardIDs),
       presentedAssignmentCardIDs = Set.unmodifiable(
         presentedAssignmentCardIDs,
       );

  final Map<String, MotionZone> nextZones;
  final Map<String, TableCard> nextCards;
  final Set<String> exiledCardIDs;
  final Set<String> suppressedCardIDs;
  final Set<String> presentedAssignmentCardIDs;
  final bool leavingAssignment;
}

abstract interface class CardMotionGeometryResolver {
  Rect? destination({
    required String cardID,
    required MotionZone? previousZone,
    required MotionZone nextZone,
    required MotionGeometry current,
  });

  Rect? source({
    required String cardID,
    required MotionZone? previousZone,
    required MotionZone nextZone,
    required MotionGeometry previous,
    required MotionGeometry current,
    required TableViewModel previousModel,
    required TableViewModel nextModel,
  });
}

/// Produces immutable playback instructions from model and geometry snapshots.
///
/// This function has no widget lifecycle or animation-controller ownership;
/// [CardMotionLayer] only collects its inputs and runs the returned stages.
CardMotionPlan planCardFlights({
  required bool motionEnabled,
  required double minimumFlightDistance,
  required TableViewModel previousModel,
  required TableViewModel nextModel,
  required Map<String, MotionZone> previousZones,
  required Map<String, MotionZone> nextZones,
  required Map<String, TableCard> previousCards,
  required Map<String, TableCard> nextCards,
  required MotionGeometry previousGeometry,
  required MotionGeometry currentGeometry,
  required CardMotionGeometryResolver geometry,
  required int? transitionID,
  required List<String> assignmentCardIDs,
  required Map<String, String> assignmentTargets,
  required Set<String> suppressedCardIDs,
  required Set<String> presentedAssignmentCardIDs,
  required int initialFlightID,
  bool explicitTransition = false,
}) {
  if (!motionEnabled) {
    return CardMotionPlan(
      transitionID: transitionID,
      stages: const [],
      immediateJobArrivals: jobCardArrivalsForChangedZones(
        previousZones,
        nextZones,
        nextCards,
      ),
      presentedAssignmentCardIDs: presentedAssignmentCardIDs,
      nextFlightID: initialFlightID,
    );
  }
  final changes = planCardMotionChanges(
    previousModel: previousModel,
    nextModel: nextModel,
    nextZones: nextZones,
    previousCards: previousCards,
    nextCards: nextCards,
    assignmentTargets: assignmentTargets,
    suppressedCardIDs: suppressedCardIDs,
    presentedAssignmentCardIDs: presentedAssignmentCardIDs,
    explicitTransition: explicitTransition,
  );
  final flights = <CardFlight>[];
  var nextFlightID = initialFlightID;
  final routedNextZones = {
    ...changes.nextZones,
    for (final cardID in changes.exiledCardIDs)
      cardID: const MotionZone.northExile(),
  };
  for (final entry in routedNextZones.entries) {
    final cardID = entry.key;
    if (changes.suppressedCardIDs.contains(cardID)) {
      continue;
    }
    final previousZone = previousZones[cardID];
    if (previousZone == entry.value) {
      continue;
    }
    final to = geometry.destination(
      cardID: cardID,
      previousZone: previousZone,
      nextZone: entry.value,
      current: currentGeometry,
    );
    if (to == null) {
      continue;
    }
    final from = geometry.source(
      cardID: cardID,
      previousZone: previousZone,
      nextZone: entry.value,
      previous: previousGeometry,
      current: currentGeometry,
      previousModel: previousModel,
      nextModel: nextModel,
    );
    final card = changes.nextCards[cardID] ?? previousCards[cardID];
    if (from == null ||
        card == null ||
        (from.center - to.center).distance < minimumFlightDistance) {
      continue;
    }
    final requisitioned =
        entry.value.kind == MotionZoneKind.northExile ||
        (previousZone?.isPlot == true &&
            entry.value.kind == MotionZoneKind.exiled);
    flights.add(
      CardFlight(
        id: nextFlightID++,
        card: card,
        from: from,
        to: to,
        destinationZone: entry.value,
        durationScale: cardFlightDurationScaleForZones(
          previousZone: previousZone,
          nextZone: entry.value,
          model: previousModel,
        ),
        faceDown: cardFlightShouldBeFaceDown(
          previousZone: previousZone,
          nextZone: entry.value,
          previousModel: previousModel,
          nextModel: nextModel,
        ),
        revealBeforeFlight:
            requisitioned && previousZone?.kind == MotionZoneKind.plotHidden,
        requisitioned: requisitioned,
      ),
    );
  }
  if (flights.isEmpty) {
    return CardMotionPlan(
      transitionID: transitionID,
      stages: const [],
      immediateJobArrivals: jobCardArrivalsForChangedZones(
        previousZones,
        changes.nextZones,
        changes.nextCards,
      ),
      presentedAssignmentCardIDs: changes.presentedAssignmentCardIDs,
      nextFlightID: nextFlightID,
    );
  }
  final flownJobCardIDs = {
    for (final flight in flights)
      if (flight.destinationZone.kind == MotionZoneKind.job) flight.card.id,
  };
  final immediateJobArrivals = jobCardArrivalsForChangedZones(
    previousZones,
    changes.nextZones,
    changes.nextCards,
  ).where((arrival) => !flownJobCardIDs.contains(arrival.cardID)).toList();
  final assignmentOrder = {
    for (final entry in assignmentCardIDs.indexed) entry.$2: entry.$1,
  };
  final assignmentFlights =
      flights
          .where((flight) => assignmentOrder.containsKey(flight.card.id))
          .toList()
        ..sort(
          (left, right) => assignmentOrder[left.card.id]!.compareTo(
            assignmentOrder[right.card.id]!,
          ),
        );
  final otherFlights = flights
      .where((flight) => !assignmentOrder.containsKey(flight.card.id))
      .toList();
  return CardMotionPlan(
    transitionID: transitionID,
    stages: assignmentFlights.isNotEmpty
        ? [
            if (otherFlights.isNotEmpty) otherFlights,
            for (final flight in assignmentFlights) [flight],
          ]
        : [flights],
    immediateJobArrivals: immediateJobArrivals,
    presentedAssignmentCardIDs: changes.presentedAssignmentCardIDs,
    nextFlightID: nextFlightID,
  );
}

bool cardFlightShouldBeFaceDown({
  required MotionZone? previousZone,
  required MotionZone nextZone,
  required TableViewModel previousModel,
  required TableViewModel nextModel,
}) {
  if (previousZone == null) {
    return false;
  }
  final seatID =
      previousZone.kind == MotionZoneKind.hand &&
          nextZone.isPlot &&
          previousZone.seatID == nextZone.seatID
      ? nextZone.seatID
      : previousZone.isPlot &&
            nextZone.kind == MotionZoneKind.hand &&
            previousZone.seatID == nextZone.seatID
      ? previousZone.seatID
      : null;
  return seatID != null && !motionSeatIsViewer(previousModel, seatID);
}

/// Derives card-zone changes without reading widget state or layout geometry.
CardMotionChanges planCardMotionChanges({
  required TableViewModel previousModel,
  required TableViewModel nextModel,
  required Map<String, MotionZone> nextZones,
  required Map<String, TableCard> previousCards,
  required Map<String, TableCard> nextCards,
  required Map<String, String> assignmentTargets,
  required Set<String> suppressedCardIDs,
  required Set<String> presentedAssignmentCardIDs,
  bool explicitTransition = false,
}) {
  final plannedZones = Map<String, MotionZone>.of(nextZones);
  final plannedCards = Map<String, TableCard>.of(nextCards);
  final presented = Set<String>.of(presentedAssignmentCardIDs);

  if (previousModel.table.phase == phaseAssignment &&
      nextModel.table.phase == phaseAssignment) {
    final pendingNext = {
      for (final job in nextModel.table.jobs)
        for (final card in job.assignedCards)
          if (card.pending) card.id,
    };
    presented.removeWhere((cardID) => !pendingNext.contains(cardID));
  }
  presented.addAll(assignmentTargets.keys);

  final leavingAssignment =
      !explicitTransition &&
      previousModel.table.phase == phaseAssignment &&
      nextModel.table.phase != phaseAssignment;
  final effectiveSuppressed = {
    ...suppressedCardIDs,
    if (leavingAssignment) ...presented,
  };

  for (final entry in assignmentTargets.entries) {
    final card = previousCards[entry.key] ?? plannedCards[entry.key];
    if (card != null) {
      plannedZones[entry.key] = MotionZone.job(entry.value);
      plannedCards[entry.key] = card;
    }
  }

  final previousExiled = {
    for (final card
        in previousModel.table.exiledByYear[previousModel.table.year] ??
            const <TableCard>[])
      card.id,
  };
  final nextExiled = {
    for (final card
        in nextModel.table.exiledByYear[nextModel.table.year] ??
            const <TableCard>[])
      card.id,
  };

  return CardMotionChanges(
    nextZones: plannedZones,
    nextCards: plannedCards,
    exiledCardIDs: nextExiled.difference(previousExiled),
    suppressedCardIDs: effectiveSuppressed,
    presentedAssignmentCardIDs: leavingAssignment ? const {} : presented,
    leavingAssignment: leavingAssignment,
  );
}

int? plotSeatIDForMotionCard(TableViewModel model, String cardID) {
  for (final seat in model.table.seats) {
    if (seat.plot.hidden.any((card) => card.id == cardID) ||
        seat.plot.revealed.any((card) => card.id == cardID) ||
        seat.plot.stacks.any(
          (stack) =>
              stack.hidden.any((card) => card.id == cardID) ||
              stack.revealed.any((card) => card.id == cardID),
        )) {
      return seat.id;
    }
  }
  for (final event in model.table.requisitionEvents.reversed) {
    if (event.card?.id == cardID && event.seatID != null) {
      return event.seatID;
    }
  }
  return null;
}

double cardFlightDurationScaleForZones({
  required MotionZone? previousZone,
  required MotionZone nextZone,
  required TableViewModel model,
}) {
  if (previousZone == null) {
    final seatID = nextZone.kind == MotionZoneKind.trick
        ? nextZone.seatID
        : null;
    if (seatID != null && !motionSeatIsViewer(model, seatID)) {
      return playerInfoCardFlightDurationScale;
    }
    return 1;
  }
  if (nextZone.kind == MotionZoneKind.northExile ||
      (previousZone.isPlot && nextZone.kind == MotionZoneKind.exiled)) {
    return requisitionCardFlightDurationScale;
  }
  if (previousZone.kind == MotionZoneKind.trick &&
      nextZone.kind == MotionZoneKind.job) {
    return jobAssignmentCardFlightDurationScale;
  }
  final previousSeat = previousZone.kind == MotionZoneKind.hand
      ? previousZone.seatID
      : null;
  final nextSeat = nextZone.kind == MotionZoneKind.trick
      ? nextZone.seatID
      : null;
  if (previousSeat == null ||
      previousSeat != nextSeat ||
      motionSeatIsViewer(model, previousSeat)) {
    return 1;
  }
  return playerInfoCardFlightDurationScale;
}

bool motionSeatIsViewer(TableViewModel model, int seatID) {
  return model.table.seats.any((seat) => seat.id == seatID && seat.isViewer);
}

List<JobCardArrival> jobCardArrivalsForChangedZones(
  Map<String, MotionZone> previousZones,
  Map<String, MotionZone> nextZones,
  Map<String, TableCard> nextCards,
) {
  return [
    for (final entry in nextZones.entries)
      if (entry.value.kind == MotionZoneKind.job &&
          previousZones[entry.key] != entry.value &&
          nextCards.containsKey(entry.key))
        JobCardArrival(cardID: entry.key, suit: entry.value.suit!),
  ];
}
