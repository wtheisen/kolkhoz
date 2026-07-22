import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'board_widgets.dart';

class CardMotionLayer extends StatefulWidget {
  const CardMotionLayer({
    required this.model,
    required this.tokens,
    required this.speed,
    required this.child,
    this.presentationRevision,
    this.assignmentPresentationCardIDs = const [],
    this.onPresentationComplete,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final GameAnimationSpeed speed;
  final Widget child;
  final int? presentationRevision;
  final List<String> assignmentPresentationCardIDs;
  final ValueChanged<int>? onPresentationComplete;

  @override
  State<CardMotionLayer> createState() => _CardMotionLayerState();
}

class _CardMotionLayerState extends State<CardMotionLayer> {
  final GlobalKey _rootKey = GlobalKey();
  final CardMotionController _controller = CardMotionController();
  final List<CardFlight> _flights = [];
  final List<CardFlight> _sequentialFlights = [];
  final Set<int> _presentationFlightIDs = {};
  int _nextFlightID = 0;
  int? _activePresentationRevision;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _afterCardLayout(() {
      _controller.commitFrame();
    });
  }

  @override
  void didUpdateWidget(CardMotionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.presentationRevision != null &&
        oldWidget.presentationRevision == widget.presentationRevision) {
      return;
    }
    if (oldWidget.model == widget.model &&
        oldWidget.presentationRevision == widget.presentationRevision) {
      return;
    }
    final previousZones = cardMotionZones(oldWidget.model);
    final nextZones = cardMotionZones(widget.model);
    final previousCards = cardMotionCards(oldWidget.model);
    final nextCards = cardMotionCards(widget.model);
    final previousRects = Map<String, Rect>.of(_controller.previousRects);
    final nextModel = widget.model;
    final presentationRevision = widget.presentationRevision;
    final assignmentPresentationCardIDs = List<String>.of(
      widget.assignmentPresentationCardIDs,
    );
    _afterCardLayout(() {
      final currentRects = Map<String, Rect>.of(_controller.currentRects);
      _startFlights(
        previousModel: oldWidget.model,
        nextModel: nextModel,
        previousZones: previousZones,
        nextZones: nextZones,
        previousCards: previousCards,
        nextCards: nextCards,
        previousRects: previousRects,
        currentRects: currentRects,
        presentationRevision: presentationRevision,
        assignmentPresentationCardIDs: assignmentPresentationCardIDs,
      );
      _controller.commitFrame();
    });
  }

  void _afterCardLayout(VoidCallback action) {
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) {
        action();
      }
    });
  }

  void _startFlights({
    required TableViewModel previousModel,
    required TableViewModel nextModel,
    required Map<String, String> previousZones,
    required Map<String, String> nextZones,
    required Map<String, TableCard> previousCards,
    required Map<String, TableCard> nextCards,
    required Map<String, Rect> previousRects,
    required Map<String, Rect> currentRects,
    required int? presentationRevision,
    required List<String> assignmentPresentationCardIDs,
  }) {
    if (widget.speed.cardFlightDuration == Duration.zero) {
      _recordImmediateJobArrivals(previousZones, nextZones, nextCards);
      _completePresentation(presentationRevision);
      return;
    }
    final newFlights = <CardFlight>[];
    final newExiledIDs = newlyExiledCardIDs(
      previousModel: previousModel,
      nextModel: nextModel,
    );
    for (final entry in nextZones.entries) {
      final cardID = entry.key;
      if (newExiledIDs.contains(cardID)) {
        continue;
      }
      final previousZone = previousZones[cardID];
      if (previousZone == entry.value) {
        continue;
      }
      final to = cardFlightDestinationRect(
        cardID: cardID,
        previousZone: previousZone,
        nextZone: entry.value,
        currentRects: currentRects,
        tokens: widget.tokens,
      );
      if (to == null) {
        continue;
      }
      var sourceRect = previousZone == null
          ? entry.value.startsWith('reward:')
                ? previousRects[rewardPileMotionSourceKey(
                    entry.value.substring('reward:'.length),
                  )]
                : entry.value == 'final-trump'
                ? previousRects[finalTrumpMotionSourceKey]
                : newTrickCardFallbackSourceRect(
                    nextZone: entry.value,
                    previousRects: previousRects,
                    model: previousModel,
                    tokens: widget.tokens,
                  )
          : cardFlightSourceRect(
              cardID: cardID,
              previousZone: previousZone,
              nextZone: entry.value,
              previousRects: previousRects,
              model: previousModel,
              tokens: widget.tokens,
            );
      sourceRect ??= cardFlightFallbackSourceRect(
        previousZone: previousZone,
        nextZone: entry.value,
        currentRects: currentRects,
        tokens: widget.tokens,
      );
      if (sourceRect == null) {
        continue;
      }
      if ((sourceRect.center - to.center).distance <
          cardMotionMinimumDistance) {
        continue;
      }
      final card = nextCards[cardID] ?? previousCards[cardID];
      if (card == null) {
        continue;
      }
      newFlights.add(
        CardFlight(
          id: _nextFlightID++,
          card: card,
          from: sourceRect,
          to: to,
          destinationZone: entry.value,
          durationScale: cardFlightDurationScale(
            previousZone: previousZone,
            nextZone: entry.value,
            model: previousModel,
          ),
        ),
      );
    }
    for (final cardID in newExiledIDs) {
      final previousZone = previousZones[cardID];
      var sourceRect = currentRects[cardID];
      if (sourceRect == null && previousZone?.startsWith('plot:') == true) {
        sourceRect = cardFlightSourceRect(
          cardID: cardID,
          previousZone: previousZone!,
          nextZone: cardMotionNorthExileZone,
          previousRects: previousRects,
          model: previousModel,
          tokens: widget.tokens,
        );
      }
      final plotSeatID =
          plotSeatIDForMotionCard(nextModel, cardID) ??
          (previousZone == null ? null : plotZoneSeatID(previousZone));
      sourceRect ??= plotSeatID == null
          ? null
          : plotCardMotionSourceRect(
              seatID: plotSeatID,
              currentRects: currentRects,
              tokens: widget.tokens,
            );
      sourceRect ??= cardFlightFallbackSourceRect(
        previousZone: previousZone,
        nextZone: cardMotionNorthExileZone,
        currentRects: currentRects,
        tokens: widget.tokens,
      );
      final to = northCardMotionTargetRect(
        currentRects: currentRects,
        tokens: widget.tokens,
      );
      final card = nextCards[cardID] ?? previousCards[cardID];
      if (sourceRect == null || to == null || card == null) {
        continue;
      }
      if ((sourceRect.center - to.center).distance <
          cardMotionMinimumDistance) {
        continue;
      }
      newFlights.add(
        CardFlight(
          id: _nextFlightID++,
          card: card,
          from: sourceRect,
          to: to,
          destinationZone: cardMotionNorthExileZone,
          durationScale: cardFlightDurationScale(
            previousZone: previousZone,
            nextZone: cardMotionNorthExileZone,
            model: previousModel,
          ),
        ),
      );
    }
    if (newFlights.isEmpty) {
      _recordImmediateJobArrivals(previousZones, nextZones, nextCards);
      _completePresentation(presentationRevision);
      return;
    }
    if (assignmentPresentationCardIDs.isNotEmpty) {
      final order = {
        for (final entry in assignmentPresentationCardIDs.indexed)
          entry.$2: entry.$1,
      };
      newFlights.sort(
        (left, right) => (order[left.card.id] ?? order.length).compareTo(
          order[right.card.id] ?? order.length,
        ),
      );
    }
    final newFlightCardIDs = {for (final flight in newFlights) flight.card.id};
    setState(() {
      _flights.removeWhere(
        (flight) => newFlightCardIDs.contains(flight.card.id),
      );
      _activePresentationRevision = presentationRevision;
      _presentationFlightIDs.clear();
      _sequentialFlights.clear();
      if (assignmentPresentationCardIDs.isNotEmpty && newFlights.length > 1) {
        _flights.add(newFlights.first);
        _presentationFlightIDs.add(newFlights.first.id);
        _sequentialFlights.addAll(newFlights.skip(1));
      } else {
        _flights.addAll(newFlights);
        _presentationFlightIDs.addAll(newFlights.map((flight) => flight.id));
      }
    });
  }

  void _removeFlight(int id) {
    if (!mounted) {
      return;
    }
    final completedFlight = _flights
        .where((flight) => flight.id == id)
        .firstOrNull;
    int? completedRevision;
    setState(() {
      _flights.removeWhere((flight) => flight.id == id);
      _presentationFlightIDs.remove(id);
      if (_presentationFlightIDs.isEmpty && _sequentialFlights.isNotEmpty) {
        final next = _sequentialFlights.removeAt(0);
        _flights.add(next);
        _presentationFlightIDs.add(next.id);
      } else if (_presentationFlightIDs.isEmpty) {
        completedRevision = _activePresentationRevision;
        _activePresentationRevision = null;
      }
    });
    if (completedFlight != null &&
        completedFlight.destinationZone.startsWith('job:')) {
      _controller.recordJobCardArrival(
        JobCardArrival(
          cardID: completedFlight.card.id,
          suit: completedFlight.destinationZone.substring('job:'.length),
        ),
      );
    }
    _completePresentation(completedRevision);
  }

  void _recordImmediateJobArrivals(
    Map<String, String> previousZones,
    Map<String, String> nextZones,
    Map<String, TableCard> nextCards,
  ) {
    for (final entry in nextZones.entries) {
      if (entry.value.startsWith('job:') &&
          previousZones[entry.key] != entry.value &&
          nextCards.containsKey(entry.key)) {
        _controller.recordJobCardArrival(
          JobCardArrival(
            cardID: entry.key,
            suit: entry.value.substring('job:'.length),
          ),
        );
      }
    }
  }

  void _completePresentation(int? revision) {
    if (revision != null) {
      widget.onPresentationComplete?.call(revision);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = _controller.beginFrame();
    final activeCardIDs = {for (final flight in _flights) flight.card.id};
    return CardMotionScope(
      controller: _controller,
      frame: frame,
      rootKey: _rootKey,
      activeCardIDs: activeCardIDs,
      child: Stack(
        key: _rootKey,
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final flight in _flights)
                    FlyingCard(
                      key: ValueKey(flight.id),
                      flight: flight,
                      tokens: widget.tokens,
                      trump: widget.model.table.trump,
                      duration: widget.speed.cardFlightDuration,
                      onDone: () => _removeFlight(flight.id),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CardMotionScope extends InheritedWidget {
  const CardMotionScope({
    required this.controller,
    required this.frame,
    required this.rootKey,
    required this.activeCardIDs,
    required super.child,
    super.key,
  });

  final CardMotionController controller;
  final int frame;
  final GlobalKey rootKey;
  final Set<String> activeCardIDs;

  static CardMotionScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CardMotionScope>();
  }

  @override
  bool updateShouldNotify(CardMotionScope oldWidget) {
    return oldWidget.frame != frame ||
        oldWidget.activeCardIDs.length != activeCardIDs.length ||
        !oldWidget.activeCardIDs.containsAll(activeCardIDs);
  }
}

class CardMotionController {
  int _frame = 0;
  Map<String, Rect> _previousRects = {};
  final Map<String, CardMotionRect> _currentRects = {};
  final ValueNotifier<JobCardArrival?> jobCardArrival = ValueNotifier(null);

  Map<String, Rect> get previousRects => _previousRects;

  Map<String, Rect> get currentRects {
    return {
      for (final entry in _currentRects.entries)
        if (entry.value.frame == _frame) entry.key: entry.value.rect,
    };
  }

  int beginFrame() {
    _frame += 1;
    return _frame;
  }

  void recordJobCardArrival(JobCardArrival arrival) {
    jobCardArrival.value = arrival;
  }

  void dispose() {
    jobCardArrival.dispose();
  }

  void record({
    required int frame,
    required String cardID,
    required Rect rect,
  }) {
    if (frame == _frame) {
      _currentRects[cardID] = CardMotionRect(frame: frame, rect: rect);
    }
  }

  void commitFrame() {
    _previousRects = currentRects;
  }
}

class CardMotionRect {
  const CardMotionRect({required this.frame, required this.rect});

  final int frame;
  final Rect rect;
}

class MotionTrackedCard extends StatefulWidget {
  const MotionTrackedCard({required this.card, required this.child, super.key});

  final TableCard card;
  final Widget child;

  @override
  State<MotionTrackedCard> createState() => _MotionTrackedCardState();
}

class MotionTrackedRegion extends StatefulWidget {
  const MotionTrackedRegion({
    required this.motionKey,
    required this.child,
    super.key,
  });

  final String motionKey;
  final Widget child;

  @override
  State<MotionTrackedRegion> createState() => _MotionTrackedRegionState();
}

class _MotionTrackedRegionState extends State<MotionTrackedRegion> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final scope = CardMotionScope.maybeOf(context);
    if (scope != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final box = _key.currentContext?.findRenderObject() as RenderBox?;
        final root =
            scope.rootKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || root == null || !box.attached || !root.attached) {
          return;
        }
        scope.controller.record(
          frame: scope.frame,
          cardID: widget.motionKey,
          rect: transformedPaintRect(box, root),
        );
      });
    }
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

class _MotionTrackedCardState extends State<MotionTrackedCard> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final scope = CardMotionScope.maybeOf(context);
    if (scope != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final box = _key.currentContext?.findRenderObject() as RenderBox?;
        final root =
            scope.rootKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || root == null || !box.attached || !root.attached) {
          return;
        }
        scope.controller.record(
          frame: scope.frame,
          cardID: widget.card.id,
          rect: transformedPaintRect(box, root),
        );
      });
    }
    final hidden = scope?.activeCardIDs.contains(widget.card.id) ?? false;
    return Opacity(key: _key, opacity: hidden ? 0 : 1, child: widget.child);
  }
}

Rect transformedPaintRect(RenderBox box, RenderBox root) {
  final topLeft = box.localToGlobal(Offset.zero, ancestor: root);
  final topRight = box.localToGlobal(Offset(box.size.width, 0), ancestor: root);
  final bottomLeft = box.localToGlobal(
    Offset(0, box.size.height),
    ancestor: root,
  );
  final bottomRight = box.localToGlobal(
    box.size.bottomRight(Offset.zero),
    ancestor: root,
  );
  final left = math.min(
    topLeft.dx,
    math.min(topRight.dx, math.min(bottomLeft.dx, bottomRight.dx)),
  );
  final top = math.min(
    topLeft.dy,
    math.min(topRight.dy, math.min(bottomLeft.dy, bottomRight.dy)),
  );
  final right = math.max(
    topLeft.dx,
    math.max(topRight.dx, math.max(bottomLeft.dx, bottomRight.dx)),
  );
  final bottom = math.max(
    topLeft.dy,
    math.max(topRight.dy, math.max(bottomLeft.dy, bottomRight.dy)),
  );
  return Rect.fromLTRB(left, top, right, bottom);
}

class CardFlight {
  const CardFlight({
    required this.id,
    required this.card,
    required this.from,
    required this.to,
    required this.destinationZone,
    this.durationScale = 1,
  });

  final int id;
  final TableCard card;
  final Rect from;
  final Rect to;
  final String destinationZone;
  final double durationScale;
}

class JobCardArrival {
  const JobCardArrival({required this.cardID, required this.suit});

  final String cardID;
  final String suit;
}

class FlyingCard extends StatelessWidget {
  const FlyingCard({
    required this.flight,
    required this.tokens,
    required this.duration,
    required this.onDone,
    this.trump,
    super.key,
  });

  final CardFlight flight;
  final DesignTokens tokens;
  final Duration duration;
  final VoidCallback onDone;
  final String? trump;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: scaledDuration(duration, flight.durationScale),
      curve: Curves.easeInOutCubic,
      onEnd: onDone,
      builder: (context, value, child) {
        final rect = Rect.lerp(flight.from, flight.to, value)!;
        return Positioned.fromRect(
          rect: rect,
          child: Transform.scale(
            scale: lerpDouble(1.04, 1, value)!,
            child: child,
          ),
        );
      },
      child: FittedBox(
        fit: BoxFit.fill,
        child: GameCard(
          card: flight.card,
          tokens: tokens,
          trump: trump,
          sizeOverride: cardFlightRenderSize(flight.from, flight.to, tokens),
          motionTracked: false,
        ),
      ),
    );
  }
}

TokenCardSize cardFlightRenderSize(Rect from, Rect to, DesignTokens tokens) {
  final height = math.max(from.height, to.height);
  if (height <= tokens.card.small.height + 8) {
    return tokens.card.small;
  }
  if (height <= tokens.card.medium.height + 8) {
    return tokens.card.medium;
  }
  return tokens.card.large;
}

class CardMotionEntry {
  const CardMotionEntry({required this.card, required this.zone});

  final TableCard card;
  final String zone;
}

Iterable<CardMotionEntry> cardMotionEntries(TableViewModel model) sync* {
  for (final seat in model.table.seats) {
    for (final card in seat.hand) {
      yield CardMotionEntry(card: card, zone: 'hand:${seat.id}');
    }
    for (final card in seat.plot.hidden) {
      yield CardMotionEntry(card: card, zone: 'plot:${seat.id}:hidden');
    }
    for (final card in seat.plot.revealed) {
      yield CardMotionEntry(card: card, zone: 'plot:${seat.id}:revealed');
    }
    for (final (stackIndex, stack) in seat.plot.stacks.indexed) {
      for (final card in stack.revealed) {
        yield CardMotionEntry(
          card: card,
          zone: 'plot:${seat.id}:stack:$stackIndex:revealed',
        );
      }
    }
  }
  for (final play in model.table.trick.plays) {
    yield CardMotionEntry(card: play.card, zone: 'trick:${play.seatID}');
  }
  for (final play in model.table.lastTrick.plays) {
    yield CardMotionEntry(card: play.card, zone: 'trick:${play.seatID}');
  }
  for (final job in model.table.jobs) {
    final reward = job.reward;
    if (reward != null) {
      yield CardMotionEntry(card: reward, zone: 'reward:${job.suit}');
    }
    for (final card in job.assignedCards) {
      if (!card.pending) {
        yield CardMotionEntry(card: card, zone: 'job:${job.suit}');
      }
    }
  }
  final finalTrumpCard = model.table.finalYearTrumpCard;
  if (finalTrumpCard != null) {
    yield CardMotionEntry(card: finalTrumpCard, zone: 'final-trump');
  }
  for (final entry in model.table.exiledByYear.entries) {
    for (final card in entry.value) {
      yield CardMotionEntry(card: card, zone: 'exiled:${entry.key}');
    }
  }
}

Map<String, String> cardMotionZones(TableViewModel model) {
  return {
    for (final entry in cardMotionEntries(model)) entry.card.id: entry.zone,
  };
}

Map<String, TableCard> cardMotionCards(TableViewModel model) {
  return {
    for (final entry in cardMotionEntries(model)) entry.card.id: entry.card,
  };
}

Rect? cardFlightSourceRect({
  required String cardID,
  required String previousZone,
  required String nextZone,
  required Map<String, Rect> previousRects,
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
  if (previousZone.startsWith('trick:') && nextZone.startsWith('job:')) {
    return previousRects[trickCardMotionSourceKey(cardID)] ??
        previousRects[cardID];
  }
  if (nextZone.startsWith('reward:')) {
    return previousRects[rewardPileMotionSourceKey(
      nextZone.substring('reward:'.length),
    )];
  }
  if (nextZone == 'final-trump') {
    return previousRects[finalTrumpMotionSourceKey];
  }
  return previousRects[cardID];
}

Rect? cardFlightDestinationRect({
  required String cardID,
  required String? previousZone,
  required String nextZone,
  required Map<String, Rect> currentRects,
  required DesignTokens tokens,
}) {
  if (previousZone != null &&
      previousZone.startsWith('plot:') &&
      nextZone.startsWith('exiled:')) {
    return northCardMotionTargetRect(
      currentRects: currentRects,
      tokens: tokens,
    );
  }
  if (nextZone.startsWith('job:')) {
    final gaugeRect = jobGaugeCardMotionTargetRect(
      suit: nextZone.substring('job:'.length),
      currentRects: currentRects,
      tokens: tokens,
    );
    if (previousZone != null && previousZone.startsWith('trick:')) {
      return gaugeRect ?? currentRects[cardID];
    }
    return currentRects[cardID] ?? gaugeRect;
  }
  if (nextZone.startsWith('reward:')) {
    return jobGaugeCardMotionTargetRect(
      suit: nextZone.substring('reward:'.length),
      currentRects: currentRects,
      tokens: tokens,
    );
  }
  return currentRects[cardID];
}

Rect? trickCardMotionSourceRect({
  required String cardID,
  required Map<String, Rect> previousRects,
}) {
  return previousRects[trickCardMotionSourceKey(cardID)] ??
      previousRects[cardID];
}

Rect? jobGaugeCardMotionTargetRect({
  required String suit,
  required Map<String, Rect> currentRects,
  required DesignTokens tokens,
}) {
  final gaugeRect = currentRects[jobGaugeMotionTargetKey(suit)];
  if (gaugeRect == null) {
    return null;
  }
  final size = Size(tokens.card.small.width, tokens.card.small.height);
  final topLeft = gaugeRect.center - Offset(size.width / 2, size.height / 2);
  return topLeft & size;
}

Rect? cardFlightFallbackSourceRect({
  required String? previousZone,
  required String nextZone,
  required Map<String, Rect> currentRects,
  required DesignTokens tokens,
}) {
  if (previousZone == null) {
    return null;
  }
  if (!previousZone.startsWith('plot:') ||
      !(nextZone.startsWith('exiled:') ||
          nextZone == cardMotionNorthExileZone)) {
    return null;
  }
  final seatID = plotZoneSeatID(previousZone);
  if (seatID == null) {
    return null;
  }
  final plotRect = currentRects[plotCardMotionSourceKey(seatID)];
  if (plotRect == null) {
    return null;
  }
  final size = Size(tokens.card.small.width, tokens.card.small.height);
  final topLeft = plotRect.center - Offset(size.width / 2, size.height / 2);
  return topLeft & size;
}

Rect? plotCardMotionSourceRect({
  required int seatID,
  required Map<String, Rect> currentRects,
  required DesignTokens tokens,
}) {
  final plotRect = currentRects[plotCardMotionSourceKey(seatID)];
  if (plotRect == null) {
    return null;
  }
  final size = Size(tokens.card.small.width, tokens.card.small.height);
  final topLeft = plotRect.center - Offset(size.width / 2, size.height / 2);
  return topLeft & size;
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

Rect? newTrickCardFallbackSourceRect({
  required String nextZone,
  required Map<String, Rect> previousRects,
  required TableViewModel model,
  required DesignTokens tokens,
}) {
  final seatID = zoneSeatID(nextZone, 'trick');
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
  required Map<String, Rect> currentRects,
  required DesignTokens tokens,
}) {
  final iconRect = currentRects[northCardMotionTargetKey];
  if (iconRect == null) {
    return null;
  }
  final size = Size(tokens.card.small.width, tokens.card.small.height);
  final topLeft = iconRect.center - Offset(size.width / 2, size.height / 2);
  return topLeft & size;
}

Set<String> newlyExiledCardIDs({
  required TableViewModel previousModel,
  required TableViewModel nextModel,
}) {
  final previous = currentYearExiledMotionCardIDs(previousModel);
  return currentYearExiledMotionCardIDs(nextModel).difference(previous);
}

Set<String> currentYearExiledMotionCardIDs(TableViewModel model) {
  return {
    for (final card in model.table.exiledByYear[model.table.year] ?? const [])
      card.id,
  };
}

Rect? playerCardMotionSourceRect({
  required int seatID,
  required Map<String, Rect> previousRects,
  required DesignTokens tokens,
}) {
  final badgeRect = previousRects[playerCardMotionSourceKey(seatID)];
  if (badgeRect == null) {
    return null;
  }
  final sourceSize = Size(tokens.card.small.width, tokens.card.small.height);
  final topLeft =
      badgeRect.center - Offset(sourceSize.width / 2, sourceSize.height / 2);
  return topLeft & sourceSize;
}

int? handToTrickFlightSeatID(String previousZone, String nextZone) {
  final previousSeat = zoneSeatID(previousZone, 'hand');
  final nextSeat = zoneSeatID(nextZone, 'trick');
  if (previousSeat == null || previousSeat != nextSeat) {
    return null;
  }
  return previousSeat;
}

bool motionSeatIsViewer(TableViewModel model, int seatID) {
  for (final seat in model.table.seats) {
    if (seat.id == seatID) {
      return seat.isViewer;
    }
  }
  return false;
}

int? zoneSeatID(String zone, String prefix) {
  final marker = '$prefix:';
  if (!zone.startsWith(marker)) {
    return null;
  }
  return int.tryParse(zone.substring(marker.length));
}

int? plotZoneSeatID(String zone) {
  final parts = zone.split(':');
  if (parts.length < 2 || parts.first != 'plot') {
    return null;
  }
  return int.tryParse(parts[1]);
}

String playerCardMotionSourceKey(int seatID) => 'player-source:$seatID';
String plotCardMotionSourceKey(int seatID) => 'plot-source:$seatID';
String trickCardMotionSourceKey(String cardID) => 'trick-source:$cardID';
String jobGaugeMotionTargetKey(String suit) => 'job-gauge-target:$suit';
String rewardPileMotionSourceKey(String suit) => 'reward-pile-source:$suit';
const finalTrumpMotionSourceKey = 'final-trump-source';
const northCardMotionTargetKey = 'north-exile-target';
const cardMotionNorthExileZone = 'north-exile';

double cardFlightDurationScale({
  required String? previousZone,
  required String nextZone,
  required TableViewModel model,
}) {
  if (previousZone == null) {
    final seatID = zoneSeatID(nextZone, 'trick');
    if (seatID != null && !motionSeatIsViewer(model, seatID)) {
      return playerInfoCardFlightDurationScale;
    }
    return 1;
  }
  if (previousZone.startsWith('plot:') &&
      (nextZone.startsWith('exiled:') ||
          nextZone == cardMotionNorthExileZone)) {
    return requisitionCardFlightDurationScale;
  }
  if (previousZone.startsWith('trick:') && nextZone.startsWith('job:')) {
    return jobAssignmentCardFlightDurationScale;
  }
  final seatID = handToTrickFlightSeatID(previousZone, nextZone);
  if (seatID == null || motionSeatIsViewer(model, seatID)) {
    return 1;
  }
  return playerInfoCardFlightDurationScale;
}

Duration scaledDuration(Duration duration, double scale) {
  return scaledGameAnimationDuration(duration, scale);
}

const cardMotionMinimumDistance = 8.0;
