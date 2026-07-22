import 'dart:math' as math;
import 'dart:ui' show Size, clampDouble;

import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';

class ResponsiveBoardMetrics {
  const ResponsiveBoardMetrics({
    required this.tokens,
    required this.scale,
    required this.margin,
  });

  factory ResponsiveBoardMetrics.fromSize(Size size, DesignTokens tokens) {
    final shortestSide = math.max(1.0, size.shortestSide);
    final scale = clampDouble(math.sqrt(shortestSide / 375), 0.9, 2.05);
    final margin = clampDouble(
      shortestSide * 0.01,
      tokens.spacing.boardOuterMarginMin,
      tokens.spacing.boardOuterMarginMax,
    );
    return ResponsiveBoardMetrics(tokens: tokens, scale: scale, margin: margin);
  }

  final DesignTokens tokens;
  final double scale;
  final double margin;

  double railWidth(double contentWidth) {
    return clampDouble(
      contentWidth * tokens.layout.board.railWidthFactor,
      tokens.layout.board.railWidthMin,
      tokens.layout.board.railWidthMax,
    );
  }

  double get separatorWidth =>
      math.max(1, tokens.layout.board.railSeparatorWidth);

  double get playAreaSeparatorThickness =>
      tokens.layout.board.playAreaSeparatorThickness;

  double get playAreaHorizontalPadding => tokens.spacing.md;

  double get panelContentBottomPadding => 4;

  double get railHorizontalPadding => _boardRailHorizontalPadding;

  double get railVerticalPadding => _boardRailVerticalPadding;

  double get railSpacing => _boardRailButtonSpacing;

  double get railButtonSize => _boardRailButtonSize;

  double get railIconSize => _boardRailPanelIconSize;

  double get topInfoHeight => tokens.layout.topInfo.height;

  double get handTrayHeight => tokens.layout.board.handTrayHeight;

  double get handTrayVisibleHeight => handTrayVisibleHeightMin;

  double handTrayLayoutHeightForBoardHeight(double boardHeight) {
    final responsiveHeight =
        handTrayHeight +
        math.max(0, boardHeight - handTrayResponsiveStartHeight) *
            handTrayResponsiveGrowthFactor;
    return clampDouble(
      responsiveHeight,
      handTrayHeight,
      handTrayLayoutHeightMax,
    );
  }

  double handTrayVisibleHeightForBoardHeight(double boardHeight) {
    return handTrayVisibleHeightForLayoutHeight(
      handTrayLayoutHeightForBoardHeight(boardHeight),
    );
  }

  double handTrayVisibleHeightForLayoutHeight(double layoutHeight) {
    return clampDouble(
      layoutHeight + handTrayVisibleOverhang,
      handTrayVisibleHeightMin,
      handTrayVisibleHeightMax,
    );
  }

  double handTrayHeightForVisibleHeight(double visibleHeight) {
    return math.max(handTrayHeight, visibleHeight - handTrayVisibleOverhang);
  }

  double scaledClamp(double value, double min, double max) {
    return clampDouble(value, min * scale, max * scale);
  }
}

const _boardRailButtonSize = 42.0;
const _boardRailPanelIconSize = 28.0;
const _boardRailButtonSpacing = 6.0;
const _boardRailHorizontalPadding = 6.0;
const _boardRailVerticalPadding = 3.0;
const handTrayVisibleHeightMin = 66.0;
const handTrayVisibleHeightMax = 404.0;
const handTrayLayoutHeightMax = 390.0;
const handTrayVisibleOverhang = 14.0;
const handTrayResponsiveStartHeight = 500.0;
const handTrayResponsiveGrowthFactor = 1.0;
