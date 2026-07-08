import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../app_text.dart';
import '../assignment_display.dart';
import '../design_tokens.dart';
import '../game_constants.dart';
import '../pixel_text.dart';
import '../render_model.dart';
import 'board_widgets.dart';

const jobsPanelLocalPadding = EdgeInsets.only(top: 8);
const jobsTileSpacingWidthFactor = 0.016;
const jobsTileSpacingMin = 6.0;
const jobsTileSpacingMax = 10.0;
const jobsTileHeightFactor = 0.98;
const jobsTilePadding = 8.0;
const jobsTileHeaderSpacing = 8.0;
const jobsTileContentGap = 7.0;
const jobsTileEmptyPromptMinHeight = 42.0;
const jobsAssignedCardsPerRow = 4;
const jobsAssignedCardHorizontalOverlapFactor = 0.18;
const jobsAssignedCardVerticalOverlapFactor = 0.14;

List<Job> jobsInDisplayOrder(List<Job> jobs) {
  final jobsBySuit = {for (final job in jobs) job.suit: job};
  return displaySuitOrder
      .map((suit) => jobsBySuit[suit] ?? emptyVisualJob(suit))
      .toList(growable: false);
}

Job emptyVisualJob(String suit) {
  return Job(
    suit: suit,
    hours: 0,
    requiredHours: jobRequiredHours,
    claimed: false,
    reward: null,
    assignedCards: const [],
    validAssignmentTarget: false,
    highlighted: false,
  );
}

double jobsTileSpacing(double width) {
  return clampDouble(
    width * jobsTileSpacingWidthFactor,
    jobsTileSpacingMin,
    jobsTileSpacingMax,
  );
}

double jobsTileHeight({
  required double availableHeight,
  required bool assignmentPhase,
  required JobsLayoutTokens tokens,
}) {
  return math.max(
    assignmentPhase
        ? tokens.assignmentMinTileHeight
        : tokens.overviewMinTileHeight,
    availableHeight * jobsTileHeightFactor,
  );
}

int assignedJobCardRowCount(int cardCount) {
  if (cardCount <= 0) {
    return 0;
  }
  return (cardCount / jobsAssignedCardsPerRow).ceil();
}

double assignedJobCardHorizontalStep(TokenCardSize cardSize) {
  return cardSize.width * (1 - jobsAssignedCardHorizontalOverlapFactor);
}

double assignedJobCardVerticalStep(TokenCardSize cardSize) {
  return cardSize.height * (1 - jobsAssignedCardVerticalOverlapFactor);
}

double assignedJobCardRowWidth({
  required int rowCardCount,
  required TokenCardSize cardSize,
}) {
  if (rowCardCount <= 0) {
    return 0;
  }
  return cardSize.width +
      math.max(0, rowCardCount - 1) * assignedJobCardHorizontalStep(cardSize);
}

Size assignedJobCardsContentSize({
  required int cardCount,
  required TokenCardSize cardSize,
}) {
  if (cardCount <= 0) {
    return Size.zero;
  }
  final fullRowWidth = assignedJobCardRowWidth(
    rowCardCount: math.min(cardCount, jobsAssignedCardsPerRow),
    cardSize: cardSize,
  );
  final rows = assignedJobCardRowCount(cardCount);
  final height =
      cardSize.height +
      math.max(0, rows - 1) * assignedJobCardVerticalStep(cardSize);
  return Size(fullRowWidth, height);
}

Size assignedJobCardRowsContentSize({
  required List<List<TableCard>> rows,
  required TokenCardSize cardSize,
}) {
  if (rows.isEmpty) {
    return Size.zero;
  }
  final maxRowCardCount = rows.fold<int>(
    0,
    (count, row) => math.max(count, row.length),
  );
  final width = assignedJobCardRowWidth(
    rowCardCount: maxRowCardCount,
    cardSize: cardSize,
  );
  final height =
      cardSize.height +
      math.max(0, rows.length - 1) * assignedJobCardVerticalStep(cardSize);
  return Size(width, height);
}

int pendingAssignedJobHours(Job job) {
  return job.assignedCards
      .where((card) => card.pending)
      .fold(0, (total, card) => total + card.value);
}

int displayedJobHours(Job job) {
  return job.hours + pendingAssignedJobHours(job);
}

List<List<TableCard>> assignedJobTrickRows(List<TableCard> cards) {
  final rows = <List<TableCard>>[];
  var currentRow = <TableCard>[];
  int? currentRound;
  for (final card in cards) {
    final nextRound = card.assignmentRound;
    final startsNewRound =
        currentRow.isNotEmpty &&
        nextRound != currentRound &&
        (nextRound != null || currentRound != null);
    final rowIsFull = currentRow.length >= jobsAssignedCardsPerRow;
    if (startsNewRound || rowIsFull) {
      rows.add(currentRow);
      currentRow = <TableCard>[];
    }
    currentRound = nextRound;
    currentRow.add(card);
  }
  if (currentRow.isNotEmpty) {
    rows.add(currentRow);
  }
  return rows;
}

TokenCardSize assignedJobCardSize({
  required Size availableSize,
  required int cardCount,
  required DesignTokens tokens,
}) {
  for (final size in [
    tokens.card.large,
    tokens.card.medium,
    tokens.card.small,
  ]) {
    final contentSize = assignedJobCardsContentSize(
      cardCount: cardCount,
      cardSize: size,
    );
    if ((contentSize.width <= availableSize.width &&
            contentSize.height <= availableSize.height) ||
        size == tokens.card.small) {
      return size;
    }
  }
  return tokens.card.small;
}

TokenCardSize assignedJobCardSizeForRows({
  required Size availableSize,
  required List<List<TableCard>> rows,
  required DesignTokens tokens,
}) {
  for (final size in [
    tokens.card.large,
    tokens.card.medium,
    tokens.card.small,
  ]) {
    final contentSize = assignedJobCardRowsContentSize(
      rows: rows,
      cardSize: size,
    );
    if ((contentSize.width <= availableSize.width &&
            contentSize.height <= availableSize.height) ||
        size == tokens.card.small) {
      return size;
    }
  }
  return tokens.card.small;
}

class JobsPanel extends StatelessWidget {
  const JobsPanel({
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
    final assignmentPhase = model.table.phase == phaseAssignment;
    final jobs = jobsInDisplayOrder(model.table.jobs);
    return Padding(
      padding: jobsPanelLocalPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = jobsTileSpacing(constraints.maxWidth);
          final tileHeight = jobsTileHeight(
            availableHeight: constraints.maxHeight,
            assignmentPhase: assignmentPhase,
            tokens: tokens.layout.jobs,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: tileHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < jobs.length; index++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == jobs.length - 1 ? 0 : spacing,
                          ),
                          child: Builder(
                            builder: (context) {
                              final assignmentAction = assignmentActionForJob(
                                model,
                                jobs[index],
                              );
                              return JobTile(
                                job: jobs[index],
                                assignmentPhase: assignmentPhase,
                                trump: model.table.trump,
                                tokens: tokens,
                                language: language,
                                onAssign:
                                    assignmentAction == null || onAction == null
                                    ? null
                                    : () => onAction!(assignmentAction),
                              );
                            },
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

class JobTile extends StatefulWidget {
  const JobTile({
    required this.job,
    required this.assignmentPhase,
    required this.trump,
    required this.tokens,
    required this.language,
    this.onAssign,
    super.key,
  });

  final Job job;
  final bool assignmentPhase;
  final String? trump;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback? onAssign;

  @override
  State<JobTile> createState() => _JobTileState();
}

class _JobTileState extends State<JobTile> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final assignmentPhase = widget.assignmentPhase;
    final trump = widget.trump;
    final tokens = widget.tokens;
    final onAssign = widget.onAssign;
    final displayHours = displayedJobHours(job);
    final progress = (displayHours / job.requiredHours).clamp(0.0, 1.0);
    final validTarget = assignmentPhase && job.validAssignmentTarget;
    final actionableTarget = validTarget && onAssign != null;
    final highlighted = trump == job.suit;
    final showHover = hovered && actionableTarget;
    final showAssignPrompt = actionableTarget && job.assignedCards.isEmpty;
    return MouseRegion(
      cursor: actionableTarget
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: actionableTarget ? onAssign : null,
        child: Opacity(
          opacity: job.claimed ? 0.68 : 1,
          child: Container(
            padding: const EdgeInsets.all(jobsTilePadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: showHover
                    ? [
                        tokens.colors.green.withValues(alpha: 0.24),
                        tokens.colors.panel,
                      ]
                    : highlighted
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
                  color: showHover
                      ? tokens.colors.green.withValues(alpha: 0.42)
                      : actionableTarget
                      ? tokens.colors.gold.withValues(alpha: 0.16)
                      : tokens.colors.black.withValues(alpha: 0.25),
                  blurRadius: showHover ? 14 : 5,
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
                        color: showHover
                            ? tokens.colors.green
                            : actionableTarget
                            ? tokens.colors.gold
                            : tokens.colors.steel.withValues(alpha: 0.55),
                        width: showHover ? 3 : 1.5,
                        dashed: actionableTarget && !showHover,
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
                      spacing: jobsTileHeaderSpacing,
                      children: [
                        job.reward == null
                            ? EmptyRewardMarker(size: 34, tokens: tokens)
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
                        PixelText(
                          job.claimed
                              ? widget.language.t(
                                  KolkhozText.boardJobspanelDone,
                                )
                              : '$displayHours/${job.requiredHours}',
                          size: PixelTextSize.headline,
                          variant: PixelTextVariant.heavy,
                          color: job.claimed
                              ? tokens.colors.green
                              : tokens.colors.gold,
                        ),
                      ],
                    ),
                    const SizedBox(height: jobsTileContentGap),
                    Expanded(
                      child: SizedBox.expand(
                        child: ClipRect(
                          child: job.assignedCards.isEmpty
                              ? Center(
                                  child: SizedBox(
                                    key: const Key(
                                      'job-tile-empty-assignment-prompt',
                                    ),
                                    width: double.infinity,
                                    height: jobsTileEmptyPromptMinHeight,
                                    child: Center(
                                      child: PixelText(
                                        showAssignPrompt
                                            ? widget.language.t(
                                                KolkhozText
                                                    .boardJobspanelTapToAssign,
                                              )
                                            : '',
                                        textAlign: TextAlign.center,
                                        size: PixelTextSize.caption2,
                                        variant: PixelTextVariant.heavy,
                                        color: showAssignPrompt
                                            ? tokens.colors.gold
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                )
                              : AssignedJobCardStack(
                                  cards: job.assignedCards,
                                  tokens: tokens,
                                  trump: trump,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AssignedJobCardStack extends StatelessWidget {
  const AssignedJobCardStack({
    required this.cards,
    required this.tokens,
    required this.trump,
    super.key,
  });

  final List<TableCard> cards;
  final DesignTokens tokens;
  final String? trump;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = assignedJobTrickRows(cards);
        final cardSize = assignedJobCardSizeForRows(
          availableSize: constraints.biggest,
          rows: rows,
          tokens: tokens,
        );
        final contentSize = assignedJobCardRowsContentSize(
          rows: rows,
          cardSize: cardSize,
        );
        final stack = SizedBox(
          width: contentSize.width,
          height: contentSize.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (rowIndex, row) in rows.indexed) ...[
                for (final (indexInRow, card) in row.indexed)
                  Positioned(
                    left: assignedJobCardLeft(
                      indexInRow: indexInRow,
                      rowCardCount: row.length,
                      fullWidth: contentSize.width,
                      cardSize: cardSize,
                    ),
                    top: rowIndex * assignedJobCardVerticalStep(cardSize),
                    child: JobBucketCard(
                      card: card,
                      tokens: tokens,
                      trump: trump,
                      size: cardSize,
                    ),
                  ),
              ],
            ],
          ),
        );
        if (contentSize.height <= constraints.maxHeight) {
          return Align(alignment: Alignment.topCenter, child: stack);
        }
        return SingleChildScrollView(
          child: Align(alignment: Alignment.topCenter, child: stack),
        );
      },
    );
  }
}

double assignedJobCardLeft({
  required int indexInRow,
  required int rowCardCount,
  required double fullWidth,
  required TokenCardSize cardSize,
}) {
  final rowWidth = assignedJobCardRowWidth(
    rowCardCount: rowCardCount,
    cardSize: cardSize,
  );
  return (fullWidth - rowWidth) / 2 +
      indexInRow * assignedJobCardHorizontalStep(cardSize);
}

class JobBucketCard extends StatelessWidget {
  const JobBucketCard({
    required this.card,
    required this.tokens,
    required this.trump,
    required this.size,
    super.key,
  });

  final TableCard card;
  final DesignTokens tokens;
  final String? trump;
  final TokenCardSize size;

  @override
  Widget build(BuildContext context) {
    final color = card.pending
        ? tokens.colors.green.withValues(alpha: 0.85)
        : tokens.colors.gold.withValues(alpha: 0.8);
    return Stack(
      children: [
        GameCard(card: card, tokens: tokens, trump: trump, sizeOverride: size),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color, width: card.pending ? 2 : 1),
              ),
            ),
          ),
        ),
      ],
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
