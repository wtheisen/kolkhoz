import 'package:flutter/widgets.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'card_motion_plan.dart';

export 'card_motion_plan.dart';

class DefaultCardMotionGeometryResolver implements CardMotionGeometryResolver {
  const DefaultCardMotionGeometryResolver(this.tokens);

  final DesignTokens tokens;

  @override
  Rect? destination({
    required String cardID,
    required MotionZone? previousZone,
    required MotionZone nextZone,
    required MotionGeometry current,
  }) => cardFlightDestinationRect(
    cardID: cardID,
    previousZone: previousZone,
    nextZone: nextZone,
    currentRects: current,
    tokens: tokens,
  );

  @override
  Rect? source({
    required String cardID,
    required MotionZone previousZone,
    required MotionZone nextZone,
    required MotionGeometry previous,
    required TableViewModel model,
  }) => cardFlightSourceRect(
    cardID: cardID,
    previousZone: previousZone,
    nextZone: nextZone,
    previousRects: previous,
    model: model,
    tokens: tokens,
  );

  @override
  Rect? sourceForNewCard({
    required MotionZone nextZone,
    required MotionGeometry previous,
    required TableViewModel model,
  }) => newTrickCardFallbackSourceRect(
    nextZone: nextZone,
    previousRects: previous,
    model: model,
    tokens: tokens,
  );

  @override
  Rect? fallbackSource({
    required MotionZone? previousZone,
    required MotionZone nextZone,
    required MotionGeometry current,
  }) => cardFlightFallbackSourceRect(
    previousZone: previousZone,
    nextZone: nextZone,
    currentRects: current,
    tokens: tokens,
  );

  @override
  Rect? plotSource({required int seatID, required MotionGeometry current}) =>
      plotCardMotionSourceRect(
        seatID: seatID,
        currentRects: current,
        tokens: tokens,
      );

  @override
  Rect? northTarget(MotionGeometry current) =>
      northCardMotionTargetRect(currentRects: current, tokens: tokens);
}

class CardMotionEntry {
  const CardMotionEntry({required this.card, required this.zone});

  final TableCard card;
  final MotionZone zone;
}

Iterable<CardMotionEntry> cardMotionEntries(TableViewModel model) sync* {
  for (final seat in model.table.seats) {
    for (final card in seat.hand) {
      yield CardMotionEntry(card: card, zone: MotionZone.hand(seat.id));
    }
    for (final card in seat.plot.hidden) {
      yield CardMotionEntry(card: card, zone: MotionZone.plotHidden(seat.id));
    }
    for (final card in seat.plot.revealed) {
      yield CardMotionEntry(card: card, zone: MotionZone.plotRevealed(seat.id));
    }
    for (final (stackIndex, stack) in seat.plot.stacks.indexed) {
      for (final card in stack.revealed) {
        yield CardMotionEntry(
          card: card,
          zone: MotionZone.plotStackRevealed(seat.id, stackIndex),
        );
      }
    }
  }
  for (final play in model.table.trick.plays) {
    yield CardMotionEntry(card: play.card, zone: MotionZone.trick(play.seatID));
  }
  for (final play in model.table.lastTrick.plays) {
    yield CardMotionEntry(card: play.card, zone: MotionZone.trick(play.seatID));
  }
  for (final job in model.table.jobs) {
    if (job.reward case final reward?) {
      yield CardMotionEntry(card: reward, zone: MotionZone.reward(job.suit));
    }
    for (final card in job.assignedCards) {
      if (!card.pending) {
        yield CardMotionEntry(card: card, zone: MotionZone.job(job.suit));
      }
    }
  }
  if (model.table.finalYearTrumpCard case final finalTrumpCard?) {
    yield CardMotionEntry(
      card: finalTrumpCard,
      zone: const MotionZone.finalTrump(),
    );
  }
  for (final entry in model.table.exiledByYear.entries) {
    for (final card in entry.value) {
      yield CardMotionEntry(card: card, zone: MotionZone.exiled(entry.key));
    }
  }
}

Map<String, MotionZone> cardMotionZones(TableViewModel model) => {
  for (final entry in cardMotionEntries(model)) entry.card.id: entry.zone,
};

Map<String, TableCard> cardMotionCards(TableViewModel model) => {
  for (final entry in cardMotionEntries(model)) entry.card.id: entry.card,
};

Rect? cardFlightSourceRect({
  required String cardID,
  required MotionZone previousZone,
  required MotionZone nextZone,
  required MotionGeometry previousRects,
  required TableViewModel model,
  required DesignTokens tokens,
}) {
  final seatID = handToTrickFlightSeatID(previousZone, nextZone);
  if (seatID != null && !motionSeatIsViewer(model, seatID)) {
    return playerCardMotionSourceRect(
      seatID: seatID,
      previousRects: previousRects,
      tokens: tokens,
    );
  }
  if (previousZone.kind == MotionZoneKind.trick &&
      nextZone.kind == MotionZoneKind.job) {
    return previousRects[trickCardMotionSourceKey(cardID)] ??
        previousRects[MotionAnchor.card(cardID)];
  }
  if (previousZone.kind == MotionZoneKind.reward && nextZone.isPlot) {
    return jobGaugeCardMotionTargetRect(
      suit: previousZone.suit!,
      currentRects: previousRects,
      tokens: tokens,
    );
  }
  if (nextZone.kind == MotionZoneKind.reward) {
    return previousRects[rewardPileMotionSourceKey(nextZone.suit!)];
  }
  if (nextZone.kind == MotionZoneKind.finalTrump) {
    return previousRects[finalTrumpMotionSourceKey];
  }
  return previousRects[MotionAnchor.card(cardID)];
}

Rect? cardFlightDestinationRect({
  required String cardID,
  required MotionZone? previousZone,
  required MotionZone nextZone,
  required MotionGeometry currentRects,
  required DesignTokens tokens,
}) {
  if (previousZone?.isPlot == true && nextZone.kind == MotionZoneKind.exiled) {
    return northCardMotionTargetRect(
      currentRects: currentRects,
      tokens: tokens,
    );
  }
  if (nextZone.kind == MotionZoneKind.job) {
    final gaugeRect = jobGaugeCardMotionTargetRect(
      suit: nextZone.suit!,
      currentRects: currentRects,
      tokens: tokens,
    );
    final assignedCardRect = currentRects[MotionAnchor.card(cardID)];
    return gaugeRect ?? assignedCardRect;
  }
  if (nextZone.kind == MotionZoneKind.reward) {
    return jobGaugeCardMotionTargetRect(
      suit: nextZone.suit!,
      currentRects: currentRects,
      tokens: tokens,
    );
  }
  return currentRects[MotionAnchor.card(cardID)];
}

Rect? trickCardMotionSourceRect({
  required String cardID,
  required MotionGeometry previousRects,
}) =>
    previousRects[trickCardMotionSourceKey(cardID)] ??
    previousRects[MotionAnchor.card(cardID)];

Rect? jobGaugeCardMotionTargetRect({
  required String suit,
  required MotionGeometry currentRects,
  required DesignTokens tokens,
}) => _cardSizedRect(currentRects[jobGaugeMotionTargetKey(suit)], tokens);

Rect? jobFieldCardMotionTargetRect({
  required String suit,
  required MotionGeometry currentRects,
  required DesignTokens tokens,
}) => _cardSizedRect(currentRects[jobFieldMotionTargetKey(suit)], tokens);

CardMotionPlan addParallelJobPanelFlights({
  required CardMotionPlan plan,
  required MotionGeometry currentGeometry,
  required DesignTokens tokens,
}) {
  var nextFlightID = plan.nextFlightID;
  return CardMotionPlan(
    transitionID: plan.transitionID,
    stages: [
      for (final stage in plan.stages)
        [
          for (final flight in stage) ...[
            if (flight.destinationZone.kind == MotionZoneKind.job)
              CardFlight(
                id: flight.id,
                card: flight.card,
                from: flight.from,
                to: flight.to,
                destinationZone: flight.destinationZone,
                durationScale: flight.durationScale,
                audiencePanel: panelBrigade,
              )
            else
              flight,
            if (flight.destinationZone.kind == MotionZoneKind.job)
              if (jobFieldCardMotionTargetRect(
                    suit: flight.destinationZone.suit!,
                    currentRects: currentGeometry,
                    tokens: tokens,
                  )
                  case final fieldTarget?)
                CardFlight(
                  id: nextFlightID++,
                  card: flight.card,
                  from: flight.from,
                  to: fieldTarget,
                  destinationZone: flight.destinationZone,
                  durationScale: flight.durationScale,
                  audiencePanel: panelJobs,
                  reportsJobArrival: false,
                ),
          ],
        ],
    ],
    immediateJobArrivals: plan.immediateJobArrivals,
    presentedAssignmentCardIDs: plan.presentedAssignmentCardIDs,
    nextFlightID: nextFlightID,
  );
}

Rect? cardFlightFallbackSourceRect({
  required MotionZone? previousZone,
  required MotionZone nextZone,
  required MotionGeometry currentRects,
  required DesignTokens tokens,
}) {
  if (previousZone == null ||
      !previousZone.isPlot ||
      !(nextZone.kind == MotionZoneKind.exiled ||
          nextZone.kind == MotionZoneKind.northExile)) {
    return null;
  }
  final seatID = previousZone.seatID;
  return seatID == null
      ? null
      : _cardSizedRect(currentRects[plotCardMotionSourceKey(seatID)], tokens);
}

Rect? plotCardMotionSourceRect({
  required int seatID,
  required MotionGeometry currentRects,
  required DesignTokens tokens,
}) => _cardSizedRect(currentRects[plotCardMotionSourceKey(seatID)], tokens);

Rect? newTrickCardFallbackSourceRect({
  required MotionZone nextZone,
  required MotionGeometry previousRects,
  required TableViewModel model,
  required DesignTokens tokens,
}) {
  final seatID = nextZone.kind == MotionZoneKind.trick ? nextZone.seatID : null;
  if (seatID == null || motionSeatIsViewer(model, seatID)) {
    return null;
  }
  return playerCardMotionSourceRect(
    seatID: seatID,
    previousRects: previousRects,
    tokens: tokens,
  );
}

Rect? northCardMotionTargetRect({
  required MotionGeometry currentRects,
  required DesignTokens tokens,
}) => _cardSizedRect(currentRects[northCardMotionTargetKey], tokens);

Rect? playerCardMotionSourceRect({
  required int seatID,
  required MotionGeometry previousRects,
  required DesignTokens tokens,
}) => _cardSizedRect(previousRects[playerCardMotionSourceKey(seatID)], tokens);

Rect? _cardSizedRect(Rect? anchor, DesignTokens tokens) {
  if (anchor == null) {
    return null;
  }
  final size = Size(tokens.card.small.width, tokens.card.small.height);
  return (anchor.center - Offset(size.width / 2, size.height / 2)) & size;
}

int? handToTrickFlightSeatID(MotionZone previousZone, MotionZone nextZone) {
  final previousSeat = previousZone.kind == MotionZoneKind.hand
      ? previousZone.seatID
      : null;
  final nextSeat = nextZone.kind == MotionZoneKind.trick
      ? nextZone.seatID
      : null;
  return previousSeat != null && previousSeat == nextSeat ? previousSeat : null;
}

double cardFlightDurationScale({
  required MotionZone? previousZone,
  required MotionZone nextZone,
  required TableViewModel model,
}) => cardFlightDurationScaleForZones(
  previousZone: previousZone,
  nextZone: nextZone,
  model: model,
);
