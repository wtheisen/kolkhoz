part of '../board_view.dart';

const handTrayOuterSpacing = 8.0;
const handTrayZoneHorizontalPadding = 6.0;
const handTrayZoneSpacing = 6.0;
const handTrayIconFrameWidth = 34.0;
const handTrayIconSize = 32.0;
const handTrayCardSpacing = 10.0;
const handTrayCardYOffset = 8.0;
const handTrayAssignmentWidth = 290.0;
const handTrayActionSingleWidth = 150.0;
const handTrayActionDoubleWidth = 268.0;
const handTrayAssignmentDividerWidth = 2.0;
const handTrayAssignmentDividerTopMargin = 5.0;
const handTrayAssignmentCardsYOffset = 4.0;
const handTrayProminentActionWidth = 132.0;
const handTraySecondaryActionWidth = 88.0;
const handTrayProminentActionHeight = 36.0;
const handTraySecondaryActionHeight = 32.0;
const handTraySwapHighlightStrokeWidth = 2.0;
const handTraySwapHighlightCornerRadius = 7.0;
const handTrayActionFontSize = 13.0;

bool handCardCanReceiveTap(TableViewModel model, TableCard card) {
  return switch (model.table.phase) {
    phaseTrick || phaseSwap => card.highlighted,
    _ => false,
  };
}

LegalAction? handCardPlayAction(TableViewModel model, TableCard card) {
  if (model.table.phase != phaseTrick) {
    return null;
  }
  for (final action in model.legalActions) {
    if (action.kind == actionPlayCard &&
        action.engineAction.card?.id == card.id) {
      return action;
    }
  }
  return null;
}

TableCard handTrayCard(TableViewModel model, TableCard card) {
  final showHighlight = switch (model.table.phase) {
    phaseTrick || phaseSwap => card.highlighted,
    _ => false,
  };
  final selected = card.selected || card.id == model.selection.handCardID;
  if (showHighlight == card.highlighted && selected == card.selected) {
    return card;
  }
  return cardWithSelection(
    card,
    selected: selected,
    highlighted: showHighlight,
  );
}

Color? handTrayHighlightColor(
  TableViewModel model,
  TableCard card, {
  required Color swapHighlightColor,
}) {
  if (model.table.phase == phaseSwap && card.highlighted && !card.selected) {
    return swapHighlightColor;
  }
  return null;
}

EdgeInsets handTrayOuterPadding({
  required double leading,
  required double trailing,
}) {
  return EdgeInsets.only(left: leading + 16, right: trailing + 16);
}

class HandTray extends StatelessWidget {
  const HandTray({
    required this.model,
    required this.tokens,
    required this.metrics,
    required this.language,
    this.onAction,
    this.onSwapHandCardTap,
    this.onAssignmentCardTap,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;
  final KolkhozLanguage language;
  final ValueChanged<LegalAction>? onAction;
  final ValueChanged<String>? onSwapHandCardTap;
  final ValueChanged<String>? onAssignmentCardTap;

  @override
  Widget build(BuildContext context) {
    final localPlayer = localSeat(model);
    final hand = localPlayer.hand.toList(growable: false)
      ..sort(compareCardsForHand);
    final assignmentCards = assignmentControlCards(model);
    final lowerBarActions = model.legalActions
        .where((action) => lowerBarActionKinds.contains(action.kind))
        .toList(growable: false);
    final visibleTrayHeight = metrics.handTrayVisibleHeight;
    final largeCardSize = tokens.card.large;
    return Padding(
      padding: handTrayOuterPadding(
        leading: tokens.spacing.handTrayHorizontalLeading,
        trailing: tokens.spacing.handTrayHorizontalTrailing,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: handTrayOuterSpacing,
        children: [
          Expanded(
            child: Container(
              height: visibleTrayHeight,
              padding: const EdgeInsets.symmetric(
                horizontal: handTrayZoneHorizontalPadding,
              ),
              decoration: BoxDecoration(
                color: tokens.colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(tokens.radius.sm),
                border: Border.all(
                  color: tokens.colors.steel.withValues(alpha: 0.32),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: handTrayZoneSpacing,
                children: [
                  SizedBox(
                    width: handTrayIconFrameWidth,
                    height: visibleTrayHeight,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Image.asset(
                        'ios_resources/Icons/icon-hand.png',
                        width: handTrayIconSize,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: SizedBox(
                        height: visibleTrayHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: handTrayCardSpacing,
                          children: [
                            for (final card in hand)
                              Builder(
                                builder: (context) {
                                  final playAction = handCardPlayAction(
                                    model,
                                    card,
                                  );
                                  final onTap = switch (model.table.phase) {
                                    phaseTrick =>
                                      playAction == null || onAction == null
                                          ? null
                                          : () => onAction!(playAction),
                                    phaseSwap =>
                                      onSwapHandCardTap == null
                                          ? null
                                          : () => onSwapHandCardTap!(card.id),
                                    _ => null,
                                  };
                                  return NaturalSizeViewport(
                                    width: largeCardSize.width,
                                    height: visibleTrayHeight,
                                    naturalWidth: largeCardSize.width,
                                    naturalHeight: largeCardSize.height,
                                    clipBehavior: Clip.none,
                                    child: Transform.translate(
                                      offset: const Offset(
                                        0,
                                        handTrayCardYOffset,
                                      ),
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap:
                                            handCardCanReceiveTap(model, card)
                                            ? onTap
                                            : null,
                                        child: GameCard(
                                          card: handTrayCard(model, card),
                                          tokens: tokens,
                                          trump: model.table.trump,
                                          sizeOverride: largeCardSize,
                                          highlightColorOverride:
                                              handTrayHighlightColor(
                                                model,
                                                card,
                                                swapHighlightColor:
                                                    tokens.colors.red,
                                              ),
                                          highlightGlowEnabled:
                                              model.table.phase != phaseSwap,
                                          highlightedStrokeWidthOverride:
                                              model.table.phase == phaseSwap
                                              ? handTraySwapHighlightStrokeWidth
                                              : null,
                                          highlightedBorderRadiusOverride:
                                              model.table.phase == phaseSwap
                                              ? handTraySwapHighlightCornerRadius
                                              : null,
                                        ),
                                      ),
                                    ),
                                  );
                                },
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
          if (assignmentCards.isNotEmpty)
            AssignmentCommandBar(
              cards: assignmentCards,
              selectedCardID: model.selection.assignmentCardID,
              trump: model.table.trump,
              tokens: tokens,
              visibleTrayHeight: visibleTrayHeight,
              onCardTap: onAssignmentCardTap,
            )
          else if (lowerBarActions.isNotEmpty)
            ActionCommandBar(
              actions: lowerBarActions,
              tableYear: model.table.year,
              tokens: tokens,
              language: language,
              visibleTrayHeight: visibleTrayHeight,
              onAction: onAction,
            ),
        ],
      ),
    );
  }
}

class ActionCommandBar extends StatelessWidget {
  const ActionCommandBar({
    required this.actions,
    required this.tableYear,
    required this.tokens,
    required this.language,
    required this.visibleTrayHeight,
    this.onAction,
    super.key,
  });

  final List<LegalAction> actions;
  final int tableYear;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final double visibleTrayHeight;
  final ValueChanged<LegalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final orderedActions = actions.toList(growable: false)
      ..sort(compareLowerBarActions);
    return SizedBox(
      width: actionBarWidth,
      height: visibleTrayHeight,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8,
            children: [
              for (final action in orderedActions)
                ActionPill(
                  action: action,
                  tableYear: tableYear,
                  tokens: tokens,
                  language: language,
                  prominent: isProminentLowerBarAction(action),
                  onPressed: onAction == null ? null : () => onAction!(action),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double get actionBarWidth {
    if (actions.length <= 1) {
      return handTrayActionSingleWidth;
    }
    return handTrayActionDoubleWidth;
  }
}

class AssignmentCommandBar extends StatelessWidget {
  const AssignmentCommandBar({
    required this.cards,
    required this.selectedCardID,
    required this.trump,
    required this.tokens,
    required this.visibleTrayHeight,
    this.onCardTap,
    super.key,
  });

  final List<TableCard> cards;
  final String? selectedCardID;
  final String? trump;
  final DesignTokens tokens;
  final double visibleTrayHeight;
  final ValueChanged<String>? onCardTap;

  @override
  Widget build(BuildContext context) {
    final mediumCardSize = tokens.card.medium;
    return SizedBox(
      width: handTrayAssignmentWidth,
      height: visibleTrayHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Container(
            width: handTrayAssignmentDividerWidth,
            height: visibleTrayHeight - 10,
            margin: const EdgeInsets.only(
              top: handTrayAssignmentDividerTopMargin,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  tokens.colors.gold.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, handTrayAssignmentCardsYOffset),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  for (final card in cards)
                    NaturalSizeViewport(
                      width: mediumCardSize.width,
                      height: visibleTrayHeight,
                      naturalWidth: mediumCardSize.width,
                      naturalHeight: mediumCardSize.height,
                      clipBehavior: Clip.none,
                      child: AssignmentCommandCard(
                        card: card,
                        tokens: tokens,
                        trump: trump,
                        selected: card.id == selectedCardID,
                        sizeOverride: mediumCardSize,
                        onTap: () => onCardTap?.call(card.id),
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

class AssignmentCommandCard extends StatelessWidget {
  const AssignmentCommandCard({
    required this.card,
    required this.tokens,
    required this.trump,
    required this.selected,
    required this.sizeOverride,
    this.onTap,
    super.key,
  });

  final TableCard card;
  final DesignTokens tokens;
  final String? trump;
  final bool selected;
  final TokenCardSize sizeOverride;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: tokens.colors.gold.withValues(
                      alpha: assignmentCommandSelectedShadowOpacity,
                    ),
                    blurRadius: assignmentCommandSelectedShadowRadius,
                    offset: const Offset(
                      0,
                      assignmentCommandSelectedShadowYOffset,
                    ),
                  ),
                ]
              : const [],
        ),
        child: Stack(
          children: [
            GameCard(
              card: cardWithSelection(card, highlighted: false),
              tokens: tokens,
              trump: trump,
              sizeOverride: sizeOverride,
            ),
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        assignmentCommandSelectedRadius,
                      ),
                      border: Border.all(
                        color: tokens.colors.gold,
                        width: assignmentCommandSelectedStrokeWidth,
                      ),
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

class ActionPill extends StatelessWidget {
  const ActionPill({
    required this.action,
    required this.tableYear,
    required this.tokens,
    required this.language,
    required this.prominent,
    this.scale = 1,
    this.onPressed,
    super.key,
  });

  final LegalAction action;
  final int tableYear;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool prominent;
  final double scale;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width:
            (prominent
                ? handTrayProminentActionWidth
                : handTraySecondaryActionWidth) *
            scale,
        height:
            (prominent
                ? handTrayProminentActionHeight
                : handTraySecondaryActionHeight) *
            scale,
        padding: EdgeInsets.only(
          left: (prominent ? 20 : 16) * scale,
          right: (prominent ? 20 : 16) * scale,
          top: (prominent ? 8 : 7) * scale,
          bottom: (prominent ? 6 : 5) * scale,
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
              blurRadius: (prominent ? 5 : 3) * scale,
              offset: Offset(0, 2 * scale),
            ),
          ],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: HandTrayActionPillLabel(
              lowerBarActionLabel(
                action,
                tableYear: tableYear,
                language: language,
              ).toUpperCase(),
              prominent: prominent,
              tokens: tokens,
            ),
          ),
        ),
      ),
    );
  }
}

class HandTrayActionPillLabel extends StatelessWidget {
  const HandTrayActionPillLabel(
    this.label, {
    required this.prominent,
    required this.tokens,
    super.key,
  });

  final String label;
  final bool prominent;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ChromePixelLabel(
      label.toUpperCase(),
      size: PixelTextSize.caption,
      color: prominent ? tokens.colors.onAccent : tokens.colors.cream,
    );
  }
}

const assignmentCommandSelectedRadius = 7.0;
const assignmentCommandSelectedStrokeWidth = 3.0;
const assignmentCommandSelectedShadowOpacity = 0.38;
const assignmentCommandSelectedShadowRadius = 9.0;
const assignmentCommandSelectedShadowYOffset = 2.0;
