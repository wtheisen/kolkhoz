import 'dart:ui' show clampDouble;

const panelTitleScaleBaseWidth = 520.0;
const panelTitleScaleMin = 0.78;
const panelTitleScaleMax = 1.0;
const panelTitleIconBoxBase = 40.0;
const panelTitleIconSizeBase = 24.0;
const panelTitleHorizontalPaddingBase = 9.0;
const panelTitleVerticalPaddingBase = 7.0;
const panelTitleSpacingBase = 10.0;
const panelTitleOrnamentWidth = 104.0;
const panelTitleOrnamentHeight = 24.0;
const panelTitleOrnamentTrailingPadding = 8.0;
const panelTitleOrnamentFadeStartWidth = 320.0;
const panelTitleOrnamentFadeDistance = 180.0;
const panelTitleOrnamentMaxOpacity = 0.52;
const panelTitleUrgentOrnamentMaxOpacity = 0.42;

double panelTitleScale(double width) {
  return clampDouble(
    width / panelTitleScaleBaseWidth,
    panelTitleScaleMin,
    panelTitleScaleMax,
  );
}

double panelTitleIconBox(double width) =>
    panelTitleIconBoxBase * panelTitleScale(width);

double panelTitleIconSize(double width) =>
    panelTitleIconSizeBase * panelTitleScale(width);

double panelTitleHorizontalPadding(double width) =>
    panelTitleHorizontalPaddingBase * panelTitleScale(width);

double panelTitleVerticalPadding(double width) =>
    panelTitleVerticalPaddingBase * panelTitleScale(width);

double panelTitleSpacing(double width) =>
    panelTitleSpacingBase * panelTitleScale(width);

double panelTitleOrnamentOpacity(double width, {required bool urgent}) {
  return clampDouble(
    (width - panelTitleOrnamentFadeStartWidth) / panelTitleOrnamentFadeDistance,
    0,
    urgent ? panelTitleUrgentOrnamentMaxOpacity : panelTitleOrnamentMaxOpacity,
  );
}

double panelTitleEffectiveOrnamentOpacity(
  double width, {
  required bool urgent,
}) {
  return panelTitleOrnamentOpacity(width, urgent: urgent);
}
