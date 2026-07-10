import 'dart:math' as math;
import 'dart:ui' show clampDouble, lerpDouble;

import 'package:flutter/material.dart';

import '../animation_speed.dart';
import '../card_art_display.dart';
import '../design_tokens.dart';
import '../game_constants.dart';
import '../panel_title_display.dart';
import '../pixel_text.dart';
import '../render_model.dart';
import '../table_display.dart';

class ChromePixelLabel extends StatelessWidget {
  const ChromePixelLabel(
    this.text, {
    required this.size,
    required this.color,
    this.variant = PixelTextVariant.heavy,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.softWrap = false,
    this.uppercase = true,
    super.key,
  });

  final String text;
  final PixelTextSize size;
  final PixelTextVariant variant;
  final Color color;
  final TextAlign textAlign;
  final int? maxLines;
  final bool softWrap;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    return PixelText(
      uppercase ? text.toUpperCase() : text,
      size: size,
      variant: variant,
      color: color,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.clip,
      softWrap: softWrap,
    );
  }
}

class CardMotionLayer extends StatefulWidget {
  const CardMotionLayer({
    required this.model,
    required this.tokens,
    required this.speed,
    required this.child,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final GameAnimationSpeed speed;
  final Widget child;

  @override
  State<CardMotionLayer> createState() => _CardMotionLayerState();
}

class _CardMotionLayerState extends State<CardMotionLayer> {
  final GlobalKey _rootKey = GlobalKey();
  final CardMotionController _controller = CardMotionController();
  final List<CardFlight> _flights = [];
  int _nextFlightID = 0;

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
    if (oldWidget.model == widget.model) {
      return;
    }
    final previousZones = cardMotionZones(oldWidget.model);
    final nextZones = cardMotionZones(widget.model);
    final previousCards = cardMotionCards(oldWidget.model);
    final nextCards = cardMotionCards(widget.model);
    final previousRects = Map<String, Rect>.of(_controller.previousRects);
    _afterCardLayout(() {
      final currentRects = Map<String, Rect>.of(_controller.currentRects);
      _startFlights(
        previousModel: oldWidget.model,
        previousZones: previousZones,
        nextZones: nextZones,
        previousCards: previousCards,
        nextCards: nextCards,
        previousRects: previousRects,
        currentRects: currentRects,
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
    required Map<String, String> previousZones,
    required Map<String, String> nextZones,
    required Map<String, TableCard> previousCards,
    required Map<String, TableCard> nextCards,
    required Map<String, Rect> previousRects,
    required Map<String, Rect> currentRects,
  }) {
    if (widget.speed.cardFlightDuration == Duration.zero) {
      return;
    }
    final newFlights = <CardFlight>[];
    for (final entry in nextZones.entries) {
      final cardID = entry.key;
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
          ? newTrickCardFallbackSourceRect(
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
          durationScale: cardFlightDurationScale(
            previousZone: previousZone,
            nextZone: entry.value,
            model: previousModel,
          ),
        ),
      );
    }
    final newExiledIDs = newlyExiledCardIDs(
      previousModel: previousModel,
      nextModel: widget.model,
    );
    for (final cardID in newExiledIDs) {
      if (newFlights.any((flight) => flight.card.id == cardID)) {
        continue;
      }
      final previousZone = previousZones[cardID];
      if (previousZone == null || !previousZone.startsWith('plot:')) {
        continue;
      }
      var sourceRect = cardFlightSourceRect(
        cardID: cardID,
        previousZone: previousZone,
        nextZone: cardMotionNorthExileZone,
        previousRects: previousRects,
        model: previousModel,
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
          durationScale: cardFlightDurationScale(
            previousZone: previousZone,
            nextZone: cardMotionNorthExileZone,
            model: previousModel,
          ),
        ),
      );
    }
    if (newFlights.isEmpty) {
      return;
    }
    setState(() {
      _flights.addAll(newFlights);
    });
  }

  void _removeFlight(int id) {
    if (!mounted) {
      return;
    }
    setState(() {
      _flights.removeWhere((flight) => flight.id == id);
    });
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
    this.durationScale = 1,
  });

  final int id;
  final TableCard card;
  final Rect from;
  final Rect to;
  final double durationScale;
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
    for (final card in job.assignedCards) {
      yield CardMotionEntry(card: card, zone: 'job:${job.suit}');
    }
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
  if (duration == Duration.zero || scale == 1) {
    return duration;
  }
  return Duration(microseconds: (duration.inMicroseconds * scale).round());
}

const playerInfoCardFlightDurationScale = 1.5;
const requisitionCardFlightDurationScale = 1.35;
const jobAssignmentCardFlightDurationScale = 2.0;
const cardMotionMinimumDistance = 8.0;

class CommandPanelSurface extends StatelessWidget {
  const CommandPanelSurface({
    required this.tokens,
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final DesignTokens tokens;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.26)),
        gradient: LinearGradient(
          colors: [
            tokens.colors.panel,
            tokens.colors.iron,
            tokens.colors.black,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radius.md),
          gradient: LinearGradient(
            colors: [
              tokens.colors.gold.withValues(alpha: 0.14),
              Colors.transparent,
              tokens.colors.redDark.withValues(alpha: 0.14),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class PanelStyleSurface extends StatelessWidget {
  const PanelStyleSurface({
    required this.tokens,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.constraints,
    super.key,
  });

  final DesignTokens tokens;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: constraints,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tokens.colors.panel,
            tokens.colors.iron.withValues(alpha: 0.96),
            tokens.colors.black.withValues(alpha: 0.94),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(tokens.radius.panelOuter),
        border: Border.all(
          color: tokens.colors.gold.withValues(alpha: 0.72),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radius.panelOuter),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tokens.colors.gold.withValues(alpha: 0.16),
                      Colors.transparent,
                      tokens.colors.redDark.withValues(alpha: 0.18),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      tokens.radius.panelInner,
                    ),
                    border: Border.all(
                      color: tokens.colors.redDark.withValues(alpha: 0.62),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KolkhozScrollbar extends StatefulWidget {
  const KolkhozScrollbar({
    required this.tokens,
    required this.childBuilder,
    this.orientation,
    this.thumbVisibility = true,
    this.trackVisibility = true,
    super.key,
  });

  final DesignTokens tokens;
  final ScrollbarOrientation? orientation;
  final bool thumbVisibility;
  final bool trackVisibility;
  final Widget Function(BuildContext context, ScrollController controller)
  childBuilder;

  @override
  State<KolkhozScrollbar> createState() => _KolkhozScrollbarState();
}

class _KolkhozScrollbarState extends State<KolkhozScrollbar> {
  late final ScrollController controller;

  @override
  void initState() {
    super.initState();
    controller = ScrollController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll(widget.thumbVisibility),
        trackVisibility: WidgetStatePropertyAll(widget.trackVisibility),
        thickness: const WidgetStatePropertyAll(5),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(
          widget.tokens.colors.gold.withValues(alpha: 0.68),
        ),
        trackColor: WidgetStatePropertyAll(
          widget.tokens.colors.black.withValues(alpha: 0.12),
        ),
        trackBorderColor: WidgetStatePropertyAll(
          widget.tokens.colors.steel.withValues(alpha: 0.28),
        ),
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: widget.thumbVisibility,
        trackVisibility: widget.trackVisibility,
        scrollbarOrientation: widget.orientation,
        child: widget.childBuilder(context, controller),
      ),
    );
  }
}

class PanelTitleRow extends StatelessWidget {
  const PanelTitleRow({
    required this.title,
    required this.iconPath,
    required this.tokens,
    this.subtitle,
    this.urgent = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String iconPath;
  final bool urgent;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconBox = panelTitleIconBox(constraints.maxWidth);
        final iconSize = panelTitleIconSize(constraints.maxWidth);
        final horizontalPadding = panelTitleHorizontalPadding(
          constraints.maxWidth,
        );
        final verticalPadding = panelTitleVerticalPadding(constraints.maxWidth);
        final spacing = panelTitleSpacing(constraints.maxWidth);
        final ornamentOpacity = panelTitleEffectiveOrnamentOpacity(
          constraints.maxWidth,
          urgent: urgent,
        );
        final titleColumn = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            PixelText(
              title.toUpperCase(),
              size: PixelTextSize.caption,
              variant: PixelTextVariant.heavy,
              color: urgent ? tokens.colors.redBright : tokens.colors.gold,
            ),
            if (subtitle != null)
              PixelText(
                subtitle!,
                size: PixelTextSize.caption,
                color: tokens.colors.creamDim,
              ),
          ],
        );
        final titleContent = constraints.hasBoundedHeight
            ? SizedBox(
                height: math.max(
                  0,
                  constraints.maxHeight - verticalPadding * 2,
                ),
                child: ClipRect(
                  child: OverflowBox(
                    maxHeight: double.infinity,
                    alignment: Alignment.centerLeft,
                    child: titleColumn,
                  ),
                ),
              )
            : titleColumn;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: tokens.colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(tokens.radius.md),
            border: Border.all(
              color: tokens.colors.gold.withValues(alpha: 0.28),
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                right: panelTitleOrnamentTrailingPadding,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: ornamentOpacity,
                    child: Image.asset(
                      'ios_resources/Embellishments/panel-divider-pixel.png',
                      width: panelTitleOrnamentWidth,
                      height: panelTitleOrnamentHeight,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              Row(
                spacing: spacing,
                children: [
                  Container(
                    width: iconBox,
                    height: iconBox,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: urgent
                            ? [
                                tokens.colors.redDark,
                                tokens.colors.red.withValues(alpha: 0.82),
                              ]
                            : [
                                tokens.colors.black.withValues(alpha: 0.58),
                                tokens.colors.steel.withValues(alpha: 0.36),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: urgent
                            ? tokens.colors.redBright
                            : tokens.colors.gold.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Image.asset(
                        iconPath,
                        width: iconSize,
                        height: iconSize,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                  Expanded(child: titleContent),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class GameCard extends StatelessWidget {
  const GameCard({
    required this.card,
    required this.tokens,
    this.trump,
    this.small = false,
    this.highlightColorOverride,
    this.highlightGlowEnabled = true,
    this.highlightedStrokeWidthOverride,
    this.highlightedBorderRadiusOverride,
    this.selectedColorOverride,
    this.selectedStrokeWidthOverride,
    this.sizeOverride,
    this.motionTracked = true,
    super.key,
  });

  final TableCard card;
  final DesignTokens tokens;
  final String? trump;
  final bool small;
  final Color? highlightColorOverride;
  final bool highlightGlowEnabled;
  final double? highlightedStrokeWidthOverride;
  final double? highlightedBorderRadiusOverride;
  final Color? selectedColorOverride;
  final double? selectedStrokeWidthOverride;
  final TokenCardSize? sizeOverride;
  final bool motionTracked;

  @override
  Widget build(BuildContext context) {
    final size =
        sizeOverride ?? (small ? tokens.card.small : tokens.card.large);
    final highlightColor = card.highlighted
        ? highlightColorOverride ??
              cardHighlightColor(card: card, trump: trump, tokens: tokens)
        : null;
    final highlightGlow = highlightGlowEnabled ? highlightColor : null;
    final highlightBorder = card.selected
        ? selectedColorOverride ?? tokens.colors.green
        : card.highlighted
        ? highlightColor
        : null;
    final highlightBorderWidth = card.selected
        ? selectedStrokeWidthOverride ?? tokens.stroke.active
        : card.highlighted
        ? highlightedStrokeWidthOverride ?? tokens.stroke.active
        : 0.0;
    final cardSurface = Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: tokens.colors.panel,
        borderRadius: BorderRadius.circular(cardViewCornerRadius),
        boxShadow: highlightGlow == null
            ? null
            : [
                BoxShadow(
                  color: highlightGlow.withValues(
                    alpha: cardHighlightShadowOpacity,
                  ),
                  blurRadius: cardHighlightShadowRadius,
                ),
              ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(cardViewCornerRadius),
              child: Image.asset(
                cardTemplateAssetPath(card: card, tokens: tokens, trump: trump),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(size.faceInset),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CardCenterFace(
                    card: card,
                    size: size,
                    tokens: tokens,
                    trump: trump,
                  ),
                ),
                Positioned(
                  left: cardCornerHorizontalInset(size),
                  top: cardTopCornerVerticalInset(size),
                  child: CardCornerIndex(
                    card: card,
                    size: size,
                    tokens: tokens,
                    placement: CardCornerPlacement.top,
                    trump: trump,
                  ),
                ),
                Positioned(
                  right: cardCornerHorizontalInset(size),
                  bottom: cardBottomCornerVerticalInset(size),
                  child: CardCornerIndex(
                    card: card,
                    size: size,
                    tokens: tokens,
                    placement: CardCornerPlacement.bottom,
                    trump: trump,
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cardViewCornerRadius),
                  border: Border.all(
                    color: tokens.colors.black.withValues(
                      alpha: tokens.colors.cardStrokeOpacity,
                    ),
                    width: cardViewStrokeWidth,
                  ),
                ),
              ),
            ),
          ),
          if (highlightBorder != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      highlightedBorderRadiusOverride ?? cardViewCornerRadius,
                    ),
                    border: Border.all(
                      color: highlightBorder,
                      width: highlightBorderWidth,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (!motionTracked) {
      return cardSurface;
    }
    return MotionTrackedCard(card: card, child: cardSurface);
  }
}

double cardCornerHorizontalInset(TokenCardSize size) => 0;

double cardTopCornerVerticalInset(TokenCardSize size) => -(size.height * 0.006);

double cardBottomCornerVerticalInset(TokenCardSize size) => 0;

double cardFaceValueRankGap(TokenCardSize size) =>
    (size.cornerRankFontSize * 0.16).clamp(2, 8).toDouble();

double cardCornerRankSuitGap(TokenCardSize size) =>
    (size.cornerSuitSize * 0.01).clamp(0, 0.5).toDouble();

double cardBottomCornerRankSuitGap(TokenCardSize size) =>
    (size.cornerSuitSize * 0.08).clamp(0.5, 2).toDouble();

double cardCornerSuitOutwardOffset(TokenCardSize size) =>
    (size.cornerSuitSize * 0.12).clamp(0.5, 2.5).toDouble();

double cardCornerSuitVisualSize(TableCard card, TokenCardSize size) {
  final suitScale = card.suit == wreckerSuit ? 1.5 : 1.0;
  return size.cornerSuitSize * 1.1 * suitScale;
}

double cardCornerSuitTowardRankOffset(TokenCardSize size) =>
    (size.cornerSuitSize * 0.25).clamp(1.5, 5).toDouble();

double cardBottomCornerRankDownOffset(TokenCardSize size) =>
    (size.cornerSuitSize * 0.2).clamp(1, 4).toDouble();

double cardCornerRankVisualHeight(TokenCardSize size) {
  final rankSize = pixelTextSizeForCardRank(size);
  return (rankSize.value + PixelText.opticalYOffset) *
      pixelTextScaleForCardRank(size);
}

enum CardCornerPlacement { top, bottom }

class CardCornerIndex extends StatelessWidget {
  const CardCornerIndex({
    required this.card,
    required this.size,
    required this.tokens,
    required this.placement,
    this.trump,
    super.key,
  });

  final TableCard card;
  final TokenCardSize size;
  final DesignTokens tokens;
  final CardCornerPlacement placement;
  final String? trump;

  @override
  Widget build(BuildContext context) {
    final countsAsTrump =
        trump != null && (card.suit == trump || card.suit == wreckerSuit);
    final top = placement == CardCornerPlacement.top;
    final spacing = top
        ? cardCornerRankSuitGap(size)
        : cardBottomCornerRankSuitGap(size);
    final rankSize = pixelTextSizeForCardRank(size);
    final rankScale = pixelTextScaleForCardRank(size);
    final rankHeight = cardCornerRankVisualHeight(size);
    final suitSize = cardCornerSuitVisualSize(card, size);
    final frameHeight = rankHeight + suitSize + spacing;
    final showFaceValue = cardShowsFaceNumericValue(card);
    final labelWidth = showFaceValue
        ? size.cornerWidth + size.cornerRankFontSize * 1.15
        : size.cornerWidth;
    final rankColor = countsAsTrump ? tokens.colors.red : tokens.colors.cream;
    final rankText = SizedBox(
      height: rankHeight,
      child: Align(
        alignment: top ? Alignment.centerLeft : Alignment.centerRight,
        child: Transform.scale(
          scale: rankScale,
          alignment: top ? Alignment.centerLeft : Alignment.centerRight,
          child: PixelText(
            card.rank,
            size: rankSize,
            variant: PixelTextVariant.heavy,
            color: rankColor,
            textAlign: top ? TextAlign.start : TextAlign.end,
          ),
        ),
      ),
    );
    final valueText = Padding(
      padding: EdgeInsets.zero,
      child: PixelText(
        '${card.value}',
        size: pixelTextSizeForCardFaceValue(size),
        variant: PixelTextVariant.heavy,
        color: rankColor,
      ),
    );
    final rankContent = showFaceValue
        ? Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: top
                ? [
                    rankText,
                    SizedBox(width: cardFaceValueRankGap(size)),
                    valueText,
                  ]
                : [
                    valueText,
                    SizedBox(width: cardFaceValueRankGap(size)),
                    rankText,
                  ],
          )
        : rankText;
    final rank = SizedBox(
      width: labelWidth,
      height: rankHeight,
      child: Align(
        alignment: top ? Alignment.centerLeft : Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: top ? Alignment.centerLeft : Alignment.centerRight,
          child: rankContent,
        ),
      ),
    );
    final suit = Transform.translate(
      offset: Offset(
        top
            ? size.topCornerSuitXOffset - cardCornerSuitOutwardOffset(size)
            : size.bottomCornerSuitXOffset + cardCornerSuitOutwardOffset(size),
        0,
      ),
      child: SuitMark(suit: card.suit, tokens: tokens, size: suitSize),
    );

    return SizedBox(
      width: size.cornerWidth,
      height: frameHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: top
            ? [
                Positioned(left: 0, top: 0, child: rank),
                Positioned(
                  left: 0,
                  top:
                      rankHeight +
                      spacing -
                      cardCornerSuitTowardRankOffset(size),
                  child: SizedBox(
                    width: suitSize,
                    height: suitSize,
                    child: suit,
                  ),
                ),
              ]
            : [
                Positioned(
                  right: 0,
                  top: cardCornerSuitTowardRankOffset(size),
                  child: SizedBox(
                    width: suitSize,
                    height: suitSize,
                    child: suit,
                  ),
                ),
                Positioned(
                  right: 0,
                  top:
                      suitSize + spacing + cardBottomCornerRankDownOffset(size),
                  child: rank,
                ),
              ],
      ),
    );
  }
}

class CardCenterFace extends StatelessWidget {
  const CardCenterFace({
    required this.card,
    required this.size,
    required this.tokens,
    this.trump,
    super.key,
  });

  final TableCard card;
  final TokenCardSize size;
  final DesignTokens tokens;
  final String? trump;

  @override
  Widget build(BuildContext context) {
    final countsAsTrump =
        trump != null && (card.suit == trump || card.suit == wreckerSuit);
    if (size.width <= tokens.card.small.width + 0.1) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              SuitMark(suit: card.suit, tokens: tokens, size: 14),
              PixelText(
                cardRankDisplayLabel(card),
                size: PixelTextSize.caption2,
                variant: PixelTextVariant.heavy,
                color: countsAsTrump ? tokens.colors.red : tokens.colors.cream,
              ),
            ],
          ),
        ),
      );
    }

    if (card.suit == wreckerSuit || card.value >= 11) {
      final portraitWidth = facePortraitArtWidth(card, size);
      return Center(
        child: SizedBox(
          width: portraitWidth,
          height: portraitWidth * 1.5,
          child: Image.asset(
            faceAssetPath(card),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, _, _) => Image.asset(
              genericFaceAssetPath(card),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, _, _) => SuitMark(
                suit: card.suit,
                tokens: tokens,
                size: size.width * 0.34,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.16,
        vertical: size.height * 0.02,
      ),
      child: PipPattern(card: card, size: size, tokens: tokens),
    );
  }
}

class PipPattern extends StatelessWidget {
  const PipPattern({
    required this.card,
    required this.size,
    required this.tokens,
    super.key,
  });

  final TableCard card;
  final TokenCardSize size;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final positions = pipPositions(card.value);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            for (final point in positions)
              Positioned(
                left: constraints.maxWidth * point.dx - size.pipSize / 2,
                top: constraints.maxHeight * point.dy - size.pipSize / 2,
                child: SuitMark(
                  suit: card.suit,
                  tokens: tokens,
                  size: size.pipSize,
                ),
              ),
          ],
        );
      },
    );
  }
}

class MiniRewardCard extends StatelessWidget {
  const MiniRewardCard({
    required this.card,
    required this.claimed,
    required this.height,
    required this.tokens,
    super.key,
  });

  final TableCard card;
  final bool claimed;
  final double height;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height * 24 / 34,
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.cardFill,
            borderRadius: BorderRadius.circular(tokens.radius.xs),
            border: Border.all(
              color: claimed
                  ? tokens.colors.green
                  : tokens.colors.black.withValues(
                      alpha: tokens.colors.cardStrokeOpacity,
                    ),
              width: claimed ? 2 : 1,
            ),
          ),
          child: SizedBox(
            width: 24,
            height: 34,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: miniRewardRankTop,
                  child: SizedBox(
                    width: 24,
                    child: Center(
                      child: PixelText(
                        cardRankDisplayLabel(card),
                        size: PixelTextSize.caption,
                        variant: PixelTextVariant.heavy,
                        color: tokens.colors.cardInk,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: miniRewardSuitTop,
                  child: SuitMark(suit: card.suit, tokens: tokens, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const miniRewardRankTop = -1.0;
const miniRewardSuitTop = 13.0;
const topInfoEmptyRewardCheckSize = 17.0;
const jobTileEmptyRewardCheckSize = 18.0;

class EmptyRewardMarker extends StatelessWidget {
  const EmptyRewardMarker({
    required this.size,
    required this.tokens,
    this.checkSize = jobTileEmptyRewardCheckSize,
    super.key,
  });

  final double size;
  final DesignTokens tokens;
  final double checkSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 24 / 34,
      height: size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radius.xs),
            border: Border.all(
              color: tokens.colors.green.withValues(alpha: 0.7),
            ),
          ),
          child: SizedBox(
            width: 24,
            height: 34,
            child: Center(
              child: Image.asset(
                'ios_resources/Icons/icon-check.png',
                width: checkSize,
                height: checkSize,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({
    required this.value,
    required this.complete,
    required this.tokens,
    super.key,
  });

  final double value;
  final bool complete;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final clampedValue = clampDouble(value, 0, 1);
          final fillWidth = clampedValue <= 0 || constraints.maxWidth <= 0
              ? 0.0
              : clampDouble(
                  constraints.maxWidth * clampedValue,
                  math.min(4.0, constraints.maxWidth),
                  constraints.maxWidth,
                );
          return DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.black,
              borderRadius: BorderRadius.circular(tokens.radius.xs),
              border: Border.all(
                color: tokens.colors.steel.withValues(alpha: 0.8),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radius.xs),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: fillWidth,
                  height: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: complete
                            ? [tokens.colors.green, tokens.colors.gold]
                            : [
                                const Color.fromRGBO(138, 105, 20, 1),
                                tokens.colors.gold,
                              ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SuitDot extends StatelessWidget {
  const SuitDot({
    required this.suit,
    required this.tokens,
    this.size = 12,
    super.key,
  });

  final String suit;
  final DesignTokens tokens;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: suitColor(tokens, suit),
        shape: BoxShape.circle,
      ),
    );
  }
}

class SuitMark extends StatelessWidget {
  const SuitMark({
    required this.suit,
    required this.tokens,
    required this.size,
    super.key,
  });

  final String suit;
  final DesignTokens tokens;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'ios_resources/Icons/icon-$suit.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, _, _) =>
          SuitDot(suit: suit, tokens: tokens, size: size),
    );
  }
}

const opponentPlotMiniSectionRadius = 4.0;
const opponentPlotMiniExileRadius = 6.0;

class NaturalSizeViewport extends StatelessWidget {
  const NaturalSizeViewport({
    required this.width,
    required this.height,
    required this.naturalWidth,
    required this.naturalHeight,
    required this.child,
    this.clipBehavior = Clip.hardEdge,
    super.key,
  });

  final double width;
  final double height;
  final double naturalWidth;
  final double naturalHeight;
  final Widget child;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final viewportChild = OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: naturalWidth,
      maxWidth: naturalWidth,
      minHeight: naturalHeight,
      maxHeight: naturalHeight,
      child: child,
    );
    return SizedBox(
      width: width,
      height: height,
      child: clipBehavior == Clip.none
          ? viewportChild
          : ClipRect(clipBehavior: clipBehavior, child: viewportChild),
    );
  }
}

const double cardViewCornerRadius = 8;
const double cardViewStrokeWidth = 0.8;
const double cardHighlightShadowOpacity = 0.34;
const double cardHighlightShadowRadius = 9;

class PlayerPortrait extends StatelessWidget {
  const PlayerPortrait({
    required this.seat,
    required this.tokens,
    required this.width,
    required this.height,
    this.badgeVisible,
    super.key,
  });

  final Seat seat;
  final DesignTokens tokens;
  final double width;
  final double height;
  final bool? badgeVisible;

  @override
  Widget build(BuildContext context) {
    final imageWidth = width * 32 / 38;
    final imageHeight = height * 36 / 42;
    final medalSize = math.max(7.0, math.min(width, height) * 9 / 38);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: imageWidth,
              height: imageHeight,
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: tokens.colors.black.withValues(alpha: 0.68),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.asset(
                  portraitAssetPath(seat),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, _, _) => Image.asset(
                    'ios_resources/worker4.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: tokens.colors.black.withValues(alpha: 0.42),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (badgeVisible ?? isHumanControlledSeat(seat))
            Positioned(
              right: 2,
              top: 2,
              child: Image.asset(
                'ios_resources/Icons/icon-medal-star.png',
                width: medalSize,
                height: medalSize,
                filterQuality: FilterQuality.none,
              ),
            ),
        ],
      ),
    );
  }
}

const double playerPortraitFrameWidth = 38;
const double playerPortraitFrameHeight = 42;

class PortraitFrame extends StatelessWidget {
  const PortraitFrame({
    required this.seat,
    required this.tokens,
    required this.width,
    required this.height,
    super.key,
  });

  final Seat seat;
  final DesignTokens tokens;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: math.max(width, playerPortraitFrameWidth),
        maxHeight: math.max(height, playerPortraitFrameHeight),
        child: PlayerPortrait(
          seat: seat,
          tokens: tokens,
          width: width,
          height: height,
        ),
      ),
    );
  }
}

class NegativeSpacingColumn extends StatelessWidget {
  const NegativeSpacingColumn({
    required this.children,
    required this.spacing,
    required this.itemHeight,
    this.bottomPadding = 0,
    super.key,
  });

  final List<Widget> children;
  final double spacing;
  final double itemHeight;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    final step = itemHeight + spacing;
    final height = itemHeight + step * (children.length - 1) + bottomPadding;
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (index, child) in children.indexed)
            Positioned(top: index * step, left: 0, child: child),
        ],
      ),
    );
  }
}
