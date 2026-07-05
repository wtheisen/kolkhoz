import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show clampDouble, lerpDouble;

import 'package:flutter/material.dart';

import 'animation_speed.dart';
import 'app_settings.dart';
import 'assignment_display.dart';
import 'brigade_display.dart';
import 'card_art_display.dart';
import 'card_display.dart';
import 'render_model.dart';
import 'design_tokens.dart';
import 'game_constants.dart';
import 'hot_seat_display.dart';
import 'lower_bar_actions.dart';
import 'panel_title_display.dart';
import 'phase_display.dart';
import 'pixel_text.dart';
import 'player_panel_display.dart';
import 'plot_display.dart';
import 'trump_actions.dart';
import 'table_display.dart';
import 'table_projection_helpers.dart';
import 'board/board_chrome.dart';
import 'board/board_metrics.dart';
import 'board/board_rail.dart';

export 'board/board_chrome.dart';
export 'board/board_metrics.dart';
export 'board/board_rail.dart';

part 'board/options_panel.dart';
part 'board/north_panel.dart';
part 'board/plot_panel.dart';
part 'board/jobs_panel.dart';
part 'board/hand_tray.dart';

const kolkhozFontStyle = TextStyle(fontFamily: 'Handjet');

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

BoxDecoration boardBackdropDecoration(DesignTokens tokens) {
  return BoxDecoration(color: tokens.colors.table);
}

BoxDecoration playAreaBackdropDecoration(DesignTokens tokens) {
  return BoxDecoration(
    color: tokens.colors.table,
    borderRadius: BorderRadius.circular(playAreaPanelCornerRadius),
  );
}

class KolkhozBoard extends StatelessWidget {
  const KolkhozBoard({
    required this.model,
    required this.tokens,
    required this.language,
    required this.appearance,
    this.onAction,
    this.onPanelSelected,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    this.onSwapHandCardTap,
    this.onPlotCardTap,
    this.onAssignmentCardTap,
    this.onHotSeatReady,
    this.onNewGame,
    this.onReturnToLobby,
    this.onTutorial,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final ValueChanged<LegalAction>? onAction;
  final ValueChanged<String>? onPanelSelected;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;
  final ValueChanged<String>? onSwapHandCardTap;
  final void Function(String cardID, String zone)? onPlotCardTap;
  final ValueChanged<String>? onAssignmentCardTap;
  final VoidCallback? onHotSeatReady;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onTutorial;
  final GameAnimationSpeed animationSpeed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: kolkhozFontStyle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = ResponsiveBoardMetrics.fromSize(
            constraints.biggest,
            tokens,
          );
          final margin = metrics.margin;
          final contentWidth = constraints.maxWidth - margin * 2;
          final contentHeight = constraints.maxHeight - margin * 2;
          final railWidth = metrics.railWidth(contentWidth);
          final separatorWidth = metrics.separatorWidth;
          final gameWidth = contentWidth - railWidth - separatorWidth;
          final safePadding = MediaQuery.paddingOf(context);

          return DecoratedBox(
            decoration: boardBackdropDecoration(tokens),
            child: CardMotionLayer(
              model: model,
              tokens: tokens,
              speed: animationSpeed,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  if (safePadding.left > 0)
                    Positioned(
                      left: boardLeftGutterOffset(safePadding.left),
                      top: 0,
                      bottom: 0,
                      child: BoardGutterInfill(
                        side: BoardGutterInfillSide.left,
                        width: boardLeftGutterWidth(safePadding.left),
                        light: appearance == KolkhozAppearance.light,
                      ),
                    ),
                  if (safePadding.right > 0)
                    Positioned(
                      right: boardRightGutterOffset(safePadding.right),
                      top: 0,
                      bottom: 0,
                      child: BoardGutterInfill(
                        side: BoardGutterInfillSide.right,
                        width: boardRightGutterWidth(safePadding.right),
                        light: appearance == KolkhozAppearance.light,
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.all(margin),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: railWidth,
                          child: BoardRail(
                            activePanel: model.panels.active,
                            actionPanel: actionPanelForPhase(model.table.phase),
                            tokens: tokens,
                            metrics: metrics,
                            language: language,
                            appearance: appearance,
                            onPanelSelected: onPanelSelected,
                            onLanguageToggle: onLanguageToggle,
                            onAppearanceToggle: onAppearanceToggle,
                          ),
                        ),
                        BoardSeparator(
                          tokens: tokens,
                          vertical: true,
                          thickness: separatorWidth,
                        ),
                        SizedBox(
                          width: gameWidth,
                          height: contentHeight,
                          child: BoardPlayArea(
                            model: model,
                            tokens: tokens,
                            metrics: metrics,
                            onAction: onAction,
                            onPanelSelected: onPanelSelected,
                            onSwapHandCardTap: onSwapHandCardTap,
                            onPlotCardTap: onPlotCardTap,
                            onAssignmentCardTap: onAssignmentCardTap,
                            onNewGame: onNewGame,
                            onReturnToLobby: onReturnToLobby,
                            onTutorial: onTutorial,
                            animationSpeed: animationSpeed,
                            onAnimationSpeedChanged: onAnimationSpeedChanged,
                            language: language,
                            appearance: appearance,
                            onLanguageToggle: onLanguageToggle,
                            onAppearanceToggle: onAppearanceToggle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (model.viewer.privacyMode == viewerPrivacyHotSeatHidden)
                    Positioned.fill(
                      child: HotSeatPrivacyOverlay(
                        model: model,
                        tokens: tokens,
                        language: language,
                        onReady: onHotSeatReady,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
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
    _afterCardLayout(() {
      _startFlights(previousZones, nextZones, previousCards, nextCards);
      _controller.commitFrame();
    });
  }

  void _afterCardLayout(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduleMicrotask(() {
        if (mounted) {
          action();
        }
      });
    });
  }

  void _startFlights(
    Map<String, String> previousZones,
    Map<String, String> nextZones,
    Map<String, TableCard> previousCards,
    Map<String, TableCard> nextCards,
  ) {
    if (widget.speed.cardFlightDuration == Duration.zero) {
      return;
    }
    final previousRects = _controller.previousRects;
    final currentRects = _controller.currentRects;
    final newFlights = <CardFlight>[];
    for (final entry in nextZones.entries) {
      final cardID = entry.key;
      final previousZone = previousZones[cardID];
      if (previousZone == null || previousZone == entry.value) {
        continue;
      }
      final from = previousRects[cardID];
      final to = currentRects[cardID];
      if (from == null || to == null) {
        continue;
      }
      if ((from.center - to.center).distance < cardMotionMinimumDistance) {
        continue;
      }
      final card = nextCards[cardID] ?? previousCards[cardID];
      if (card == null) {
        continue;
      }
      newFlights.add(
        CardFlight(id: _nextFlightID++, card: card, from: from, to: to),
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
        final topLeft = box.localToGlobal(Offset.zero, ancestor: root);
        scope.controller.record(
          frame: scope.frame,
          cardID: widget.card.id,
          rect: topLeft & box.size,
        );
      });
    }
    final hidden = scope?.activeCardIDs.contains(widget.card.id) ?? false;
    return Opacity(key: _key, opacity: hidden ? 0 : 1, child: widget.child);
  }
}

class CardFlight {
  const CardFlight({
    required this.id,
    required this.card,
    required this.from,
    required this.to,
  });

  final int id;
  final TableCard card;
  final Rect from;
  final Rect to;
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
      duration: duration,
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

Map<String, String> cardMotionZones(TableViewModel model) {
  final zones = <String, String>{};
  for (final seat in model.table.seats) {
    for (final card in seat.hand) {
      zones[card.id] = 'hand:${seat.id}';
    }
    for (final card in seat.plot.hidden) {
      zones[card.id] = 'plot:${seat.id}:hidden';
    }
    for (final card in seat.plot.revealed) {
      zones[card.id] = 'plot:${seat.id}:revealed';
    }
    for (final (stackIndex, stack) in seat.plot.stacks.indexed) {
      for (final card in stack.revealed) {
        zones[card.id] = 'plot:${seat.id}:stack:$stackIndex:revealed';
      }
    }
  }
  for (final play in model.table.trick.plays) {
    zones[play.card.id] = 'trick:${play.seatID}';
  }
  for (final play in model.table.lastTrick.plays) {
    zones[play.card.id] = 'trick:${play.seatID}';
  }
  for (final job in model.table.jobs) {
    for (final card in job.assignedCards) {
      zones[card.id] = 'job:${job.suit}';
    }
  }
  for (final entry in model.table.exiledByYear.entries) {
    for (final card in entry.value) {
      zones[card.id] = 'exiled:${entry.key}';
    }
  }
  return zones;
}

Map<String, TableCard> cardMotionCards(TableViewModel model) {
  final cards = <String, TableCard>{};
  void add(TableCard card) {
    cards[card.id] = card;
  }

  for (final seat in model.table.seats) {
    seat.hand.forEach(add);
    seat.plot.hidden.forEach(add);
    seat.plot.revealed.forEach(add);
    for (final stack in seat.plot.stacks) {
      stack.revealed.forEach(add);
    }
  }
  for (final play in model.table.trick.plays) {
    add(play.card);
  }
  for (final play in model.table.lastTrick.plays) {
    add(play.card);
  }
  for (final job in model.table.jobs) {
    job.assignedCards.forEach(add);
  }
  for (final cardsForYear in model.table.exiledByYear.values) {
    cardsForYear.forEach(add);
  }
  return cards;
}

const cardMotionMinimumDistance = 8.0;

class HotSeatPrivacyOverlay extends StatelessWidget {
  const HotSeatPrivacyOverlay({
    required this.model,
    required this.tokens,
    required this.language,
    this.onReady,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback? onReady;

  @override
  Widget build(BuildContext context) {
    final player = hotSeatPrivacyPlayer(model);
    return ColoredBox(
      color: tokens.colors.black.withValues(alpha: hotSeatScrimOpacity),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panelWidth = hotSeatPanelWidth(constraints.maxWidth);
          final portraitSlotSize = hotSeatPortraitSlotSize(
            constraints.maxHeight,
          );
          return Center(
            child: SizedBox(
              width: panelWidth,
              child: PanelStyleSurface(
                tokens: tokens,
                padding: const EdgeInsets.symmetric(
                  horizontal: hotSeatPanelHorizontalPadding,
                  vertical: hotSeatPanelVerticalPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: hotSeatContentSpacing,
                  children: [
                    SizedBox(
                      height: hotSeatTitleRowHeight,
                      child: PanelTitleRow(
                        title: language.text(
                          en: 'Pass Device',
                          ru: 'Передайте устройство',
                        ),
                        subtitle: language.text(
                          en: 'Seat ${player.id + 1} is up.',
                          ru: 'Ходит место ${player.id + 1}.',
                        ),
                        iconPath: 'ios_resources/Icons/icon-pass-device.png',
                        tokens: tokens,
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: hotSeatPlacardMaxWidth,
                        maxHeight: hotSeatPlacardMaxHeight,
                      ),
                      child: Opacity(
                        opacity: hotSeatPlacardOpacity,
                        child: Image.asset(
                          'ios_resources/Embellishments/art-pass-device-placard.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: portraitSlotSize,
                      height: portraitSlotSize,
                      child: Center(
                        child: DecoratedBox(
                          key: const Key('hot-seat-portrait-shadow'),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: tokens.colors.black.withValues(
                                  alpha: hotSeatPortraitShadowOpacity,
                                ),
                                blurRadius: hotSeatPortraitShadowRadius,
                                offset: const Offset(
                                  0,
                                  hotSeatPortraitShadowYOffset,
                                ),
                              ),
                            ],
                          ),
                          child: PlayerPortrait(
                            seat: player,
                            tokens: tokens,
                            width: playerPortraitFrameWidth,
                            height: playerPortraitFrameHeight,
                            badgeVisible: true,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: hotSeatLabelSpacing,
                      children: [
                        PixelText(
                          player.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          size: PixelTextSize.title,
                          variant: PixelTextVariant.heavy,
                          color: tokens.colors.gold,
                        ),
                        Text(
                          hotSeatPhaseLine(
                            model,
                            language: language,
                          ).toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: kolkhozFontStyle.copyWith(
                            color: tokens.colors.creamDim,
                            fontSize: hotSeatPhaseLineFontSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: hotSeatReadyButtonMaxWidth,
                      child: HotSeatReadyButton(
                        tokens: tokens,
                        label: language.text(en: 'Ready', ru: 'Готов'),
                        onPressed: onReady,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class HotSeatReadyButton extends StatelessWidget {
  const HotSeatReadyButton({
    required this.tokens,
    required this.label,
    this.onPressed,
    super.key,
  });

  final DesignTokens tokens;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        key: const Key('hot-seat-ready-button'),
        height: commandButtonProminentMinHeight,
        padding: const EdgeInsets.only(
          left: commandButtonProminentHorizontalPadding,
          right: commandButtonProminentHorizontalPadding,
          top: commandButtonProminentTopPadding,
          bottom: commandButtonProminentBottomPadding,
        ),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('ios_resources/ui-button-primary.png'),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
          ),
          boxShadow: [
            BoxShadow(
              color: tokens.colors.black.withValues(
                alpha: commandButtonProminentOuterShadowOpacity,
              ),
              blurRadius: commandButtonProminentOuterShadowRadius,
              offset: const Offset(0, commandButtonProminentOuterShadowYOffset),
            ),
          ],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: CommandSurfaceButtonLabel(label, tokens: tokens),
          ),
        ),
      ),
    );
  }
}

const playAreaPanelCornerRadius = 10.0;

class BoardPlayArea extends StatelessWidget {
  const BoardPlayArea({
    required this.model,
    required this.tokens,
    required this.metrics,
    this.onAction,
    this.onPanelSelected,
    this.onSwapHandCardTap,
    this.onPlotCardTap,
    this.onAssignmentCardTap,
    this.onNewGame,
    this.onReturnToLobby,
    this.onTutorial,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    required this.language,
    required this.appearance,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;
  final ValueChanged<LegalAction>? onAction;
  final ValueChanged<String>? onPanelSelected;
  final ValueChanged<String>? onSwapHandCardTap;
  final void Function(String cardID, String zone)? onPlotCardTap;
  final ValueChanged<String>? onAssignmentCardTap;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onTutorial;
  final GameAnimationSpeed animationSpeed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.playAreaHorizontalPadding,
      ),
      child: Column(
        children: [
          TopInfoStrip(model: model, tokens: tokens, metrics: metrics),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: playAreaBackdropDecoration(tokens),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: metrics.panelContentBottomPadding,
                    ),
                    child: ActivePanelView(
                      model: model,
                      tokens: tokens,
                      onAction: onAction,
                      onPlotCardTap: onPlotCardTap,
                      onNewGame: onNewGame,
                      onReturnToLobby: onReturnToLobby,
                      onTutorial: onTutorial,
                      animationSpeed: animationSpeed,
                      onAnimationSpeedChanged: onAnimationSpeedChanged,
                      language: language,
                      appearance: appearance,
                      onLanguageToggle: onLanguageToggle,
                      onAppearanceToggle: onAppearanceToggle,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: BoardSeparator(
                    tokens: tokens,
                    thickness: metrics.playAreaSeparatorThickness,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: BoardSeparator(
                    tokens: tokens,
                    thickness: metrics.playAreaSeparatorThickness,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: metrics.handTrayHeight,
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: metrics.handTrayVisibleHeight,
              maxHeight: metrics.handTrayVisibleHeight,
              child: HandTray(
                model: model,
                tokens: tokens,
                metrics: metrics,
                language: language,
                onAction: onAction,
                onSwapHandCardTap: onSwapHandCardTap,
                onAssignmentCardTap: onAssignmentCardTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const iconMutedSaturationMatrix = <double>[
  0.76378,
  0.21456,
  0.02166,
  0,
  0,
  0.06378,
  0.91456,
  0.02166,
  0,
  0,
  0.06378,
  0.21456,
  0.72166,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];
const iconMutedOpacity = 0.82;

class TopInfoStrip extends StatelessWidget {
  const TopInfoStrip({
    required this.model,
    required this.tokens,
    required this.metrics,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final localPlayer = localSeat(model);
    final jobs = jobsInDisplayOrder(model.table.jobs);
    final cellarScore = localPlayer.plot.hidden.fold<int>(
      0,
      (score, card) => score + card.value,
    );
    final plotScore = localPlayer.plot.revealed.fold<int>(
      0,
      (score, card) => score + card.value,
    );
    final topInfo = tokens.layout.topInfo;
    return SizedBox(
      height: metrics.topInfoHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rowSpacing = clampDouble(
            constraints.maxWidth * topInfo.rowSpacingFactor,
            topInfo.rowSpacingMin,
            topInfo.rowSpacingMax,
          );
          final yearWidth = clampDouble(
            constraints.maxWidth * topInfo.yearWidthFactor,
            topInfo.yearWidthMin,
            topInfo.yearWidthMax,
          );
          final gaugeWidth = clampDouble(
            constraints.maxWidth * topInfo.gaugeWidthFactor,
            topInfo.gaugeWidthMin,
            topInfo.gaugeWidthMax,
          );
          final gaugeHeight = clampDouble(
            constraints.maxHeight * topInfo.gaugeHeightFactor,
            topInfo.gaugeHeightMin,
            topInfo.gaugeHeightMax,
          );
          final gaugeSpacing = clampDouble(
            constraints.maxWidth * topInfo.gaugeSpacingFactor,
            topInfo.gaugeSpacingMin,
            topInfo.gaugeSpacingMax,
          );
          final gaugeFrameWidth =
              gaugeWidth * topInfo.gaugeFrameWidthMultiplier;
          final gaugesWidth =
              gaugeFrameWidth * jobs.length + gaugeSpacing * (jobs.length - 1);
          final gaugeClusterLeftOffset = -clampDouble(
            constraints.maxWidth * topInfo.gaugeClusterLeftOffsetFactor,
            topInfo.gaugeClusterLeftOffsetMin,
            topInfo.gaugeClusterLeftOffsetMax,
          );
          final scoreWidth = clampDouble(
            constraints.maxWidth * topInfo.scoreWidthFactor,
            topInfo.scoreWidthMin,
            topInfo.scoreWidthMax,
          );
          final scoreGroupWidth = scoreWidth * 2 + rowSpacing;

          return ClipRect(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  spacing: rowSpacing,
                  children: [
                    SizedBox(
                      width: yearWidth,
                      child: TopInfoCell(
                        icon: 'icon-year-${model.table.year.clamp(1, 5)}.png',
                        value: '',
                        iconSize: gaugeHeight * 1.3,
                        contentSpacing: rowSpacing,
                        height: metrics.topInfoHeight,
                        tokens: tokens,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: scoreGroupWidth,
                      child: Row(
                        spacing: rowSpacing,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: scoreWidth,
                            child: TopInfoCell(
                              icon: 'icon-cellar.png',
                              value: '$cellarScore',
                              iconSize: gaugeHeight * 0.8,
                              contentSpacing: rowSpacing,
                              height: metrics.topInfoHeight,
                              tokens: tokens,
                            ),
                          ),
                          SizedBox(
                            width: scoreWidth,
                            child: TopInfoCell(
                              icon: 'icon-plot.png',
                              value: '$plotScore',
                              iconSize: gaugeHeight * 0.8,
                              contentSpacing: rowSpacing,
                              height: metrics.topInfoHeight,
                              tokens: tokens,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Transform.translate(
                  offset: Offset(gaugeClusterLeftOffset, 0),
                  child: OverflowBox(
                    minWidth: 0,
                    maxWidth: gaugesWidth,
                    minHeight: 0,
                    maxHeight: gaugeHeight,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: gaugesWidth,
                      height: gaugeHeight,
                      child: Row(
                        spacing: gaugeSpacing,
                        children: [
                          for (final job in jobs)
                            SizedBox(
                              width: gaugeFrameWidth,
                              child: Center(
                                child: JobGauge(
                                  job: job,
                                  highlighted: model.table.trump == job.suit,
                                  width:
                                      gaugeWidth *
                                      topInfo.gaugeContentWidthMultiplier,
                                  height: gaugeHeight,
                                  tokens: tokens,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TopInfoCell extends StatelessWidget {
  const TopInfoCell({
    required this.icon,
    required this.value,
    required this.tokens,
    required this.height,
    this.iconSize = 24,
    this.contentSpacing = 5,
    this.horizontalPadding = 6,
    super.key,
  });

  final String icon;
  final String value;
  final DesignTokens tokens;
  final double height;
  final double iconSize;
  final double contentSpacing;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.centerLeft,
        child: OverflowBox(
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: height,
          maxHeight: height,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: contentSpacing,
                children: [
                  Image.asset(
                    'ios_resources/Icons/$icon',
                    width: iconSize,
                    height: iconSize,
                    filterQuality: FilterQuality.none,
                  ),
                  if (value.isNotEmpty)
                    PixelText(
                      value,
                      size: PixelTextSize.cardRank,
                      variant: PixelTextVariant.heavy,
                      color: tokens.colors.gold,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class JobGauge extends StatelessWidget {
  const JobGauge({
    required this.job,
    required this.highlighted,
    required this.width,
    required this.height,
    required this.tokens,
    super.key,
  });

  final Job job;
  final bool highlighted;
  final double width;
  final double height;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final markerWidth =
        height * tokens.layout.topInfo.rewardMarkerHeightMultiplier;
    const contentSpacing = 4.0;
    final contentWidth = width - markerWidth - contentSpacing;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('ios_resources/ui-header-counter.png'),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
          ),
        ),
        child: Row(
          spacing: contentSpacing,
          children: [
            SizedBox(
              width: markerWidth,
              height: height,
              child: Center(
                child: job.reward == null
                    ? EmptyRewardMarker(
                        size: 34,
                        checkSize: topInfoEmptyRewardCheckSize,
                        tokens: tokens,
                      )
                    : MiniRewardCard(
                        card: job.reward!,
                        claimed: job.claimed,
                        height: height * 0.84,
                        tokens: tokens,
                      ),
              ),
            ),
            SizedBox(
              width: contentWidth,
              height: height,
              child: job.claimed
                  ? Center(
                      child: Image.asset(
                        'ios_resources/Icons/icon-check.png',
                        width:
                            height *
                            tokens.layout.topInfo.checkIconHeightMultiplier,
                        height:
                            height *
                            tokens.layout.topInfo.checkIconHeightMultiplier,
                        filterQuality: FilterQuality.none,
                      ),
                    )
                  : Center(
                      child: PixelText(
                        '${job.hours}/$jobRequiredHours',
                        textAlign: TextAlign.center,
                        size: PixelTextSize.title,
                        variant: PixelTextVariant.regular,
                        color: highlighted
                            ? tokens.colors.red
                            : tokens.colors.smoke,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivePanelView extends StatelessWidget {
  const ActivePanelView({
    required this.model,
    required this.tokens,
    this.onAction,
    this.onPlotCardTap,
    this.onNewGame,
    this.onReturnToLobby,
    this.onTutorial,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    required this.language,
    required this.appearance,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final ValueChanged<LegalAction>? onAction;
  final void Function(String cardID, String zone)? onPlotCardTap;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onTutorial;
  final GameAnimationSpeed animationSpeed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    switch (model.panels.active) {
      case panelJobs:
        return JobsPanel(
          model: model,
          tokens: tokens,
          language: language,
          onAction: onAction,
        );
      case panelPlot:
        return PlotPanel(
          model: model,
          tokens: tokens,
          language: language,
          onPlotCardTap: onPlotCardTap,
        );
      case panelNorth:
        return NorthPanel(model: model, tokens: tokens, language: language);
      case panelOptions:
        return OptionsPanel(
          model: model,
          tokens: tokens,
          onNewGame: onNewGame,
          onReturnToLobby: onReturnToLobby,
          onTutorial: onTutorial,
          animationSpeed: animationSpeed,
          onAnimationSpeedChanged: onAnimationSpeedChanged,
          language: language,
          appearance: appearance,
          onLanguageToggle: onLanguageToggle,
          onAppearanceToggle: onAppearanceToggle,
        );
      default:
        return BrigadePanel(
          model: model,
          tokens: tokens,
          language: language,
          onAction: onAction,
          onNewGame: onNewGame,
        );
    }
  }
}

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

class BrigadePanel extends StatelessWidget {
  const BrigadePanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.onAction,
    this.onNewGame,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final ValueChanged<LegalAction>? onAction;
  final VoidCallback? onNewGame;

  @override
  Widget build(BuildContext context) {
    final seats = model.table.seats;
    final trick = model.table.phase == phaseAssignment
        ? model.table.lastTrick
        : model.table.trick;
    return LayoutBuilder(
      builder: (context, constraints) {
        final playerOrder = orderedSeats(seats);
        final columnCount = playerOrder.length.toDouble();
        final columnWidth = brigadeColumnWidth(
          maxWidth: constraints.maxWidth,
          mediumCardWidth: tokens.card.medium.width,
        );
        final totalColumnWidth = columnWidth * columnCount;
        final availableSpacing = (constraints.maxWidth - totalColumnWidth)
            .clamp(0, double.infinity);
        final spacing = columnCount <= 1
            ? 0.0
            : (availableSpacing / (columnCount - 1)) * brigadeColumnSpacingFill;
        final rowWidth = totalColumnWidth + spacing * (columnCount - 1);
        final brigadeRowHeight = clampDouble(
          constraints.maxHeight - brigadePanelLocalPadding.vertical,
          0,
          double.infinity,
        );

        return Stack(
          children: [
            Padding(
              padding: brigadePanelLocalPadding,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: math.min(rowWidth, constraints.maxWidth),
                  height: brigadeRowHeight,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: rowWidth,
                      maxWidth: rowWidth,
                      minHeight: brigadeRowHeight,
                      maxHeight: brigadeRowHeight,
                      child: SizedBox(
                        width: rowWidth,
                        height: brigadeRowHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (
                              var index = 0;
                              index < playerOrder.length;
                              index++
                            )
                              Padding(
                                padding: EdgeInsets.only(
                                  right: index == playerOrder.length - 1
                                      ? 0
                                      : spacing,
                                ),
                                child: BrigadePlayerColumn(
                                  seat: playerOrder[index],
                                  play: trick.playForSeat(
                                    playerOrder[index].id,
                                  ),
                                  columnWidth: columnWidth,
                                  maxTricks: model.table.maxTricks,
                                  trump: model.table.trump,
                                  phase: model.table.phase,
                                  tokens: tokens,
                                  language: language,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (model.table.phase == phasePlanning)
              PhaseOverlayFrame(
                tokens: tokens,
                child: PlanningTrumpPanel(
                  model: model,
                  tokens: tokens,
                  language: language,
                  onAction: onAction,
                ),
              ),
            if (model.table.phase == phaseGameOver)
              PhaseOverlayFrame(
                tokens: tokens,
                child: GameOverPanel(
                  model: model,
                  tokens: tokens,
                  language: language,
                  onNewGame: onNewGame,
                ),
              ),
          ],
        );
      },
    );
  }

  List<Seat> orderedSeats(List<Seat> seats) {
    final byID = {for (final seat in seats) seat.id: seat};
    return [
      1,
      2,
      3,
      0,
    ].map((id) => byID[id]).whereType<Seat>().toList(growable: false);
  }
}

class PhaseOverlayFrame extends StatelessWidget {
  const PhaseOverlayFrame({
    required this.tokens,
    required this.child,
    super.key,
  });

  final DesignTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radius.panelOuter),
              boxShadow: [
                BoxShadow(
                  color: tokens.colors.black.withValues(
                    alpha: phaseOverlayOuterShadowOpacity,
                  ),
                  blurRadius: phaseOverlayOuterShadowRadius,
                  offset: const Offset(0, phaseOverlayOuterShadowYOffset),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

const phaseOverlayOuterShadowOpacity = 0.5;
const phaseOverlayOuterShadowRadius = 16.0;
const phaseOverlayOuterShadowYOffset = 8.0;

extension on Trick {
  TrickPlay? playForSeat(int seatID) {
    for (final play in plays) {
      if (play.seatID == seatID) {
        return play;
      }
    }
    return null;
  }
}

class BrigadePlayerColumn extends StatelessWidget {
  const BrigadePlayerColumn({
    required this.seat,
    required this.play,
    required this.columnWidth,
    required this.maxTricks,
    required this.trump,
    required this.phase,
    required this.tokens,
    required this.language,
    super.key,
  });

  final Seat seat;
  final TrickPlay? play;
  final double columnWidth;
  final int maxTricks;
  final String? trump;
  final String phase;
  final DesignTokens tokens;
  final KolkhozLanguage language;

  @override
  Widget build(BuildContext context) {
    final cardSize = tokens.card.medium;
    final slotWidth = brigadeSlotWidth(columnWidth);
    const playAreaScale = brigadePlayAreaScale;
    final playAreaTopOffset = brigadePlayAreaTopOffset(columnWidth);
    final playerPanelWidth = cardSize.width * playAreaScale;
    const playerPanelHeight = brigadePlayerPanelHeight;
    final playAreaWidth =
        (cardSize.width > slotWidth ? cardSize.width : slotWidth) *
        playAreaScale;
    final playAreaLeftOffset = brigadePlayAreaLeftOffset(
      playerPanelWidth: playerPanelWidth,
      playAreaWidth: playAreaWidth,
    );
    final playAreaHeight =
        (cardSize.height > slotWidth * 1.2
            ? cardSize.height
            : slotWidth * 1.2) *
        playAreaScale;
    final active = phase == phaseTrick && seat.isCurrentTurn && play == null;

    return SizedBox(
      width: columnWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: playerPanelWidth,
            height: playerPanelHeight,
            child: PlayerBadge(
              seat: seat,
              tokens: tokens,
              active: active,
              width: playerPanelWidth,
              height: playerPanelHeight,
              maxTricks: maxTricks,
              language: language,
            ),
          ),
          Transform.translate(
            offset: Offset(
              playAreaLeftOffset,
              -brigadeColumnOverlap(columnWidth),
            ),
            child: Padding(
              padding: EdgeInsets.only(top: playAreaTopOffset),
              child: SizedBox(
                width: playAreaWidth,
                height: playAreaHeight,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.scale(
                    scale: playAreaScale,
                    alignment: Alignment.topCenter,
                    child: play == null
                        ? CardSlot(
                            active: active,
                            human: seat.isViewer,
                            width: slotWidth,
                            height: slotWidth * 1.4,
                            tokens: tokens,
                            language: language,
                          )
                        : GameCard(
                            card: play!.card,
                            tokens: tokens,
                            trump: trump,
                            sizeOverride: cardSize,
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
          width: playerPortraitFrameWidth,
          height: playerPortraitFrameHeight,
        ),
      ),
    );
  }
}

class PlayerBadge extends StatelessWidget {
  const PlayerBadge({
    required this.seat,
    required this.tokens,
    required this.active,
    required this.language,
    this.width = 178,
    this.height = 40,
    this.maxTricks = 4,
    super.key,
  });

  final Seat seat;
  final DesignTokens tokens;
  final bool active;
  final KolkhozLanguage language;
  final double width;
  final double height;
  final int maxTricks;

  @override
  Widget build(BuildContext context) {
    final human = seat.isViewer;
    final portraitColumnWidth = playerPanelPortraitColumnWidth(width, height);
    final portraitSize = playerPanelPortraitSize(width, height);
    final rowSpacing = playerPanelRowSpacing(width);
    final stackSpacing = playerPanelStackSpacing(width);
    final statColumnWidth = playerPanelStatColumnWidth(width);
    final topPadding = playerPanelTopPadding(height);
    final cellarCardSpacing = playerPanelCellarCardSpacing(width);
    final contentNaturalWidth = playerPanelContentNaturalWidth(width);
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: active
                  ? tokens.colors.gold.withValues(
                      alpha: playerPanelActiveShadowOpacity,
                    )
                  : tokens.colors.black.withValues(
                      alpha: playerPanelInactiveShadowOpacity,
                    ),
              blurRadius: playerPanelShadowRadius,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Image.asset(
                'ios_resources/ui-player-panel.png',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: portraitColumnWidth,
                      child: Transform.translate(
                        offset: const Offset(-2, 2),
                        child: PortraitFrame(
                          seat: seat,
                          tokens: tokens,
                          width: portraitSize,
                          height: portraitSize,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(0, -2),
                        child: ClipRect(
                          child: OverflowBox(
                            minWidth: contentNaturalWidth,
                            maxWidth: contentNaturalWidth,
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: contentNaturalWidth,
                              child: Padding(
                                padding: EdgeInsets.only(top: topPadding),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  spacing: math.max(0, stackSpacing),
                                  children: [
                                    Row(
                                      spacing: rowSpacing,
                                      children: [
                                        Expanded(
                                          child: PixelText(
                                            displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            size: PixelTextSize.caption,
                                            variant: PixelTextVariant.heavy,
                                            color: active
                                                ? tokens.colors.gold
                                                : tokens.colors.cardInk,
                                          ),
                                        ),
                                        const Spacer(),
                                        PlayerPlotScoreStat(
                                          score: seat.visibleScore,
                                          tokens: tokens,
                                          width: statColumnWidth,
                                        ),
                                      ],
                                    ),
                                    Transform.translate(
                                      offset: Offset(
                                        0,
                                        math.min(0, stackSpacing),
                                      ),
                                      child: Row(
                                        spacing: rowSpacing,
                                        children: [
                                          PlayerMedalStat(
                                            medals: seat.medals,
                                            maxTricks: maxTricks,
                                            tokens: tokens,
                                            statColumnWidth: statColumnWidth,
                                          ),
                                          const Spacer(),
                                          PlayerCellarStat(
                                            count: seat.plot.hidden.length,
                                            tokens: tokens,
                                            width: statColumnWidth,
                                            cardSpacing: cellarCardSpacing,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: active
                            ? tokens.colors.gold.withValues(alpha: 0.78)
                            : human
                            ? tokens.colors.redDark.withValues(alpha: 0.42)
                            : Colors.transparent,
                        width: active
                            ? 1.3
                            : human
                            ? 1
                            : 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (statusBadgeAssets.isNotEmpty)
              Positioned(
                top: 3,
                right: 5,
                child: PlayerStatusBadgeStrip(
                  assets: statusBadgeAssets,
                  tokens: tokens,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get displayName {
    return seatDisplayName(seat, language: language);
  }

  List<String> get statusBadgeAssets {
    return [
      if (active)
        isHumanControlledSeat(seat)
            ? 'icon-status-current-turn.png'
            : 'icon-status-ai-thinking.png',
      if (seat.isBrigadeLeader) 'icon-status-brigade-leader.png',
    ];
  }
}

class PlayerStatusBadgeStrip extends StatelessWidget {
  const PlayerStatusBadgeStrip({
    required this.assets,
    required this.tokens,
    super.key,
  });

  final List<String> assets;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.3)),
      ),
      child: SizedBox(
        width: 14 + (assets.take(3).length - 1) * 11,
        height: 14,
        child: Stack(
          children: [
            for (final (index, asset) in assets.take(3).indexed)
              Positioned(
                left: index * 11,
                top: 0,
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: Center(
                    child: Image.asset(
                      'ios_resources/Icons/$asset',
                      width: 13,
                      height: 13,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PlayerPlotScoreStat extends StatelessWidget {
  const PlayerPlotScoreStat({
    required this.score,
    required this.tokens,
    required this.width,
    super.key,
  });

  final int score;
  final DesignTokens tokens;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 18,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              Image.asset(
                'ios_resources/Icons/icon-plot.png',
                width: 16,
                height: 16,
                filterQuality: FilterQuality.none,
              ),
              PixelText(
                '$score',
                size: PixelTextSize.headline,
                variant: PixelTextVariant.heavy,
                color: tokens.colors.smoke,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerMedalStat extends StatelessWidget {
  const PlayerMedalStat({
    required this.medals,
    required this.maxTricks,
    required this.tokens,
    required this.statColumnWidth,
    super.key,
  });

  final int medals;
  final int maxTricks;
  final DesignTokens tokens;
  final double statColumnWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: statColumnWidth * 0.72,
      height: 12,
      child: Stack(
        children: [
          for (var index = 0; index < maxTricks; index++)
            Positioned(
              left:
                  index * (playerPanelMedalIconSize + playerPanelMedalSpacing),
              top: 0,
              child: Opacity(
                opacity: index < medals ? 1 : playerPanelUnearnedMedalOpacity,
                child: index < medals
                    ? playerMedalIcon()
                    : ColorFiltered(
                        colorFilter: const ColorFilter.matrix(
                          iconMutedSaturationMatrix,
                        ),
                        child: Opacity(
                          opacity: iconMutedOpacity,
                          child: playerMedalIcon(),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget playerMedalIcon() {
    return Image.asset(
      'ios_resources/Icons/icon-medal-star.png',
      width: playerPanelMedalIconSize,
      height: playerPanelMedalIconSize,
      filterQuality: FilterQuality.none,
    );
  }
}

const playerPanelMedalIconSize = 12.0;
const playerPanelMedalSpacing = -4.0;
const playerPanelUnearnedMedalOpacity = 0.18;

class PlayerCellarStat extends StatelessWidget {
  const PlayerCellarStat({
    required this.count,
    required this.tokens,
    required this.width,
    required this.cardSpacing,
    super.key,
  });

  final int count;
  final DesignTokens tokens;
  final double width;
  final double cardSpacing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 16,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              Image.asset(
                'ios_resources/Icons/icon-cellar.png',
                width: 16,
                height: 16,
                filterQuality: FilterQuality.none,
              ),
              SizedBox(
                width: math.max(0, count * 10 + (count - 1) * cardSpacing),
                height: 15,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var index = 0; index < count; index++)
                      Positioned(
                        left: index * (10 + cardSpacing),
                        top: 0,
                        child: PlayerCardBackThumbnail(tokens: tokens),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerCardBackThumbnail extends StatelessWidget {
  const PlayerCardBackThumbnail({required this.tokens, super.key});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        width: 10,
        height: 15,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: tokens.colors.gold.withValues(alpha: 0.62),
            width: 0.5,
          ),
        ),
        child: Image.asset(
          'ios_resources/Cards/card-back-icon.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }
}

class CardSlot extends StatelessWidget {
  const CardSlot({
    required this.active,
    required this.human,
    required this.width,
    required this.height,
    required this.tokens,
    required this.language,
    super.key,
  });

  final bool active;
  final bool human;
  final double width;
  final double height;
  final DesignTokens tokens;
  final KolkhozLanguage language;

  @override
  Widget build(BuildContext context) {
    final slotColor = active
        ? human
              ? tokens.colors.gold
              : tokens.colors.red
        : tokens.colors.steel.withValues(alpha: cardSlotInactiveSteelOpacity);
    final fillColor = active
        ? human
              ? tokens.colors.gold.withValues(alpha: cardSlotHumanFillOpacity)
              : tokens.colors.red.withValues(alpha: cardSlotOpponentFillOpacity)
        : Colors.transparent;
    final slot = CustomPaint(
      painter: CardSlotPainter(
        color: slotColor,
        fillColor: fillColor,
        active: active,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: active
              ? PixelText(
                  human
                      ? language.text(en: 'PLAY', ru: 'ХОД')
                      : language.text(en: 'WAIT', ru: 'ЖДИТЕ'),
                  size: PixelTextSize.caption2,
                  variant: PixelTextVariant.heavy,
                  color: human ? tokens.colors.gold : tokens.colors.redBright,
                )
              : null,
        ),
      ),
    );
    if (!active) {
      return slot;
    }
    return PulsingCardSlotFrame(human: human, tokens: tokens, child: slot);
  }
}

class PulsingCardSlotFrame extends StatefulWidget {
  const PulsingCardSlotFrame({
    required this.human,
    required this.tokens,
    required this.child,
    super.key,
  });

  final bool human;
  final DesignTokens tokens;
  final Widget child;

  @override
  State<PulsingCardSlotFrame> createState() => _PulsingCardSlotFrameState();
}

class _PulsingCardSlotFrameState extends State<PulsingCardSlotFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> pulse;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    pulse = CurvedAnimation(parent: controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.human
        ? widget.tokens.colors.gold
        : widget.tokens.colors.red;
    final restOpacity = widget.human
        ? cardSlotHumanShadowRestOpacity
        : cardSlotOpponentShadowRestOpacity;
    final pulseOpacity = widget.human
        ? cardSlotHumanShadowPulseOpacity
        : cardSlotOpponentShadowPulseOpacity;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final value = pulse.value;
        return Transform.scale(
          scale: lerpDouble(1, cardSlotActiveScale, value)!,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cardSlotCornerRadius),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(
                    alpha: lerpDouble(restOpacity, pulseOpacity, value)!,
                  ),
                  blurRadius: lerpDouble(
                    cardSlotShadowRestRadius,
                    cardSlotShadowPulseRadius,
                    value,
                  )!,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

const cardSlotCornerRadius = 8.0;
const cardSlotStrokeWidth = 2.0;
const cardSlotDashLength = 6.0;
const cardSlotDashGap = 6.0;
const cardSlotActiveScale = 1.035;
const cardSlotHumanFillOpacity = 0.10;
const cardSlotOpponentFillOpacity = 0.12;
const cardSlotInactiveSteelOpacity = 0.35;
const cardSlotShadowRestRadius = 10.0;
const cardSlotShadowPulseRadius = 18.0;
const cardSlotHumanShadowRestOpacity = 0.28;
const cardSlotHumanShadowPulseOpacity = 0.58;
const cardSlotOpponentShadowRestOpacity = 0.22;
const cardSlotOpponentShadowPulseOpacity = 0.48;

class CardSlotPainter extends CustomPainter {
  const CardSlotPainter({
    required this.color,
    required this.fillColor,
    required this.active,
  });

  final Color color;
  final Color fillColor;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(cardSlotCornerRadius),
    );
    if (active) {
      canvas.drawRRect(
        rect,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cardSlotStrokeWidth;
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + cardSlotDashLength),
          paint,
        );
        distance += cardSlotDashLength + cardSlotDashGap;
      }
    }
  }

  @override
  bool shouldRepaint(CardSlotPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.active != active;
}

class DashedSlot extends StatelessWidget {
  const DashedSlot({
    required this.width,
    required this.height,
    required this.tokens,
    required this.label,
    super.key,
  });

  final double width;
  final double height;
  final DesignTokens tokens;
  final String label;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DashedSlotPainter(tokens.colors.gold),
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: PixelText(
            label.toUpperCase(),
            size: PixelTextSize.title,
            variant: PixelTextVariant.heavy,
            color: tokens.colors.gold.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class DashedSlotPainter extends CustomPainter {
  const DashedSlotPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const dash = 9.0;
    const gap = 7.0;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedSlotPainter oldDelegate) =>
      oldDelegate.color != color;
}

class TrickCards extends StatelessWidget {
  const TrickCards({required this.trick, required this.tokens, super.key});

  final Trick trick;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (trick.plays.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: tokens.spacing.sm,
      runSpacing: tokens.spacing.sm,
      children: [
        for (final play in trick.plays)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameCard(card: play.card, tokens: tokens, small: true),
              PixelText(
                '${play.seatID + 1}',
                size: PixelTextSize.caption2,
                color: tokens.colors.creamDim,
              ),
            ],
          ),
      ],
    );
  }
}

class InfoPlaque extends StatelessWidget {
  const InfoPlaque({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: EdgeInsets.all(tokens.spacing.md),
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.36)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelText(
            model.table.phasePrompt.title,
            size: PixelTextSize.title,
            variant: PixelTextVariant.heavy,
            color: tokens.colors.gold,
          ),
          SizedBox(height: tokens.spacing.xs),
          PixelText(
            model.table.phasePrompt.body,
            size: PixelTextSize.caption,
            color: tokens.colors.creamDim,
            softWrap: true,
          ),
        ],
      ),
    );
  }
}

class PlanningTrumpPanel extends StatelessWidget {
  const PlanningTrumpPanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.onAction,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final ValueChanged<LegalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final isFamine = model.table.isFamine;
    final trumpOptions = planningTrumpOptions(
      model.legalActions,
      language: language,
    );
    final title = isFamine
        ? language.text(en: 'Famine year', ru: 'Год неурожая')
        : language.text(en: 'Choose Trump', ru: 'Выберите козырь');
    final subtitle = isFamine
        ? language.text(
            en: 'No trump suit is used this year.',
            ru: 'В этом году козырь не используется.',
          )
        : language.text(
            en: 'Pick the trump suit for this year.',
            ru: 'Выберите козырную масть на этот год.',
          );
    const buttonSize = planningTrumpButtonSize;
    const gridSpacing = planningTrumpGridSpacing;
    return PanelStyleSurface(
      tokens: tokens,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: planningPanelContentSpacing,
        children: [
          PanelTitleRow(
            title: title,
            subtitle: subtitle,
            iconPath: isFamine
                ? 'ios_resources/Icons/icon-famine.png'
                : 'ios_resources/Icons/icon-jobs.png',
            urgent: isFamine,
            tokens: tokens,
          ),
          if (isFamine) ...[
            Center(
              child: Opacity(
                opacity: famineBannerOpacity,
                child: Image.asset(
                  'ios_resources/Embellishments/art-famine-banner.png',
                  width: famineBannerWidth,
                  height: famineBannerHeight,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            Text(
              subtitle,
              key: const Key('famine-body-text'),
              softWrap: true,
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.creamDim,
                fontSize: famineBodyFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else
            Center(
              child: SizedBox(
                width: buttonSize * 2 + gridSpacing,
                child: Wrap(
                  spacing: gridSpacing,
                  runSpacing: gridSpacing,
                  children: [
                    for (final option in trumpOptions)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: option.action != null && onAction != null
                            ? () {
                                onAction!(option.action!);
                              }
                            : null,
                        child: TrumpSelectionButton(
                          suit: option.suit,
                          label: option.label,
                          selected: option.suit == model.table.trump,
                          tokens: tokens,
                          size: buttonSize,
                          iconSize: planningTrumpIconSize,
                        ),
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

const planningTrumpButtonSize = 54.0;
const planningTrumpIconSize = 34.0;
const planningTrumpGridSpacing = 8.0;
const planningPanelContentSpacing = 10.0;
const famineBannerWidth = 270.0;
const famineBannerHeight = 68.0;
const famineBannerOpacity = 0.9;
const famineBodyFontSize = 15.0;

class TrumpSelectionButton extends StatelessWidget {
  const TrumpSelectionButton({
    required this.suit,
    required this.label,
    required this.selected,
    required this.tokens,
    this.size = 54,
    this.iconSize = 34,
    super.key,
  });

  final String suit;
  final String label;
  final bool selected;
  final DesignTokens tokens;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scale = size / 54;
    return Tooltip(
      message: label,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: selected
                    ? tokens.colors.red.withValues(alpha: 0.38)
                    : tokens.colors.gold.withValues(alpha: 0.16),
                blurRadius: (selected ? 8 : 4) * scale,
                offset: Offset(0, 3 * scale),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  selected
                      ? 'ios_resources/ui-nav-button-active-current.png'
                      : 'ios_resources/ui-nav-button-inactive-current.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: selected ? 2 * scale : 0),
                child: Image.asset(
                  'ios_resources/Icons/icon-trump-$suit.png',
                  width: iconSize,
                  height: iconSize,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, _, _) =>
                      SuitMark(suit: suit, tokens: tokens, size: 28 * scale),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameOverPanel extends StatelessWidget {
  const GameOverPanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.onNewGame,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback? onNewGame;

  @override
  Widget build(BuildContext context) {
    final scores = model.table.gameResult?.scores ?? model.table.scoreboard;
    final winnerID =
        model.table.gameResult?.winnerSeatID ?? inferredWinnerID(scores);
    return PanelStyleSurface(
      tokens: tokens,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: gameOverPanelRowSpacing,
        children: [
          PanelTitleRow(
            title: language.text(en: 'Game Over!', ru: 'Игра окончена!'),
            subtitle: language.text(
              en: 'Final cellar and medal scores.',
              ru: 'Итоговые очки участка и медалей.',
            ),
            iconPath: 'ios_resources/Icons/icon-medal-star.png',
            tokens: tokens,
          ),
          for (final seat in model.table.seats)
            GameOverScoreRow(
              seat: seat,
              score: finalScoreForSeat(scores, seat.id),
              winner: seat.id == winnerID,
              tokens: tokens,
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: gameOverNewGameTopPadding),
              child: ActionSurfaceButton(
                label: language.text(en: 'New game', ru: 'Новая игра'),
                iconPath: null,
                prominent: true,
                tokens: tokens,
                onPressed: onNewGame,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GameOverScoreRow extends StatelessWidget {
  const GameOverScoreRow({
    required this.seat,
    required this.score,
    required this.winner,
    required this.tokens,
    super.key,
  });

  final Seat seat;
  final int score;
  final bool winner;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: gameOverRowVerticalPadding),
      child: Row(
        spacing: gameOverRowSpacing,
        children: [
          PlayerPortrait(
            seat: seat,
            tokens: tokens,
            width: gameOverPortraitWidth,
            height: gameOverPortraitHeight,
          ),
          Expanded(
            child: Row(
              spacing: gameOverNameIconSpacing,
              children: [
                Flexible(
                  child: PixelText(
                    seat.name,
                    size: PixelTextSize.title,
                    variant: winner
                        ? PixelTextVariant.heavy
                        : PixelTextVariant.regular,
                    color: winner ? tokens.colors.gold : tokens.colors.cream,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (winner)
                  Image.asset(
                    'ios_resources/Icons/icon-medal-star.png',
                    width: gameOverWinnerIconSize,
                    height: gameOverWinnerIconSize,
                    filterQuality: FilterQuality.none,
                  ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: gameOverScoreMinWidth),
            child: Align(
              alignment: Alignment.centerRight,
              child: PixelText(
                '$score',
                size: PixelTextSize.title,
                variant: PixelTextVariant.heavy,
                color: winner ? tokens.colors.gold : tokens.colors.cream,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const gameOverPanelRowSpacing = 1.0;
const gameOverNewGameTopPadding = 0.0;
const gameOverRowVerticalPadding = 1.0;
const gameOverRowSpacing = 10.0;
const gameOverNameIconSpacing = 2.0;
const gameOverPortraitWidth = 38.0;
const gameOverPortraitHeight = 42.0;
const gameOverWinnerIconSize = 32.0;
const gameOverScoreMinWidth = 28.0;

class PhasePromptLine extends StatelessWidget {
  const PhasePromptLine({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return PixelText(
      model.table.phasePrompt.title,
      size: PixelTextSize.title,
      variant: PixelTextVariant.heavy,
      color: tokens.colors.gold,
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
        ? tokens.colors.green
        : card.highlighted
        ? highlightColor
        : null;
    final highlightBorderWidth = card.selected
        ? tokens.stroke.active
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
                cardTemplateAssetPathForTokens(tokens),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(size.faceInset),
            child: Stack(
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
                  left: size.width * 0.03,
                  top: size.height * 0.03,
                  child: CardCornerIndex(
                    card: card,
                    size: size,
                    tokens: tokens,
                    placement: CardCornerPlacement.top,
                    trump: trump,
                  ),
                ),
                Positioned(
                  right: size.width * 0.02,
                  bottom: -(size.height * 0.03),
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
    final top = placement == CardCornerPlacement.top;
    final spacing = top
        ? size.topCornerRankSuitSpacing
        : size.bottomCornerRankSuitSpacing;
    final frameHeight = size.cornerHeight + size.cornerSuitSize + 2;
    final contentHeight = size.cornerHeight + size.cornerSuitSize + spacing;
    final bottomContentTop = frameHeight - contentHeight;
    final rank = SizedBox(
      width: size.cornerWidth,
      height: size.cornerHeight,
      child: Align(
        alignment: top ? Alignment.centerLeft : Alignment.centerRight,
        child: PixelText(
          card.rank,
          size: pixelTextSizeForCardRank(size),
          variant: PixelTextVariant.heavy,
          color: card.suit == trump ? tokens.colors.red : tokens.colors.cream,
          textAlign: top ? TextAlign.start : TextAlign.end,
        ),
      ),
    );
    final suit = Transform.translate(
      offset: Offset(
        top ? size.topCornerSuitXOffset : size.bottomCornerSuitXOffset,
        0,
      ),
      child: SuitMark(
        suit: card.suit,
        tokens: tokens,
        size: size.cornerSuitSize,
      ),
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
                  top: size.cornerHeight + spacing,
                  child: SizedBox(
                    width: size.cornerSuitSize,
                    height: size.cornerSuitSize,
                    child: suit,
                  ),
                ),
              ]
            : [
                Positioned(
                  right: 0,
                  top: bottomContentTop,
                  child: SizedBox(
                    width: size.cornerSuitSize,
                    height: size.cornerSuitSize,
                    child: suit,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: bottomContentTop + size.cornerSuitSize + spacing,
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
    if (size.width <= tokens.card.small.width + 0.1) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            SuitMark(suit: card.suit, tokens: tokens, size: 14),
            PixelText(
              card.rank,
              size: PixelTextSize.caption2,
              variant: PixelTextVariant.heavy,
              color: card.suit == trump
                  ? tokens.colors.red
                  : tokens.colors.cream,
            ),
          ],
        ),
      );
    }

    if (card.value >= 11) {
      return Center(
        child: SizedBox(
          width: faceArtWidth(size),
          height: faceArtWidth(size) * 1.5,
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
                        card.rank,
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
          final fillWidth = clampDouble(
            constraints.maxWidth * clampedValue / 2,
            4.0,
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

class MiniCard extends StatelessWidget {
  const MiniCard({
    required this.card,
    required this.tokens,
    this.emptySuit,
    super.key,
  });

  final TableCard? card;
  final DesignTokens tokens;
  final String? emptySuit;

  @override
  Widget build(BuildContext context) {
    final visibleCard = card;
    if (visibleCard != null) {
      return GameCard(
        card: visibleCard,
        tokens: tokens,
        sizeOverride: tokens.card.small,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(cardTemplateAssetPathForTokens(tokens)),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
        ),
        borderRadius: BorderRadius.circular(cardViewCornerRadius),
        border: Border.all(color: tokens.colors.green.withValues(alpha: 0.7)),
      ),
      child: SizedBox(
        width: tokens.card.small.width,
        height: tokens.card.small.height,
        child: Center(
          child: SuitMark(
            suit: emptySuit ?? 'wheat',
            tokens: tokens,
            size: tokens.card.small.cornerSuitSize * 2,
          ),
        ),
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
    final shadowColor = suitMarkDisplayColor(
      suit,
      tokens,
    ).withValues(alpha: size > suitMarkShadowSizeThreshold ? 0.34 : 0);
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: size > suitMarkShadowSizeThreshold ? 3 : 0,
          ),
        ],
      ),
      child: Image.asset(
        'ios_resources/Icons/icon-$suit.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) =>
            SuitDot(suit: suit, tokens: tokens, size: size),
      ),
    );
  }
}

const suitMarkShadowSizeThreshold = 17.0;
