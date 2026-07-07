import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../chrome_button.dart';
import '../design_tokens.dart';
import '../game_constants.dart';
import '../pixel_text.dart';
import '../plot_display.dart';
import '../render_model.dart';
import '../table_display.dart';
import 'board_widgets.dart';

class PlotPanel extends StatelessWidget {
  const PlotPanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.onPlotCardTap,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final void Function(String cardID, String zone)? onPlotCardTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = PlotPanelMetrics.fromSize(constraints.biggest, tokens);
        return CommandPanelSurface(
          tokens: tokens,
          padding: EdgeInsets.all(metrics.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: model.table.phase == phaseRequisition ? 58 : 54,
                child: PanelTitleRow(
                  title: model.table.phase == phaseRequisition
                      ? language.text(en: 'Requisition', ru: 'Реквизиция')
                      : language.text(en: 'Private plot', ru: 'Личный участок'),
                  subtitle: plotHeaderSubtitle(model, language),
                  iconPath: model.table.phase == phaseRequisition
                      ? 'ios_resources/Icons/icon-requisition-north.png'
                      : 'ios_resources/Icons/icon-plot.png',
                  urgent: model.table.phase == phaseRequisition,
                  tokens: tokens,
                ),
              ),
              SizedBox(height: metrics.spacing),
              Expanded(
                child: model.table.phase == phaseRequisition
                    ? PlotRowsView(
                        model: model,
                        metrics: metrics,
                        tokens: tokens,
                        language: language,
                        prominent: false,
                        onPlotCardTap: onPlotCardTap,
                      )
                    : PlotOverviewView(
                        model: model,
                        metrics: metrics,
                        tokens: tokens,
                        onPlotCardTap: onPlotCardTap,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class GameOverPlotPanel extends StatelessWidget {
  const GameOverPlotPanel({
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
    final winnerScore = finalScoreForSeat(scores, winnerID);
    final winnerName = model.table.seats
        .firstWhere(
          (seat) => seat.id == winnerID,
          orElse: () => model.table.seats.first,
        )
        .name;

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = PlotPanelMetrics.fromSize(constraints.biggest, tokens);
        return CommandPanelSurface(
          tokens: tokens,
          padding: EdgeInsets.all(metrics.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: gameOverPlotHeaderHeight,
                child: PanelTitleRow(
                  title: language.text(en: 'Game Over', ru: 'Игра окончена'),
                  subtitle: language.text(
                    en: 'Winner: $winnerName - $winnerScore',
                    ru: 'Победитель: $winnerName - $winnerScore',
                  ),
                  iconPath: 'ios_resources/Icons/icon-medal-star.png',
                  tokens: tokens,
                ),
              ),
              SizedBox(height: metrics.spacing),
              Expanded(
                child: PlotRowsView(
                  model: model,
                  metrics: metrics,
                  tokens: tokens,
                  language: language,
                  prominent: true,
                  onPlotCardTap: null,
                ),
              ),
              SizedBox(height: metrics.spacing),
              SizedBox(
                height: gameOverPlotFooterHeight,
                child: Row(
                  spacing: metrics.spacing,
                  children: [
                    Expanded(
                      child: GameOverFinalScoreStrip(
                        seats: model.table.seats,
                        scores: scores,
                        winnerID: winnerID,
                        tokens: tokens,
                      ),
                    ),
                    ChromeAssetButton.command(
                      label: language.text(en: 'New game', ru: 'Новая игра'),
                      prominent: true,
                      tokens: tokens,
                      onPressed: onNewGame,
                      surfaceKey: const Key('game-over-new-game-button'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class GameOverFinalScoreStrip extends StatelessWidget {
  const GameOverFinalScoreStrip({
    required this.seats,
    required this.scores,
    required this.winnerID,
    required this.tokens,
    super.key,
  });

  final List<Seat> seats;
  final List<Score> scores;
  final int winnerID;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: gameOverScoreStripSpacing,
      children: [
        for (final seat in seats)
          Expanded(
            child: GameOverFinalScorePill(
              seat: seat,
              score: finalScoreForSeat(scores, seat.id),
              winner: seat.id == winnerID,
              tokens: tokens,
            ),
          ),
      ],
    );
  }
}

class GameOverFinalScorePill extends StatelessWidget {
  const GameOverFinalScorePill({
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
    final borderColor = winner
        ? tokens.colors.gold.withValues(alpha: 0.74)
        : tokens.colors.steel.withValues(alpha: 0.44);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: winner ? 0.26 : 0.16),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        border: Border.all(color: borderColor, width: winner ? 1.5 : 1),
      ),
      child: Row(
        spacing: 5,
        children: [
          Expanded(
            child: PixelText(
              seat.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              size: PixelTextSize.caption2,
              variant: winner
                  ? PixelTextVariant.heavy
                  : PixelTextVariant.regular,
              color: winner ? tokens.colors.gold : tokens.colors.cream,
            ),
          ),
          PixelText(
            '$score',
            size: PixelTextSize.caption,
            variant: PixelTextVariant.heavy,
            color: winner ? tokens.colors.gold : tokens.colors.cream,
          ),
        ],
      ),
    );
  }
}

const gameOverPlotHeaderHeight = 58.0;
const gameOverPlotFooterHeight = 40.0;
const gameOverScoreStripSpacing = 6.0;

class PlotRowsView extends StatelessWidget {
  const PlotRowsView({
    required this.model,
    required this.metrics,
    required this.tokens,
    required this.language,
    required this.prominent,
    this.onPlotCardTap,
    super.key,
  });

  final TableViewModel model;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool prominent;
  final void Function(String cardID, String zone)? onPlotCardTap;

  @override
  Widget build(BuildContext context) {
    final hiddenExiledCardIDs = hiddenExiledPlotCardIDs(model);
    final exiledCardIDs = requisitionExiledCardIDs(model);
    final viewer = localSeat(model);
    return Column(
      spacing: metrics.spacing,
      children: [
        for (final seat in model.table.seats)
          Expanded(
            child: PlotPlayerRow(
              seat: seat,
              viewerSeatID: viewer.id,
              model: model,
              metrics: metrics,
              tokens: tokens,
              hiddenExiledCardIDs: hiddenExiledCardIDs,
              exiledCardIDs: exiledCardIDs,
              prominent: prominent,
              onPlotCardTap: onPlotCardTap,
            ),
          ),
      ],
    );
  }
}

class PlotOverviewView extends StatelessWidget {
  const PlotOverviewView({
    required this.model,
    required this.metrics,
    required this.tokens,
    this.onPlotCardTap,
    super.key,
  });

  final TableViewModel model;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;
  final void Function(String cardID, String zone)? onPlotCardTap;

  @override
  Widget build(BuildContext context) {
    final hiddenExiledCardIDs = hiddenExiledPlotCardIDs(model);
    final exiledCardIDs = requisitionExiledCardIDs(model);
    final viewer = localSeat(model);
    final otherSeats = model.table.seats
        .where((seat) => seat.id != viewer.id)
        .toList(growable: false);
    final viewerHiddenCards = visiblePlotCards(
      viewer.plot.hidden,
      hiddenExiledCardIDs,
    );
    final viewerRevealedCards = visiblePlotCards(
      viewer.plot.revealed,
      hiddenExiledCardIDs,
    );
    final selectable = model.table.phase == phaseSwap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final opponentCount = otherSeats.length;
        final opponentSpacing =
            metrics.spacing * math.max(0, opponentCount - 1);
        final availableForOpponents = math.max(
          0.0,
          constraints.maxHeight - metrics.spacing - plotLocalAreaMinHeight,
        );
        final rawOpponentHeight = opponentCount == 0
            ? 0.0
            : (availableForOpponents - opponentSpacing) / opponentCount;
        final opponentHeightMin = math.min(
          plotOpponentRowHeightMin,
          math.max(0.0, rawOpponentHeight),
        );
        final opponentHeight = opponentCount == 0
            ? 0.0
            : clampDouble(
                rawOpponentHeight,
                opponentHeightMin,
                metrics.opponentHeight,
              );
        final opponentMetrics = metrics.copyWith(
          opponentHeight: opponentHeight,
        );

        return Column(
          spacing: metrics.spacing,
          children: [
            if (otherSeats.isNotEmpty)
              Column(
                spacing: metrics.spacing,
                children: [
                  for (final seat in otherSeats)
                    SizedBox(
                      height: opponentHeight,
                      child: OpponentPlotPanel(
                        seat: seat,
                        metrics: opponentMetrics,
                        tokens: tokens,
                        exiledCardIDs: exiledCardIDs,
                        hiddenExiledCardIDs: hiddenExiledCardIDs,
                      ),
                    ),
                ],
              ),
            Expanded(
              child: Row(
                spacing: metrics.spacing,
                children: [
                  Expanded(
                    child: LocalPlotColumn(
                      title: 'Cellar',
                      iconPath: 'ios_resources/Icons/icon-cellar.png',
                      cards: viewerHiddenCards,
                      hiddenCount: viewerHiddenCards.length,
                      hidden: true,
                      selectable: selectable,
                      selectedCardID: model.selection.plotCardID,
                      exiledCardIDs: exiledCardIDs,
                      metrics: metrics,
                      tokens: tokens,
                      onCardTap: (cardID) =>
                          onPlotCardTap?.call(cardID, plotZoneHidden),
                    ),
                  ),
                  Expanded(
                    child: LocalPlotColumn(
                      title: 'Plot',
                      iconPath: 'ios_resources/Icons/icon-plot.png',
                      cards: viewerRevealedCards,
                      stacks: viewer.plot.stacks,
                      hiddenCount: viewerRevealedCards.length,
                      hidden: false,
                      selectable: selectable,
                      selectedCardID: model.selection.plotCardID,
                      exiledCardIDs: exiledCardIDs,
                      metrics: metrics,
                      tokens: tokens,
                      onCardTap: (cardID) =>
                          onPlotCardTap?.call(cardID, plotZoneRevealed),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class PlotPlayerRow extends StatelessWidget {
  const PlotPlayerRow({
    required this.seat,
    required this.viewerSeatID,
    required this.model,
    required this.metrics,
    required this.tokens,
    required this.hiddenExiledCardIDs,
    required this.exiledCardIDs,
    required this.prominent,
    this.denseCards = false,
    this.onPlotCardTap,
    super.key,
  });

  final Seat seat;
  final int viewerSeatID;
  final TableViewModel model;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;
  final Set<String> hiddenExiledCardIDs;
  final Set<String> exiledCardIDs;
  final bool prominent;
  final bool denseCards;
  final void Function(String cardID, String zone)? onPlotCardTap;

  @override
  Widget build(BuildContext context) {
    final viewerRow = seat.id == viewerSeatID;
    final hiddenCards = visiblePlotCards(seat.plot.hidden, hiddenExiledCardIDs);
    final revealedCards = visiblePlotCards(
      seat.plot.revealed,
      hiddenExiledCardIDs,
    );
    final selectable = viewerRow && model.table.phase == phaseSwap;
    final playerWidth = prominent
        ? denseCards
              ? plotRowPlayerWidthProminent
              : plotRowPlayerWidthProminent
        : plotRowPlayerWidthCompact;
    return Container(
      padding: EdgeInsets.all(metrics.panelPadding),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: viewerRow ? 0.2 : 0.14),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        border: Border.all(
          color: viewerRow
              ? tokens.colors.gold.withValues(alpha: 0.42)
              : tokens.colors.steel.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        spacing: metrics.spacing,
        children: [
          SizedBox(
            width: playerWidth,
            child: PlotRowPlayerBadge(
              seat: seat,
              tokens: tokens,
              prominent: prominent,
            ),
          ),
          Expanded(
            child: PlotRowCardSection(
              title: 'Cellar',
              iconPath: 'ios_resources/Icons/icon-cellar.png',
              cards: hiddenCards,
              stacks: const [],
              hiddenCards: !viewerRow,
              hiddenCount: hiddenCards.length,
              selectable: selectable,
              selectedCardID: model.selection.plotCardID,
              zone: plotZoneHidden,
              exiledCardIDs: exiledCardIDs,
              metrics: metrics,
              tokens: tokens,
              prominent: prominent,
              denseCards: denseCards,
              onPlotCardTap: onPlotCardTap,
            ),
          ),
          Expanded(
            child: PlotRowCardSection(
              title: 'Plot',
              iconPath: 'ios_resources/Icons/icon-plot.png',
              cards: revealedCards,
              stacks: seat.plot.stacks,
              hiddenCards: false,
              hiddenCount: revealedCards.length,
              selectable: selectable,
              selectedCardID: model.selection.plotCardID,
              zone: plotZoneRevealed,
              exiledCardIDs: exiledCardIDs,
              metrics: metrics,
              tokens: tokens,
              prominent: prominent,
              denseCards: denseCards,
              onPlotCardTap: onPlotCardTap,
            ),
          ),
        ],
      ),
    );
  }
}

class PlotRowPlayerBadge extends StatelessWidget {
  const PlotRowPlayerBadge({
    required this.seat,
    required this.tokens,
    required this.prominent,
    super.key,
  });

  final Seat seat;
  final DesignTokens tokens;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final portraitSize = math.min(
          constraints.maxHeight * (prominent ? 0.64 : 0.54),
          prominent ? 76.0 : 52.0,
        );
        return Row(
          spacing: prominent ? 8 : 6,
          children: [
            SizedBox(
              width: portraitSize,
              height: portraitSize,
              child: PortraitFrame(
                seat: seat,
                tokens: tokens,
                width: portraitSize,
                height: portraitSize,
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  PixelText(
                    seat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    size: prominent
                        ? PixelTextSize.caption
                        : PixelTextSize.caption2,
                    variant: PixelTextVariant.heavy,
                    color: tokens.colors.cream,
                  ),
                  PixelText(
                    '${seat.visibleScore}',
                    size: PixelTextSize.caption2,
                    variant: PixelTextVariant.heavy,
                    color: tokens.colors.gold,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class PlotRowCardSection extends StatelessWidget {
  const PlotRowCardSection({
    required this.title,
    required this.iconPath,
    required this.cards,
    required this.stacks,
    required this.hiddenCards,
    required this.hiddenCount,
    required this.selectable,
    required this.selectedCardID,
    required this.zone,
    required this.exiledCardIDs,
    required this.metrics,
    required this.tokens,
    required this.prominent,
    required this.denseCards,
    this.onPlotCardTap,
    super.key,
  });

  final String title;
  final String iconPath;
  final List<TableCard> cards;
  final List<PlotStackState> stacks;
  final bool hiddenCards;
  final int hiddenCount;
  final bool selectable;
  final String? selectedCardID;
  final String zone;
  final Set<String> exiledCardIDs;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;
  final bool prominent;
  final bool denseCards;
  final void Function(String cardID, String zone)? onPlotCardTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: metrics.spacing,
      children: [
        SizedBox(
          width: prominent ? 84 : 68,
          child: Row(
            spacing: 5,
            children: [
              Image.asset(
                iconPath,
                width: metrics.headerIconSize,
                height: metrics.headerIconSize,
                filterQuality: FilterQuality.none,
              ),
              Expanded(
                child: PixelText(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  size: PixelTextSize.caption2,
                  variant: PixelTextVariant.heavy,
                  color: selectable ? tokens.colors.gold : tokens.colors.cream,
                ),
              ),
              PixelText(
                stacks.isEmpty
                    ? '$hiddenCount'
                    : '$hiddenCount+${stacks.length}',
                size: PixelTextSize.caption2,
                color: tokens.colors.smoke,
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemCount = gameOverPlotItemCount(cards, stacks);
              final cardSize = plotRowCardSize(
                tokens.card.large,
                constraints.biggest,
                itemCount,
                prominent: prominent,
                dense: denseCards,
              );
              final items = plotRowCardItems(
                cards: cards,
                stacks: stacks,
                hiddenCards: hiddenCards,
                cardSize: cardSize,
                selectedCardID: selectedCardID,
                selectable: selectable,
                zone: zone,
                exiledCardIDs: exiledCardIDs,
                tokens: tokens,
                onPlotCardTap: onPlotCardTap,
              );
              return Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: OverlappedCardRow(
                    itemWidth: cardSize.width,
                    itemHeight: cardSize.height,
                    spacing: gameOverPlotCardOverlap(
                      cardSize.width,
                      dense: denseCards,
                    ),
                    children: items.isEmpty
                        ? [
                            SizedBox(
                              width: cardSize.width,
                              height: cardSize.height,
                              child: Center(
                                child: PixelText(
                                  '-',
                                  size: PixelTextSize.title,
                                  variant: PixelTextVariant.heavy,
                                  color: tokens.colors.smoke.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                              ),
                            ),
                          ]
                        : items,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

List<Widget> plotRowCardItems({
  required List<TableCard> cards,
  required List<PlotStackState> stacks,
  required bool hiddenCards,
  required TokenCardSize cardSize,
  required String? selectedCardID,
  required bool selectable,
  required String zone,
  required Set<String> exiledCardIDs,
  required DesignTokens tokens,
  required void Function(String cardID, String zone)? onPlotCardTap,
}) {
  return [
    for (final card in cards)
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selectable ? () => onPlotCardTap?.call(card.id, zone) : null,
        child: PlotCardExileFrame(
          exiled: exiledCardIDs.contains(card.id),
          tokens: tokens,
          radius: tokens.radius.card,
          child: hiddenCards
              ? ScaledHighlightableCardBack(
                  card: selectedPlotCard(card, selectedCardID),
                  tokens: tokens,
                  size: cardSize,
                )
              : GameCard(
                  card: selectedPlotCard(card, selectedCardID),
                  tokens: tokens,
                  sizeOverride: cardSize,
                  motionTracked: false,
                ),
        ),
      ),
    for (final stack in stacks) ...[
      for (final card in stack.revealed.take(2))
        GameOverPlotCard(
          card: card,
          size: cardSize,
          exiled: exiledCardIDs.contains(card.id),
          tokens: tokens,
        ),
      if (stack.hidden.isNotEmpty)
        GameOverPlotHiddenStackBack(
          hiddenCount: stack.hidden.length,
          size: cardSize,
          tokens: tokens,
        ),
    ],
  ];
}

class GameOverPlotCard extends StatelessWidget {
  const GameOverPlotCard({
    required this.card,
    required this.size,
    required this.exiled,
    required this.tokens,
    super.key,
  });

  final TableCard card;
  final TokenCardSize size;
  final bool exiled;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return PlotCardExileFrame(
      exiled: exiled,
      tokens: tokens,
      radius: tokens.radius.card,
      child: GameCard(
        card: card,
        tokens: tokens,
        sizeOverride: size,
        motionTracked: false,
      ),
    );
  }
}

class GameOverPlotHiddenStackBack extends StatelessWidget {
  const GameOverPlotHiddenStackBack({
    required this.hiddenCount,
    required this.size,
    required this.tokens,
    super.key,
  });

  final int hiddenCount;
  final TokenCardSize size;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaledCardBack(tokens: tokens, size: size),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: tokens.colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(tokens.radius.xs),
          ),
          child: PixelText(
            '$hiddenCount',
            size: PixelTextSize.title,
            variant: PixelTextVariant.heavy,
            color: tokens.colors.gold,
          ),
        ),
      ],
    );
  }
}

class ScaledCardBack extends StatelessWidget {
  const ScaledCardBack({required this.tokens, required this.size, super.key});

  final DesignTokens tokens;
  final TokenCardSize size;

  @override
  Widget build(BuildContext context) {
    final scale = size.width / tokens.card.small.width;
    return NaturalSizeViewport(
      width: size.width,
      height: size.height,
      naturalWidth: tokens.card.small.width,
      naturalHeight: tokens.card.small.height,
      child: Transform.scale(
        alignment: Alignment.topLeft,
        scale: scale,
        child: CardBackMini(tokens: tokens),
      ),
    );
  }
}

class ScaledHighlightableCardBack extends StatelessWidget {
  const ScaledHighlightableCardBack({
    required this.card,
    required this.tokens,
    required this.size,
    super.key,
  });

  final TableCard card;
  final DesignTokens tokens;
  final TokenCardSize size;

  @override
  Widget build(BuildContext context) {
    final scale = size.width / tokens.card.small.width;
    return NaturalSizeViewport(
      width: size.width,
      height: size.height,
      naturalWidth: tokens.card.small.width,
      naturalHeight: tokens.card.small.height,
      child: Transform.scale(
        alignment: Alignment.topLeft,
        scale: scale,
        child: HighlightableCardBack(card: card, tokens: tokens),
      ),
    );
  }
}

TokenCardSize gameOverPlotCardSize(
  TokenCardSize base,
  Size available,
  int itemCount,
) {
  return plotRowCardSize(
    base,
    available,
    itemCount,
    prominent: true,
    dense: false,
  );
}

TokenCardSize plotRowCardSize(
  TokenCardSize base,
  Size available,
  int itemCount, {
  required bool prominent,
  bool dense = false,
}) {
  final availableWidth = available.width.isFinite
      ? available.width
      : (prominent
            ? plotRowFallbackWidthProminent
            : plotRowFallbackWidthCompact);
  final rawAvailableHeight = available.height.isFinite
      ? available.height
      : (prominent
            ? plotRowFallbackHeightProminent
            : plotRowFallbackHeightCompact);
  final availableHeight = math.min(
    rawAvailableHeight,
    prominent ? plotRowHeightCapProminent : plotRowHeightCapCompact,
  );
  final maxByHeight =
      (availableHeight *
          (dense
              ? plotGridCardHeightFill
              : prominent
              ? plotRowCardHeightFillProminent
              : plotRowCardHeightFillCompact)) /
      base.height;
  final overlapFraction = dense
      ? plotGridCardOverlapFraction
      : gameOverPlotCardOverlapFraction;
  final overlappedWidthUnits = 1 + (itemCount - 1) * (1 - overlapFraction);
  final maxByWidth =
      (availableWidth * 0.86) / (base.width * overlappedWidthUnits);
  final minScale = dense
      ? plotGridCardScaleMin
      : prominent
      ? gameOverPlotCardScaleMin
      : plotRowCardScaleMin;
  final heightAwareMinScale = math.min(minScale, maxByHeight);
  final scale = clampDouble(
    math.min(maxByHeight, maxByWidth),
    heightAwareMinScale,
    prominent ? gameOverPlotCardScaleMax : plotRowCardScaleMax,
  );
  return scaledPlotCardSize(base, scale);
}

int gameOverPlotItemCount(List<TableCard> cards, List<PlotStackState> stacks) {
  final stackCards = stacks.fold<int>(0, (count, stack) {
    final revealedCount = stack.revealed.length > 2 ? 2 : stack.revealed.length;
    return count + revealedCount + (stack.hidden.isEmpty ? 0 : 1);
  });
  return math.max(1, cards.length + stackCards);
}

TokenCardSize scaledPlotCardSize(TokenCardSize base, double scale) {
  return TokenCardSize(
    width: base.width * scale,
    height: base.height * scale,
    faceInset: base.faceInset * scale,
    cornerWidth: base.cornerWidth * scale,
    cornerHeight: base.cornerHeight * scale,
    cornerRankFontSize: base.cornerRankFontSize * scale,
    cornerSuitSize: base.cornerSuitSize * scale,
    topCornerRankSuitSpacing: base.topCornerRankSuitSpacing * scale,
    bottomCornerRankSuitSpacing: base.bottomCornerRankSuitSpacing * scale,
    topCornerSuitXOffset: base.topCornerSuitXOffset * scale,
    bottomCornerSuitXOffset: base.bottomCornerSuitXOffset * scale,
    pipSize: base.pipSize * scale,
  );
}

double gameOverPlotCardLeadingPadding(double cardWidth) =>
    clampDouble(cardWidth * 0.16, 12, 22);

double gameOverPlotCardOverlap(double cardWidth, {bool dense = false}) {
  final overlapFraction = dense
      ? plotGridCardOverlapFraction
      : gameOverPlotCardOverlapFraction;
  final overlapMax = dense
      ? plotGridCardOverlapMax
      : gameOverPlotCardOverlapMax;
  return -clampDouble(
    cardWidth * overlapFraction,
    gameOverPlotCardOverlapMin,
    overlapMax,
  );
}

const gameOverPlotCardScaleMin = 0.88;
const gameOverPlotCardScaleMax = 1.45;
const plotRowCardScaleMin = 0.42;
const plotRowCardScaleMax = 1.35;
const plotGridCardScaleMin = 0.62;
const plotRowCardHeightFillCompact = 0.92;
const plotRowCardHeightFillProminent = 0.74;
const plotGridCardHeightFill = 0.84;
const gameOverPlotCardOverlapFraction = 0.18;
const plotGridCardOverlapFraction = 0.34;
const gameOverPlotCardOverlapMin = 18.0;
const gameOverPlotCardOverlapMax = 36.0;
const plotGridCardOverlapMax = 48.0;
const plotRowPlayerWidthCompact = 116.0;
const plotRowPlayerWidthProminent = 150.0;
const plotRowFallbackWidthCompact = 260.0;
const plotRowFallbackWidthProminent = 420.0;
const plotRowFallbackHeightCompact = 72.0;
const plotRowFallbackHeightProminent = 128.0;
const plotRowHeightCapCompact = 86.0;
const plotRowHeightCapProminent = 150.0;
const plotLocalAreaMinHeight = 140.0;
const plotOpponentRowHeightMin = 56.0;

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
    final spacing = clampDouble(shorter * 0.02, 7, 10);
    final opponentHeight = clampDouble(
      size.height * 0.18,
      plot.opponentHeightMin,
      plot.opponentHeightMax,
    );
    final panelPadding = clampDouble(shorter * 0.018, 7, 8);
    final portraitMaxForRow = opponentHeight - (panelPadding * 2) - 3.0 - 20.0;
    final portraitMax = math.min(
      plot.portraitSizeMax,
      math.max(30.0, portraitMaxForRow),
    );
    final portraitMin = math.min(plot.portraitSizeMin, portraitMax);
    return PlotPanelMetrics(
      spacing: spacing,
      padding: clampDouble(shorter * 0.025, 8, 12),
      opponentHeight: opponentHeight,
      opponentCardScale: clampDouble(size.width * 0.001, 0.68, 0.76),
      opponentCardFrameWidth: clampDouble(size.width * 0.04, 25, 29),
      opponentCardFrameHeight: clampDouble(size.height * 0.10, 38, 44),
      opponentVisibleCardCount: clampDouble(
        size.width / 190,
        plot.opponentVisibleCardCountMin,
        plot.opponentVisibleCardCountMax,
      ).toInt(),
      portraitSize: clampDouble(size.width * 0.055, portraitMin, portraitMax),
      panelPadding: panelPadding,
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

  PlotPanelMetrics copyWith({
    double? spacing,
    double? padding,
    double? opponentHeight,
    double? opponentCardScale,
    double? opponentCardFrameWidth,
    double? opponentCardFrameHeight,
    int? opponentVisibleCardCount,
    double? portraitSize,
    double? panelPadding,
    double? headerIconSize,
    double? columnCardSpacing,
    double? columnTrailingPadding,
  }) {
    return PlotPanelMetrics(
      spacing: spacing ?? this.spacing,
      padding: padding ?? this.padding,
      opponentHeight: opponentHeight ?? this.opponentHeight,
      opponentCardScale: opponentCardScale ?? this.opponentCardScale,
      opponentCardFrameWidth:
          opponentCardFrameWidth ?? this.opponentCardFrameWidth,
      opponentCardFrameHeight:
          opponentCardFrameHeight ?? this.opponentCardFrameHeight,
      opponentVisibleCardCount:
          opponentVisibleCardCount ?? this.opponentVisibleCardCount,
      portraitSize: portraitSize ?? this.portraitSize,
      panelPadding: panelPadding ?? this.panelPadding,
      headerIconSize: headerIconSize ?? this.headerIconSize,
      columnCardSpacing: columnCardSpacing ?? this.columnCardSpacing,
      columnTrailingPadding:
          columnTrailingPadding ?? this.columnTrailingPadding,
    );
  }
}

class OpponentPlotPanel extends StatelessWidget {
  const OpponentPlotPanel({
    required this.seat,
    required this.metrics,
    required this.tokens,
    required this.exiledCardIDs,
    required this.hiddenExiledCardIDs,
    super.key,
  });

  final Seat seat;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;
  final Set<String> exiledCardIDs;
  final Set<String> hiddenExiledCardIDs;

  @override
  Widget build(BuildContext context) {
    final visibleHiddenCards = visiblePlotCards(
      seat.plot.hidden,
      hiddenExiledCardIDs,
    );
    final visibleRevealedCards = visiblePlotCards(
      seat.plot.revealed,
      hiddenExiledCardIDs,
    );
    final vulnerable = hasExiledPlotCard;
    return MotionTrackedRegion(
      motionKey: plotCardMotionSourceKey(seat.id),
      child: Container(
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
                  SizedBox(
                    width: metrics.portraitSize,
                    height: metrics.portraitSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PortraitFrame(
                          seat: seat,
                          tokens: tokens,
                          width: metrics.portraitSize,
                          height: metrics.portraitSize,
                        ),
                        if (vulnerable)
                          Positioned(
                            top: -3,
                            right: -4,
                            child: Image.asset(
                              'ios_resources/Icons/icon-status-vulnerable.png',
                              width: 14,
                              height: 14,
                              filterQuality: FilterQuality.none,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PixelText(
                    seat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    size: PixelTextSize.caption2,
                    variant: PixelTextVariant.heavy,
                    color: tokens.colors.cream,
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
                      value: '${visibleHiddenCards.length}',
                      cards: visibleHiddenCards,
                      hidden: true,
                      metrics: metrics,
                      tokens: tokens,
                      exiledCardIDs: exiledCardIDs,
                    ),
                  ),
                  Expanded(
                    child: OpponentPlotMiniSection(
                      iconPath: 'ios_resources/Icons/icon-plot.png',
                      value: '${visiblePlotScore(seat, hiddenExiledCardIDs)}',
                      cards: visibleRevealedCards,
                      hidden: false,
                      metrics: metrics,
                      tokens: tokens,
                      exiledCardIDs: exiledCardIDs,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get hasExiledPlotCard {
    return visiblePlotCards(
          seat.plot.hidden,
          hiddenExiledCardIDs,
        ).any((card) => exiledCardIDs.contains(card.id)) ||
        visiblePlotCards(
          seat.plot.revealed,
          hiddenExiledCardIDs,
        ).any((card) => exiledCardIDs.contains(card.id));
  }
}

class OpponentPlotMiniSection extends StatelessWidget {
  const OpponentPlotMiniSection({
    required this.iconPath,
    required this.value,
    required this.cards,
    required this.hidden,
    required this.metrics,
    required this.tokens,
    required this.exiledCardIDs,
    super.key,
  });

  final String iconPath;
  final String value;
  final List<TableCard> cards;
  final bool hidden;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;
  final Set<String> exiledCardIDs;

  @override
  Widget build(BuildContext context) {
    const visibleCardLimit = 2;
    final cardWidgets = <Widget>[
      for (final card in cards.take(visibleCardLimit))
        NaturalSizeViewport(
          width: metrics.opponentCardFrameWidth,
          height: metrics.opponentCardFrameHeight,
          naturalWidth: tokens.card.small.width,
          naturalHeight: tokens.card.small.height,
          child: Transform.scale(
            alignment: Alignment.topLeft,
            scale:
                metrics.opponentCardScale *
                (exiledCardIDs.contains(card.id) ? 1.08 : 1),
            child: PlotCardExileFrame(
              exiled: exiledCardIDs.contains(card.id),
              radius: opponentPlotMiniExileRadius,
              tokens: tokens,
              child: hidden
                  ? MotionTrackedCard(
                      card: card,
                      child: CardBackMini(tokens: tokens),
                    )
                  : GameCard(card: card, tokens: tokens, small: true),
            ),
          ),
        ),
      if (cards.isEmpty)
        SizedBox(
          width: metrics.opponentCardFrameWidth,
          height: metrics.opponentCardFrameHeight,
          child: Center(
            child: PixelText(
              '-',
              size: PixelTextSize.caption,
              variant: PixelTextVariant.heavy,
              color: tokens.colors.smoke.withValues(alpha: 0.72),
            ),
          ),
        ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(opponentPlotMiniSectionRadius),
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
                  filterQuality: FilterQuality.none,
                ),
                PixelText(
                  value,
                  size: PixelTextSize.caption2,
                  variant: PixelTextVariant.heavy,
                  color: tokens.colors.gold,
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
    this.stacks = const [],
    required this.hiddenCount,
    required this.hidden,
    required this.selectable,
    required this.selectedCardID,
    required this.exiledCardIDs,
    required this.metrics,
    required this.tokens,
    this.onCardTap,
    super.key,
  });

  final String title;
  final String iconPath;
  final List<TableCard> cards;
  final List<PlotStackState> stacks;
  final int hiddenCount;
  final bool hidden;
  final bool selectable;
  final String? selectedCardID;
  final Set<String> exiledCardIDs;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;
  final ValueChanged<String>? onCardTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(metrics.padding),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        border: Border.all(
          color: selectable
              ? tokens.colors.gold.withValues(alpha: 0.58)
              : tokens.colors.steel.withValues(alpha: 0.5),
          width: selectable ? 1.5 : 1,
        ),
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
                filterQuality: FilterQuality.none,
              ),
              PixelText(
                title.toUpperCase(),
                size: PixelTextSize.caption,
                variant: PixelTextVariant.heavy,
                color: tokens.colors.gold,
              ),
              const Spacer(),
              PixelText(
                stacks.isEmpty
                    ? '$hiddenCount'
                    : '$hiddenCount+${stacks.length}',
                size: PixelTextSize.caption2,
                color: tokens.colors.smoke,
              ),
            ],
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemCount = gameOverPlotItemCount(cards, stacks);
                final cardSize = plotRowCardSize(
                  tokens.card.large,
                  constraints.biggest,
                  itemCount,
                  prominent: true,
                );
                final cardWidgets = plotRowCardItems(
                  cards: cards,
                  stacks: stacks,
                  hiddenCards: hidden,
                  cardSize: cardSize,
                  selectedCardID: selectedCardID,
                  selectable: selectable,
                  zone: hidden ? plotZoneHidden : plotZoneRevealed,
                  exiledCardIDs: exiledCardIDs,
                  tokens: tokens,
                  onPlotCardTap: (cardID, _) => onCardTap?.call(cardID),
                );
                final children = cardWidgets.isEmpty
                    ? [
                        SizedBox(
                          width: cardSize.width,
                          height: cardSize.height,
                          child: Center(
                            child: PixelText(
                              '-',
                              size: PixelTextSize.title,
                              variant: PixelTextVariant.heavy,
                              color: tokens.colors.smoke.withValues(
                                alpha: 0.72,
                              ),
                            ),
                          ),
                        ),
                      ]
                    : cardWidgets;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 2,
                      bottom: 2,
                      right: metrics.columnTrailingPadding,
                    ),
                    child: OverlappedCardRow(
                      itemWidth: cardSize.width,
                      itemHeight: cardSize.height,
                      spacing: gameOverPlotCardOverlap(cardSize.width),
                      children: children,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PlotStackMini extends StatelessWidget {
  const PlotStackMini({
    required this.stack,
    required this.index,
    required this.metrics,
    required this.tokens,
    super.key,
  });

  final PlotStackState stack;
  final int index;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final revealed = stack.revealed;
    final hidden = stack.hidden;
    return Container(
      key: ValueKey('plot-stack-mini-$index'),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.colors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.32)),
      ),
      child: Row(
        spacing: 4,
        children: [
          for (final card in revealed.take(2))
            GameCard(card: card, tokens: tokens, small: true),
          if (hidden.isNotEmpty)
            Stack(
              alignment: Alignment.center,
              children: [
                CardBackMini(tokens: tokens),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(tokens.radius.xs),
                  ),
                  child: PixelText(
                    '${hidden.length}',
                    size: PixelTextSize.caption2,
                    variant: PixelTextVariant.heavy,
                    color: tokens.colors.gold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class PlotCardExileFrame extends StatelessWidget {
  const PlotCardExileFrame({
    required this.exiled,
    required this.tokens,
    required this.child,
    this.radius = cardViewCornerRadius,
    super.key,
  });

  final bool exiled;
  final DesignTokens tokens;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (!exiled) {
      return child;
    }
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tokens.colors.redBright, width: 3),
      ),
      child: child,
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

  final TableCard card;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final border = card.selected
        ? tokens.colors.green
        : card.highlighted
        ? tokens.colors.gold
        : Colors.transparent;
    return MotionTrackedCard(
      card: card,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardViewCornerRadius),
          border: Border.all(
            color: border,
            width: card.selected || card.highlighted ? tokens.stroke.active : 0,
          ),
        ),
        child: CardBackMini(tokens: tokens),
      ),
    );
  }
}

class CardBackMini extends StatelessWidget {
  const CardBackMini({required this.tokens, super.key});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardViewCornerRadius),
        boxShadow: [
          BoxShadow(
            color: tokens.colors.black.withValues(
              alpha: tokens.colors.cardStrokeOpacity,
            ),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        width: tokens.card.small.width,
        height: tokens.card.small.height,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardViewCornerRadius),
          border: Border.all(
            color: tokens.colors.black.withValues(
              alpha: tokens.colors.cardStrokeOpacity,
            ),
            width: cardViewStrokeWidth,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cardViewCornerRadius),
          child: Image.asset(
            'ios_resources/Cards/card-back.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, _, _) => ColoredBox(color: tokens.colors.iron),
          ),
        ),
      ),
    );
  }
}
