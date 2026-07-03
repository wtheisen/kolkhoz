import 'dart:ui' show clampDouble;

const optionsPanelMaxWidth = 620.0;
const optionsPanelHorizontalPadding = 20.0;
const optionsPanelOuterShadowOpacity = 0.5;
const optionsPanelOuterShadowRadius = 16.0;
const optionsPanelOuterShadowYOffset = 8.0;
const optionsPanelContentMinHeight = 206.0;
const optionsPanelContentMaxHeight = 360.0;
const optionsPanelSurfaceVerticalPadding = 24.0;
const optionsPanelSurfaceMinHeight =
    optionsPanelContentMinHeight + optionsPanelSurfaceVerticalPadding;
const optionsPanelSurfaceMaxHeight =
    optionsPanelContentMaxHeight + optionsPanelSurfaceVerticalPadding;
const optionsMenuSectionSpacingFactor = 0.035;
const optionsMenuSectionSpacingMin = 7.0;
const optionsMenuSectionSpacingMax = 10.0;
const optionsMenuActionsSpacing = 10.0;
const optionsMenuControlsSpacing = 8.0;
const optionsMenuRulesSpacing = 8.0;
const optionsMenuChromeToggleSpacing = 8.0;
const optionsMenuContentBottomPadding = 6.0;
const optionsMenuHeaderIconSize = 18.0;
const optionsMenuHeaderSpacing = 8.0;
const optionsMenuHeaderFontSize = 17.0;
const optionsMenuSectionLabelFontSize = 11.0;
const optionsMenuRulesHeaderFontSize = 15.0;
const optionsMenuActionWidth = 170.0;
const optionsReadabilityButtonWidth = 190.0;
const optionsMenuActionHeight = 34.0;
const optionsMenuActionHorizontalPadding = 12.0;
const optionsMenuActionContentSpacing = 7.0;
const optionsMenuActionIconSize = 15.0;
const optionsMenuActionFontSize = 13.0;
const optionsReadabilityGlyphBoxWidth = 24.0;
const optionsReadabilityFontSize = 13.0;
const optionsChromeToggleSize = 48.0;
const optionsChromeToggleIconSize = 25.0;

double optionsMenuSectionSpacing(double height) {
  return clampDouble(
    height * optionsMenuSectionSpacingFactor,
    optionsMenuSectionSpacingMin,
    optionsMenuSectionSpacingMax,
  );
}
