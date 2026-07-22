import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

const playerPanelActiveShadowOpacity = 0.18;
const playerPanelInactiveShadowOpacity = 0.24;
const playerPanelShadowRadius = 4.0;

double playerPanelScale(double height) => clampDouble(height / 48, 1, 2.35);

double playerPanelOuterInset(double width, [double height = 48]) =>
    clampDouble(width * 0.04, 5, 7) * playerPanelScale(height);

double playerPanelPortraitColumnWidth(double width, double height) =>
    math.min(math.max(34, width * 0.28), math.max(34, height * 0.92));

double playerPanelPortraitSize(double width, double height) {
  final outerInset = playerPanelOuterInset(width, height);
  final naturalSize =
      math.max(24, height - outerInset * 2 - 2 * playerPanelScale(height)) *
      1.1;
  return clampDouble(naturalSize, 24, height * 0.75);
}

double playerPanelPortraitLeft(double width, double portraitSize) =>
    math.max(0, width * 0.18 - portraitSize / 2);

double playerPanelPortraitTop(double height, double portraitSize) =>
    math.max(0, height * 0.5 - portraitSize / 2);

double playerPanelContentLeft(double width) => width * 0.35;
double playerPanelContentRight(double width) => width * 0.86;
double playerPanelNameTop(double height) => height * 0.29;
double playerPanelScoreTop(double height) => height * 0.22;
double playerPanelLowerStatsTop(double height) => height * 0.51;

double playerPanelRowSpacing(double width, [double height = 48]) =>
    clampDouble(width * 0.025, 3, 5) * playerPanelScale(height);

double playerPanelStackSpacing(double width) =>
    clampDouble(width * 0.01, -1, -1);

double playerPanelStatColumnWidth(double width, [double height = 48]) =>
    clampDouble(width * 0.22, 44, 50) * playerPanelScale(height);

double playerPanelTopPadding(double height) => clampDouble(height * 0.07, 2, 8);

double playerPanelContentNaturalWidth(double width) {
  final statWidth = playerPanelStatColumnWidth(width);
  return math.max(80, statWidth * 2 + playerPanelRowSpacing(width) + 8);
}

double playerPanelContentNaturalWidthForSize(double width, double height) {
  final statWidth = playerPanelStatColumnWidth(width, height);
  return math.max(
    80 * playerPanelScale(height),
    statWidth * 2 + playerPanelRowSpacing(width, height) + 8,
  );
}

double playerPanelCellarCardSpacing(double width, [double height = 48]) =>
    -clampDouble(width * 0.03, 5, 6) * playerPanelScale(height);

const brigadePanelLocalPadding = EdgeInsets.only(top: 8);
const brigadeColumnSpacingWidthFactor = 0.012;
const brigadeColumnSpacingMin = 8.0;
const brigadeColumnSpacingMax = 14.0;
const brigadeColumnMinHeight = 120.0;
const brigadeColumnPadding = EdgeInsets.only(
  left: 8,
  top: 6,
  right: 8,
  bottom: 4,
);
const brigadePlayerPanelAspectRatio = 672 / 262;
const brigadePlayerPanelHeightMin = 42.0;
const brigadePlayObjectWidthFactor = 0.9;
const brigadePlayAreaTopInset = 10.0;
const brigadeColumnContentBottomPadding = 4.0;

double brigadeColumnSpacing(double width) => clampDouble(
  width * brigadeColumnSpacingWidthFactor,
  brigadeColumnSpacingMin,
  brigadeColumnSpacingMax,
);

double brigadeExpandedColumnWidth({
  required double maxWidth,
  required int columnCount,
  required double spacing,
}) {
  if (columnCount <= 0) return 0;
  return math.max(0, (maxWidth - spacing * (columnCount - 1)) / columnCount);
}

double brigadeColumnHeight(double availableHeight) => math.max(
  brigadeColumnMinHeight,
  availableHeight - brigadePanelLocalPadding.vertical,
);

double brigadeContentColumnHeight({
  required double playerPanelHeight,
  required double playObjectHeight,
}) => math.max(
  brigadeColumnMinHeight,
  brigadeColumnPadding.vertical +
      playerPanelHeight +
      brigadePlayAreaTopInset +
      playObjectHeight +
      brigadeColumnContentBottomPadding,
);

double brigadePanelHeightForWidth({
  required double maxWidth,
  required int columnCount,
  required double minCardWidth,
  required double cardAspectRatio,
}) {
  final spacing = brigadeColumnSpacing(maxWidth);
  final columnWidth = brigadeExpandedColumnWidth(
    maxWidth: maxWidth,
    columnCount: columnCount,
    spacing: spacing,
  );
  final playerPanelHeight = brigadePlayerPanelHeight(
    brigadePlayerPanelWidth(columnWidth),
  );
  final playObjectWidth = brigadePlayObjectWidth(
    columnWidth: columnWidth,
    minWidth: minCardWidth,
  );
  return brigadePanelLocalPadding.vertical +
      brigadeContentColumnHeight(
        playerPanelHeight: playerPanelHeight,
        playObjectHeight: brigadePlayObjectHeight(
          playObjectWidth,
          cardAspectRatio,
        ),
      );
}

double brigadeColumnContentWidth(double columnWidth) =>
    math.max(0, columnWidth - brigadeColumnPadding.horizontal);

double brigadePlayerPanelWidth(double columnWidth) =>
    brigadeColumnContentWidth(columnWidth);

double brigadePlayerPanelHeight(double panelWidth) => math.max(
  brigadePlayerPanelHeightMin,
  panelWidth / brigadePlayerPanelAspectRatio,
);

double brigadePlayObjectWidth({
  required double columnWidth,
  required double minWidth,
}) => clampDouble(
  brigadeColumnContentWidth(columnWidth) * brigadePlayObjectWidthFactor,
  minWidth,
  double.infinity,
);

double brigadePlayObjectMaxHeight(
  double columnHeight,
  double playerPanelHeight,
) => math.max(
  0,
  columnHeight -
      brigadeColumnPadding.vertical -
      playerPanelHeight -
      brigadePlayAreaTopInset -
      brigadeColumnContentBottomPadding,
);

double brigadePlayObjectFittingWidth({
  required double desiredWidth,
  required double maxHeight,
  required double aspectRatio,
}) {
  if (aspectRatio <= 0) return desiredWidth;
  return math.max(0, math.min(desiredWidth, maxHeight / aspectRatio));
}

double brigadePlayObjectHeight(double width, double aspectRatio) =>
    width * aspectRatio;

class TrumpActionOption {
  const TrumpActionOption({
    required this.suit,
    required this.label,
    required this.action,
  });

  final String suit;
  final String label;
  final LegalAction? action;

  bool get enabled => action != null;
}

List<TrumpActionOption> planningTrumpOptions(
  List<LegalAction> actions, {
  KolkhozLanguage? language,
}) {
  final bySuit = {
    for (final action in actions)
      if (action.kind == actionSetTrump && action.engineAction.suit != null)
        action.engineAction.suit!: action,
  };
  return displaySuitOrder
      .map(
        (suit) => TrumpActionOption(
          suit: suit,
          label: (language ?? KolkhozLanguage.en).suitName(suit),
          action: bySuit[suit],
        ),
      )
      .toList(growable: false);
}
