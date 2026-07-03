import 'package:flutter/material.dart';

import '../design_tokens.dart';

enum BoardGutterInfillSide { left, right }

double boardLeftGutterOffset(double safeLeading) => -safeLeading;

double boardLeftGutterWidth(double safeLeading) => safeLeading;

double boardRightGutterOffset(double safeTrailing) => -safeTrailing;

double boardRightGutterWidth(double safeTrailing) => safeTrailing * 2;

class BoardGutterInfill extends StatelessWidget {
  const BoardGutterInfill({required this.side, required this.width, super.key});

  final BoardGutterInfillSide side;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: double.infinity,
      child: Image.asset(
        'ios_resources/Embellishments/$assetName',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.none,
      ),
    );
  }

  String get assetName {
    return switch (side) {
      BoardGutterInfillSide.left =>
        'iphone17promax-left-gutter-infill-dark.png',
      BoardGutterInfillSide.right =>
        'iphone17promax-right-gutter-infill-dark.png',
    };
  }
}

class BoardSeparator extends StatelessWidget {
  const BoardSeparator({
    required this.tokens,
    this.vertical = false,
    this.thickness,
    super.key,
  });

  final DesignTokens tokens;
  final bool vertical;
  final double? thickness;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: vertical
          ? thickness ?? tokens.layout.board.railSeparatorWidth
          : null,
      height: vertical
          ? null
          : thickness ?? tokens.layout.board.playAreaSeparatorThickness,
      decoration: BoxDecoration(
        color: tokens.colors.gold,
        image: DecorationImage(
          image: AssetImage(
            vertical
                ? 'ios_resources/ui-left-rail-separator-tile.png'
                : 'ios_resources/ui-play-area-separator-horizontal-tile.png',
          ),
          repeat: ImageRepeat.repeat,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }
}
