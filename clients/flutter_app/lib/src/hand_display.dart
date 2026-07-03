import 'package:flutter/material.dart' show Color, EdgeInsets;

import 'card_display.dart';
import 'game_constants.dart';
import 'render_model.dart';

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
