import 'dart:math' as math;
import 'dart:ui' show clampDouble;

const playerPanelActiveShadowOpacity = 0.18;
const playerPanelInactiveShadowOpacity = 0.24;
const playerPanelShadowRadius = 4.0;

double playerPanelOuterInset(double width) => clampDouble(width * 0.04, 5, 7);

double playerPanelPortraitColumnWidth(double width, double height) {
  return math.min(math.max(34, width * 0.28), math.max(34, height * 1.08));
}

double playerPanelPortraitSize(double width, double height) {
  final outerInset = playerPanelOuterInset(width);
  return clampDouble(math.max(24, height - outerInset * 2 - 2), 24, 40);
}

double playerPanelRowSpacing(double width) => clampDouble(width * 0.025, 3, 5);

double playerPanelStackSpacing(double width) =>
    clampDouble(width * 0.01, -1, -1);

double playerPanelStatColumnWidth(double width) =>
    clampDouble(width * 0.22, 44, 50);

double playerPanelTopPadding(double height) => clampDouble(height * 0.07, 2, 4);

double playerPanelContentNaturalWidth(double width) {
  final statWidth = playerPanelStatColumnWidth(width);
  return math.max(80, statWidth * 2 + playerPanelRowSpacing(width) + 8);
}

double playerPanelCellarCardSpacing(double width) {
  return -clampDouble(width * 0.03, 5, 6);
}
