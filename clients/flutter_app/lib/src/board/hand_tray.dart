import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../app_text.dart';
import '../assignment_display.dart';
import '../card_display.dart';
import '../chrome_button.dart';
import '../design_tokens.dart';
import '../game_constants.dart';
import '../lower_bar_actions.dart';
import '../render_model.dart';
import '../table_display.dart';
import 'board_widgets.dart';

const handTrayOuterSpacing = 8.0;
const handTrayZoneHorizontalPadding = 6.0;
const handTrayZoneSpacing = 6.0;
const handTrayIconFrameWidth = 34.0;
const handTrayIconSize = 32.0;
const handTrayCardSpacing = 10.0;
const handTrayCardYOffset = 8.0;
const handTrayAssignmentWidth = 290.0;
const handTrayAssignmentDividerWidth = 2.0;
const handTrayAssignmentDividerTopMargin = 5.0;
const handTrayAssignmentCardsYOffset = 4.0;
const handTrayActionButtonSize = 48.0;
const handTrayActionIconSize = 34.0;
const handTrayActionSpacing = 8.0;
const handTrayActionBarPadding = 6.0;
const handTraySwapHighlightStrokeWidth = 2.0;
const handTraySwapHighlightCornerRadius = 7.0;
const handTrayCardHeightFillFactor = 1.0;
const handTrayCardMinScale = 0.65;
const handTrayCardMaxScale = 3.0;

bool handCardCanReceiveTap(TableViewModel model, TableCard card) {
  return switch (model.table.phase) {
    phaseTrick || phaseSwap => card.highlighted,
    _ => false,
  };
}

bool handCardCanShowInvalidHint(TableViewModel model, TableCard card) {
  return model.table.phase == phaseTrick &&
      model.table.currentPlayerID == localSeat(model).id &&
      !card.highlighted;
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

LegalAction? selectedHandCardPlayAction(TableViewModel model) {
  final selectedCardID = model.selection.handCardID;
  if (model.table.phase != phaseTrick || selectedCardID == null) {
    return null;
  }
  for (final action in model.legalActions) {
    if (action.kind == actionPlayCard &&
        action.engineAction.card?.id == selectedCardID) {
      return action;
    }
  }
  return null;
}

bool assignmentCommandBarVisible(TableViewModel model) {
  if (model.table.phase != phaseAssignment) {
    return false;
  }
  final winnerID = model.table.lastTrick.winnerSeatID;
  if (winnerID == null) {
    return false;
  }
  final winner = seatByID(model, winnerID);
  return winner != null && winner.isViewer && isHumanControlledSeat(winner);
}

bool handCardMatchesPlanningTrumpFocus(
  TableViewModel model,
  TableCard card,
  String? focusedSuit,
) {
  return model.table.phase == phasePlanning &&
      focusedSuit != null &&
      (card.suit == focusedSuit || card.suit == wreckerSuit);
}

TableCard handTrayCard(
  TableViewModel model,
  TableCard card, {
  String? planningTrumpFocusedSuit,
}) {
  final showHighlight = switch (model.table.phase) {
    phaseTrick || phaseSwap => card.highlighted,
    phasePlanning => handCardMatchesPlanningTrumpFocus(
      model,
      card,
      planningTrumpFocusedSuit,
    ),
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
  String? planningTrumpFocusedSuit,
  required Color swapHighlightColor,
  required Color playableHighlightColor,
}) {
  if (handCardMatchesPlanningTrumpFocus(
    model,
    card,
    planningTrumpFocusedSuit,
  )) {
    return playableHighlightColor;
  }
  if (model.table.phase == phaseSwap && card.highlighted && !card.selected) {
    return swapHighlightColor;
  }
  if (model.table.phase == phaseTrick && card.highlighted) {
    return playableHighlightColor;
  }
  return null;
}

EdgeInsets handTrayOuterPadding({required double trailing}) {
  return EdgeInsets.only(right: trailing + 16);
}

double handTrayCardScale(
  double visibleTrayHeight,
  TokenCardSize cardSize, {
  double? availableWidth,
  int cardCount = 0,
}) {
  final heightScale = clampDouble(
    (visibleTrayHeight * handTrayCardHeightFillFactor - handTrayCardYOffset) /
        cardSize.height,
    1,
    handTrayCardMaxScale,
  );
  if (availableWidth == null || cardCount <= 0) {
    return heightScale;
  }
  final spacingWidth = math.max(0, cardCount - 1) * handTrayCardSpacing;
  final widthScale =
      (availableWidth - spacingWidth) / (cardSize.width * cardCount);
  return clampDouble(
    math.min(heightScale, widthScale),
    handTrayCardMinScale,
    handTrayCardMaxScale,
  );
}

TokenCardSize scaledHandTrayCardSize(
  TokenCardSize cardSize,
  double visibleTrayHeight, {
  double? availableWidth,
  int cardCount = 0,
}) {
  final scale = handTrayCardScale(
    visibleTrayHeight,
    cardSize,
    availableWidth: availableWidth,
    cardCount: cardCount,
  );
  return scaledHandTrayCardSizeForScale(cardSize, scale);
}

TokenCardSize fittedHandTrayCardSize(
  TokenCardSize cardSize,
  double visibleTrayHeight,
  double availableWidth,
  int cardCount,
) {
  return scaledHandTrayCardSize(
    cardSize,
    visibleTrayHeight,
    availableWidth: availableWidth,
    cardCount: cardCount,
  );
}

TokenCardSize scaledHandTrayCardSizeForScale(
  TokenCardSize cardSize,
  double scale,
) {
  return TokenCardSize(
    width: cardSize.width * scale,
    height: cardSize.height * scale,
    faceInset: cardSize.faceInset * scale,
    cornerWidth: cardSize.cornerWidth * scale,
    cornerHeight: cardSize.cornerHeight * scale,
    cornerRankFontSize: cardSize.cornerRankFontSize * scale,
    cornerSuitSize: cardSize.cornerSuitSize * scale,
    topCornerRankSuitSpacing: cardSize.topCornerRankSuitSpacing * scale,
    bottomCornerRankSuitSpacing: cardSize.bottomCornerRankSuitSpacing * scale,
    topCornerSuitXOffset: cardSize.topCornerSuitXOffset * scale,
    bottomCornerSuitXOffset: cardSize.bottomCornerSuitXOffset * scale,
    pipSize: cardSize.pipSize * scale,
  );
}

class HandTray extends StatelessWidget {
  const HandTray({
    required this.model,
    required this.tokens,
    required this.language,
    required this.visibleTrayHeight,
    this.onAction,
    this.onSwapHandCardTap,
    this.onTrickHandCardTap,
    this.onAssignmentCardTap,
    this.onInvalidHandCardTap,
    this.canUndo = false,
    this.onUndo,
    this.planningTrumpFocusedSuit,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final double visibleTrayHeight;
  final ValueChanged<LegalAction>? onAction;
  final ValueChanged<String>? onSwapHandCardTap;
  final ValueChanged<String>? onTrickHandCardTap;
  final ValueChanged<String>? onAssignmentCardTap;
  final VoidCallback? onInvalidHandCardTap;
  final bool canUndo;
  final VoidCallback? onUndo;
  final String? planningTrumpFocusedSuit;

  @override
  Widget build(BuildContext context) {
    final localPlayer = localSeat(model);
    final hand = localPlayer.hand.toList(growable: false)
      ..sort(compareCardsForHand);
    final assignmentCards = assignmentControlCards(model);
    final lowerBarActions = model.legalActions
        .where((action) => lowerBarActionKinds.contains(action.kind))
        .toList(growable: false);
    final selectedPlayAction = selectedHandCardPlayAction(model);
    final showAssignmentCommandBar =
        assignmentCards.isNotEmpty && assignmentCommandBarVisible(model);
    return Padding(
      padding: handTrayOuterPadding(
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final largeCardSize = fittedHandTrayCardSize(
                          tokens.card.large,
                          visibleTrayHeight,
                          constraints.maxWidth,
                          hand.length,
                        );
                        return KolkhozScrollbar(
                          tokens: tokens,
                          orientation: ScrollbarOrientation.bottom,
                          childBuilder: (context, scrollController) => SingleChildScrollView(
                            controller: scrollController,
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
                                        final onTap = switch (model
                                            .table
                                            .phase) {
                                          phaseTrick =>
                                            playAction != null &&
                                                    onTrickHandCardTap != null
                                                ? () => onTrickHandCardTap!(
                                                    card.id,
                                                  )
                                                : handCardCanShowInvalidHint(
                                                    model,
                                                    card,
                                                  )
                                                ? onInvalidHandCardTap
                                                : null,
                                          phaseSwap =>
                                            onSwapHandCardTap == null
                                                ? null
                                                : () => onSwapHandCardTap!(
                                                    card.id,
                                                  ),
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
                                                  handCardCanReceiveTap(
                                                        model,
                                                        card,
                                                      ) ||
                                                      handCardCanShowInvalidHint(
                                                        model,
                                                        card,
                                                      )
                                                  ? onTap
                                                  : null,
                                              child: GameCard(
                                                card: handTrayCard(
                                                  model,
                                                  card,
                                                  planningTrumpFocusedSuit:
                                                      planningTrumpFocusedSuit,
                                                ),
                                                tokens: tokens,
                                                trump: model.table.trump,
                                                sizeOverride: largeCardSize,
                                                highlightColorOverride:
                                                    handTrayHighlightColor(
                                                      model,
                                                      card,
                                                      planningTrumpFocusedSuit:
                                                          planningTrumpFocusedSuit,
                                                      swapHighlightColor:
                                                          tokens.colors.red,
                                                      playableHighlightColor:
                                                          tokens.colors.green,
                                                    ),
                                                highlightGlowEnabled:
                                                    model.table.phase !=
                                                    phaseSwap,
                                                highlightedStrokeWidthOverride:
                                                    model.table.phase ==
                                                        phaseSwap
                                                    ? handTraySwapHighlightStrokeWidth
                                                    : null,
                                                highlightedBorderRadiusOverride:
                                                    model.table.phase ==
                                                        phaseSwap
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
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showAssignmentCommandBar)
            AssignmentCommandBar(
              cards: assignmentCards,
              selectedCardID: model.selection.assignmentCardID,
              trump: model.table.trump,
              tokens: tokens,
              visibleTrayHeight: visibleTrayHeight,
              onCardTap: onAssignmentCardTap,
            )
          else if (selectedPlayAction != null ||
              lowerBarActions.isNotEmpty ||
              canUndo)
            ActionCommandBar(
              actions: lowerBarActions,
              selectedPlayAction: selectedPlayAction,
              tableYear: model.table.year,
              tokens: tokens,
              language: language,
              visibleTrayHeight: visibleTrayHeight,
              onAction: onAction,
              canUndo: canUndo,
              onUndo: onUndo,
            ),
          if (showAssignmentCommandBar && canUndo)
            ActionCommandBar(
              actions: const [],
              tableYear: model.table.year,
              tokens: tokens,
              language: language,
              visibleTrayHeight: visibleTrayHeight,
              canUndo: canUndo,
              onUndo: onUndo,
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
    this.selectedPlayAction,
    required this.tableYear,
    required this.tokens,
    required this.language,
    required this.visibleTrayHeight,
    this.canUndo = false,
    this.onUndo,
    this.onAction,
    super.key,
  });

  final List<LegalAction> actions;
  final LegalAction? selectedPlayAction;
  final int tableYear;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final double visibleTrayHeight;
  final bool canUndo;
  final VoidCallback? onUndo;
  final ValueChanged<LegalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final orderedActions = actions.toList(growable: false)
      ..sort(compareLowerBarActions);
    final selectedPlayAction = this.selectedPlayAction;
    final commands = [
      if (canUndo)
        HandTrayCommand(
          label: language.t(KolkhozText.boardHandtrayUndo),
          iconAsset: 'icon-toolbar-undo.png',
          prominent: false,
          onPressed: onUndo,
        ),
      if (selectedPlayAction != null)
        HandTrayCommand(
          label: language.t(KolkhozText.boardHandtrayPlay),
          iconAsset: 'icon-toolbar-play.png',
          prominent: true,
          onPressed: onAction == null
              ? null
              : () => onAction!(selectedPlayAction),
        )
      else
        for (final action in orderedActions)
          HandTrayCommand(
            label: lowerBarActionLabel(
              action,
              tableYear: tableYear,
              language: language,
            ),
            iconAsset: lowerBarActionIconAsset(action),
            prominent: isProminentLowerBarAction(action),
            onPressed: onAction == null ? null : () => onAction!(action),
          ),
    ];
    return SizedBox(
      width: actionBarWidth(commands.length),
      height: visibleTrayHeight,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8,
            children: [
              for (final command in commands)
                ActionIconButton(
                  label: command.label,
                  iconAsset: command.iconAsset,
                  tokens: tokens,
                  prominent: command.prominent,
                  onPressed: command.onPressed,
                ),
            ],
          ),
        ),
      ),
    );
  }

  double actionBarWidth(int commandCount) {
    final visibleCommands = math.max(1, commandCount);
    return handTrayActionBarPadding * 2 +
        visibleCommands * handTrayActionButtonSize +
        math.max(0, visibleCommands - 1) * handTrayActionSpacing;
  }
}

class HandTrayCommand {
  const HandTrayCommand({
    required this.label,
    required this.iconAsset,
    required this.prominent,
    this.onPressed,
  });

  final String label;
  final String iconAsset;
  final bool prominent;
  final VoidCallback? onPressed;
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

class ActionIconButton extends StatelessWidget {
  const ActionIconButton({
    required this.label,
    required this.iconAsset,
    required this.tokens,
    required this.prominent,
    this.scale = 1,
    this.onPressed,
    super.key,
  });

  final String label;
  final String iconAsset;
  final DesignTokens tokens;
  final bool prominent;
  final double scale;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = SizedBox(
      width: handTrayActionButtonSize * scale,
      height: handTrayActionButtonSize * scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ChromeButtonBackground(asset: chromeButtonSecondaryAsset),
          ),
          ChromeAssetIcon(
            asset: 'ios_resources/Icons/$iconAsset',
            width: handTrayActionIconSize * scale,
            height: handTrayActionIconSize * scale,
            fit: BoxFit.contain,
            muted: !enabled,
          ),
        ],
      ),
    );
    final child = enabled ? button : Opacity(opacity: 0.55, child: button);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: DecoratedBox(
              decoration: BoxDecoration(
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
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

const assignmentCommandSelectedRadius = 7.0;
const assignmentCommandSelectedStrokeWidth = 3.0;
const assignmentCommandSelectedShadowOpacity = 0.38;
const assignmentCommandSelectedShadowRadius = 9.0;
const assignmentCommandSelectedShadowYOffset = 2.0;
