import 'dart:ui';

const defaultDesignTokens = DesignTokens(
  colors: TokenColors(
    background: Color(0xff0a0a0a),
    black: Color(0xff080808),
    table: Color(0xff1a1a1a),
    panel: Color(0xff24211c),
    iron: Color(0xff1a1714),
    steel: Color(0xff4f4a40),
    gold: Color(0xffd4a857),
    goldBright: Color(0xffffd600),
    red: Color(0xffc41f3b),
    redDark: Color(0xff8c0000),
    redBright: Color(0xffdb143d),
    green: Color(0xff4db04f),
    onAccent: Color(0xfff5e8cc),
    cream: Color(0xffe8dbc4),
    creamDim: Color(0xffc2b094),
    smoke: Color(0xff8c8275),
    cardFill: Color(0xfffaf5e3),
    cardInk: Color(0xff0f0d0a),
    cardStrokeOpacity: 0.38,
    suits: {
      'wheat': Color(0xffd4a857),
      'sunflower': Color(0xffffd600),
      'potato': Color(0xff8c8275),
      'beet': Color(0xffc41f3b),
    },
  ),
  spacing: TokenSpacing(
    xs: 3,
    sm: 6,
    md: 8,
    lg: 10,
    xl: 12,
    panelPadding: 12,
    boardOuterMarginMin: 4,
    boardOuterMarginMax: 8,
    handTrayHorizontalLeading: 18,
    handTrayHorizontalTrailing: 24,
  ),
  radius: TokenRadius(
    xs: 3,
    sm: 4,
    md: 6,
    panelOuter: 8,
    panelInner: 5,
    card: 8,
  ),
  stroke: TokenStroke(hairline: 0.8, standard: 1, emphasis: 1.5, active: 3),
  typography: TokenTypography(
    family: 'Handjet',
    scale: {
      'largeTitle': 34,
      'title': 28,
      'title2': 22,
      'title3': 20,
      'headline': 17,
      'body': 17,
      'callout': 16,
      'subheadline': 15,
      'caption': 13,
      'footnote': 12,
      'caption2': 11,
    },
  ),
  card: TokenCard(
    aspectRatio: 1.42,
    small: TokenCardSize(
      width: 42,
      height: 59.64,
      faceInset: 5,
      cornerWidth: 15,
      cornerHeight: 10,
      cornerRankFontSize: 8,
      cornerSuitSize: 5,
      topCornerRankSuitSpacing: -1,
      bottomCornerRankSuitSpacing: -1,
      topCornerSuitXOffset: 0,
      bottomCornerSuitXOffset: 0,
      pipSize: 8,
    ),
    medium: TokenCardSize(
      width: 58,
      height: 82.36,
      faceInset: 6,
      cornerWidth: 19,
      cornerHeight: 13,
      cornerRankFontSize: 10.5,
      cornerSuitSize: 6,
      topCornerRankSuitSpacing: -1,
      bottomCornerRankSuitSpacing: -1,
      topCornerSuitXOffset: 0,
      bottomCornerSuitXOffset: 0,
      pipSize: 10.4,
    ),
    large: TokenCardSize(
      width: 70,
      height: 99.4,
      faceInset: 7,
      cornerWidth: 24,
      cornerHeight: 20,
      cornerRankFontSize: 24,
      cornerSuitSize: 10,
      topCornerRankSuitSpacing: -4,
      bottomCornerRankSuitSpacing: 1,
      topCornerSuitXOffset: -1,
      bottomCornerSuitXOffset: 1,
      pipSize: 14,
    ),
  ),
  layout: TokenLayout(
    board: BoardLayoutTokens(
      railWidthMin: 60,
      railWidthMax: 72,
      railWidthFactor: 0.07,
      railSeparatorWidth: 4,
      playAreaSeparatorThickness: 4,
      handTrayHeight: 64,
      minimumContentWidth: 280,
      minimumContentHeight: 240,
    ),
    topInfo: TopInfoLayoutTokens(
      height: 48,
      rowSpacingFactor: 0.008,
      rowSpacingMin: 3,
      rowSpacingMax: 6,
      yearWidthFactor: 0.2,
      yearWidthMin: 64,
      yearWidthMax: 72,
      gaugeWidthFactor: 0.15,
      gaugeWidthMin: 86,
      gaugeWidthMax: 92,
      gaugeHeightFactor: 0.9,
      gaugeHeightMin: 34,
      gaugeHeightMax: 38,
      gaugeSpacingFactor: 0.006,
      gaugeSpacingMin: 3,
      gaugeSpacingMax: 6,
      gaugeFrameWidthMultiplier: 1.2,
      gaugeContentWidthMultiplier: 1.1,
      scoreWidthFactor: 0.075,
      scoreWidthMin: 92,
      scoreWidthMax: 104,
      rewardMarkerHeightMultiplier: 0.72,
      checkIconHeightMultiplier: 0.4,
    ),
    jobs: JobsLayoutTokens(
      requiredHours: 40,
      assignmentMinTileHeight: 88,
      overviewMinTileHeight: 106,
    ),
    plot: PlotLayoutTokens(opponentHeightFraction: 0.5),
  ),
);

final lightDesignTokens = DesignTokens(
  colors: TokenColors(
    background: Color(0xffe6dbc2),
    black: Color(0xfff5ebd1),
    table: Color(0xffc9b899),
    panel: Color(0xffe8dbbd),
    iron: Color(0xffd6c7a8),
    steel: Color(0xff7d684a),
    gold: Color(0xff96611a),
    goldBright: Color(0xffb87814),
    red: Color(0xffb01229),
    redDark: Color(0xffc72e29),
    redBright: Color(0xffa30821),
    green: Color(0xff4db04f),
    onAccent: Color(0xfff5e8cc),
    cream: Color(0xff261f17),
    creamDim: Color(0xff594730),
    smoke: Color(0xff6e5c45),
    cardFill: Color(0xfffaf5e3),
    cardInk: Color(0xff0f0d0a),
    cardStrokeOpacity: 0.38,
    suits: {
      'wheat': Color(0xff96611a),
      'sunflower': Color(0xffb87814),
      'potato': Color(0xff6e5c45),
      'beet': Color(0xffb01229),
    },
  ),
  spacing: defaultDesignTokens.spacing,
  radius: defaultDesignTokens.radius,
  stroke: defaultDesignTokens.stroke,
  typography: defaultDesignTokens.typography,
  card: defaultDesignTokens.card,
  layout: defaultDesignTokens.layout,
);

class DesignTokens {
  const DesignTokens({
    required this.colors,
    required this.spacing,
    required this.radius,
    required this.stroke,
    required this.typography,
    required this.card,
    required this.layout,
  });

  final TokenColors colors;
  final TokenSpacing spacing;
  final TokenRadius radius;
  final TokenStroke stroke;
  final TokenTypography typography;
  final TokenCard card;
  final TokenLayout layout;

  bool get usesLightAppearance =>
      colors.background == lightDesignTokens.colors.background &&
      colors.table == lightDesignTokens.colors.table;
}

class TokenColors {
  const TokenColors({
    required this.background,
    required this.black,
    required this.table,
    required this.panel,
    required this.iron,
    required this.steel,
    required this.gold,
    required this.goldBright,
    required this.red,
    required this.redDark,
    required this.redBright,
    required this.green,
    required this.onAccent,
    required this.cream,
    required this.creamDim,
    required this.smoke,
    required this.cardFill,
    required this.cardInk,
    required this.cardStrokeOpacity,
    required this.suits,
  });

  final Color background;
  final Color black;
  final Color table;
  final Color panel;
  final Color iron;
  final Color steel;
  final Color gold;
  final Color goldBright;
  final Color red;
  final Color redDark;
  final Color redBright;
  final Color green;
  final Color onAccent;
  final Color cream;
  final Color creamDim;
  final Color smoke;
  final Color cardFill;
  final Color cardInk;
  final double cardStrokeOpacity;
  final Map<String, Color> suits;

  Color get activeSurfaceText => onAccent;

  Color get activeSurfaceTextMuted => onAccent.withValues(alpha: 0.82);
}

class TokenSpacing {
  const TokenSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.panelPadding,
    required this.boardOuterMarginMin,
    required this.boardOuterMarginMax,
    required this.handTrayHorizontalLeading,
    required this.handTrayHorizontalTrailing,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double panelPadding;
  final double boardOuterMarginMin;
  final double boardOuterMarginMax;
  final double handTrayHorizontalLeading;
  final double handTrayHorizontalTrailing;
}

class TokenRadius {
  const TokenRadius({
    required this.xs,
    required this.sm,
    required this.md,
    required this.panelOuter,
    required this.panelInner,
    required this.card,
  });

  final double xs;
  final double sm;
  final double md;
  final double panelOuter;
  final double panelInner;
  final double card;
}

class TokenStroke {
  const TokenStroke({
    required this.hairline,
    required this.standard,
    required this.emphasis,
    required this.active,
  });

  final double hairline;
  final double standard;
  final double emphasis;
  final double active;
}

class TokenTypography {
  const TokenTypography({required this.family, required this.scale});

  final String family;
  final Map<String, double> scale;

  double size(String name, double fallback) => scale[name] ?? fallback;
}

class TokenCard {
  const TokenCard({
    required this.aspectRatio,
    required this.small,
    required this.medium,
    required this.large,
  });

  final double aspectRatio;
  final TokenCardSize small;
  final TokenCardSize medium;
  final TokenCardSize large;
}

class TokenCardSize {
  const TokenCardSize({
    required this.width,
    required this.height,
    required this.faceInset,
    required this.cornerWidth,
    required this.cornerHeight,
    required this.cornerRankFontSize,
    required this.cornerSuitSize,
    required this.topCornerRankSuitSpacing,
    required this.bottomCornerRankSuitSpacing,
    required this.topCornerSuitXOffset,
    required this.bottomCornerSuitXOffset,
    required this.pipSize,
  });

  final double width;
  final double height;
  final double faceInset;
  final double cornerWidth;
  final double cornerHeight;
  final double cornerRankFontSize;
  final double cornerSuitSize;
  final double topCornerRankSuitSpacing;
  final double bottomCornerRankSuitSpacing;
  final double topCornerSuitXOffset;
  final double bottomCornerSuitXOffset;
  final double pipSize;
}

class TokenLayout {
  const TokenLayout({
    required this.board,
    required this.topInfo,
    required this.jobs,
    required this.plot,
  });

  final BoardLayoutTokens board;
  final TopInfoLayoutTokens topInfo;
  final JobsLayoutTokens jobs;
  final PlotLayoutTokens plot;
}

class BoardLayoutTokens {
  const BoardLayoutTokens({
    required this.railWidthMin,
    required this.railWidthMax,
    required this.railWidthFactor,
    required this.railSeparatorWidth,
    required this.playAreaSeparatorThickness,
    required this.handTrayHeight,
    required this.minimumContentWidth,
    required this.minimumContentHeight,
  });

  final double railWidthMin;
  final double railWidthMax;
  final double railWidthFactor;
  final double railSeparatorWidth;
  final double playAreaSeparatorThickness;
  final double handTrayHeight;
  final double minimumContentWidth;
  final double minimumContentHeight;
}

class TopInfoLayoutTokens {
  const TopInfoLayoutTokens({
    required this.height,
    required this.rowSpacingFactor,
    required this.rowSpacingMin,
    required this.rowSpacingMax,
    required this.yearWidthFactor,
    required this.yearWidthMin,
    required this.yearWidthMax,
    required this.gaugeWidthFactor,
    required this.gaugeWidthMin,
    required this.gaugeWidthMax,
    required this.gaugeHeightFactor,
    required this.gaugeHeightMin,
    required this.gaugeHeightMax,
    required this.gaugeSpacingFactor,
    required this.gaugeSpacingMin,
    required this.gaugeSpacingMax,
    required this.gaugeFrameWidthMultiplier,
    required this.gaugeContentWidthMultiplier,
    required this.scoreWidthFactor,
    required this.scoreWidthMin,
    required this.scoreWidthMax,
    required this.rewardMarkerHeightMultiplier,
    required this.checkIconHeightMultiplier,
  });

  final double height;
  final double rowSpacingFactor;
  final double rowSpacingMin;
  final double rowSpacingMax;
  final double yearWidthFactor;
  final double yearWidthMin;
  final double yearWidthMax;
  final double gaugeWidthFactor;
  final double gaugeWidthMin;
  final double gaugeWidthMax;
  final double gaugeHeightFactor;
  final double gaugeHeightMin;
  final double gaugeHeightMax;
  final double gaugeSpacingFactor;
  final double gaugeSpacingMin;
  final double gaugeSpacingMax;
  final double gaugeFrameWidthMultiplier;
  final double gaugeContentWidthMultiplier;
  final double scoreWidthFactor;
  final double scoreWidthMin;
  final double scoreWidthMax;
  final double rewardMarkerHeightMultiplier;
  final double checkIconHeightMultiplier;
}

class JobsLayoutTokens {
  const JobsLayoutTokens({
    required this.requiredHours,
    required this.assignmentMinTileHeight,
    required this.overviewMinTileHeight,
  });

  final double requiredHours;
  final double assignmentMinTileHeight;
  final double overviewMinTileHeight;
}

class PlotLayoutTokens {
  const PlotLayoutTokens({required this.opponentHeightFraction});

  final double opponentHeightFraction;
}

Color suitColor(DesignTokens tokens, String suit) {
  return tokens.colors.suits[suit] ?? tokens.colors.gold;
}
