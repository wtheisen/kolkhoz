import 'dart:ui';

class DesignTokens {
  const DesignTokens({required this.colors, required this.cardAspectRatio});

  factory DesignTokens.fromJson(Map<String, Object?> json) {
    final color = json['color']! as Map<String, Object?>;
    return DesignTokens(
      colors: TokenColors.fromJson(color),
      cardAspectRatio:
          (json['card']! as Map<String, Object?>)['aspectRatio'] as num,
    );
  }

  final TokenColors colors;
  final num cardAspectRatio;
}

class TokenColors {
  const TokenColors({
    required this.background,
    required this.table,
    required this.panel,
    required this.iron,
    required this.gold,
    required this.red,
    required this.green,
    required this.cream,
    required this.creamDim,
    required this.cardFill,
    required this.cardInk,
    required this.suits,
  });

  factory TokenColors.fromJson(Map<String, Object?> json) {
    return TokenColors(
      background: _adaptive(json['background']),
      table: _adaptive(json['table']),
      panel: _adaptive(json['panel']),
      iron: _adaptive(json['iron']),
      gold: _adaptive(json['gold']),
      red: _adaptive(json['red']),
      green: _adaptive(json['green']),
      cream: _adaptive(json['cream']),
      creamDim: _adaptive(json['creamDim']),
      cardFill: _hex(json['cardFill']! as String),
      cardInk: _hex(json['cardInk']! as String),
      suits: (json['suit']! as Map<String, Object?>).map(
        (key, value) => MapEntry(key, _hex(value! as String)),
      ),
    );
  }

  final Color background;
  final Color table;
  final Color panel;
  final Color iron;
  final Color gold;
  final Color red;
  final Color green;
  final Color cream;
  final Color creamDim;
  final Color cardFill;
  final Color cardInk;
  final Map<String, Color> suits;
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
