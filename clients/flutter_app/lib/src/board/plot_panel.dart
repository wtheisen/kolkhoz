part of '../board_view.dart';

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
    final viewer = localSeat(model);
    final opponents = model.table.seats
        .where((seat) => seat.id != viewer.id)
        .toList(growable: false);
    final exiledCardIDs = requisitionExiledCardIDs(model);
    final hiddenExiledCardIDs = hiddenExiledPlotCardIDs(model);
    final viewerHiddenCards = visiblePlotCards(
      viewer.plot.hidden,
      hiddenExiledCardIDs,
    );
    final viewerRevealedCards = visiblePlotCards(
      viewer.plot.revealed,
      hiddenExiledCardIDs,
    );
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
                          exiledCardIDs: exiledCardIDs,
                          hiddenExiledCardIDs: hiddenExiledCardIDs,
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
                        title: language.text(en: 'Cellar', ru: 'Подвал'),
                        iconPath: 'ios_resources/Icons/icon-cellar.png',
                        cards: viewerHiddenCards,
                        hiddenCount: viewerHiddenCards.length,
                        hidden: false,
                        selectable: model.table.phase == phaseSwap,
                        selectedCardID: model.selection.plotCardID,
                        exiledCardIDs: exiledCardIDs,
                        metrics: metrics,
                        tokens: tokens,
                        onCardTap: onPlotCardTap == null
                            ? null
                            : (cardID) =>
                                  onPlotCardTap!(cardID, plotZoneHidden),
                      ),
                    ),
                    Expanded(
                      child: LocalPlotColumn(
                        title: language.text(en: 'Plot', ru: 'Участок'),
                        iconPath: 'ios_resources/Icons/icon-plot.png',
                        cards: viewerRevealedCards,
                        stacks: viewer.plot.stacks,
                        hiddenCount: viewerRevealedCards.length,
                        hidden: false,
                        selectable: model.table.phase == phaseSwap,
                        selectedCardID: model.selection.plotCardID,
                        exiledCardIDs: exiledCardIDs,
                        metrics: metrics,
                        tokens: tokens,
                        onCardTap: onPlotCardTap == null
                            ? null
                            : (cardID) =>
                                  onPlotCardTap!(cardID, plotZoneRevealed),
                      ),
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
      ).toInt(),
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
                  ? CardBackMini(tokens: tokens)
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
    final cardWidgets = <Widget>[
      for (final card in cards)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: selectable ? () => onCardTap?.call(card.id) : null,
          child: PlotCardExileFrame(
            exiled: exiledCardIDs.contains(card.id),
            tokens: tokens,
            child: hidden
                ? HighlightableCardBack(
                    card: selectedPlotCard(card, selectedCardID),
                    tokens: tokens,
                  )
                : GameCard(
                    card: selectedPlotCard(card, selectedCardID),
                    tokens: tokens,
                    small: true,
                  ),
          ),
        ),
      if (cards.isEmpty)
        SizedBox(
          width: tokens.card.small.width,
          height: tokens.card.small.height,
          child: Center(
            child: PixelText(
              '-',
              size: PixelTextSize.title,
              variant: PixelTextVariant.heavy,
              color: tokens.colors.smoke.withValues(alpha: 0.72),
            ),
          ),
        ),
    ];
    final contentWidgets = <Widget>[
      OverlappedCardRow(
        itemWidth: tokens.card.small.width,
        itemHeight: tokens.card.small.height,
        spacing: metrics.columnCardSpacing,
        children: cardWidgets,
      ),
      for (final (index, stack) in stacks.indexed)
        PlotStackMini(
          key: ValueKey('plot-stack-$index'),
          stack: stack,
          index: index,
          metrics: metrics,
          tokens: tokens,
        ),
    ];

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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: EdgeInsets.only(
                  top: 2,
                  bottom: 2,
                  right: metrics.columnTrailingPadding,
                ),
                child: Row(
                  spacing: metrics.spacing * 0.7,
                  children: contentWidgets,
                ),
              ),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardViewCornerRadius),
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
