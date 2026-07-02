import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';

import 'contracts.dart';
import 'design_tokens.dart';
import 'fixture_repository.dart';

class FixtureRendererApp extends StatelessWidget {
  const FixtureRendererApp({required this.repository, super.key});

  final FixtureRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kolkhoz Fixture Renderer',
      theme: ThemeData(
        fontFamily: 'Handjet',
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Handjet'),
      ),
      home: FutureBuilder<FixtureBundle>(
        future: repository.load(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error!);
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return FixtureHome(bundle: snapshot.data!);
        },
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Fixture load failed: $error')));
  }
}

class FixtureHome extends StatefulWidget {
  const FixtureHome({required this.bundle, super.key});

  final FixtureBundle bundle;

  @override
  State<FixtureHome> createState() => _FixtureHomeState();
}

class _FixtureHomeState extends State<FixtureHome> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.bundle.tokens;
    final fixture = widget.bundle.fixtures[selectedIndex];
    return Scaffold(
      backgroundColor: tokens.colors.table,
      body: Stack(
        children: [
          Positioned.fill(
            child: FixtureBoard(fixture: fixture, tokens: tokens),
          ),
          Positioned(
            top: tokens.spacing.md,
            right: tokens.spacing.md,
            child: FixtureHeader(
              fixtures: widget.bundle.fixtures,
              selectedIndex: selectedIndex,
              tokens: tokens,
              onSelected: (index) => setState(() => selectedIndex = index),
            ),
          ),
        ],
      ),
    );
  }
}

class FixtureHeader extends StatelessWidget {
  const FixtureHeader({
    required this.fixtures,
    required this.selectedIndex,
    required this.tokens,
    required this.onSelected,
    super.key,
  });

  final List<NamedFixture> fixtures;
  final int selectedIndex;
  final DesignTokens tokens;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.md,
          vertical: tokens.spacing.sm,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.xs,
          children: [
            Text(
              'Kolkhoz fixtures',
              style: TextStyle(
                color: tokens.colors.gold,
                fontSize: tokens.typography.size('caption', 13),
                fontWeight: FontWeight.w800,
              ),
            ),
            for (var index = 0; index < fixtures.length; index++)
              ChoiceChip(
                label: Text(fixtures[index].name),
                selected: selectedIndex == index,
                onSelected: (_) => onSelected(index),
                selectedColor: tokens.colors.gold,
                backgroundColor: tokens.colors.panel,
                labelStyle: TextStyle(
                  color: selectedIndex == index
                      ? tokens.colors.cardInk
                      : tokens.colors.cream,
                  fontWeight: FontWeight.w700,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ),
    );
  }
}

class FixtureBoard extends StatelessWidget {
  const FixtureBoard({required this.fixture, required this.tokens, super.key});

  final NamedFixture fixture;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final model = fixture.model;
    return LayoutBuilder(
      builder: (context, constraints) {
        final shorterSide = constraints.biggest.shortestSide;
        final margin = clampDouble(
          shorterSide * 0.01,
          tokens.spacing.boardOuterMarginMin,
          tokens.spacing.boardOuterMarginMax,
        );
        final contentWidth = constraints.maxWidth - margin * 2;
        final contentHeight = constraints.maxHeight - margin * 2;
        final railWidth = clampDouble(
          contentWidth * tokens.layout.board.railWidthFactor,
          tokens.layout.board.railWidthMin,
          tokens.layout.board.railWidthMax,
        );
        final separatorWidth = tokens.layout.board.railSeparatorWidth;
        final gameWidth = contentWidth - railWidth - separatorWidth;

        return Container(
          color: tokens.colors.table,
          padding: EdgeInsets.all(margin),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: railWidth,
                child: BoardRail(
                  activePanel: model.panels.active,
                  actionPanel: actionPanelFor(model.table.phase),
                  tokens: tokens,
                ),
              ),
              BoardSeparator(tokens: tokens, vertical: true),
              SizedBox(
                width: gameWidth,
                height: contentHeight,
                child: BoardPlayArea(model: model, tokens: tokens),
              ),
            ],
          ),
        );
      },
    );
  }
}

String actionPanelFor(String phase) {
  switch (phase) {
    case 'assignment':
      return 'jobs';
    case 'swap':
    case 'requisition':
      return 'plot';
    default:
      return 'brigade';
  }
}

class BoardPlayArea extends StatelessWidget {
  const BoardPlayArea({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
      child: Column(
        children: [
          TopInfoStrip(model: model, tokens: tokens),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.colors.table,
                gradient: LinearGradient(
                  colors: [
                    tokens.colors.gold.withValues(alpha: 0.04),
                    tokens.colors.table,
                    tokens.colors.red.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(tokens.radius.panelOuter),
              ),
              child: Column(
                children: [
                  BoardSeparator(tokens: tokens),
                  Expanded(
                    child: ActivePanelView(model: model, tokens: tokens),
                  ),
                  BoardSeparator(tokens: tokens),
                ],
              ),
            ),
          ),
          SizedBox(
            height: tokens.card.large.height + 20,
            child: HandTray(model: model, tokens: tokens),
          ),
        ],
      ),
    );
  }
}

class BoardRail extends StatelessWidget {
  const BoardRail({
    required this.activePanel,
    required this.actionPanel,
    required this.tokens,
    super.key,
  });

  final String activePanel;
  final String actionPanel;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.colors.table,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Column(
        spacing: 6,
        children: [
          RailButton(
            asset: 'icon-panel-menu.png',
            active: activePanel == 'options',
            action: false,
            label: 'Menu',
            tokens: tokens,
          ),
          RailButton(
            asset: 'icon-panel-brigade.png',
            active: activePanel == 'brigade',
            action: actionPanel == 'brigade',
            label: 'Brigade',
            tokens: tokens,
          ),
          RailButton(
            asset: 'icon-panel-jobs.png',
            active: activePanel == 'jobs',
            action: actionPanel == 'jobs',
            label: 'Jobs',
            tokens: tokens,
          ),
          RailButton(
            asset: 'icon-panel-north.png',
            active: activePanel == 'north',
            action: actionPanel == 'north',
            label: 'North',
            tokens: tokens,
          ),
          RailButton(
            asset: 'icon-panel-plot.png',
            active: activePanel == 'plot',
            action: actionPanel == 'plot',
            label: 'Plot',
            tokens: tokens,
          ),
          RailButton(
            asset: 'icon-language.png',
            active: false,
            action: false,
            label: 'Language',
            tokens: tokens,
          ),
          RailButton(
            asset: 'icon-appearance.png',
            active: false,
            action: false,
            label: 'Appearance',
            tokens: tokens,
          ),
        ],
      ),
    );
  }
}

class RailButton extends StatelessWidget {
  const RailButton({
    required this.asset,
    required this.active,
    required this.action,
    required this.label,
    required this.tokens,
    super.key,
  });

  final String asset;
  final bool active;
  final bool action;
  final String label;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 42,
        height: 42,
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              if (active)
                BoxShadow(
                  color: tokens.colors.red.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'ios_resources/$backgroundAsset',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: action ? 2 : 0),
                child: Opacity(
                  opacity: active ? 1 : 0.82,
                  child: Image.asset(
                    'ios_resources/Icons/$asset',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.crop_square,
                      size: 28,
                      color: active
                          ? tokens.colors.cream
                          : tokens.colors.creamDim,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get backgroundAsset {
    return switch ((active, action)) {
      (true, true) => 'ui-nav-button-active-current.png',
      (false, true) => 'ui-nav-button-inactive-current.png',
      (true, false) => 'ui-nav-button-active.png',
      (false, false) => 'ui-nav-button-inactive.png',
    };
  }
}

class BoardSeparator extends StatelessWidget {
  const BoardSeparator({
    required this.tokens,
    this.vertical = false,
    super.key,
  });

  final DesignTokens tokens;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: vertical ? tokens.layout.board.railSeparatorWidth : null,
      height: vertical ? null : tokens.layout.board.playAreaSeparatorThickness,
      decoration: BoxDecoration(
        color: tokens.colors.gold,
        image: DecorationImage(
          image: AssetImage(
            vertical
                ? 'ios_resources/ui-left-rail-separator-tile.png'
                : 'ios_resources/ui-play-area-separator-horizontal-tile.png',
          ),
          repeat: ImageRepeat.repeat,
          filterQuality: FilterQuality.none,
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.colors.black.withValues(alpha: 0.5),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }
}

class TopInfoStrip extends StatelessWidget {
  const TopInfoStrip({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final viewer = viewerSeat(model);
    final cellarScore = viewer.plot.hiddenCount;
    final plotScore = viewer.plot.revealed.fold<int>(
      0,
      (score, card) => score + card.value,
    );
    final topInfo = tokens.layout.topInfo;
    return SizedBox(
      height: topInfo.height,
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
              gaugeFrameWidth * model.table.jobs.length +
              gaugeSpacing * (model.table.jobs.length - 1);
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
                  child: SizedBox(
                    width: gaugesWidth,
                    child: Row(
                      spacing: gaugeSpacing,
                      children: [
                        for (final job in model.table.jobs)
                          SizedBox(
                            width: gaugeFrameWidth,
                            child: Center(
                              child: JobGauge(
                                job: job,
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
    this.iconSize = 24,
    this.contentSpacing = 5,
    super.key,
  });

  final String icon;
  final String value;
  final DesignTokens tokens;
  final double iconSize;
  final double contentSpacing;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: contentSpacing,
          children: [
            Image.asset(
              'ios_resources/Icons/$icon',
              width: iconSize,
              height: iconSize,
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: TextStyle(
                  color: tokens.colors.gold,
                  fontSize: tokens.card.large.cornerRankFontSize,
                  fontWeight: FontWeight.w900,
                  height: 0.9,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class JobGauge extends StatelessWidget {
  const JobGauge({
    required this.job,
    required this.width,
    required this.height,
    required this.tokens,
    super.key,
  });

  final Job job;
  final double width;
  final double height;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final highlighted = job.highlighted || job.validAssignmentTarget;
    final markerWidth =
        height * tokens.layout.topInfo.rewardMarkerHeightMultiplier;
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
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radius.sm),
            border: Border.all(
              color: highlighted
                  ? tokens.colors.gold.withValues(alpha: 0.72)
                  : Colors.transparent,
              width: highlighted ? tokens.stroke.emphasis : 0,
            ),
          ),
          child: Row(
            spacing: tokens.spacing.xs,
            children: [
              SizedBox(
                width: markerWidth,
                height: height,
                child: Center(
                  child: job.reward == null
                      ? EmptyRewardMarker(
                          suit: job.suit,
                          size: height * 0.62,
                          tokens: tokens,
                        )
                      : MiniRewardCard(
                          card: job.reward!,
                          claimed: job.claimed,
                          height: height,
                          tokens: tokens,
                        ),
                ),
              ),
              Expanded(
                child: job.claimed
                    ? Image.asset(
                        'ios_resources/Icons/icon-check.png',
                        width:
                            height *
                            tokens.layout.topInfo.checkIconHeightMultiplier,
                        height:
                            height *
                            tokens.layout.topInfo.checkIconHeightMultiplier,
                      )
                    : Text(
                        '${job.hours}/${job.requiredHours}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: highlighted
                              ? tokens.colors.red
                              : tokens.colors.smoke,
                          fontSize: tokens.typography.size('title', 28),
                          fontWeight: FontWeight.w700,
                          height: 0.9,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActivePanelView extends StatelessWidget {
  const ActivePanelView({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    switch (model.panels.active) {
      case 'jobs':
        return JobsPanel(model: model, tokens: tokens);
      case 'plot':
        return PlotPanel(model: model, tokens: tokens);
      default:
        return BrigadePanel(model: model, tokens: tokens);
    }
  }
}

class BrigadePanel extends StatelessWidget {
  const BrigadePanel({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final seats = model.table.seats;
    final trick = model.table.lastTrick.plays.isNotEmpty
        ? model.table.lastTrick
        : model.table.trick;
    return LayoutBuilder(
      builder: (context, constraints) {
        final playerOrder = orderedSeats(seats);
        const columnSpacingFill = 0.72;
        final columnCount = playerOrder.length.toDouble();
        final playerPanelWidth = tokens.card.medium.width * 1.6;
        final preferredColumnWidth = clampDouble(
          constraints.maxWidth * 0.18,
          96,
          120,
        );
        final columnWidth = playerPanelWidth > preferredColumnWidth
            ? playerPanelWidth
            : preferredColumnWidth;
        final totalColumnWidth = columnWidth * columnCount;
        final availableSpacing = (constraints.maxWidth - totalColumnWidth)
            .clamp(0, double.infinity);
        final spacing = columnCount <= 1
            ? 0.0
            : (availableSpacing / (columnCount - 1)) * columnSpacingFill;
        final rowWidth = totalColumnWidth + spacing * (columnCount - 1);

        return Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: rowWidth,
                height: constraints.maxHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < playerOrder.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          right: index == playerOrder.length - 1 ? 0 : spacing,
                        ),
                        child: BrigadePlayerColumn(
                          seat: playerOrder[index],
                          play: trick.playForSeat(playerOrder[index].id),
                          columnWidth: columnWidth,
                          phase: model.table.phase,
                          tokens: tokens,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (model.table.phase == 'planning')
              Align(
                alignment: Alignment.center,
                child: PlanningTrumpPanel(model: model, tokens: tokens),
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
    required this.phase,
    required this.tokens,
    super.key,
  });

  final Seat seat;
  final TrickPlay? play;
  final double columnWidth;
  final String phase;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final cardSize = tokens.card.medium;
    final maxTricksForYear = 4;
    final slotWidth = clampDouble(columnWidth * 0.52, 44, 76);
    const playAreaScale = 1.8;
    final playAreaLeftOffset = clampDouble(columnWidth * 0.06, 30, 54);
    final playAreaTopOffset = clampDouble(columnWidth * 0.15, 18, 24);
    final playerPanelWidth = cardSize.width * playAreaScale;
    final playAreaWidth =
        (cardSize.width > slotWidth ? cardSize.width : slotWidth) *
        playAreaScale;
    final playAreaHeight =
        (cardSize.height > slotWidth * 1.2
            ? cardSize.height
            : slotWidth * 1.2) *
        playAreaScale;

    return SizedBox(
      width: columnWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: playerPanelWidth,
            height: 40,
            child: PlayerBadge(
              seat: seat,
              tokens: tokens,
              width: playerPanelWidth,
              maxTricks: maxTricksForYear,
            ),
          ),
          Transform.translate(
            offset: Offset(
              playAreaLeftOffset,
              -clampDouble(columnWidth * 0.055, 2, 6),
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
                            active: phase == 'trick' && seat.isCurrentTurn,
                            human: seat.isViewer,
                            width: slotWidth,
                            height: slotWidth * 1.4,
                            tokens: tokens,
                          )
                        : GameCard(
                            card: play!.card,
                            tokens: tokens,
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

class PlotPanel extends StatelessWidget {
  const PlotPanel({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final viewer = model.table.seats.firstWhere(
      (seat) => seat.isViewer,
      orElse: () => model.table.seats.first,
    );
    final opponents = model.table.seats
        .where((seat) => seat.id != viewer.id)
        .toList(growable: false);
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = PlotPanelMetrics.fromSize(
            constraints.biggest,
            tokens,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 54,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PhasePromptLine(model: model, tokens: tokens),
                    ),
                    if (model.viewer.isOnline) ...[
                      SizedBox(width: metrics.spacing),
                      OnlineStatusPill(model: model, tokens: tokens),
                    ],
                  ],
                ),
              ),
              SizedBox(height: metrics.spacing),
              SizedBox(
                height: metrics.opponentHeight,
                child: Row(
                  spacing: metrics.spacing,
                  children: [
                    for (final seat in opponents)
                      Expanded(
                        child: OpponentPlotPanel(
                          seat: seat,
                          metrics: metrics,
                          tokens: tokens,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: metrics.spacing),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: metrics.spacing,
                  children: [
                    Expanded(
                      child: LocalPlotColumn(
                        title: 'Cellar',
                        iconPath: 'ios_resources/Icons/icon-cellar.png',
                        cards: viewer.plot.hidden,
                        hiddenCount: viewer.plot.hiddenCount,
                        hidden: true,
                        metrics: metrics,
                        tokens: tokens,
                      ),
                    ),
                    Expanded(
                      child: LocalPlotColumn(
                        title: 'Plot',
                        iconPath: 'ios_resources/Icons/icon-plot.png',
                        cards: viewer.plot.revealed,
                        hiddenCount: viewer.plot.revealed.length,
                        hidden: false,
                        metrics: metrics,
                        tokens: tokens,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PlotPanelMetrics {
  const PlotPanelMetrics({
    required this.spacing,
    required this.padding,
    required this.opponentHeight,
    required this.opponentCardScale,
    required this.opponentCardFrameWidth,
    required this.opponentCardFrameHeight,
    required this.opponentVisibleCardCount,
    required this.portraitSize,
    required this.panelPadding,
    required this.headerIconSize,
    required this.columnCardSpacing,
    required this.columnTrailingPadding,
  });

  factory PlotPanelMetrics.fromSize(Size size, DesignTokens tokens) {
    final shorter = size.shortestSide;
    final plot = tokens.layout.plot;
    return PlotPanelMetrics(
      spacing: clampDouble(shorter * 0.02, 7, 10),
      padding: clampDouble(shorter * 0.025, 8, 12),
      opponentHeight: clampDouble(
        size.height * 0.18,
        plot.opponentHeightMin,
        plot.opponentHeightMax,
      ),
      opponentCardScale: clampDouble(size.width * 0.001, 0.68, 0.76),
      opponentCardFrameWidth: clampDouble(size.width * 0.04, 25, 29),
      opponentCardFrameHeight: clampDouble(size.height * 0.10, 38, 44),
      opponentVisibleCardCount: clampDouble(
        size.width / 190,
        plot.opponentVisibleCardCountMin,
        plot.opponentVisibleCardCountMax,
      ).round(),
      portraitSize: clampDouble(
        size.width * 0.055,
        plot.portraitSizeMin,
        plot.portraitSizeMax,
      ),
      panelPadding: clampDouble(shorter * 0.018, 7, 8),
      headerIconSize: clampDouble(size.width * 0.026, 17, 20),
      columnCardSpacing: clampDouble(-size.width * 0.04, -30, -24),
      columnTrailingPadding: clampDouble(size.width * 0.035, 20, 28),
    );
  }

  final double spacing;
  final double padding;
  final double opponentHeight;
  final double opponentCardScale;
  final double opponentCardFrameWidth;
  final double opponentCardFrameHeight;
  final int opponentVisibleCardCount;
  final double portraitSize;
  final double panelPadding;
  final double headerIconSize;
  final double columnCardSpacing;
  final double columnTrailingPadding;
}

class OnlineStatusPill extends StatelessWidget {
  const OnlineStatusPill({
    required this.model,
    required this.tokens,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        border: Border.all(color: tokens.colors.green.withValues(alpha: 0.62)),
      ),
      child: Text(
        'Online: ${model.viewer.isOnline ? model.viewer.connection : 'offline'}',
        style: TextStyle(
          color: tokens.colors.creamDim,
          fontSize: tokens.typography.size('caption', 13),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class OpponentPlotPanel extends StatelessWidget {
  const OpponentPlotPanel({
    required this.seat,
    required this.metrics,
    required this.tokens,
    super.key,
  });

  final Seat seat;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(metrics.panelPadding),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: metrics.spacing * 0.75,
        children: [
          SizedBox(
            width: metrics.portraitSize + 12,
            child: Column(
              spacing: 3,
              children: [
                Image.asset(
                  seat.isViewer
                      ? 'ios_resources/Icons/icon-human-seat.png'
                      : 'ios_resources/Icons/icon-basic-ai.png',
                  width: metrics.portraitSize,
                  height: metrics.portraitSize,
                  fit: BoxFit.contain,
                ),
                Text(
                  seat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.colors.cream,
                    fontSize: tokens.typography.size('caption2', 11),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              spacing: metrics.spacing * 0.5,
              children: [
                Expanded(
                  child: OpponentPlotMiniSection(
                    iconPath: 'ios_resources/Icons/icon-cellar.png',
                    value: '${seat.plot.hiddenCount}',
                    cards: seat.plot.hidden,
                    hiddenCount: seat.plot.hiddenCount,
                    hidden: true,
                    metrics: metrics,
                    tokens: tokens,
                  ),
                ),
                Expanded(
                  child: OpponentPlotMiniSection(
                    iconPath: 'ios_resources/Icons/icon-plot.png',
                    value: '${seat.visibleScore}',
                    cards: seat.plot.revealed,
                    hiddenCount: seat.plot.revealed.length,
                    hidden: false,
                    metrics: metrics,
                    tokens: tokens,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OpponentPlotMiniSection extends StatelessWidget {
  const OpponentPlotMiniSection({
    required this.iconPath,
    required this.value,
    required this.cards,
    required this.hiddenCount,
    required this.hidden,
    required this.metrics,
    required this.tokens,
    super.key,
  });

  final String iconPath;
  final String value;
  final List<ContractCard> cards;
  final int hiddenCount;
  final bool hidden;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final cardWidgets = <Widget>[
      for (final card in cards.take(metrics.opponentVisibleCardCount))
        SizedBox(
          width: metrics.opponentCardFrameWidth,
          height: metrics.opponentCardFrameHeight,
          child: Transform.scale(
            alignment: Alignment.topLeft,
            scale: metrics.opponentCardScale,
            child: hidden
                ? CardBackMini(tokens: tokens)
                : GameCard(card: card, tokens: tokens, small: true),
          ),
        ),
      for (
        var index = cards.length;
        index < hiddenCount && index < metrics.opponentVisibleCardCount;
        index++
      )
        SizedBox(
          width: metrics.opponentCardFrameWidth,
          height: metrics.opponentCardFrameHeight,
          child: Transform.scale(
            alignment: Alignment.topLeft,
            scale: metrics.opponentCardScale,
            child: CardBackMini(tokens: tokens),
          ),
        ),
      if (cards.isEmpty && hiddenCount == 0)
        SizedBox(
          width: metrics.opponentCardFrameWidth,
          height: metrics.opponentCardFrameHeight,
          child: Center(
            child: Text(
              '-',
              style: TextStyle(
                color: tokens.colors.smoke.withValues(alpha: 0.72),
                fontSize: tokens.typography.size('caption', 13),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tokens.radius.xs),
      ),
      child: Row(
        spacing: 3,
        children: [
          SizedBox(
            width: metrics.headerIconSize + 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 1,
              children: [
                Image.asset(
                  iconPath,
                  width: metrics.headerIconSize,
                  height: metrics.headerIconSize,
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: tokens.colors.gold,
                    fontSize: tokens.typography.size('caption2', 11),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRect(
              child: OverlappedCardRow(
                itemWidth: metrics.opponentCardFrameWidth,
                itemHeight: metrics.opponentCardFrameHeight,
                spacing: metrics.columnCardSpacing * 0.56,
                children: cardWidgets,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LocalPlotColumn extends StatelessWidget {
  const LocalPlotColumn({
    required this.title,
    required this.iconPath,
    required this.cards,
    required this.hiddenCount,
    required this.hidden,
    required this.metrics,
    required this.tokens,
    super.key,
  });

  final String title;
  final String iconPath;
  final List<ContractCard> cards;
  final int hiddenCount;
  final bool hidden;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final missingBacks = hiddenCount > cards.length
        ? hiddenCount - cards.length
        : 0;
    final cardWidgets = <Widget>[
      for (final card in cards)
        hidden
            ? HighlightableCardBack(card: card, tokens: tokens)
            : GameCard(card: card, tokens: tokens, small: true),
      for (var index = 0; index < missingBacks; index++)
        CardBackMini(tokens: tokens),
      if (cards.isEmpty && missingBacks == 0)
        SizedBox(
          width: tokens.card.small.width,
          height: tokens.card.small.height,
          child: Center(
            child: Text(
              '-',
              style: TextStyle(
                color: tokens.colors.smoke.withValues(alpha: 0.72),
                fontSize: tokens.typography.size('title', 32),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
    ];

    return Container(
      padding: EdgeInsets.all(metrics.padding),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: metrics.spacing * 0.75,
        children: [
          Row(
            spacing: 5,
            children: [
              Image.asset(
                iconPath,
                width: metrics.headerIconSize,
                height: metrics.headerIconSize,
              ),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: tokens.colors.gold,
                  fontSize: tokens.typography.size('caption', 13),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '$hiddenCount',
                style: TextStyle(
                  color: tokens.colors.smoke,
                  fontSize: tokens.typography.size('caption2', 11),
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: EdgeInsets.only(
                  top: 2,
                  bottom: 2,
                  right: metrics.columnTrailingPadding,
                ),
                child: OverlappedCardRow(
                  itemWidth: tokens.card.small.width,
                  itemHeight: tokens.card.small.height,
                  spacing: metrics.columnCardSpacing,
                  children: cardWidgets,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OverlappedCardRow extends StatelessWidget {
  const OverlappedCardRow({
    required this.children,
    required this.itemWidth,
    required this.itemHeight,
    required this.spacing,
    super.key,
  });

  final List<Widget> children;
  final double itemWidth;
  final double itemHeight;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final step = itemWidth + spacing > 1 ? itemWidth + spacing : 1.0;
    final width = children.isEmpty
        ? 0.0
        : itemWidth + step * (children.length - 1);
    return SizedBox(
      width: width,
      height: itemHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (index, child) in children.indexed)
            Positioned(left: index * step, top: 0, child: child),
        ],
      ),
    );
  }
}

class HighlightableCardBack extends StatelessWidget {
  const HighlightableCardBack({
    required this.card,
    required this.tokens,
    super.key,
  });

  final ContractCard card;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final border = card.selected
        ? tokens.colors.green
        : card.highlighted
        ? tokens.colors.gold
        : Colors.transparent;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(
          color: border,
          width: card.selected || card.highlighted ? tokens.stroke.active : 0,
        ),
      ),
      child: CardBackMini(tokens: tokens),
    );
  }
}

class CardBackMini extends StatelessWidget {
  const CardBackMini({required this.tokens, super.key});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tokens.card.small.width,
      height: tokens.card.small.height,
      decoration: BoxDecoration(
        color: tokens.colors.panel,
        image: const DecorationImage(
          image: AssetImage('ios_resources/Cards/card-back.png'),
          fit: BoxFit.fill,
        ),
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.colors.iron),
      ),
    );
  }
}

class PlayerBadge extends StatelessWidget {
  const PlayerBadge({
    required this.seat,
    required this.tokens,
    this.width = 178,
    this.maxTricks = 4,
    super.key,
  });

  final Seat seat;
  final DesignTokens tokens;
  final double width;
  final int maxTricks;

  @override
  Widget build(BuildContext context) {
    final active = seat.isCurrentTurn;
    final human = seat.isViewer;
    return SizedBox(
      width: width,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: active
                  ? tokens.colors.gold.withValues(alpha: 0.24)
                  : tokens.colors.black.withValues(alpha: 0.24),
              blurRadius: active ? 8 : 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
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
                      width: clampDouble(width * 0.28, 34, 40),
                      child: Transform.translate(
                        offset: const Offset(-2, 2),
                        child: Image.asset(
                          human
                              ? 'ios_resources/Icons/icon-human-seat.png'
                              : 'ios_resources/Icons/icon-basic-ai.png',
                          width: 34,
                          height: 34,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(0, -2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 0,
                          children: [
                            Row(
                              spacing: 3,
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: active
                                          ? tokens.colors.gold
                                          : tokens.colors.cardInk,
                                      fontSize: tokens.typography.size(
                                        'caption',
                                        13,
                                      ),
                                      fontWeight: FontWeight.w900,
                                      height: 0.9,
                                    ),
                                  ),
                                ),
                                PlayerPlotScoreStat(
                                  score: seat.visibleScore,
                                  tokens: tokens,
                                ),
                              ],
                            ),
                            Row(
                              spacing: 0,
                              children: [
                                PlayerMedalStat(
                                  medals: seat.medals,
                                  maxTricks: maxTricks,
                                  tokens: tokens,
                                ),
                                const Spacer(),
                                PlayerCellarStat(
                                  count: seat.plot.hiddenCount,
                                  tokens: tokens,
                                ),
                              ],
                            ),
                          ],
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
                            ? tokens.colors.red.withValues(alpha: 0.42)
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
    if (seat.isViewer) {
      return 'You';
    }
    final firstName = seat.name.split(' ').first;
    return firstName.length > 6 ? '${firstName.substring(0, 6)}.' : firstName;
  }

  List<String> get statusBadgeAssets {
    return [
      if (seat.isCurrentTurn)
        seat.isViewer
            ? 'icon-status-current-turn.png'
            : 'icon-status-ai-thinking.png',
      if (seat.isBrigadeLeader) 'icon-status-brigade-leader.png',
      if (seat.isProtected) 'icon-status-protected.png',
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
                child: Image.asset(
                  'ios_resources/Icons/$asset',
                  width: 14,
                  height: 14,
                  filterQuality: FilterQuality.none,
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
    super.key,
  });

  final int score;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Row(
        spacing: 2,
        children: [
          Image.asset(
            'ios_resources/Icons/icon-plot.png',
            width: 12,
            height: 12,
            filterQuality: FilterQuality.none,
          ),
          Text(
            '$score',
            style: TextStyle(
              color: tokens.colors.smoke,
              fontSize: tokens.typography.size('headline', 17),
              fontWeight: FontWeight.w900,
              height: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerMedalStat extends StatelessWidget {
  const PlayerMedalStat({
    required this.medals,
    required this.maxTricks,
    required this.tokens,
    super.key,
  });

  final int medals;
  final int maxTricks;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 10,
      child: Stack(
        children: [
          for (var index = 0; index < maxTricks; index++)
            Positioned(
              left: index * 6,
              top: 0,
              child: Opacity(
                opacity: index < medals ? 1 : 0.18,
                child: Image.asset(
                  'ios_resources/Icons/icon-medal-star.png',
                  width: 10,
                  height: 10,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PlayerCellarStat extends StatelessWidget {
  const PlayerCellarStat({
    required this.count,
    required this.tokens,
    super.key,
  });

  final int count;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      child: Row(
        spacing: 2,
        children: [
          Image.asset(
            'ios_resources/Icons/icon-cellar.png',
            width: 12,
            height: 12,
            filterQuality: FilterQuality.none,
          ),
          SizedBox(
            width: 12,
            height: 12,
            child: Stack(
              children: [
                for (var index = 0; index < count.clamp(0, 4); index++)
                  Positioned(
                    left: index * 3,
                    top: 1,
                    child: Image.asset(
                      'ios_resources/Cards/card-back-icon.png',
                      width: 7,
                      height: 10,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
              ],
            ),
          ),
        ],
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
    super.key,
  });

  final bool active;
  final bool human;
  final double width;
  final double height;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CardSlotPainter(
        color: active
            ? tokens.colors.gold
            : human
            ? tokens.colors.creamDim
            : tokens.colors.steel,
        active: active,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: active
              ? Image.asset('ios_resources/Icons/icon-play-tap.png', width: 18)
              : null,
        ),
      ),
    );
  }
}

class CardSlotPainter extends CustomPainter {
  const CardSlotPainter({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: active ? 0.95 : 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 2 : 1.4;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(7),
    );
    final path = Path()..addRRect(rect);
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(CardSlotPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.active != active;
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
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: tokens.colors.gold.withValues(alpha: 0.8),
              fontWeight: FontWeight.w900,
              fontSize: tokens.typography.size('title3', 20),
            ),
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
              Text(
                '${play.seatID + 1}',
                style: TextStyle(color: tokens.colors.creamDim),
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
          Text(
            model.table.phasePrompt.title,
            style: TextStyle(
              color: tokens.colors.gold,
              fontSize: tokens.typography.size('title3', 20),
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            model.table.phasePrompt.body,
            style: TextStyle(color: tokens.colors.creamDim),
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
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final trumpActions = model.legalActions
        .where((action) => action.kind == 'setTrump')
        .toList(growable: false);
    return Container(
      width: 262,
      padding: const EdgeInsets.all(12),
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
        borderRadius: BorderRadius.circular(tokens.radius.md),
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
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.red.withValues(alpha: 0.62)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          PanelTitleHeader(
            title: model.table.phasePrompt.title,
            subtitle: model.table.phasePrompt.body,
            iconPath: 'ios_resources/Icons/icon-jobs.png',
            tokens: tokens,
          ),
          if (trumpActions.isEmpty)
            Text(
              model.table.phasePrompt.body,
              style: TextStyle(
                color: tokens.colors.creamDim,
                fontSize: tokens.typography.size('subheadline', 15),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Center(
              child: SizedBox(
                width: 116,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final action in orderedTrumpActions(trumpActions))
                      TrumpSelectionButton(
                        action: action,
                        selected: action.targets.contains(model.table.trump),
                        tokens: tokens,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<LegalAction> orderedTrumpActions(List<LegalAction> actions) {
    final bySuit = {
      for (final action in actions)
        if (action.targets.isNotEmpty) action.targets.first: action,
    };
    return ['wheat', 'sunflower', 'potato', 'beet']
        .map((suit) => bySuit[suit])
        .whereType<LegalAction>()
        .toList(growable: false);
  }
}

class PanelTitleHeader extends StatelessWidget {
  const PanelTitleHeader({
    required this.title,
    required this.subtitle,
    required this.iconPath,
    required this.tokens,
    super.key,
  });

  final String title;
  final String subtitle;
  final String iconPath;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                tokens.colors.black.withValues(alpha: 0.58),
                tokens.colors.steel.withValues(alpha: 0.36),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: tokens.colors.gold.withValues(alpha: 0.8),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Image.asset(
              iconPath,
              width: 24,
              height: 24,
              filterQuality: FilterQuality.none,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.colors.gold,
                  fontSize: tokens.typography.size('caption', 13),
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.colors.creamDim,
                  fontSize: tokens.typography.size('caption', 13),
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TrumpSelectionButton extends StatelessWidget {
  const TrumpSelectionButton({
    required this.action,
    required this.selected,
    required this.tokens,
    super.key,
  });

  final LegalAction action;
  final bool selected;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final suit = action.targets.isEmpty
        ? action.label.toLowerCase()
        : action.targets.first;
    return Tooltip(
      message: action.label,
      child: SizedBox(
        width: 54,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: selected
                    ? tokens.colors.red.withValues(alpha: 0.38)
                    : tokens.colors.gold.withValues(alpha: 0.16),
                blurRadius: selected ? 8 : 4,
                offset: const Offset(0, 3),
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
                padding: EdgeInsets.only(top: selected ? 2 : 0),
                child: Image.asset(
                  'ios_resources/Icons/icon-trump-$suit.png',
                  width: 34,
                  height: 34,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, _, _) =>
                      SuitMark(suit: suit, tokens: tokens, size: 28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Seat viewerSeat(TableViewModel model) {
  final viewerID = model.viewer.seatID;
  if (viewerID == null) {
    return model.table.seats.first;
  }
  return model.table.seats.firstWhere(
    (seat) => seat.id == viewerID,
    orElse: () => model.table.seats.first,
  );
}

class JobsPanel extends StatelessWidget {
  const JobsPanel({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final assignmentPhase = model.table.phase == 'assignment';
    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.md,
        right: tokens.spacing.md,
        top: tokens.spacing.md,
        bottom: tokens.spacing.lg,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = clampDouble(
            constraints.maxWidth * 0.016,
            tokens.spacing.sm,
            tokens.spacing.lg,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var index = 0;
                      index < model.table.jobs.length;
                      index++
                    )
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == model.table.jobs.length - 1
                                ? 0
                                : spacing,
                          ),
                          child: JobTile(
                            job: model.table.jobs[index],
                            assignmentPhase: assignmentPhase,
                            tokens: tokens,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class JobTile extends StatelessWidget {
  const JobTile({
    required this.job,
    required this.assignmentPhase,
    required this.tokens,
    super.key,
  });

  final Job job;
  final bool assignmentPhase;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final progress = (job.hours / job.requiredHours).clamp(0.0, 1.0);
    final validTarget = assignmentPhase && job.validAssignmentTarget;
    final highlighted = job.highlighted;
    return Opacity(
      opacity: job.claimed ? 0.68 : 1,
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: highlighted
                ? [
                    tokens.colors.gold.withValues(alpha: 0.18),
                    tokens.colors.panel,
                  ]
                : [tokens.colors.panel, tokens.colors.iron],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(tokens.radius.md),
          boxShadow: [
            BoxShadow(
              color: validTarget
                  ? tokens.colors.gold.withValues(alpha: 0.16)
                  : tokens.colors.black.withValues(alpha: 0.25),
              blurRadius: validTarget ? 12 : 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: JobTileBorderPainter(
                    color: validTarget
                        ? tokens.colors.gold
                        : tokens.colors.steel.withValues(alpha: 0.55),
                    width: 1.5,
                    dashed: validTarget,
                    radius: tokens.radius.md,
                  ),
                ),
              ),
            ),
            Positioned(
              right: tokens.spacing.sm,
              bottom: tokens.spacing.sm,
              child: Opacity(
                opacity: 0.08,
                child: SuitMark(suit: job.suit, tokens: tokens, size: 54),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: tokens.spacing.md,
                  children: [
                    job.reward == null
                        ? EmptyRewardMarker(
                            suit: job.suit,
                            size: 34,
                            tokens: tokens,
                          )
                        : MiniRewardCard(
                            card: job.reward!,
                            claimed: job.claimed,
                            height: 34,
                            tokens: tokens,
                          ),
                    Expanded(
                      child: ProgressBar(
                        value: progress,
                        complete: job.claimed,
                        tokens: tokens,
                      ),
                    ),
                    Text(
                      job.claimed
                          ? 'DONE'
                          : '${job.hours}/${job.requiredHours}',
                      style: TextStyle(
                        color: job.claimed
                            ? tokens.colors.green
                            : tokens.colors.gold,
                        fontSize: tokens.typography.size('headline', 17),
                        fontWeight: FontWeight.w900,
                        height: 0.9,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.md),
                Expanded(
                  child: ClipRect(
                    child: job.assignedCards.isEmpty
                        ? Center(
                            child: Text(
                              validTarget ? 'TAP TO ASSIGN' : '',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: validTarget
                                    ? tokens.colors.gold
                                    : Colors.transparent,
                                fontSize: tokens.typography.size(
                                  'caption2',
                                  11,
                                ),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          )
                        : Align(
                            alignment: Alignment.topCenter,
                            child: Column(
                              children: [
                                for (
                                  var index = 0;
                                  index < job.assignedCards.length;
                                  index++
                                )
                                  Transform.translate(
                                    offset: Offset(
                                      0,
                                      index == 0 ? 0 : -34.0 * index,
                                    ),
                                    child: GameCard(
                                      card: job.assignedCards[index],
                                      tokens: tokens,
                                      sizeOverride: tokens.card.medium,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class JobTileBorderPainter extends CustomPainter {
  const JobTileBorderPainter({
    required this.color,
    required this.width,
    required this.dashed,
    required this.radius,
  });

  final Color color;
  final double width;
  final bool dashed;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final rect = Rect.fromLTWH(
      width / 2,
      width / 2,
      size.width - width,
      size.height - width,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }

    const dash = 6.0;
    const gap = 6.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(JobTileBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.width != width ||
        oldDelegate.dashed != dashed ||
        oldDelegate.radius != radius;
  }
}

class PhasePromptLine extends StatelessWidget {
  const PhasePromptLine({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      model.table.phasePrompt.title,
      style: TextStyle(
        color: tokens.colors.gold,
        fontSize: tokens.typography.size('title3', 20),
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class HandTray extends StatelessWidget {
  const HandTray({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final viewer = viewerSeat(model);
    final hand = viewer.hand.toList(growable: false)..sort(compareCardsForHand);
    final enabledActions = model.legalActions
        .where((action) => action.enabled)
        .toList(growable: false);
    const visibleTrayHeight = 66.0;
    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.handTrayHorizontalLeading,
        right: tokens.spacing.handTrayHorizontalTrailing,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Expanded(
            child: Container(
              height: visibleTrayHeight,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: tokens.colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(tokens.radius.sm),
                border: Border.all(
                  color: tokens.colors.steel.withValues(alpha: 0.32),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  SizedBox(
                    width: 34,
                    height: visibleTrayHeight,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Image.asset(
                        'ios_resources/Icons/icon-hand.png',
                        width: 32,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        height: visibleTrayHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 10,
                          children: [
                            for (final card in hand)
                              Transform.translate(
                                offset: const Offset(0, 8),
                                child: GameCard(card: card, tokens: tokens),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (enabledActions.isNotEmpty)
            ActionCommandBar(actions: enabledActions, tokens: tokens),
        ],
      ),
    );
  }
}

int compareCardsForHand(ContractCard lhs, ContractCard rhs) {
  final lhsSuit = suitSortIndex(lhs.suit);
  final rhsSuit = suitSortIndex(rhs.suit);
  if (lhsSuit != rhsSuit) {
    return lhsSuit.compareTo(rhsSuit);
  }
  return lhs.value.compareTo(rhs.value);
}

int suitSortIndex(String suit) {
  const order = ['wheat', 'sunflower', 'potato', 'beet'];
  final index = order.indexOf(suit);
  return index == -1 ? order.length : index;
}

class ActionCommandBar extends StatelessWidget {
  const ActionCommandBar({
    required this.actions,
    required this.tokens,
    super.key,
  });

  final List<LegalAction> actions;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    const visibleTrayHeight = 66.0;
    return SizedBox(
      width: actionBarWidth,
      height: visibleTrayHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            for (final action in actions)
              ActionPill(
                action: action,
                tokens: tokens,
                prominent: isProminentAction(action),
              ),
          ],
        ),
      ),
    );
  }

  double get actionBarWidth {
    if (actions.length <= 1) {
      return 150;
    }
    return 268;
  }

  bool isProminentAction(LegalAction action) {
    return action.kind == 'confirmSwap' ||
        action.kind == 'submitAssignments' ||
        action.kind == 'continueAfterRequisition';
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return PanelShell(
      tokens: tokens,
      title: model.panels.rightInfo.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panel: ${model.panels.active}',
            style: TextStyle(
              color: tokens.colors.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Online: ${model.viewer.isOnline ? model.viewer.connection : 'offline'}',
            style: TextStyle(color: tokens.colors.creamDim),
          ),
          const SizedBox(height: 12),
          for (final section in model.panels.rightInfo.sections) ...[
            Text(
              section.title,
              style: TextStyle(
                color: tokens.colors.cream,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(section.body, style: TextStyle(color: tokens.colors.creamDim)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class PanelShell extends StatelessWidget {
  const PanelShell({
    required this.tokens,
    required this.title,
    required this.child,
    super.key,
  });

  final DesignTokens tokens;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.colors.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: tokens.colors.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class GameCard extends StatelessWidget {
  const GameCard({
    required this.card,
    required this.tokens,
    this.small = false,
    this.sizeOverride,
    super.key,
  });

  final ContractCard card;
  final DesignTokens tokens;
  final bool small;
  final TokenCardSize? sizeOverride;

  @override
  Widget build(BuildContext context) {
    final size =
        sizeOverride ?? (small ? tokens.card.small : tokens.card.large);
    final border = card.selected
        ? tokens.colors.green
        : card.highlighted
        ? tokens.colors.gold
        : tokens.colors.iron;
    return Opacity(
      opacity: card.disabled ? 0.5 : 1,
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: tokens.colors.cardFill,
          image: const DecorationImage(
            image: AssetImage('ios_resources/Cards/card-template-light.png'),
            fit: BoxFit.fill,
          ),
          borderRadius: BorderRadius.circular(tokens.radius.card),
          border: Border.all(
            color: border,
            width: card.selected || card.highlighted
                ? tokens.stroke.active
                : tokens.stroke.standard,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(size.faceInset),
          child: Stack(
            children: [
              Positioned.fill(
                child: CardCenterFace(card: card, size: size, tokens: tokens),
              ),
              Positioned(
                left: size.width * 0.03,
                top: size.height * 0.03,
                child: CardCornerIndex(
                  card: card,
                  size: size,
                  tokens: tokens,
                  placement: CardCornerPlacement.top,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum CardCornerPlacement { top, bottom }

class CardCornerIndex extends StatelessWidget {
  const CardCornerIndex({
    required this.card,
    required this.size,
    required this.tokens,
    required this.placement,
    super.key,
  });

  final ContractCard card;
  final TokenCardSize size;
  final DesignTokens tokens;
  final CardCornerPlacement placement;

  @override
  Widget build(BuildContext context) {
    final top = placement == CardCornerPlacement.top;
    final rank = SizedBox(
      width: size.cornerWidth,
      height: size.cornerHeight,
      child: Align(
        alignment: top ? Alignment.centerLeft : Alignment.centerRight,
        child: Text(
          card.rank,
          style: TextStyle(
            color: card.highlighted ? tokens.colors.red : tokens.colors.cardInk,
            fontSize: size.cornerRankFontSize,
            fontWeight: FontWeight.w900,
            height: 0.82,
          ),
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
      height: size.cornerHeight + size.cornerSuitSize + 2,
      child: Column(
        crossAxisAlignment: top
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        mainAxisAlignment: top
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: top ? [rank, suit] : [suit, rank],
      ),
    );
  }
}

class CardCenterFace extends StatelessWidget {
  const CardCenterFace({
    required this.card,
    required this.size,
    required this.tokens,
    super.key,
  });

  final ContractCard card;
  final TokenCardSize size;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (size.width <= tokens.card.small.width + 0.1) {
      return Center(
        child: SuitMark(suit: card.suit, tokens: tokens, size: size.pipSize),
      );
    }

    if (card.value >= 11) {
      return Center(
        child: Opacity(
          opacity: 0.72,
          child: Image.asset(
            faceAssetPath(card),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => SuitMark(
              suit: card.suit,
              tokens: tokens,
              size: size.width * 0.34,
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

  final ContractCard card;
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

  final ContractCard card;
  final bool claimed;
  final double height;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: claimed ? 0.72 : 1,
      child: SizedBox(
        width: height * 0.72,
        height: height,
        child: FittedBox(
          fit: BoxFit.contain,
          child: MiniCard(card: card, tokens: tokens),
        ),
      ),
    );
  }
}

class EmptyRewardMarker extends StatelessWidget {
  const EmptyRewardMarker({
    required this.suit,
    required this.size,
    required this.tokens,
    super.key,
  });

  final String suit;
  final double size;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 0.72,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius.xs),
        border: Border.all(color: tokens.colors.green.withValues(alpha: 0.7)),
      ),
      child: Center(
        child: SuitMark(suit: suit, tokens: tokens, size: size * 0.42),
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
      height: 11,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(tokens.radius.xs),
          border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.6)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radius.xs - 1),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  color: complete ? tokens.colors.green : tokens.colors.gold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<Offset> pipPositions(int value) {
  switch (value.clamp(1, 10)) {
    case 1:
      return const [Offset(0.5, 0.5)];
    case 2:
      return const [Offset(0.5, 0.20), Offset(0.5, 0.80)];
    case 3:
      return const [Offset(0.5, 0.18), Offset(0.5, 0.5), Offset(0.5, 0.82)];
    case 4:
      return const [
        Offset(0.25, 0.22),
        Offset(0.75, 0.22),
        Offset(0.25, 0.78),
        Offset(0.75, 0.78),
      ];
    case 5:
      return const [
        Offset(0.25, 0.20),
        Offset(0.75, 0.20),
        Offset(0.5, 0.5),
        Offset(0.25, 0.80),
        Offset(0.75, 0.80),
      ];
    case 6:
      return const [
        Offset(0.25, 0.17),
        Offset(0.75, 0.17),
        Offset(0.25, 0.50),
        Offset(0.75, 0.50),
        Offset(0.25, 0.83),
        Offset(0.75, 0.83),
      ];
    case 7:
      return const [
        Offset(0.25, 0.15),
        Offset(0.75, 0.15),
        Offset(0.5, 0.31),
        Offset(0.25, 0.50),
        Offset(0.75, 0.50),
        Offset(0.25, 0.85),
        Offset(0.75, 0.85),
      ];
    case 8:
      return const [
        Offset(0.25, 0.14),
        Offset(0.75, 0.14),
        Offset(0.5, 0.30),
        Offset(0.25, 0.46),
        Offset(0.75, 0.46),
        Offset(0.5, 0.66),
        Offset(0.25, 0.86),
        Offset(0.75, 0.86),
      ];
    case 9:
      return const [
        Offset(0.25, 0.13),
        Offset(0.75, 0.13),
        Offset(0.25, 0.37),
        Offset(0.75, 0.37),
        Offset(0.5, 0.50),
        Offset(0.25, 0.63),
        Offset(0.75, 0.63),
        Offset(0.25, 0.87),
        Offset(0.75, 0.87),
      ];
    default:
      return const [
        Offset(0.25, 0.11),
        Offset(0.75, 0.11),
        Offset(0.5, 0.27),
        Offset(0.25, 0.39),
        Offset(0.75, 0.39),
        Offset(0.25, 0.61),
        Offset(0.75, 0.61),
        Offset(0.5, 0.73),
        Offset(0.25, 0.89),
        Offset(0.75, 0.89),
      ];
  }
}

String faceAssetPath(ContractCard card) {
  final rank = switch (card.value) {
    11 => 'jack',
    12 => 'queen',
    13 => 'king',
    _ => 'king',
  };
  return 'ios_resources/Cards/face-$rank-${card.suit}.png';
}

class MiniCard extends StatelessWidget {
  const MiniCard({
    required this.card,
    required this.tokens,
    this.emptySuit,
    super.key,
  });

  final ContractCard? card;
  final DesignTokens tokens;
  final String? emptySuit;

  @override
  Widget build(BuildContext context) {
    final visibleCard = card;
    return Container(
      width: tokens.card.small.width,
      height: tokens.card.small.height,
      padding: EdgeInsets.all(tokens.spacing.xs),
      decoration: BoxDecoration(
        color: visibleCard == null
            ? tokens.colors.panel
            : tokens.colors.cardFill,
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        border: Border.all(
          color: visibleCard?.pending == true
              ? tokens.colors.green
              : tokens.colors.iron,
        ),
      ),
      child: visibleCard == null
          ? Center(
              child: SuitMark(
                suit: emptySuit ?? 'wheat',
                tokens: tokens,
                size: tokens.card.small.cornerSuitSize * 2,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visibleCard.rank,
                  style: TextStyle(
                    color: tokens.colors.cardInk,
                    fontSize: tokens.card.small.cornerRankFontSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: SuitMark(
                    suit: visibleCard.suit,
                    tokens: tokens,
                    size: tokens.card.small.cornerSuitSize * 1.6,
                  ),
                ),
              ],
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
      errorBuilder: (_, _, _) =>
          SuitDot(suit: suit, tokens: tokens, size: size),
    );
  }
}

class ActionPill extends StatelessWidget {
  const ActionPill({
    required this.action,
    required this.tokens,
    required this.prominent,
    super.key,
  });

  final LegalAction action;
  final DesignTokens tokens;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: action.enabled ? 1 : 0.45,
      child: Container(
        constraints: BoxConstraints(
          minWidth: prominent ? 132 : 88,
          minHeight: prominent ? 36 : 32,
        ),
        padding: EdgeInsets.only(
          left: prominent ? 20 : 16,
          right: prominent ? 20 : 16,
          top: prominent ? 8 : 7,
          bottom: prominent ? 6 : 5,
        ),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              prominent
                  ? 'ios_resources/ui-button-primary.png'
                  : 'ios_resources/ui-button-secondary.png',
            ),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
          ),
          boxShadow: [
            BoxShadow(
              color: tokens.colors.black.withValues(
                alpha: prominent ? 0.28 : 0.18,
              ),
              blurRadius: prominent ? 5 : 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              action.label.toUpperCase(),
              maxLines: 1,
              style: TextStyle(
                color: prominent ? tokens.colors.cardInk : tokens.colors.cream,
                fontSize: tokens.typography.size('caption', 13),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
