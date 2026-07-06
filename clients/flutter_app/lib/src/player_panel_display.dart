import 'dart:math' as math;
import 'dart:ui' show clampDouble;

const playerPanelActiveShadowOpacity = 0.18;
const playerPanelInactiveShadowOpacity = 0.24;
const playerPanelShadowRadius = 4.0;

double playerPanelScale(double height) => clampDouble(height / 48, 1, 2.35);

double playerPanelOuterInset(double width, [double height = 48]) =>
    clampDouble(width * 0.04, 5, 7) * playerPanelScale(height);

double playerPanelPortraitColumnWidth(double width, double height) {
  return math.min(math.max(34, width * 0.28), math.max(34, height * 0.92));
}

double playerPanelPortraitSize(double width, double height) {
  final outerInset = playerPanelOuterInset(width, height);
  final naturalSize =
      math.max(24, height - outerInset * 2 - 2 * playerPanelScale(height)) *
      1.1;
  return clampDouble(naturalSize, 24, height * 0.75);
}

double playerPanelPortraitLeft(double width, double portraitSize) {
  return math.max(0, width * 0.18 - portraitSize / 2);
}

double playerPanelPortraitTop(double height, double portraitSize) {
  return math.max(0, height * 0.5 - portraitSize / 2);
}

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

double playerPanelCellarCardSpacing(double width, [double height = 48]) {
  return -clampDouble(width * 0.03, 5, 6) * playerPanelScale(height);
}
