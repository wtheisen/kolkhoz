import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/widgets.dart' show EdgeInsets;

const brigadeColumnSpacingFill = 0.72;
const brigadeColumnPlayerPanelScale = 1.6;
const brigadePlayAreaScale = 1.8;
const brigadePlayerPanelHeight = 40.0;
const brigadePanelLocalPadding = EdgeInsets.only(top: 8);

double brigadeColumnWidth({
  required double maxWidth,
  required double mediumCardWidth,
}) {
  return math.max(
    mediumCardWidth * brigadeColumnPlayerPanelScale,
    clampDouble(maxWidth * 0.18, 96, 120),
  );
}

double brigadeSlotWidth(double columnWidth) =>
    clampDouble(columnWidth * 0.52, 44, 76);

double brigadePlayAreaLeftOffset({
  required double playerPanelWidth,
  required double playAreaWidth,
}) {
  return (playerPanelWidth - playAreaWidth) / 2;
}

double brigadePlayAreaTopOffset(double columnWidth) =>
    clampDouble(columnWidth * 0.15, 18, 24);

double brigadeColumnOverlap(double columnWidth) =>
    clampDouble(columnWidth * 0.055, 2, 6);
