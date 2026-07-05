import 'dart:math' as math;
import 'dart:ui' show Size, clampDouble;

import '../design_tokens.dart';

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

  double get panelContentBottomPadding => 10;

  double get railHorizontalPadding => _boardRailHorizontalPadding;

  double get railVerticalPadding => _boardRailVerticalPadding;

  double get railSpacing => _boardRailButtonSpacing;

  double get railButtonSize => _boardRailButtonSize;

  double get railIconSize => _boardRailPanelIconSize;

  double get topInfoHeight => tokens.layout.topInfo.height;

  double get handTrayHeight => tokens.layout.board.handTrayHeight;

  double get handTrayVisibleHeight => 66;

  double scaledClamp(double value, double min, double max) {
    return clampDouble(value, min * scale, max * scale);
  }
}

const _boardRailButtonSize = 42.0;
const _boardRailPanelIconSize = 28.0;
const _boardRailButtonSpacing = 6.0;
const _boardRailHorizontalPadding = 6.0;
const _boardRailVerticalPadding = 3.0;
