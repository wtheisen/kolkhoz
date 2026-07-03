import 'dart:ui' show clampDouble;

import 'render_model.dart';
import 'table_display.dart';

const hotSeatScrimOpacity = 0.96;
const hotSeatPanelWidthFactor = 0.58;
const hotSeatPanelMinWidth = 300.0;
const hotSeatPanelMaxWidth = 470.0;
const hotSeatPanelHorizontalPadding = 20.0;
const hotSeatPanelVerticalPadding = 18.0;
const hotSeatContentSpacing = 14.0;
const hotSeatTitleRowHeight = 62.0;
const hotSeatPlacardMaxWidth = 310.0;
const hotSeatPlacardMaxHeight = 78.0;
const hotSeatPlacardOpacity = 0.92;
const hotSeatPortraitHeightFactor = 0.20;
const hotSeatPortraitMinSize = 58.0;
const hotSeatPortraitMaxSize = 86.0;
const hotSeatPortraitShadowOpacity = 0.35;
const hotSeatPortraitShadowRadius = 8.0;
const hotSeatPortraitShadowYOffset = 4.0;
const hotSeatLabelSpacing = 4.0;
const hotSeatPhaseLineFontSize = 13.0;
const hotSeatReadyButtonMaxWidth = 210.0;

double hotSeatPanelWidth(double availableWidth) {
  return clampDouble(
    availableWidth * hotSeatPanelWidthFactor,
    hotSeatPanelMinWidth,
    hotSeatPanelMaxWidth,
  );
}

double hotSeatPortraitSlotSize(double availableHeight) {
  return clampDouble(
    availableHeight * hotSeatPortraitHeightFactor,
    hotSeatPortraitMinSize,
    hotSeatPortraitMaxSize,
  );
}

Seat hotSeatPrivacyPlayer(TableViewModel model) {
  return localSeat(model);
}
