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
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs,
      ),
      child: Column(
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
          const Spacer(),
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
    final border = active || action
        ? tokens.colors.gold
        : tokens.colors.gold.withValues(alpha: 0.28);
    return Tooltip(
      message: label,
      child: Container(
        width: 42,
        height: 42,
        margin: EdgeInsets.only(bottom: tokens.spacing.sm),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active
              ? tokens.colors.gold.withValues(alpha: 0.94)
              : action
              ? tokens.colors.red.withValues(alpha: 0.42)
              : tokens.colors.panel,
          borderRadius: BorderRadius.circular(tokens.radius.sm),
          border: Border.all(color: border, width: active ? 2 : 1),
          boxShadow: [
            if (active)
              BoxShadow(
                color: tokens.colors.red.withValues(alpha: 0.32),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Image.asset(
          'ios_resources/Icons/$asset',
          color: active ? tokens.colors.cardInk : null,
          errorBuilder: (_, _, _) => Icon(
            Icons.crop_square,
            color: active ? tokens.colors.cardInk : tokens.colors.creamDim,
          ),
        ),
      ),
    );
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
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TopInfoCell(
              icon: 'icon-year-${model.table.year.clamp(1, 5)}.png',
              value: 'Y${model.table.year}',
              tokens: tokens,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final job in model.table.jobs)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.xs),
                  child: JobGauge(job: job, tokens: tokens),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TopInfoCell(
                  icon: 'icon-cellar.png',
                  value: '$cellarScore',
                  tokens: tokens,
                ),
                SizedBox(width: tokens.spacing.sm),
                TopInfoCell(
                  icon: 'icon-plot.png',
                  value: '$plotScore',
                  tokens: tokens,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TopInfoCell extends StatelessWidget {
  const TopInfoCell({
    required this.icon,
    required this.value,
    required this.tokens,
    super.key,
  });

  final String icon;
  final String value;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('ios_resources/Icons/$icon', width: 28, height: 28),
        SizedBox(width: tokens.spacing.xs),
        Text(
          value,
          style: TextStyle(
            color: tokens.colors.gold,
            fontSize: tokens.typography.size('title2', 22),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class JobGauge extends StatelessWidget {
  const JobGauge({required this.job, required this.tokens, super.key});

  final Job job;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final highlighted = job.highlighted || job.validAssignmentTarget;
    return Container(
      width: 104,
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm),
      decoration: BoxDecoration(
        color: tokens.colors.panel,
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        border: Border.all(
          color: highlighted ? tokens.colors.gold : tokens.colors.steel,
          width: highlighted ? tokens.stroke.emphasis : tokens.stroke.hairline,
        ),
      ),
      child: Row(
        children: [
          MiniCard(card: job.reward, tokens: tokens, emptySuit: job.suit),
          SizedBox(width: tokens.spacing.xs),
          Expanded(
            child: Text(
              job.claimed ? 'OK' : '${job.hours}/${job.requiredHours}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: highlighted ? tokens.colors.red : tokens.colors.smoke,
                fontSize: tokens.typography.size('caption', 13),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
        final centerCardSize = tokens.card.large;
        return Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: DashedSlot(
                  width: centerCardSize.width * 2.5,
                  height: centerCardSize.height * 1.35,
                  tokens: tokens,
                  label: model.table.phase == 'planning'
                      ? model.table.phasePrompt.title
                      : 'Trick',
                ),
              ),
            ),
            if (seats.length > 1)
              Align(
                alignment: Alignment.topCenter,
                child: PlayerBadge(seat: seats[1], tokens: tokens),
              ),
            if (seats.length > 2)
              Align(
                alignment: Alignment.centerRight,
                child: PlayerBadge(seat: seats[2], tokens: tokens),
              ),
            if (seats.length > 3)
              Align(
                alignment: Alignment.centerLeft,
                child: PlayerBadge(seat: seats[3], tokens: tokens),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: PlayerBadge(seat: seats.first, tokens: tokens),
            ),
            Align(
              alignment: Alignment.center,
              child: TrickCards(trick: trick, tokens: tokens),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: InfoPlaque(model: model, tokens: tokens),
            ),
          ],
        );
      },
    );
  }
}

class PlotPanel extends StatelessWidget {
  const PlotPanel({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhasePromptLine(model: model, tokens: tokens),
          SizedBox(height: tokens.spacing.md),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: tokens.spacing.lg,
                    runSpacing: tokens.spacing.lg,
                    children: [
                      for (final seat in model.table.seats)
                        SizedBox(
                          width: 210,
                          child: PlotBadge(seat: seat, tokens: tokens),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: tokens.spacing.xl),
                SizedBox(
                  width: 270,
                  child: InfoPanel(model: model, tokens: tokens),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerBadge extends StatelessWidget {
  const PlayerBadge({required this.seat, required this.tokens, super.key});

  final Seat seat;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final active = seat.isCurrentTurn || seat.isViewer;
    return Container(
      width: 178,
      margin: EdgeInsets.all(tokens.spacing.md),
      padding: EdgeInsets.all(tokens.spacing.sm),
      decoration: BoxDecoration(
        color: tokens.colors.panel,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(
          color: active ? tokens.colors.gold : tokens.colors.steel,
          width: active ? tokens.stroke.emphasis : tokens.stroke.hairline,
        ),
      ),
      child: Row(
        children: [
          Image.asset('ios_resources/Icons/icon-human-seat.png', width: 30),
          SizedBox(width: tokens.spacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.colors.cream,
                    fontSize: tokens.typography.size('caption', 13),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${seat.controller}  ${seat.visibleScore}',
                  style: TextStyle(
                    color: tokens.colors.creamDim,
                    fontSize: tokens.typography.size('caption2', 11),
                  ),
                ),
              ],
            ),
          ),
          if (seat.isBrigadeLeader)
            Image.asset(
              'ios_resources/Icons/icon-status-brigade-leader.png',
              width: 18,
            ),
        ],
      ),
    );
  }
}

class PlotBadge extends StatelessWidget {
  const PlotBadge({required this.seat, required this.tokens, super.key});

  final Seat seat;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: tokens.colors.panel,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: tokens.colors.steel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerBadge(seat: seat, tokens: tokens),
          SizedBox(height: tokens.spacing.sm),
          Text(
            'Cellar ${seat.plot.hiddenCount}  Plot ${seat.plot.revealed.length}',
            style: TextStyle(color: tokens.colors.creamDim),
          ),
          SizedBox(height: tokens.spacing.sm),
          Wrap(
            spacing: tokens.spacing.xs,
            runSpacing: tokens.spacing.xs,
            children: [
              for (final card in seat.plot.revealed)
                MiniCard(card: card, tokens: tokens),
            ],
          ),
        ],
      ),
    );
  }
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
    return PanelShell(
      tokens: tokens,
      title: 'Jobs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhasePromptLine(model: model, tokens: tokens),
          SizedBox(height: tokens.spacing.md),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.35,
              children: [
                for (final job in model.table.jobs)
                  JobTile(job: job, tokens: tokens),
              ],
            ),
          ),
        ],
      ),
    );
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

class JobTile extends StatelessWidget {
  const JobTile({required this.job, required this.tokens, super.key});

  final Job job;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final progress = job.hours / job.requiredHours;
    final accent = suitColor(tokens, job.suit);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: job.validAssignmentTarget
            ? tokens.colors.iron
            : tokens.colors.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: job.highlighted || job.validAssignmentTarget
              ? tokens.colors.gold
              : tokens.colors.iron,
          width: job.validAssignmentTarget ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SuitDot(suit: job.suit, tokens: tokens),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  job.suit,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                job.claimed ? 'done' : '${job.hours}/40',
                style: TextStyle(color: tokens.colors.cream),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            color: job.claimed ? tokens.colors.green : accent,
            backgroundColor: tokens.colors.background,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (job.reward != null)
                MiniCard(card: job.reward!, tokens: tokens),
              for (final card in job.assignedCards)
                MiniCard(card: card, tokens: tokens),
            ],
          ),
        ],
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
    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.handTrayHorizontalLeading,
        right: tokens.spacing.handTrayHorizontalTrailing,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: tokens.card.large.height + 12,
            alignment: Alignment.topCenter,
            child: Image.asset('ios_resources/Icons/icon-hand.png', width: 32),
          ),
          Expanded(
            child: Container(
              height: tokens.card.large.height + 12,
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm),
              decoration: BoxDecoration(
                color: tokens.colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(tokens.radius.md),
                border: Border.all(
                  color: tokens.colors.steel.withValues(alpha: 0.32),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final card in viewer.hand)
                            Padding(
                              padding: EdgeInsets.only(
                                right: tokens.spacing.lg,
                              ),
                              child: Transform.translate(
                                offset: const Offset(0, 8),
                                child: GameCard(card: card, tokens: tokens),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.md),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 310),
                    child: Wrap(
                      spacing: tokens.spacing.sm,
                      runSpacing: tokens.spacing.xs,
                      children: [
                        for (final action in model.legalActions.where(
                          (action) => action.enabled,
                        ))
                          ActionPill(action: action, tokens: tokens),
                      ],
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
    super.key,
  });

  final ContractCard card;
  final DesignTokens tokens;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? tokens.card.small : tokens.card.large;
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
        padding: EdgeInsets.all(small ? tokens.spacing.xs : tokens.spacing.sm),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.rank,
              style: TextStyle(
                color: card.highlighted
                    ? tokens.colors.red
                    : tokens.colors.cardInk,
                fontSize: small
                    ? tokens.card.small.cornerRankFontSize
                    : tokens.card.large.cornerRankFontSize,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: SuitDot(
                suit: card.suit,
                tokens: tokens,
                size: small
                    ? tokens.card.small.cornerSuitSize * 1.8
                    : tokens.card.large.cornerSuitSize * 1.8,
              ),
            ),
          ],
        ),
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
              child: SuitDot(
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
                  child: SuitDot(
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

class ActionPill extends StatelessWidget {
  const ActionPill({required this.action, required this.tokens, super.key});

  final LegalAction action;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.colors.gold,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        action.kind,
        style: TextStyle(
          color: tokens.colors.cardInk,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
