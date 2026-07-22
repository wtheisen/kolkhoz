import 'package:flutter/material.dart';

import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';

enum BoardGutterInfillSide { left, right }

double boardLeftGutterOffset(double safeLeading) => -safeLeading;

double boardLeftGutterWidth(double safeLeading) => safeLeading;

double boardRightGutterOffset(double safeTrailing) => -safeTrailing;

double boardRightGutterWidth(double safeTrailing) => safeTrailing * 2;

class BoardGutterInfill extends StatelessWidget {
  const BoardGutterInfill({
    required this.side,
    required this.width,
    this.light = false,
    super.key,
  });

  final BoardGutterInfillSide side;
  final double width;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: double.infinity,
      child: Image.asset(
        'assets/ui/Embellishments/$assetName',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.none,
      ),
    );
  }

  String get assetName {
    return switch (side) {
      BoardGutterInfillSide.left =>
        light
            ? 'iphone17promax-left-gutter-infill-light.png'
            : 'iphone17promax-left-gutter-infill-dark.png',
      BoardGutterInfillSide.right =>
        light
            ? 'iphone17promax-right-gutter-infill-light.png'
            : 'iphone17promax-right-gutter-infill-dark.png',
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
                ? 'assets/ui/ui-left-rail-separator-tile.png'
                : 'assets/ui/ui-play-area-separator-horizontal-tile.png',
          ),
          repeat: ImageRepeat.repeat,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }
}
