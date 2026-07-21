import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../board/board_widgets.dart';
import '../render_model.dart';
import 'brigade_fields_diorama.dart';

const northBarracksFrontTexturePath =
    'assets/art/field_plan/world_lab_brigade_fields_north_diorama/'
    'north-barracks-front-texture-v1.png';
const northBarracksRoofTexturePath =
    'assets/art/field_plan/world_lab_brigade_fields_north_diorama/'
    'north-barracks-roof-texture-v1.png';

/// Physical year history laid directly into the terminal North landscape.
///
/// The registered route and forest remain owned by the depth scene. This layer
/// owns only gameplay objects. Roofs, fronts, and cards are separate planes so
/// the camera geometry—not baked artwork—owns their perspective.
class NorthDioramaOverlay extends StatelessWidget {
  const NorthDioramaOverlay({
    required this.arrivalProgress,
    required this.visibleYear,
    required this.removedCardsByYear,
    super.key,
  });

  final double arrivalProgress;
  final int visibleYear;
  final List<List<TableCard>> removedCardsByYear;

  @override
  Widget build(BuildContext context) {
    final arrival = Curves.easeInOutCubic.transform(
      arrivalProgress.clamp(0.0, 1.0),
    );
    if (arrival <= 0 || visibleYear <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: Opacity(
        opacity: arrival,
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: 1920,
            height: 800,
            child: Transform.translate(
              offset: Offset(0, lerpDouble(-170, 0, arrival)!),
              child: Transform.scale(
                alignment: const Alignment(0, -0.08),
                scale: lerpDouble(0.56, 1, arrival)!,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (var year = 1; year <= visibleYear; year++)
                      _NorthBarracksYear(
                        key: Key('north-barracks-year-$year'),
                        year: year,
                        cards: year <= removedCardsByYear.length
                            ? removedCardsByYear[year - 1]
                            : const [],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NorthBarracksYear extends StatelessWidget {
  const _NorthBarracksYear({
    required this.year,
    required this.cards,
    super.key,
  });

  static const centerX = 960.0;
  static const horizonY = 413.0;
  static const nearestBaseY = 737.0;

  final int year;
  final List<TableCard> cards;

  @override
  Widget build(BuildContext context) {
    final tokens = KolkhozAppearance.light.tokens;
    final baseY = 505.0 + (year - 1) * 58;
    final perspective = ((baseY - horizonY) / (nearestBaseY - horizonY)).clamp(
      0.0,
      1.0,
    );
    final bottomWidth = lerpDouble(790, 1480, perspective)!;
    final topWidth = bottomWidth * lerpDouble(0.93, 0.975, perspective)!;
    final frontHeight = lerpDouble(48, 108, perspective)!;
    final frontTopY = baseY - frontHeight;
    final roofDepth = lerpDouble(28, 68, perspective)!;
    final roofBackY = frontTopY - roofDepth;
    final roofBackWidth = topWidth * lerpDouble(0.76, 0.86, perspective)!;

    final roofQuad = <Offset>[
      Offset(centerX - roofBackWidth / 2, roofBackY),
      Offset(centerX + roofBackWidth / 2, roofBackY),
      Offset(centerX + topWidth / 2, frontTopY),
      Offset(centerX - topWidth / 2, frontTopY),
    ];
    final frontQuad = <Offset>[
      Offset(centerX - topWidth / 2, frontTopY),
      Offset(centerX + topWidth / 2, frontTopY),
      Offset(centerX + bottomWidth / 2, baseY),
      Offset(centerX - bottomWidth / 2, baseY),
    ];

    final spreadSourceWidth = cards.isEmpty
        ? 66.0
        : 58.0 + (cards.length - 1) * 34;
    final spreadWidth =
        spreadSourceWidth * lerpDouble(0.88, 1.38, perspective)!;
    final spreadBackWidth = spreadWidth * 0.78;
    final spreadBackY = roofBackY + roofDepth * 0.14;
    final spreadFrontY = frontTopY - roofDepth * 0.10;
    final spreadQuad = <Offset>[
      Offset(centerX - spreadBackWidth / 2, spreadBackY),
      Offset(centerX + spreadBackWidth / 2, spreadBackY),
      Offset(centerX + spreadWidth / 2, spreadFrontY),
      Offset(centerX - spreadWidth / 2, spreadFrontY),
    ];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.82, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutBack,
      builder: (context, reveal, child) => Opacity(
        opacity: ((reveal - 0.82) / 0.18).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - reveal) * -72),
          child: Transform.scale(
            alignment: Alignment.topCenter,
            scale: reveal,
            child: child,
          ),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ProjectedNorthPlane(
            key: Key('north-barracks-roof-year-$year'),
            sourceSize: const Size(1150, 105),
            destination: roofQuad,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  northBarracksRoofTexturePath,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                ),
                Positioned(
                  left: 28,
                  bottom: 12,
                  child: _NorthYearLabel(year: year),
                ),
              ],
            ),
          ),
          _ProjectedNorthPlane(
            key: Key('north-barracks-art-year-$year'),
            sourceSize: const Size(1540, 145),
            destination: frontQuad,
            child: Image.asset(
              northBarracksFrontTexturePath,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
          _ProjectedNorthPlane(
            key: Key('north-card-spread-year-$year'),
            sourceSize: Size(spreadSourceWidth, 88),
            destination: spreadQuad,
            child: cards.isEmpty
                ? const _EmptyNorthYearMark()
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final indexed in cards.indexed)
                        Positioned(
                          left: indexed.$1 * 34,
                          top: indexed.$1.isOdd ? 4 : 0,
                          child: Transform.rotate(
                            angle:
                                (indexed.$1.isEven ? -1 : 1) *
                                (0.014 + indexed.$1 * 0.004),
                            child: GameCard(
                              key: Key(
                                'north-year-$year-card-${indexed.$2.id}',
                              ),
                              card: indexed.$2,
                              tokens: tokens,
                              sizeOverride: tokens.card.medium,
                              motionTracked: false,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _NorthYearLabel extends StatelessWidget {
  const _NorthYearLabel({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xffd9c99f),
        border: Border.all(color: const Color(0xff263f47), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          'YEAR $year',
          style: const TextStyle(
            color: Color(0xff263f47),
            fontSize: 23,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _ProjectedNorthPlane extends StatelessWidget {
  const _ProjectedNorthPlane({
    required this.sourceSize,
    required this.destination,
    required this.child,
    super.key,
  });

  final Size sourceSize;
  final List<Offset> destination;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final transform = dioramaHomographyToQuad(sourceSize, destination);
    if (transform == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: Transform(
        alignment: Alignment.topLeft,
        transform: transform,
        transformHitTests: false,
        child: Align(
          alignment: Alignment.topLeft,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: sourceSize.width,
            maxWidth: sourceSize.width,
            minHeight: sourceSize.height,
            maxHeight: sourceSize.height,
            child: SizedBox.fromSize(size: sourceSize, child: child),
          ),
        ),
      ),
    );
  }
}

class _EmptyNorthYearMark extends StatelessWidget {
  const _EmptyNorthYearMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xffe2d7b7),
        border: Border.all(color: const Color(0xff263f47), width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const SizedBox(
        width: 58,
        height: 82,
        child: Icon(Icons.check, color: Color(0xff9f2d31), size: 42),
      ),
    );
  }
}
