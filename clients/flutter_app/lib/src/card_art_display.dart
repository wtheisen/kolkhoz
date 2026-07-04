import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'pixel_text.dart';
import 'render_model.dart';

List<Offset> pipPositions(int value) {
  switch (value.clamp(1, 10)) {
    case 1:
      return const [Offset(0.5, 0.5)];
    case 2:
      return const [Offset(0.5, 0.20), Offset(0.5, 0.80)];
    case 3:
      return const [Offset(0.5, 0.18), Offset(0.5, 0.5), Offset(0.5, 0.82)];
    case 4:
      return const [
        Offset(0.25, 0.22),
        Offset(0.75, 0.22),
        Offset(0.25, 0.78),
        Offset(0.75, 0.78),
      ];
    case 5:
      return const [
        Offset(0.25, 0.20),
        Offset(0.75, 0.20),
        Offset(0.5, 0.5),
        Offset(0.25, 0.80),
        Offset(0.75, 0.80),
      ];
    case 6:
      return const [
        Offset(0.25, 0.17),
        Offset(0.75, 0.17),
        Offset(0.25, 0.50),
        Offset(0.75, 0.50),
        Offset(0.25, 0.83),
        Offset(0.75, 0.83),
      ];
    case 7:
      return const [
        Offset(0.25, 0.15),
        Offset(0.75, 0.15),
        Offset(0.5, 0.31),
        Offset(0.25, 0.50),
        Offset(0.75, 0.50),
        Offset(0.25, 0.85),
        Offset(0.75, 0.85),
      ];
    case 8:
      return const [
        Offset(0.25, 0.14),
        Offset(0.75, 0.14),
        Offset(0.5, 0.30),
        Offset(0.25, 0.46),
        Offset(0.75, 0.46),
        Offset(0.5, 0.66),
        Offset(0.25, 0.86),
        Offset(0.75, 0.86),
      ];
    case 9:
      return const [
        Offset(0.25, 0.13),
        Offset(0.75, 0.13),
        Offset(0.25, 0.37),
        Offset(0.75, 0.37),
        Offset(0.5, 0.50),
        Offset(0.25, 0.63),
        Offset(0.75, 0.63),
        Offset(0.25, 0.87),
        Offset(0.75, 0.87),
      ];
    default:
      return const [
        Offset(0.25, 0.11),
        Offset(0.75, 0.11),
        Offset(0.5, 0.27),
        Offset(0.25, 0.39),
        Offset(0.75, 0.39),
        Offset(0.25, 0.61),
        Offset(0.75, 0.61),
        Offset(0.5, 0.73),
        Offset(0.25, 0.89),
        Offset(0.75, 0.89),
      ];
  }
}

String faceAssetPath(TableCard card) {
  final rank = faceRankName(card);
  return 'ios_resources/Cards/face-$rank-${card.suit}.png';
}

String genericFaceAssetPath(TableCard card) {
  final rank = faceRankName(card);
  return 'ios_resources/Cards/face-$rank.png';
}

String faceRankName(TableCard card) {
  return switch (card.value) {
    11 => 'jack',
    12 => 'queen',
    13 => 'king',
    _ => 'king',
  };
}

String portraitAssetPath(Seat seat) {
  return 'ios_resources/${seat.portraitAsset}.png';
}

String cardTemplateAssetPath({required bool dark}) {
  return dark
      ? 'ios_resources/Cards/card-template-dark.png'
      : 'ios_resources/Cards/card-template-light.png';
}

String cardTemplateAssetPathForTokens(DesignTokens tokens) {
  return cardTemplateAssetPath(dark: !tokens.usesLightAppearance);
}

double faceArtWidth(TokenCardSize size) {
  if (size.width <= 42.1) {
    return 20;
  }
  return size.width * 0.45;
}

PixelTextSize pixelTextSizeForCardRank(TokenCardSize size) {
  if (size.width <= 42.1) {
    return PixelTextSize.xSmall;
  }
  if (size.width <= 58.1) {
    return PixelTextSize.caption2;
  }
  return PixelTextSize.headline;
}

Color cardHighlightColor({
  required TableCard card,
  required String? trump,
  required DesignTokens tokens,
}) {
  return card.suit == trump ? tokens.colors.red : tokens.colors.cream;
}

Color suitMarkDisplayColor(String suit, DesignTokens tokens) {
  return switch (suit) {
    'wheat' || 'sunflower' => tokens.colors.cream,
    'potato' || 'beet' => tokens.colors.red,
    _ => suitColor(tokens, suit),
  };
}
