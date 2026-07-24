import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/assignment_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/views/brigade/planning_phase_view.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/display/plot_display.dart';
import 'package:kolkhoz_app/src/app/views/game/views/fields/fields_view.dart';
import 'package:kolkhoz_app/src/app/views/game/views/plots/plots_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_typography.dart';

enum StaticHeroGamePanelKind { brigade, fields, north }

const staticHeroJobRects = {
  'wheat': Rect.fromLTWH(0.10, 0.25, 0.34, 0.28),
  'beet': Rect.fromLTWH(0.56, 0.25, 0.34, 0.28),
  'sunflower': Rect.fromLTWH(0.10, 0.59, 0.34, 0.29),
  'potato': Rect.fromLTWH(0.56, 0.59, 0.34, 0.29),
};

class StaticHeroJobMotionTargets extends StatelessWidget {
  const StaticHeroJobMotionTargets({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          children: [
            for (final entry in staticHeroJobRects.entries)
              Positioned.fromRect(
                rect: Rect.fromLTWH(
                  size.width * entry.value.left,
                  size.height * entry.value.top,
                  size.width * entry.value.width,
                  size.height * entry.value.height,
                ),
                child: MotionTrackedRegion(
                  motionKey: jobFieldMotionTargetKey(entry.key),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        );
      },
    );
  }
}

extension on StaticHeroGamePanelKind {
  String get label => switch (this) {
    StaticHeroGamePanelKind.brigade => 'BRIGADE',
    StaticHeroGamePanelKind.fields => 'FIELDS',
    StaticHeroGamePanelKind.north => 'NORTH',
  };

  String get asset =>
      'assets/art/field_plan/game/backgrounds/'
      'static-hero-$name-underlay-v1.png';
}

class StaticHeroGamePanel extends StatelessWidget {
  const StaticHeroGamePanel({
    required this.kind,
    required this.model,
    required this.tokens,
    required this.language,
    this.compact = false,
    this.showPlanningPanel = true,
    this.planningTrumpFocusedSuit,
    this.onPlanningTrumpActionSelected,
    this.onAction,
    this.onPlotCardTap,
    super.key,
  });

  final StaticHeroGamePanelKind kind;
  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool compact;
  final bool showPlanningPanel;
  final String? planningTrumpFocusedSuit;
  final ValueChanged<LegalAction>? onPlanningTrumpActionSelected;
  final ValueChanged<LegalAction>? onAction;
  final void Function(String cardID, String zone)? onPlotCardTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final posterCompact =
            compact ||
            constraints.maxWidth < 820 ||
            constraints.maxHeight < 440;
        return ClipRect(
          child: Stack(
            key: Key('production-static-hero-${kind.name}'),
            fit: StackFit.expand,
            children: [
              Image.asset(
                kind.asset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: const Color(0x0d6f5a37)),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: MotionTrackedRegion(
                    motionKey: northCardMotionTargetKey,
                    child: SizedBox(width: 48, height: 28),
                  ),
                ),
              ),
              switch (kind) {
                StaticHeroGamePanelKind.brigade => _BrigadePosterContent(
                  model: model,
                  tokens: tokens,
                  language: language,
                  compact: posterCompact,
                  showPlanningPanel: showPlanningPanel,
                  planningTrumpFocusedSuit: planningTrumpFocusedSuit,
                  onPlanningTrumpActionSelected: onPlanningTrumpActionSelected,
                  onPlotCardTap: onPlotCardTap,
                ),
                StaticHeroGamePanelKind.fields => _FieldsPosterContent(
                  model: model,
                  tokens: tokens,
                  onAction: onAction,
                ),
                StaticHeroGamePanelKind.north => _NorthPosterContent(
                  model: model,
                  tokens: tokens,
                ),
              },
              Positioned(
                left: posterCompact ? 8 : 14,
                top: posterCompact ? 8 : 12,
                child: _PosterTitle(
                  title: kind.label,
                  subtitle: _subtitle(),
                  compact: posterCompact,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _subtitle() => switch (kind) {
    StaticHeroGamePanelKind.brigade =>
      '${model.table.phasePrompt.title.toUpperCase()} · COMMUNAL TRICK',
    StaticHeroGamePanelKind.fields =>
      model.table.phase == phaseAssignment
          ? 'ASSIGN THE CAPTURED CARDS'
          : 'WORKER ASSIGNMENT',
    StaticHeroGamePanelKind.north => 'REMOVED CARDS · YEAR ${model.table.year}',
  };
}

class _PosterTitle extends StatelessWidget {
  const _PosterTitle({
    required this.title,
    required this.subtitle,
    required this.compact,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 146 : 236,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xffefe0b7),
          boxShadow: [
            BoxShadow(color: Color(0x6621251f), offset: Offset(3, 3)),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 5 : 7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontFamily: fieldPlanDisplayFontFamily,
                  color: const Color(0xffb52b1d),
                  fontSize: compact ? 17 : 24,
                  height: 0.95,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              if (!compact)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: fieldPlanDisplayFontFamily,
                    color: Color(0xff20231f),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrigadePosterContent extends StatefulWidget {
  const _BrigadePosterContent({
    required this.model,
    required this.tokens,
    required this.language,
    required this.compact,
    required this.showPlanningPanel,
    this.planningTrumpFocusedSuit,
    this.onPlanningTrumpActionSelected,
    this.onPlotCardTap,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool compact;
  final bool showPlanningPanel;
  final String? planningTrumpFocusedSuit;
  final ValueChanged<LegalAction>? onPlanningTrumpActionSelected;
  final void Function(String cardID, String zone)? onPlotCardTap;

  @override
  State<_BrigadePosterContent> createState() => _BrigadePosterContentState();
}

class _BrigadePosterContentState extends State<_BrigadePosterContent> {
  int? inspectedSeatID;

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final seats = _brigadeSeatsAroundViewer(model);
    final seatPositionByID = {
      for (final (index, seat) in seats.indexed) seat.id: index,
    };
    const centers = [
      Offset(0.22, 0.35),
      Offset(0.75, 0.35),
      Offset(0.22, 0.72),
      Offset(0.75, 0.72),
    ];
    final trick = model.table.phase == phaseAssignment
        ? visibleAssignmentTrick(model)
        : model.table.trick;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          children: [
            for (final (index, seat) in seats.indexed)
              _BrigadePlotZone(
                seat: seat,
                center: centers[index],
                model: model,
                tokens: widget.tokens,
                size: size,
                inspecting: inspectedSeatID == seat.id,
                onInspect: () => setState(() {
                  inspectedSeatID = inspectedSeatID == seat.id ? null : seat.id;
                }),
                onPlotCardTap: widget.onPlotCardTap,
              ),
            if (widget.showPlanningPanel && model.table.phase == phasePlanning)
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: widget.compact ? 190 : 250,
                    maxHeight: widget.compact ? 128 : 180,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PlanningPhasePanel(
                      model: model,
                      tokens: widget.tokens,
                      language: widget.language,
                      focusedSuit: widget.planningTrumpFocusedSuit,
                      onAction: widget.onPlanningTrumpActionSelected,
                    ),
                  ),
                ),
              )
            else
              Positioned(
                left: size.width * 0.33,
                top: size.height * 0.28,
                width: size.width * 0.34,
                height: size.height * 0.47,
                child: _PosterTrickGrid(
                  plays: trick.plays,
                  tokens: widget.tokens,
                  trump: model.table.trump,
                  seatPositionByID: seatPositionByID,
                ),
              ),
          ],
        );
      },
    );
  }
}

List<Seat> _brigadeSeatsAroundViewer(TableViewModel model) {
  final seats = [...model.table.seats]..sort((a, b) => a.id.compareTo(b.id));
  if (seats.length != 4) {
    return seats;
  }

  var viewerIndex = seats.indexWhere((seat) => seat.isViewer);
  final fallbackViewerSeatID = model.viewer.seatID;
  if (viewerIndex < 0 && fallbackViewerSeatID != null) {
    viewerIndex = seats.indexWhere((seat) => seat.id == fallbackViewerSeatID);
  }
  if (viewerIndex < 0) {
    viewerIndex = 0;
  }

  return [
    seats[(viewerIndex + 2) % seats.length],
    seats[(viewerIndex + 3) % seats.length],
    seats[(viewerIndex + 1) % seats.length],
    seats[viewerIndex],
  ];
}

class _PosterTrickGrid extends StatelessWidget {
  const _PosterTrickGrid({
    required this.plays,
    required this.tokens,
    required this.trump,
    required this.seatPositionByID,
  });

  final List<TrickPlay> plays;
  final DesignTokens tokens;
  final String? trump;
  final Map<int, int> seatPositionByID;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth / 2;
        final slotHeight = constraints.maxHeight / 2;
        return Stack(
          children: [
            for (final entry in seatPositionByID.entries)
              Builder(
                builder: (context) {
                  final play = plays
                      .where((play) => play.seatID == entry.key)
                      .firstOrNull;
                  return Positioned(
                    left: _trickColumn(entry.value) * slotWidth,
                    top: _trickRow(entry.value) * slotHeight,
                    width: slotWidth,
                    height: slotHeight,
                    child: MotionTrackedRegion(
                      motionKey: trickCardMotionTargetKey(entry.key),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: play == null
                            ? const SizedBox.expand()
                            : SizedBox(
                                key: Key(
                                  'static-hero-trick-card-${play.card.id}',
                                ),
                                child: _SinglePosterCard(
                                  card: play.card,
                                  tokens: tokens,
                                  trump: trump,
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

int _trickColumn(int seatPosition) => seatPosition.isOdd ? 1 : 0;

int _trickRow(int seatPosition) => seatPosition < 2 ? 0 : 1;

class _BrigadePlotZone extends StatelessWidget {
  const _BrigadePlotZone({
    required this.seat,
    required this.center,
    required this.model,
    required this.tokens,
    required this.size,
    required this.inspecting,
    required this.onInspect,
    this.onPlotCardTap,
  });

  final Seat seat;
  final Offset center;
  final TableViewModel model;
  final DesignTokens tokens;
  final Size size;
  final bool inspecting;
  final VoidCallback onInspect;
  final void Function(String cardID, String zone)? onPlotCardTap;

  @override
  Widget build(BuildContext context) {
    final hiddenExiledCardIDs = hiddenExiledPlotCardIDs(model);
    final entries = <_PosterCardEntry>[
      for (final card in visiblePlotCards(
        seat.plot.revealed,
        hiddenExiledCardIDs,
      ))
        _PosterCardEntry(card: card, onTap: _plotTap(card, plotZoneRevealed)),
      for (final stack in visiblePlotStacks(
        seat.plot.stacks,
        hiddenExiledCardIDs,
      ))
        for (final card in stack.revealed) _PosterCardEntry(card: card),
      for (final card in visiblePlotCards(
        seat.plot.hidden,
        hiddenExiledCardIDs,
      ))
        _PosterCardEntry(
          card: card,
          hidden: true,
          revealable: seat.isViewer,
          onTap: _plotTap(card, plotZoneHidden),
        ),
    ];
    final width = size.width * 0.27;
    final height = size.height * 0.27;
    return Positioned(
      left: size.width * center.dx - width / 2,
      top: size.height * center.dy - height / 2,
      width: width,
      height: height,
      child: MotionTrackedRegion(
        motionKey: plotCardMotionSourceKey(seat.id),
        child: Stack(
          children: [
            _LabeledCardFan(
              label:
                  '${seat.name.toUpperCase()}  '
                  '${visiblePlotScore(seat, hiddenExiledCardIDs)}',
              labelKey: Key('player-portrait-${seat.id}-inspect'),
              labelMotionKey: playerCardMotionSourceKey(seat.id),
              onLabelTap: onInspect,
              cards: entries,
              tokens: tokens,
              maxPerRow: 6,
            ),
            if (inspecting)
              Positioned.fill(top: 27, child: _PosterPlayerInfo(seat: seat)),
          ],
        ),
      ),
    );
  }

  VoidCallback? _plotTap(TableCard card, String zone) {
    if (!seat.isViewer || (!card.highlighted && !card.selected)) {
      return null;
    }
    final handler = onPlotCardTap;
    return handler == null ? null : () => handler(card.id, zone);
  }
}

class _FieldsPosterContent extends StatelessWidget {
  const _FieldsPosterContent({
    required this.model,
    required this.tokens,
    this.onAction,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final ValueChanged<LegalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final jobs = jobsInDisplayOrder(model.table.jobs);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          children: [
            for (final job in jobs)
              _JobPosterZone(
                job: job,
                model: model,
                tokens: tokens,
                rect: Rect.fromLTWH(
                  size.width * staticHeroJobRects[job.suit]!.left,
                  size.height * staticHeroJobRects[job.suit]!.top,
                  size.width * staticHeroJobRects[job.suit]!.width,
                  size.height * staticHeroJobRects[job.suit]!.height,
                ),
                onAction: onAction,
              ),
          ],
        );
      },
    );
  }
}

class _JobPosterZone extends StatelessWidget {
  const _JobPosterZone({
    required this.job,
    required this.model,
    required this.tokens,
    required this.rect,
    this.onAction,
  });

  final Job job;
  final TableViewModel model;
  final DesignTokens tokens;
  final Rect rect;
  final ValueChanged<LegalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final action = assignmentActionForJob(model, job);
    final handler = action == null || onAction == null
        ? null
        : () => onAction!(action);
    final hours = displayedJobHours(job);
    return Positioned.fromRect(
      rect: rect,
      child: Semantics(
        key: Key('static-hero-job-${job.suit}'),
        button: handler != null,
        label: '${job.suit}, $hours of ${job.requiredHours} hours',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: handler,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: handler == null
                    ? Colors.transparent
                    : const Color(0xffffdc65),
                width: handler == null ? 0 : 3,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 30),
                    child: _PosterCardFan(
                      cards: [
                        for (final card in job.assignedCards)
                          _PosterCardEntry(card: card),
                      ],
                      tokens: tokens,
                      maxPerRow: 6,
                    ),
                  ),
                ),
                if (job.reward case final reward?)
                  Positioned(
                    right: 8,
                    top: 8,
                    width: math.min(44, rect.width * 0.14),
                    height: math.min(64, rect.height * 0.38),
                    child: _SinglePosterCard(card: reward, tokens: tokens),
                  ),
                Positioned(
                  left: 8,
                  bottom: 6,
                  child: _PosterPlacard(
                    text:
                        '${job.suit.toUpperCase()}  $hours/${job.requiredHours}',
                    active: handler != null,
                    complete: hours >= job.requiredHours,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NorthPosterContent extends StatelessWidget {
  const _NorthPosterContent({required this.model, required this.tokens});

  final TableViewModel model;
  final DesignTokens tokens;

  static const roofY = [0.205, 0.335, 0.44, 0.585, 0.755];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          children: [
            for (var year = 1; year <= finalGameYear; year++)
              _NorthYearPosterRow(
                year: year,
                cards: model.table.exiledByYear[year] ?? const [],
                centerY: roofY[year - 1],
                completed:
                    year < model.table.year ||
                    model.table.phase == phaseGameOver ||
                    (year == model.table.year &&
                        model.table.phase == phaseRequisition),
                tokens: tokens,
                size: size,
              ),
          ],
        );
      },
    );
  }
}

class _NorthYearPosterRow extends StatelessWidget {
  const _NorthYearPosterRow({
    required this.year,
    required this.cards,
    required this.centerY,
    required this.completed,
    required this.tokens,
    required this.size,
  });

  final int year;
  final List<TableCard> cards;
  final double centerY;
  final bool completed;
  final DesignTokens tokens;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final height = size.height * 0.13;
    return Positioned(
      key: Key('static-hero-north-year-$year'),
      left: size.width * 0.17,
      top: size.height * centerY - height / 2,
      width: size.width * 0.66,
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 4,
            child: _PosterPlacard(text: 'YEAR $year'),
          ),
          Positioned(
            left: size.width * 0.20,
            right: 0,
            top: 0,
            bottom: 0,
            child: cards.isEmpty && completed
                ? const _EmptyYearStamp()
                : _PosterCardFan(
                    cards: [
                      for (final card in cards) _PosterCardEntry(card: card),
                    ],
                    tokens: tokens,
                    maxPerRow: 8,
                  ),
          ),
        ],
      ),
    );
  }
}

class _LabeledCardFan extends StatelessWidget {
  const _LabeledCardFan({
    required this.label,
    required this.cards,
    required this.tokens,
    required this.maxPerRow,
    this.labelKey,
    this.labelMotionKey,
    this.onLabelTap,
  });

  final String label;
  final List<_PosterCardEntry> cards;
  final DesignTokens tokens;
  final int maxPerRow;
  final Key? labelKey;
  final MotionAnchor? labelMotionKey;
  final VoidCallback? onLabelTap;

  @override
  Widget build(BuildContext context) {
    final labelWidget = GestureDetector(
      key: labelKey,
      behavior: HitTestBehavior.opaque,
      onTap: onLabelTap,
      child: _PosterPlacard(text: label),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 26, 4, 2),
            child: _PosterCardFan(
              cards: cards,
              tokens: tokens,
              maxPerRow: maxPerRow,
            ),
          ),
        ),
        Positioned(
          left: 2,
          top: 2,
          child: labelMotionKey == null
              ? labelWidget
              : MotionTrackedRegion(
                  motionKey: labelMotionKey!,
                  child: labelWidget,
                ),
        ),
      ],
    );
  }
}

class _PosterPlayerInfo extends StatelessWidget {
  const _PosterPlayerInfo({required this.seat});

  final Seat seat;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('player-info-panel-${seat.id}'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xff20231f).withValues(alpha: 0.94),
        border: Border.all(color: const Color(0xffefe0b7), width: 2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              seat.name.toUpperCase(),
              style: const TextStyle(
                fontFamily: fieldPlanDisplayFontFamily,
                color: Color(0xffffdc65),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'PLAYER  ·  SCORE ${seat.visibleScore}  ·  HAND ${seat.hand.length + seat.hiddenHandCount}',
              style: const TextStyle(
                fontFamily: fieldPlanDisplayFontFamily,
                color: Color(0xffffecc2),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterCardFan extends StatelessWidget {
  const _PosterCardFan({
    required this.cards,
    required this.tokens,
    required this.maxPerRow,
  });

  final List<_PosterCardEntry> cards;
  final DesignTokens tokens;
  final int maxPerRow;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = math.min(maxPerRow, cards.length);
        final rows = (cards.length / perRow).ceil();
        final base = tokens.card.small;
        final widthUnits = 1 + math.max(0, perRow - 1) * 0.58;
        final heightUnits = 1 + math.max(0, rows - 1) * 0.44;
        final scale = math.min(
          1.55,
          math.min(
            constraints.maxWidth / (base.width * widthUnits),
            constraints.maxHeight / (base.height * heightUnits),
          ),
        );
        final cardSize = _scaledCardSize(base, math.max(0.36, scale));
        final strideX = cardSize.width * 0.58;
        final strideY = cardSize.height * 0.44;
        final contentHeight = cardSize.height + (rows - 1) * strideY;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (index, entry) in cards.indexed)
              Builder(
                builder: (context) {
                  final row = index ~/ perRow;
                  final column = index % perRow;
                  final rowCount = math.min(
                    perRow,
                    cards.length - row * perRow,
                  );
                  final rowWidth = cardSize.width + (rowCount - 1) * strideX;
                  return Positioned(
                    left:
                        (constraints.maxWidth - rowWidth) / 2 +
                        column * strideX,
                    top:
                        (constraints.maxHeight - contentHeight) / 2 +
                        row * strideY,
                    width: cardSize.width,
                    height: cardSize.height,
                    child: MotionTrackedCard(
                      card: entry.card,
                      compositeWhenVisible: false,
                      child: PendingAssignmentCardPulse(
                        cardID: entry.card.id,
                        active: entry.card.pending,
                        tokens: tokens,
                        child: entry.hidden && entry.revealable
                            ? InteractiveCardFlip(
                                key: Key('static-hero-card-${entry.card.id}'),
                                concealedLabel: 'Cellar card. Tap to reveal.',
                                revealedLabel:
                                    '${entry.card.rank} of ${entry.card.suit}. '
                                    'Tap to conceal.',
                                frontKey: ValueKey(
                                  'cellar-face-${entry.card.id}',
                                ),
                                backKey: ValueKey(
                                  'cellar-back-${entry.card.id}',
                                ),
                                onTap: entry.onTap,
                                front: GameCard(
                                  card: entry.card,
                                  tokens: tokens,
                                  sizeOverride: cardSize,
                                  motionTracked: false,
                                ),
                                back: ScaledHighlightableCardBack(
                                  card: entry.card,
                                  tokens: tokens,
                                  size: cardSize,
                                ),
                              )
                            : GestureDetector(
                                key: Key('static-hero-card-${entry.card.id}'),
                                behavior: HitTestBehavior.opaque,
                                onTap: entry.onTap,
                                child: entry.hidden
                                    ? ScaledHighlightableCardBack(
                                        card: entry.card,
                                        tokens: tokens,
                                        size: cardSize,
                                      )
                                    : GameCard(
                                        card: entry.card,
                                        tokens: tokens,
                                        sizeOverride: cardSize,
                                        motionTracked: false,
                                      ),
                              ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _SinglePosterCard extends StatelessWidget {
  const _SinglePosterCard({
    required this.card,
    required this.tokens,
    this.trump,
  });

  final TableCard card;
  final DesignTokens tokens;
  final String? trump;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final base = tokens.card.small;
        final scale = math.min(
          constraints.maxWidth / base.width,
          constraints.maxHeight / base.height,
        );
        final targetSize = _scaledCardSize(base, scale);
        final renderSize = tokens.card.large;
        final renderScale = targetSize.width / renderSize.width;
        return Center(
          child: MotionTrackedCard(
            card: card,
            compositeWhenVisible: false,
            child: SizedBox(
              width: targetSize.width,
              height: targetSize.height,
              child: OverflowBox(
                minWidth: renderSize.width,
                maxWidth: renderSize.width,
                minHeight: renderSize.height,
                maxHeight: renderSize.height,
                child: Transform.scale(
                  scale: renderScale,
                  filterQuality: FilterQuality.high,
                  child: RepaintBoundary(
                    child: GameCard(
                      card: card,
                      tokens: tokens,
                      trump: trump,
                      sizeOverride: renderSize,
                      motionTracked: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PosterPlacard extends StatelessWidget {
  const _PosterPlacard({
    required this.text,
    this.active = false,
    this.complete = false,
  });

  final String text;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? const Color(0xffb52b1d)
            : complete
            ? const Color(0xff52633f)
            : const Color(0xffefe0b7),
        border: Border.all(color: const Color(0xff20231f), width: 0.8),
        boxShadow: const [
          BoxShadow(color: Color(0x5521251f), offset: Offset(2, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: fieldPlanDisplayFontFamily,
            color: active || complete
                ? const Color(0xffffecc2)
                : const Color(0xff20231f),
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
      ),
    );
  }
}

class _EmptyYearStamp extends StatelessWidget {
  const _EmptyYearStamp();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: -0.04,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xffefe0b7),
            border: Border.all(color: const Color(0xffb52b1d), width: 3),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              'CLEAR',
              style: TextStyle(
                fontFamily: fieldPlanDisplayFontFamily,
                color: Color(0xffb52b1d),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterCardEntry {
  const _PosterCardEntry({
    required this.card,
    this.hidden = false,
    this.revealable = false,
    this.onTap,
  });

  final TableCard card;
  final bool hidden;
  final bool revealable;
  final VoidCallback? onTap;
}

TokenCardSize _scaledCardSize(TokenCardSize source, double scale) =>
    TokenCardSize(
      width: source.width * scale,
      height: source.height * scale,
      faceInset: source.faceInset * scale,
      cornerWidth: source.cornerWidth * scale,
      cornerHeight: source.cornerHeight * scale,
      cornerRankFontSize: source.cornerRankFontSize * scale,
      cornerSuitSize: source.cornerSuitSize * scale,
      topCornerRankSuitSpacing: source.topCornerRankSuitSpacing * scale,
      bottomCornerRankSuitSpacing: source.bottomCornerRankSuitSpacing * scale,
      topCornerSuitXOffset: source.topCornerSuitXOffset * scale,
      bottomCornerSuitXOffset: source.bottomCornerSuitXOffset * scale,
      pipSize: source.pipSize * scale,
    );
