import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/widgets.dart' show EdgeInsets;

const brigadePanelLocalPadding = EdgeInsets.only(top: 8);
const brigadeColumnSpacingWidthFactor = 0.012;
const brigadeColumnSpacingMin = 8.0;
const brigadeColumnSpacingMax = 14.0;
const brigadeColumnMinHeight = 120.0;
const brigadeColumnPadding = EdgeInsets.only(
  left: 8,
  top: 6,
  right: 8,
  bottom: 10,
);
const brigadePlayerPanelAspectRatio = 672 / 262;
const brigadePlayerPanelHeightMin = 42.0;
const brigadePlayObjectWidthFactor = 0.9;
const brigadePlayAreaTopInset = 10.0;
const brigadeColumnContentBottomPadding = 12.0;

double brigadeColumnSpacing(double width) {
  return clampDouble(
    width * brigadeColumnSpacingWidthFactor,
    brigadeColumnSpacingMin,
    brigadeColumnSpacingMax,
  );
}

double brigadeExpandedColumnWidth({
  required double maxWidth,
  required int columnCount,
  required double spacing,
}) {
  if (columnCount <= 0) {
    return 0;
  }
  return math.max(0, (maxWidth - spacing * (columnCount - 1)) / columnCount);
}

double brigadeColumnHeight(double availableHeight) {
  return math.max(
    brigadeColumnMinHeight,
    availableHeight - brigadePanelLocalPadding.vertical,
  );
}

double brigadeContentColumnHeight({
  required double playerPanelHeight,
  required double playObjectHeight,
}) {
  return math.max(
    brigadeColumnMinHeight,
    brigadeColumnPadding.vertical +
        playerPanelHeight +
        brigadePlayAreaTopInset +
        playObjectHeight +
        brigadeColumnContentBottomPadding,
  );
}

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

double brigadeColumnContentWidth(double columnWidth) {
  return math.max(0, columnWidth - brigadeColumnPadding.horizontal);
}

double brigadePlayerPanelWidth(double columnWidth) {
  return brigadeColumnContentWidth(columnWidth);
}

double brigadePlayerPanelHeight(double panelWidth) {
  return math.max(
    brigadePlayerPanelHeightMin,
    panelWidth / brigadePlayerPanelAspectRatio,
  );
}

double brigadePlayObjectWidth({
  required double columnWidth,
  required double minWidth,
}) {
  return clampDouble(
    brigadeColumnContentWidth(columnWidth) * brigadePlayObjectWidthFactor,
    minWidth,
    double.infinity,
  );
}

double brigadePlayObjectMaxHeight(
  double columnHeight,
  double playerPanelHeight,
) {
  return math.max(
    0,
    columnHeight -
        brigadeColumnPadding.vertical -
        playerPanelHeight -
        brigadePlayAreaTopInset -
        brigadeColumnContentBottomPadding,
  );
}

double brigadePlayObjectFittingWidth({
  required double desiredWidth,
  required double maxHeight,
  required double aspectRatio,
}) {
  if (aspectRatio <= 0) {
    return desiredWidth;
  }
  return math.max(0, math.min(desiredWidth, maxHeight / aspectRatio));
}

double brigadePlayObjectHeight(double width, double aspectRatio) =>
    width * aspectRatio;
