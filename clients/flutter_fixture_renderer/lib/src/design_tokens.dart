import 'dart:ui';

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

  factory DesignTokens.fromJson(Map<String, Object?> json) {
    final color = json['color']! as Map<String, Object?>;
    final card = json['card']! as Map<String, Object?>;
    return DesignTokens(
      colors: TokenColors.fromJson(color),
      spacing: TokenSpacing.fromJson(json['spacing']! as Map<String, Object?>),
      radius: TokenRadius.fromJson(json['radius']! as Map<String, Object?>),
      stroke: TokenStroke.fromJson(json['stroke']! as Map<String, Object?>),
      typography: TokenTypography.fromJson(
        json['typography']! as Map<String, Object?>,
      ),
      card: TokenCard.fromJson(card),
      layout: TokenLayout.fromJson(json['layout']! as Map<String, Object?>),
    );
  }

  final TokenColors colors;
  final TokenSpacing spacing;
  final TokenRadius radius;
  final TokenStroke stroke;
  final TokenTypography typography;
  final TokenCard card;
  final TokenLayout layout;
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
    required this.red,
    required this.green,
    required this.cream,
    required this.creamDim,
    required this.smoke,
    required this.cardFill,
    required this.cardInk,
    required this.suits,
  });

  factory TokenColors.fromJson(Map<String, Object?> json) {
    return TokenColors(
      background: _adaptive(json['background']),
      black: _adaptive(json['black']),
      table: _adaptive(json['table']),
      panel: _adaptive(json['panel']),
      iron: _adaptive(json['iron']),
      steel: _adaptive(json['steel']),
      gold: _adaptive(json['gold']),
      red: _adaptive(json['red']),
      green: _adaptive(json['green']),
      cream: _adaptive(json['cream']),
      creamDim: _adaptive(json['creamDim']),
      smoke: _adaptive(json['smoke']),
      cardFill: _hex(json['cardFill']! as String),
      cardInk: _hex(json['cardInk']! as String),
      suits: (json['suit']! as Map<String, Object?>).map(
        (key, value) => MapEntry(key, _hex(value! as String)),
      ),
    );
  }

  final Color background;
  final Color black;
  final Color table;
  final Color panel;
  final Color iron;
  final Color steel;
  final Color gold;
  final Color red;
  final Color green;
  final Color cream;
  final Color creamDim;
  final Color smoke;
  final Color cardFill;
  final Color cardInk;
  final Map<String, Color> suits;
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

  factory TokenSpacing.fromJson(Map<String, Object?> json) {
    return TokenSpacing(
      xs: _number(json['xs']),
      sm: _number(json['sm']),
      md: _number(json['md']),
      lg: _number(json['lg']),
      xl: _number(json['xl']),
      panelPadding: _number(json['panelPadding']),
      boardOuterMarginMin: _number(json['boardOuterMarginMin']),
      boardOuterMarginMax: _number(json['boardOuterMarginMax']),
      handTrayHorizontalLeading: _number(json['handTrayHorizontalLeading']),
      handTrayHorizontalTrailing: _number(json['handTrayHorizontalTrailing']),
    );
  }

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

  factory TokenRadius.fromJson(Map<String, Object?> json) {
    return TokenRadius(
      xs: _number(json['xs']),
      sm: _number(json['sm']),
      md: _number(json['md']),
      panelOuter: _number(json['panelOuter']),
      panelInner: _number(json['panelInner']),
      card: _number(json['card']),
    );
  }

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

  factory TokenStroke.fromJson(Map<String, Object?> json) {
    return TokenStroke(
      hairline: _number(json['hairline']),
      standard: _number(json['standard']),
      emphasis: _number(json['emphasis']),
      active: _number(json['active']),
    );
  }

  final double hairline;
  final double standard;
  final double emphasis;
  final double active;
}

class TokenTypography {
  const TokenTypography({required this.family, required this.scale});

  factory TokenTypography.fromJson(Map<String, Object?> json) {
    return TokenTypography(
      family: json['family']! as String,
      scale: (json['textScale']! as Map<String, Object?>).map(
        (key, value) => MapEntry(key, _number(value)),
      ),
    );
  }

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

  factory TokenCard.fromJson(Map<String, Object?> json) {
    final sizes = json['sizes']! as Map<String, Object?>;
    return TokenCard(
      aspectRatio: _number(json['aspectRatio']),
      small: TokenCardSize.fromJson(sizes['small']! as Map<String, Object?>),
      medium: TokenCardSize.fromJson(sizes['medium']! as Map<String, Object?>),
      large: TokenCardSize.fromJson(sizes['large']! as Map<String, Object?>),
    );
  }

  final double aspectRatio;
  final TokenCardSize small;
  final TokenCardSize medium;
  final TokenCardSize large;
}

class TokenCardSize {
  const TokenCardSize({
    required this.width,
    required this.height,
    required this.cornerRankFontSize,
    required this.cornerSuitSize,
  });

  factory TokenCardSize.fromJson(Map<String, Object?> json) {
    return TokenCardSize(
      width: _number(json['width']),
      height: _number(json['height']),
      cornerRankFontSize: _number(json['cornerRankFontSize']),
      cornerSuitSize: _number(json['cornerSuitSize']),
    );
  }

  final double width;
  final double height;
  final double cornerRankFontSize;
  final double cornerSuitSize;
}

class TokenLayout {
  const TokenLayout({required this.board, required this.jobs});

  factory TokenLayout.fromJson(Map<String, Object?> json) {
    return TokenLayout(
      board: BoardLayoutTokens.fromJson(json['board']! as Map<String, Object?>),
      jobs: JobsLayoutTokens.fromJson(json['jobs']! as Map<String, Object?>),
    );
  }

  final BoardLayoutTokens board;
  final JobsLayoutTokens jobs;
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

  factory BoardLayoutTokens.fromJson(Map<String, Object?> json) {
    return BoardLayoutTokens(
      railWidthMin: _number(json['railWidthMin']),
      railWidthMax: _number(json['railWidthMax']),
      railWidthFactor: _number(json['railWidthFactor']),
      railSeparatorWidth: _number(json['railSeparatorWidth']),
      playAreaSeparatorThickness: _number(json['playAreaSeparatorThickness']),
      handTrayHeight: _number(json['handTrayHeight']),
      minimumContentWidth: _number(json['minimumContentWidth']),
      minimumContentHeight: _number(json['minimumContentHeight']),
    );
  }

  final double railWidthMin;
  final double railWidthMax;
  final double railWidthFactor;
  final double railSeparatorWidth;
  final double playAreaSeparatorThickness;
  final double handTrayHeight;
  final double minimumContentWidth;
  final double minimumContentHeight;
}

class JobsLayoutTokens {
  const JobsLayoutTokens({required this.requiredHours});

  factory JobsLayoutTokens.fromJson(Map<String, Object?> json) {
    return JobsLayoutTokens(requiredHours: _number(json['requiredHours']));
  }

  final double requiredHours;
}

Color suitColor(DesignTokens tokens, String suit) {
  return tokens.colors.suits[suit] ?? tokens.colors.gold;
}

Color _adaptive(Object? value) {
  final map = value! as Map<String, Object?>;
  return _hex(map['dark']! as String);
}

Color _hex(String value) {
  final normalized = value.replaceFirst('#', '');
  return Color(int.parse('ff$normalized', radix: 16));
}

double _number(Object? value) => (value! as num).toDouble();
