import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../board/board_widgets.dart';
import '../design_tokens.dart';
import '../render_model.dart';

@immutable
class DioramaPoint {
  const DioramaPoint(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

@immutable
class DioramaCameraPose {
  const DioramaCameraPose({
    required this.routeZ,
    required this.height,
    required this.pitchRadians,
    this.verticalFieldOfViewRadians = math.pi * 0.31,
  });

  final double routeZ;
  final double height;
  final double pitchRadians;
  final double verticalFieldOfViewRadians;
}

@immutable
class DioramaWorldCardPlacement {
  const DioramaWorldCardPlacement({
    required this.card,
    required this.center,
    required this.role,
    this.interactive = true,
    this.worldWidth = 1.35,
    this.worldHeight = 1.95,
  });

  final TableCard card;
  final DioramaPoint center;
  final String role;
  final bool interactive;
  final double worldWidth;
  final double worldHeight;
}

class BrigadeFieldsCameraPath {
  const BrigadeFieldsCameraPath();

  static const fieldsProgress = 0.44;
  static const brigadeRouteZ = -8.0;
  static const fieldsRouteZ = 22.0;
  static const northRouteZ = 72.0;
  static const heroHeight = 7.5;
  static const travelHeight = 2.8;
  static const heroPitch = math.pi * 0.19;
  static const travelPitch = math.pi * 0.055;

  DioramaCameraPose poseAt(double progress) {
    final t = progress.clamp(0.0, 1.0);
    final distanceToStop = [
      t,
      (t - fieldsProgress).abs(),
      1 - t,
    ].reduce(math.min);
    final heroInfluence = _heroInfluence(distanceToStop);
    final routeZ = t <= fieldsProgress
        ? lerpDouble(brigadeRouteZ, fieldsRouteZ, t / fieldsProgress)!
        : lerpDouble(
            fieldsRouteZ,
            northRouteZ,
            (t - fieldsProgress) / (1 - fieldsProgress),
          )!;
    return DioramaCameraPose(
      routeZ: routeZ,
      height: lerpDouble(travelHeight, heroHeight, heroInfluence)!,
      pitchRadians: lerpDouble(travelPitch, heroPitch, heroInfluence)!,
    );
  }

  double _heroInfluence(double distanceFromStop) {
    const liftDistance = 0.13;
    final t = (1 - distanceFromStop / liftDistance).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}

class DioramaProjector {
  const DioramaProjector({required this.pose, required this.viewport});

  final DioramaCameraPose pose;
  final Size viewport;

  Offset? project(DioramaPoint point) {
    final relativeX = point.x;
    final relativeY = point.y - pose.height;
    final relativeZ = point.z - pose.routeZ;
    final sinPitch = math.sin(pose.pitchRadians);
    final cosPitch = math.cos(pose.pitchRadians);
    final cameraY = relativeY * cosPitch + relativeZ * sinPitch;
    final cameraZ = -relativeY * sinPitch + relativeZ * cosPitch;
    if (cameraZ <= 0.2) return null;
    final focalLength =
        viewport.height / (2 * math.tan(pose.verticalFieldOfViewRadians / 2));
    return Offset(
      viewport.width / 2 + relativeX / cameraZ * focalLength,
      viewport.height / 2 - cameraY / cameraZ * focalLength,
    );
  }

  List<Offset>? projectQuad(List<DioramaPoint> points) {
    final projected = <Offset>[];
    for (final point in points) {
      final screenPoint = project(point);
      if (screenPoint == null) return null;
      projected.add(screenPoint);
    }
    return projected;
  }
}

double brigadeFieldsSnapTarget(double progress, double velocity) {
  final clamped = progress.clamp(0.0, 1.0);
  const stops = [0.0, BrigadeFieldsCameraPath.fieldsProgress, 1.0];
  if (velocity.abs() > 1.15) {
    if (velocity > 0) {
      return stops.firstWhere(
        (stop) => stop > clamped + 0.025,
        orElse: () => 1,
      );
    }
    return stops.lastWhere((stop) => stop < clamped - 0.025, orElse: () => 0);
  }
  final nearest = stops.reduce(
    (best, stop) =>
        (stop - clamped).abs() < (best - clamped).abs() ? stop : best,
  );
  if ((nearest - clamped).abs() <= 0.075) return nearest;
  return clamped;
}

double brigadeFieldsResistedDelta({
  required double progress,
  required double delta,
}) {
  final distanceToStop = [
    progress.abs(),
    (progress - BrigadeFieldsCameraPath.fieldsProgress).abs(),
    (1 - progress).abs(),
  ].reduce(math.min);
  final stopInfluence = (1 - distanceToStop / 0.07).clamp(0.0, 1.0);
  return delta * lerpDouble(1, 0.78, stopInfluence)!;
}

class BrigadeFieldsDioramaScene extends StatelessWidget {
  const BrigadeFieldsDioramaScene({
    required this.cameraProgress,
    required this.truckProgress,
    required this.cardPlacements,
    required this.legalFieldIDs,
    required this.selectedCardID,
    required this.onCardTap,
    required this.onFieldTap,
    this.visibleNorthYear = 0,
    this.removedCardsByYear = const [],
    this.showGuides = false,
    super.key,
  });

  final double cameraProgress;
  final double truckProgress;
  final List<DioramaWorldCardPlacement> cardPlacements;
  final Set<String> legalFieldIDs;
  final String? selectedCardID;
  final ValueChanged<String> onCardTap;
  final ValueChanged<String> onFieldTap;
  final int visibleNorthYear;
  final List<List<TableCard>> removedCardsByYear;
  final bool showGuides;

  @override
  Widget build(BuildContext context) {
    final tokens = KolkhozAppearance.light.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final pose = const BrigadeFieldsCameraPath().poseAt(cameraProgress);
        final projector = DioramaProjector(pose: pose, viewport: size);
        final depthLayers = _depthSortedLayers(projector, tokens);
        return ClipRect(
          key: const Key('diorama-world'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                key: const Key('diorama-world-paint'),
                painter: BrigadeFieldsBlockoutPainter(
                  pose: pose,
                  showGuides: showGuides,
                ),
              ),
              ..._generatedHorizonPlates(projector, size),
              _generatedRouteGroundPlate(projector, pose),
              CustomPaint(
                painter: BrigadeFieldsBlockoutPainter(
                  pose: pose,
                  showGuides: false,
                  gameplayGroundOnly: true,
                ),
              ),
              ..._generatedFieldGroundPlates(projector),
              ..._generatedNorthGroundPlates(projector),
              CustomPaint(
                key: const Key('diorama-unified-north-railway'),
                painter: _UnifiedNorthRailwayPainter(projector: projector),
              ),
              ...depthLayers,
              ..._northBarracksLayers(projector, tokens),
              ..._fieldTargets(projector),
              CustomPaint(
                painter: BrigadeFieldsBlockoutPainter(
                  pose: pose,
                  showGuides: showGuides,
                  overlayOnly: true,
                ),
              ),
              IgnorePointer(
                child: Opacity(
                  opacity: 0.13,
                  child: Image.asset(
                    'assets/art/field_plan/shared/textures/paper-light.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.none,
                    color: const Color(0xff725f39),
                    colorBlendMode: BlendMode.multiply,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _generatedHorizonPlates(DioramaProjector projector, Size size) {
    const root = 'assets/art/field_plan/world_lab_brigade_fields_diorama';
    final projectedHorizon = projector.project(const DioramaPoint(0, 0, 10000));
    final horizonY = (projectedHorizon?.dy ?? size.height * 0.42).clamp(
      size.height * 0.08,
      size.height * 0.50,
    );
    final farWidth = size.width * lerpDouble(1.08, 1.34, cameraProgress)!;
    final farHeight = farWidth / (2149 / 131);
    final midWidth = size.width * lerpDouble(1.18, 1.55, cameraProgress)!;
    final midHeight = midWidth / (2020 / 140);
    final agriculturalOpacity =
        (1 - ((cameraProgress - 0.48) / 0.20).clamp(0.0, 1.0)).toDouble();
    return [
      Positioned(
        left: (size.width - farWidth) / 2,
        top: horizonY + size.height * 0.08 - farHeight,
        width: farWidth,
        height: farHeight,
        child: Opacity(
          opacity: agriculturalOpacity,
          child: Image.asset(
            '$root/far-ridge-v1.png',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
      Positioned(
        left: (size.width - midWidth) / 2,
        top: horizonY + size.height * 0.14 - midHeight,
        width: midWidth,
        height: midHeight,
        child: Opacity(
          opacity: agriculturalOpacity,
          child: Image.asset(
            '$root/mid-ridge-v1.png',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    ];
  }

  Widget _generatedRouteGroundPlate(
    DioramaProjector projector,
    DioramaCameraPose pose,
  ) {
    const sourceSize = Size(853, 1843);
    const zNear = -12.0;
    const zFar = 48.0;
    final visibleNear = math.max(zNear, pose.routeZ + 4);
    final visibleFraction = (zFar - visibleNear) / (zFar - zNear);
    final farLeft = projector.project(const DioramaPoint(-14, 0.01, zFar));
    final farRight = projector.project(const DioramaPoint(14, 0.01, zFar));
    if (farLeft == null || farRight == null) return const SizedBox.shrink();
    final size = projector.viewport;
    return DioramaWorldPlate(
      projector: projector,
      assetPath:
          'assets/art/field_plan/world_lab_brigade_fields_diorama/route-ground-v2.png',
      sourceSize: sourceSize,
      sourceRect: Rect.fromLTWH(
        0,
        0,
        sourceSize.width,
        sourceSize.height * visibleFraction,
      ),
      corners: const [],
      screenCorners: [
        farLeft,
        farRight,
        Offset(size.width * 1.25, size.height * 1.08),
        Offset(size.width * -0.25, size.height * 1.08),
      ],
    );
  }

  List<Widget> _generatedFieldGroundPlates(DioramaProjector projector) {
    const root = 'assets/art/field_plan/world_lab_brigade_fields_diorama';
    const fields = [
      ('$root/field-ground-v1.png', -10.5, -2.2, 35.2, 43.5),
      ('$root/field-ground-v1.png', 2.2, 10.5, 35.2, 43.5),
      ('$root/field-ground-v1.png', -10.5, -2.2, 26.5, 34.2),
      ('$root/field-ground-v1.png', 2.2, 10.5, 26.5, 34.2),
    ];
    return [
      for (final field in fields)
        DioramaWorldPlate(
          projector: projector,
          assetPath: field.$1,
          sourceSize: const Size(1672, 941),
          corners: [
            DioramaPoint(field.$2, 0.035, field.$5),
            DioramaPoint(field.$3, 0.035, field.$5),
            DioramaPoint(field.$3, 0.035, field.$4),
            DioramaPoint(field.$2, 0.035, field.$4),
          ],
        ),
    ];
  }

  List<Widget> _generatedNorthGroundPlates(DioramaProjector projector) {
    const asset =
        'assets/art/field_plan/world_lab_unified_north/'
        'north-transition-ground-v1.png';
    return [
      DioramaWorldPlate(
        key: const Key('diorama-north-ground-near'),
        projector: projector,
        assetPath: asset,
        sourceSize: const Size(1536, 1024),
        corners: const [
          DioramaPoint(-20, 0.018, 68),
          DioramaPoint(20, 0.018, 68),
          DioramaPoint(18, 0.018, 44),
          DioramaPoint(-18, 0.018, 44),
        ],
      ),
      DioramaWorldPlate(
        key: const Key('diorama-north-ground-far'),
        projector: projector,
        assetPath: asset,
        sourceSize: const Size(1536, 1024),
        flipX: true,
        corners: const [
          DioramaPoint(-25, 0.016, 112),
          DioramaPoint(25, 0.016, 112),
          DioramaPoint(20, 0.016, 65),
          DioramaPoint(-20, 0.016, 65),
        ],
      ),
    ];
  }

  List<Widget> _depthSortedLayers(
    DioramaProjector projector,
    DesignTokens tokens,
  ) {
    final layers = _generatedVerticalLayers(projector);
    final truckZ = lerpDouble(9.5, 29.0, truckProgress.clamp(0.0, 1.0))!;
    layers.add((
      z: truckZ,
      widget: DioramaWorldPlate.vertical(
        projector: projector,
        assetPath:
            'assets/art/field_plan/world_lab_brigade_fields_diorama/truck-v2.png',
        sourceSize: const Size(1050, 850),
        centerX: 0,
        worldZ: truckZ,
        worldWidth: 2.35,
        worldHeight: 1.9,
      ),
    ));
    for (final placement in cardPlacements) {
      layers.add((
        z: placement.center.z,
        widget: DioramaWorldCard(
          key: Key('diorama-${placement.role}-card-${placement.card.id}'),
          projector: projector,
          card: placement.card,
          tokens: tokens,
          center: placement.center,
          selected: selectedCardID == placement.card.id,
          worldWidth: placement.worldWidth,
          worldHeight: placement.worldHeight,
          onTap: placement.interactive
              ? () => onCardTap(placement.card.id)
              : null,
        ),
      ));
    }
    layers.sort((a, b) => b.z.compareTo(a.z));
    return [for (final layer in layers) layer.widget];
  }

  List<Widget> _fieldTargets(DioramaProjector projector) {
    const fields = [
      ('wheat', -10.5, -2.2, 35.2, 43.5),
      ('sunflower', 2.2, 10.5, 35.2, 43.5),
      ('potato', -10.5, -2.2, 26.5, 34.2),
      ('beet', 2.2, 10.5, 26.5, 34.2),
    ];
    return [
      for (final field in fields)
        DioramaFieldTarget(
          key: Key('diorama-field-target-${field.$1}'),
          projector: projector,
          fieldID: field.$1,
          enabled: legalFieldIDs.contains(field.$1),
          corners: [
            DioramaPoint(field.$2, 0.08, field.$5),
            DioramaPoint(field.$3, 0.08, field.$5),
            DioramaPoint(field.$3, 0.08, field.$4),
            DioramaPoint(field.$2, 0.08, field.$4),
          ],
          onTap: () => onFieldTap(field.$1),
        ),
    ];
  }

  List<Widget> _northBarracksLayers(
    DioramaProjector projector,
    DesignTokens tokens,
  ) {
    if (visibleNorthYear <= 0) return const [];
    const roofAsset =
        'assets/art/field_plan/world_lab_brigade_fields_north_diorama/'
        'north-barracks-roof-texture-v1.png';
    const frontAsset =
        'assets/art/field_plan/world_lab_brigade_fields_north_diorama/'
        'north-barracks-front-texture-v1.png';
    return [
      for (var year = 1; year <= visibleNorthYear; year++)
        Positioned.fill(
          key: Key('north-barracks-year-$year'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DioramaWorldPlate(
                key: Key('north-barracks-roof-year-$year'),
                projector: projector,
                assetPath: roofAsset,
                sourceSize: const Size(1150, 105),
                corners: [
                  DioramaPoint(-7.6, 1.36, _northBarracksZ(year) + 1.7),
                  DioramaPoint(7.6, 1.36, _northBarracksZ(year) + 1.7),
                  DioramaPoint(8.5, 1.36, _northBarracksZ(year)),
                  DioramaPoint(-8.5, 1.36, _northBarracksZ(year)),
                ],
              ),
              Positioned.fill(
                key: Key('north-card-spread-year-$year'),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final indexed
                        in (year <= removedCardsByYear.length
                                ? removedCardsByYear[year - 1]
                                : const <TableCard>[])
                            .indexed)
                      DioramaWorldCard(
                        key: Key('north-year-$year-card-${indexed.$2.id}'),
                        projector: projector,
                        card: indexed.$2,
                        tokens: tokens,
                        center: DioramaPoint(
                          (indexed.$1 -
                                  ((year <= removedCardsByYear.length
                                              ? removedCardsByYear[year - 1]
                                                    .length
                                              : 0) -
                                          1) /
                                      2) *
                              0.72,
                          1.43,
                          _northBarracksZ(year) +
                              0.78 +
                              (indexed.$1.isOdd ? 0.08 : 0),
                        ),
                        selected: false,
                        worldWidth: 0.84,
                        worldHeight: 1.18,
                        onTap: null,
                      ),
                    if ((year <= removedCardsByYear.length
                            ? removedCardsByYear[year - 1]
                            : const <TableCard>[])
                        .isEmpty)
                      _DioramaNorthEmptyMark(
                        projector: projector,
                        year: year,
                        worldZ: _northBarracksZ(year),
                      ),
                  ],
                ),
              ),
              DioramaWorldPlate.vertical(
                projector: projector,
                assetPath: frontAsset,
                sourceSize: const Size(1540, 145),
                centerX: 0,
                worldZ: _northBarracksZ(year),
                worldWidth: 17,
                worldHeight: 1.36,
              ),
              _DioramaNorthYearSign(
                projector: projector,
                year: year,
                worldZ: _northBarracksZ(year) - 0.03,
              ),
            ],
          ),
        ),
    ];
  }

  double _northBarracksZ(int year) => 92 - (year - 1) * 3.2;

  List<({double z, Widget widget})> _generatedVerticalLayers(
    DioramaProjector projector,
  ) {
    const root = 'assets/art/field_plan/world_lab_brigade_fields_diorama';
    const northRoot = 'assets/art/field_plan/world_lab_unified_north';
    return [
      (
        z: 48,
        widget: DioramaWorldPlate.vertical(
          projector: projector,
          assetPath: '$northRoot/north-station-v1.png',
          sourceSize: const Size(1774, 887),
          centerX: 0,
          worldZ: 48,
          worldWidth: 22,
          worldHeight: 5.7,
        ),
      ),
      for (final pines in const [
        (-8.5, 57.0, 11.5, 6.4, false),
        (8.5, 58.5, 11.5, 6.4, true),
        (-9.0, 65.0, 12.5, 6.9, true),
        (9.0, 67.0, 12.5, 6.9, false),
        (-9.5, 73.0, 13.5, 7.5, false),
        (9.5, 75.0, 13.5, 7.5, true),
        (-10.0, 81.0, 15.0, 8.2, true),
        (10.0, 82.5, 15.0, 8.2, false),
        (-10.5, 89.0, 16.0, 8.8, false),
        (10.5, 92.0, 16.0, 8.8, true),
      ])
        (
          z: pines.$2,
          widget: DioramaWorldPlate.vertical(
            projector: projector,
            assetPath: '$northRoot/north-sparse-pines-v1.png',
            sourceSize: const Size(1536, 1024),
            centerX: pines.$1,
            worldZ: pines.$2,
            worldWidth: pines.$3,
            worldHeight: pines.$4,
            flipX: pines.$5,
          ),
        ),
      (
        z: 104,
        widget: DioramaWorldPlate.vertical(
          projector: projector,
          assetPath: '$northRoot/north-forest-edge-v1.png',
          sourceSize: const Size(1774, 887),
          centerX: 0,
          worldZ: 104,
          worldWidth: 40,
          worldHeight: 17,
        ),
      ),
      for (final building in const [
        (-6.2, 12.1, 5.0, 2.5, false),
        (6.2, 12.1, 5.0, 2.5, true),
        (-6.3, 5.5, 4.6, 2.3, false),
        (6.3, 5.5, 4.6, 2.3, true),
      ])
        (
          z: building.$2,
          widget: DioramaWorldPlate.vertical(
            projector: projector,
            assetPath: '$root/farm-building-v1.png',
            sourceSize: const Size(1774, 887),
            centerX: building.$1,
            worldZ: building.$2,
            worldWidth: building.$3,
            worldHeight: building.$4,
            flipX: building.$5,
          ),
        ),
      for (final vegetation in const [
        (-6.5, 15.5, 8.2, 3.2, false),
        (6.4, 19.0, 8.6, 3.35, true),
        (-6.7, 23.0, 8.4, 3.25, false),
        (6.5, 26.0, 8.0, 3.1, true),
      ])
        (
          z: vegetation.$2,
          widget: DioramaWorldPlate.vertical(
            projector: projector,
            assetPath: '$root/travel-vegetation-v1.png',
            sourceSize: const Size(2008, 783),
            centerX: vegetation.$1,
            worldZ: vegetation.$2,
            worldWidth: vegetation.$3,
            worldHeight: vegetation.$4,
            flipX: vegetation.$5,
          ),
        ),
      for (final crop in const [
        (
          'crop-row-wheat-v1.png',
          -6.35,
          [42.5, 40.4, 38.3, 36.2],
          7.55,
          1.28,
          Size(2172, 724),
        ),
        (
          'crop-row-sunflower-v1.png',
          6.35,
          [42.5, 40.4, 38.3, 36.2],
          7.55,
          1.48,
          Size(2164, 726),
        ),
        (
          'crop-row-potato-v1.png',
          -6.35,
          [33.3, 31.4, 29.5, 27.6],
          7.55,
          0.82,
          Size(2172, 724),
        ),
        (
          'crop-row-beet-v1.png',
          6.35,
          [33.3, 31.4, 29.5, 27.6],
          7.55,
          0.68,
          Size(2048, 768),
        ),
      ])
        for (final row in crop.$3.indexed)
          (
            z: row.$2,
            widget: DioramaWorldPlate.vertical(
              projector: projector,
              assetPath: '$root/${crop.$1}',
              sourceSize: crop.$6,
              centerX: crop.$2,
              worldZ: row.$2,
              worldWidth: crop.$4,
              worldHeight: crop.$5,
              flipX: row.$1.isOdd,
            ),
          ),
    ];
  }
}

class _UnifiedNorthRailwayPainter extends CustomPainter {
  const _UnifiedNorthRailwayPainter({required this.projector});

  final DioramaProjector projector;

  double _centerX(double z) =>
      math.sin((z - 48) * 0.23) * 1.15 + math.sin((z - 48) * 0.09) * 0.55;

  Offset? _project(double z, double lateral) =>
      projector.project(DioramaPoint(_centerX(z) + lateral, 0.07, z));

  @override
  void paint(Canvas canvas, Size size) {
    final visibleZ = <double>[];
    for (var z = 48.6; z <= 97; z += 0.55) {
      if (_project(z, 0) != null) visibleZ.add(z);
    }
    if (visibleZ.length < 2) return;

    final leftBallast = <Offset>[];
    final rightBallast = <Offset>[];
    for (final z in visibleZ.reversed) {
      final left = _project(z, -1.08);
      final right = _project(z, 1.08);
      if (left != null && right != null) {
        leftBallast.add(left);
        rightBallast.add(right);
      }
    }
    if (leftBallast.length > 1) {
      final ballastPath = Path()
        ..addPolygon([...leftBallast, ...rightBallast.reversed], true);
      canvas.drawPath(ballastPath, Paint()..color = const Color(0x527c715b));
    }

    final sleeper = Paint()
      ..color = const Color(0xff574b38)
      ..strokeCap = StrokeCap.square;
    for (var z = 49.0; z <= 96.5; z += 1.25) {
      final left = _project(z, -0.92);
      final right = _project(z, 0.92);
      if (left == null || right == null) continue;
      sleeper.strokeWidth = ((right - left).distance * 0.12).clamp(1.1, 5.5);
      canvas.drawLine(left, right, sleeper);
    }

    for (final lateral in const [-0.58, 0.58]) {
      final rail = Path();
      var started = false;
      for (final z in visibleZ.reversed) {
        final point = _project(z, lateral);
        if (point == null) continue;
        if (!started) {
          rail.moveTo(point.dx, point.dy);
          started = true;
        } else {
          rail.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        rail,
        Paint()
          ..color = const Color(0xff20393d)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UnifiedNorthRailwayPainter oldDelegate) =>
      oldDelegate.projector.pose != projector.pose ||
      oldDelegate.projector.viewport != projector.viewport;
}

class _DioramaNorthYearSign extends StatelessWidget {
  const _DioramaNorthYearSign({
    required this.projector,
    required this.year,
    required this.worldZ,
  });

  final DioramaProjector projector;
  final int year;
  final double worldZ;

  @override
  Widget build(BuildContext context) {
    final quad = projector.projectQuad([
      DioramaPoint(-7.7, 1.16, worldZ),
      DioramaPoint(-5.25, 1.16, worldZ),
      DioramaPoint(-5.25, 0.72, worldZ),
      DioramaPoint(-7.7, 0.72, worldZ),
    ]);
    if (quad == null) return const SizedBox.shrink();
    const sourceSize = Size(150, 34);
    final transform = dioramaHomographyToQuad(sourceSize, quad);
    if (transform == null) return const SizedBox.shrink();
    return Positioned.fill(
      key: Key('north-year-label-$year'),
      child: Transform(
        alignment: Alignment.topLeft,
        transform: transform,
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            width: sourceSize.width,
            height: sourceSize.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xffd8c487),
              border: Border.all(color: const Color(0xff263f47), width: 3),
            ),
            child: Text(
              'YEAR $year',
              style: const TextStyle(
                color: Color(0xff263f47),
                fontFamily: 'PTSansNarrow',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DioramaNorthEmptyMark extends StatelessWidget {
  const _DioramaNorthEmptyMark({
    required this.projector,
    required this.year,
    required this.worldZ,
  });

  final DioramaProjector projector;
  final int year;
  final double worldZ;

  @override
  Widget build(BuildContext context) {
    final quad = projector.projectQuad([
      DioramaPoint(-0.68, 1.45, worldZ + 1.34),
      DioramaPoint(0.68, 1.45, worldZ + 1.34),
      DioramaPoint(0.82, 1.45, worldZ + 0.28),
      DioramaPoint(-0.82, 1.45, worldZ + 0.28),
    ]);
    if (quad == null) return const SizedBox.shrink();
    const sourceSize = Size(100, 70);
    final transform = dioramaHomographyToQuad(sourceSize, quad);
    if (transform == null) return const SizedBox.shrink();
    return Positioned.fill(
      key: Key('north-empty-year-mark-$year'),
      child: Transform(
        alignment: Alignment.topLeft,
        transform: transform,
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            width: sourceSize.width,
            height: sourceSize.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xffe3d59f),
              border: Border.all(color: const Color(0xff263f47), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55263f47),
                  offset: Offset(2, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: const Text(
              '✓',
              style: TextStyle(
                color: Color(0xffa22d24),
                fontFamily: 'PTSansNarrow',
                fontWeight: FontWeight.w700,
                fontSize: 48,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DioramaWorldPlate extends StatelessWidget {
  const DioramaWorldPlate({
    required this.projector,
    required this.assetPath,
    required this.sourceSize,
    required this.corners,
    this.flipX = false,
    this.screenCorners,
    this.sourceRect,
    super.key,
  });

  factory DioramaWorldPlate.vertical({
    required DioramaProjector projector,
    required String assetPath,
    required Size sourceSize,
    required double centerX,
    required double worldZ,
    required double worldWidth,
    required double worldHeight,
    bool flipX = false,
  }) => DioramaWorldPlate(
    projector: projector,
    assetPath: assetPath,
    sourceSize: sourceSize,
    flipX: flipX,
    corners: [
      DioramaPoint(centerX - worldWidth / 2, worldHeight, worldZ),
      DioramaPoint(centerX + worldWidth / 2, worldHeight, worldZ),
      DioramaPoint(centerX + worldWidth / 2, 0, worldZ),
      DioramaPoint(centerX - worldWidth / 2, 0, worldZ),
    ],
  );

  final DioramaProjector projector;
  final String assetPath;
  final Size sourceSize;
  final List<DioramaPoint> corners;
  final bool flipX;
  final List<Offset>? screenCorners;
  final Rect? sourceRect;

  @override
  Widget build(BuildContext context) {
    final quad = screenCorners ?? projector.projectQuad(corners);
    if (quad == null || quad.any((point) => !point.isFinite)) {
      return const SizedBox.shrink();
    }
    final visibleSource = sourceRect ?? (Offset.zero & sourceSize);
    final transform = dioramaHomographyToQuad(visibleSource.size, quad);
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
            minWidth: visibleSource.width,
            maxWidth: visibleSource.width,
            minHeight: visibleSource.height,
            maxHeight: visibleSource.height,
            child: SizedBox.fromSize(
              size: visibleSource.size,
              child: Transform.flip(
                flipX: flipX,
                child: Image.asset(
                  assetPath,
                  fit: sourceRect == null ? BoxFit.fill : BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DioramaWorldCard extends StatelessWidget {
  const DioramaWorldCard({
    required this.projector,
    required this.card,
    required this.tokens,
    required this.center,
    required this.selected,
    this.worldWidth = 1.35,
    this.worldHeight = 1.95,
    required this.onTap,
    super.key,
  });

  final DioramaProjector projector;
  final TableCard card;
  final DesignTokens tokens;
  final DioramaPoint center;
  final bool selected;
  final double worldWidth;
  final double worldHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final quad = projector.projectQuad([
      DioramaPoint(
        center.x - worldWidth / 2,
        center.y,
        center.z + worldHeight / 2,
      ),
      DioramaPoint(
        center.x + worldWidth / 2,
        center.y,
        center.z + worldHeight / 2,
      ),
      DioramaPoint(
        center.x + worldWidth / 2,
        center.y,
        center.z - worldHeight / 2,
      ),
      DioramaPoint(
        center.x - worldWidth / 2,
        center.y,
        center.z - worldHeight / 2,
      ),
    ]);
    if (quad == null || quad.any((point) => !point.isFinite)) {
      return const SizedBox.shrink();
    }
    final sourceSize = Size(
      tokens.card.medium.width,
      tokens.card.medium.height,
    );
    final transform = dioramaHomographyToQuad(sourceSize, quad);
    if (transform == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: Transform(
        alignment: Alignment.topLeft,
        transform: transform,
        transformHitTests: true,
        child: Align(
          alignment: Alignment.topLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: GameCard(
              card: TableCard(
                id: card.id,
                suit: card.suit,
                value: card.value,
                rank: card.rank,
                selected: selected,
                highlighted: card.highlighted,
                pending: card.pending,
                assignmentRound: card.assignmentRound,
                nomenclature: card.nomenclature,
                ownerSeatID: card.ownerSeatID,
              ),
              tokens: tokens,
              sizeOverride: tokens.card.medium,
              motionTracked: false,
            ),
          ),
        ),
      ),
    );
  }
}

class DioramaFieldTarget extends StatelessWidget {
  const DioramaFieldTarget({
    required this.projector,
    required this.fieldID,
    required this.enabled,
    required this.corners,
    required this.onTap,
    super.key,
  });

  final DioramaProjector projector;
  final String fieldID;
  final bool enabled;
  final List<DioramaPoint> corners;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    final quad = projector.projectQuad(corners);
    if (quad == null || quad.any((point) => !point.isFinite)) {
      return const SizedBox.shrink();
    }
    const sourceSize = Size(240, 160);
    final transform = dioramaHomographyToQuad(sourceSize, quad);
    if (transform == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: Transform(
        alignment: Alignment.topLeft,
        transform: transform,
        transformHitTests: true,
        child: Align(
          alignment: Alignment.topLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: sourceSize.width,
              height: sourceSize.height,
              decoration: BoxDecoration(
                color: const Color(0x149f2d31),
                border: Border.all(color: const Color(0xfff1df9c), width: 8),
              ),
              alignment: Alignment.topCenter,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xdd9f2d31)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Text(
                    'ASSIGN TO ${fieldID.toUpperCase()}',
                    style: const TextStyle(
                      color: Color(0xfff4e8bd),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Matrix4? dioramaHomographyToQuad(Size size, List<Offset> destination) {
  if (destination.length != 4 || size.isEmpty) return null;
  final p0 = destination[0];
  final p1 = destination[1];
  final p2 = destination[2];
  final p3 = destination[3];
  final dx1 = p1.dx - p2.dx;
  final dx2 = p3.dx - p2.dx;
  final dx3 = p0.dx - p1.dx + p2.dx - p3.dx;
  final dy1 = p1.dy - p2.dy;
  final dy2 = p3.dy - p2.dy;
  final dy3 = p0.dy - p1.dy + p2.dy - p3.dy;
  final determinant = dx1 * dy2 - dx2 * dy1;
  if (determinant.abs() < 0.000001) return null;
  final projectiveX = (dx3 * dy2 - dx2 * dy3) / determinant;
  final projectiveY = (dx1 * dy3 - dx3 * dy1) / determinant;
  final a = p1.dx - p0.dx + projectiveX * p1.dx;
  final b = p3.dx - p0.dx + projectiveY * p3.dx;
  final d = p1.dy - p0.dy + projectiveX * p1.dy;
  final e = p3.dy - p0.dy + projectiveY * p3.dy;
  return Matrix4.identity()
    ..setEntry(0, 0, a / size.width)
    ..setEntry(0, 1, b / size.height)
    ..setEntry(0, 3, p0.dx)
    ..setEntry(1, 0, d / size.width)
    ..setEntry(1, 1, e / size.height)
    ..setEntry(1, 3, p0.dy)
    ..setEntry(3, 0, projectiveX / size.width)
    ..setEntry(3, 1, projectiveY / size.height);
}

class BrigadeFieldsBlockoutPainter extends CustomPainter {
  const BrigadeFieldsBlockoutPainter({
    required this.pose,
    required this.showGuides,
    this.overlayOnly = false,
    this.gameplayGroundOnly = false,
  });

  final DioramaCameraPose pose;
  final bool showGuides;
  final bool overlayOnly;
  final bool gameplayGroundOnly;

  static const paper = Color(0xffded3ad);
  static const palePaper = Color(0xffeadcaf);
  static const distantInk = Color(0xff173b43);
  static const fieldGreen = Color(0xff747b32);
  static const fieldGold = Color(0xffc59a25);
  static const deepGreen = Color(0xff2f573f);
  static const red = Color(0xff9f2d31);

  @override
  void paint(Canvas canvas, Size size) {
    final projector = DioramaProjector(pose: pose, viewport: size);
    if (gameplayGroundOnly) {
      _drawBrigade(canvas, projector);
      _drawFields(canvas, projector);
      _drawNorthGround(canvas, projector);
      return;
    }
    if (overlayOnly) {
      _drawFieldsOverlay(canvas, projector);
      if (showGuides) _drawGuides(canvas, size, projector);
      return;
    }
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    _drawPrintedHorizon(canvas, size, projector);
  }

  void _drawPrintedHorizon(
    Canvas canvas,
    Size size,
    DioramaProjector projector,
  ) {
    final projectedHorizon = projector.project(const DioramaPoint(0, 0, 10000));
    final horizonY = (projectedHorizon?.dy ?? size.height * 0.42).clamp(
      size.height * 0.08,
      size.height * 0.50,
    );
    final northInfluence = ((pose.routeZ - 34) / 34).clamp(0.0, 1.0);
    final sky = Color.lerp(distantInk, palePaper, northInfluence)!;
    final ground = Color.lerp(
      const Color(0xff92924d),
      const Color(0xffd5cfb8),
      northInfluence,
    )!;
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, horizonY + size.height * 0.16),
      Paint()..color = sky,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, horizonY + size.height * 0.13, size.width, size.height),
      Paint()..color = ground,
    );
    final cloudPaint = Paint()
      ..color = palePaper
      ..strokeWidth = math.max(2, size.width / 520)
      ..strokeCap = StrokeCap.square;
    for (final cloud in const [
      (0.08, 0.34, 0.16),
      (0.42, 0.25, 0.13),
      (0.72, 0.38, 0.19),
    ]) {
      final y = horizonY * cloud.$2;
      canvas.drawLine(
        Offset(size.width * cloud.$1, y),
        Offset(size.width * (cloud.$1 + cloud.$3), y),
        cloudPaint,
      );
    }
  }

  void _drawBrigade(Canvas canvas, DioramaProjector projector) {
    const plots = [
      (-10.5, -2.2, 7.0, 12.5, fieldGreen, 'PLOT 1'),
      (2.2, 10.5, 7.0, 12.5, fieldGold, 'PLOT 2'),
      (-10.5, -2.2, 0.5, 5.8, fieldGold, 'PLOT 3'),
      (2.2, 10.5, 0.5, 5.8, fieldGreen, 'YOU'),
    ];
    for (final plot in plots) {
      _drawGroundQuad(
        canvas,
        projector,
        xMin: plot.$1,
        xMax: plot.$2,
        zNear: plot.$3,
        zFar: plot.$4,
        color: plot.$5,
        outline: paper,
        label: plot.$6,
      );
      _drawCropRows(
        canvas,
        projector,
        xMin: plot.$1 + 0.45,
        xMax: plot.$2 - 0.45,
        zNear: plot.$3 + 0.35,
        zFar: plot.$4 - 0.45,
        color: plot.$5 == fieldGreen ? palePaper : deepGreen,
        rowCount: 7,
      );
    }
    _drawGroundQuad(
      canvas,
      projector,
      xMin: -2.0,
      xMax: 2.0,
      zNear: 2.7,
      zFar: 9.5,
      color: const Color(0xffb48d5c),
      outline: red,
      label: 'COMMUNAL TRICK ROAD',
    );
  }

  void _drawFields(Canvas canvas, DioramaProjector projector) {
    const fields = [
      (-10.5, -2.2, 35.2, 43.5, fieldGold, 'WHEAT'),
      (2.2, 10.5, 35.2, 43.5, Color(0xff8b8443), 'SUNFLOWER'),
      (-10.5, -2.2, 26.5, 34.2, Color(0xff9a8752), 'POTATO'),
      (2.2, 10.5, 26.5, 34.2, Color(0xff727b47), 'BEET'),
    ];
    for (final field in fields) {
      _drawGroundQuad(
        canvas,
        projector,
        xMin: field.$1,
        xMax: field.$2,
        zNear: field.$3,
        zFar: field.$4,
        color: field.$5,
        outline: paper,
        label: field.$6,
      );
    }
    _drawGroundQuad(
      canvas,
      projector,
      xMin: -2.3,
      xMax: 2.3,
      zNear: 28.0,
      zFar: 36.0,
      color: const Color(0xffb48d5c),
      outline: red,
      label: 'TRUCK YARD',
    );
  }

  void _drawNorthGround(Canvas canvas, DioramaProjector projector) {
    for (final band in const [
      (44.0, 58.0, Color(0xff8d884f)),
      (57.5, 70.5, Color(0xffa89c70)),
      (70.0, 82.5, Color(0xffc4b990)),
      (82.0, 112.0, Color(0xffded7be)),
    ]) {
      _drawGroundQuad(
        canvas,
        projector,
        xMin: -28,
        xMax: 28,
        zNear: band.$1,
        zFar: band.$2,
        color: band.$3,
      );
    }
  }

  void _drawFieldsOverlay(Canvas canvas, DioramaProjector projector) {
    const fields = [
      (-10.5, -2.2, 35.2, 43.5, 'WHEAT'),
      (2.2, 10.5, 35.2, 43.5, 'SUNFLOWER'),
      (-10.5, -2.2, 26.5, 34.2, 'POTATO'),
      (2.2, 10.5, 26.5, 34.2, 'BEET'),
    ];
    for (final field in fields) {
      _drawFieldFence(
        canvas,
        projector,
        xMin: field.$1,
        xMax: field.$2,
        zNear: field.$3,
        zFar: field.$4,
      );
      _drawJobSign(
        canvas,
        projector,
        x: (field.$1 + field.$2) / 2,
        z: field.$4 - 0.7,
        label: '${field.$5}  18/40',
      );
    }
  }

  void _drawCropRows(
    Canvas canvas,
    DioramaProjector projector, {
    required double xMin,
    required double xMax,
    required double zNear,
    required double zFar,
    required Color color,
    required int rowCount,
  }) {
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.72)
      ..strokeWidth = 1.15;
    for (var row = 0; row < rowCount; row++) {
      final x = lerpDouble(xMin, xMax, (row + 0.5) / rowCount)!;
      final near = projector.project(DioramaPoint(x, 0.025, zNear));
      final far = projector.project(DioramaPoint(x, 0.025, zFar));
      if (near == null || far == null) continue;
      canvas.drawLine(near, far, linePaint);
    }
  }

  void _drawFieldFence(
    Canvas canvas,
    DioramaProjector projector, {
    required double xMin,
    required double xMax,
    required double zNear,
    required double zFar,
  }) {
    final paint = Paint()
      ..color = distantInk
      ..strokeWidth = 1.7;
    _drawWorldLine(
      canvas,
      projector,
      DioramaPoint(xMin, 0.32, zNear),
      DioramaPoint(xMax, 0.32, zNear),
      paint,
    );
    _drawWorldLine(
      canvas,
      projector,
      DioramaPoint(xMin, 0.32, zFar),
      DioramaPoint(xMax, 0.32, zFar),
      paint,
    );
    for (var index = 0; index <= 5; index++) {
      final x = lerpDouble(xMin, xMax, index / 5)!;
      for (final z in [zNear, zFar]) {
        _drawWorldLine(
          canvas,
          projector,
          DioramaPoint(x, 0, z),
          DioramaPoint(x, 0.48, z),
          paint,
        );
      }
    }
  }

  void _drawWorldLine(
    Canvas canvas,
    DioramaProjector projector,
    DioramaPoint start,
    DioramaPoint end,
    Paint paint,
  ) {
    final a = projector.project(start);
    final b = projector.project(end);
    if (a != null && b != null) canvas.drawLine(a, b, paint);
  }

  void _drawJobSign(
    Canvas canvas,
    DioramaProjector projector, {
    required double x,
    required double z,
    required String label,
  }) {
    final bottom = projector.project(DioramaPoint(x, 0, z));
    final top = projector.project(DioramaPoint(x, 2.1, z));
    if (bottom == null || top == null) return;
    final height = (bottom.dy - top.dy).abs();
    final rect = Rect.fromCenter(
      center: top.translate(0, height * 0.22),
      width: math.max(34, height * 1.6),
      height: math.max(18, height * 0.62),
    );
    canvas.drawRect(rect, Paint()..color = paper);
    canvas.drawRect(
      rect,
      Paint()
        ..color = distantInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(rect.center.dx, rect.bottom),
      bottom,
      Paint()
        ..color = distantInk
        ..strokeWidth = 2,
    );
    _drawText(canvas, label, rect.center, distantInk, 10);
  }

  void _drawGroundQuad(
    Canvas canvas,
    DioramaProjector projector, {
    required double xMin,
    required double xMax,
    required double zNear,
    required double zFar,
    required Color color,
    Color? outline,
    String? label,
  }) {
    final clippedNear = math.max(zNear, projector.pose.routeZ + 0.38);
    if (zFar <= clippedNear) return;
    final points = projector.projectQuad([
      DioramaPoint(xMin, 0, zFar),
      DioramaPoint(xMax, 0, zFar),
      DioramaPoint(xMax, 0, clippedNear),
      DioramaPoint(xMin, 0, clippedNear),
    ]);
    if (points == null) return;
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, Paint()..color = color);
    if (outline != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (label != null) {
      final center = projector.project(
        DioramaPoint((xMin + xMax) / 2, 0.03, (zNear + zFar) / 2),
      );
      if (center != null) _drawText(canvas, label, center, paper, 11);
    }
  }

  void _drawGuides(Canvas canvas, Size size, DioramaProjector projector) {
    final paint = Paint()
      ..color = const Color(0x99ffdf83)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    for (var z = 0.0; z <= 45; z += 5) {
      final point = projector.project(DioramaPoint(0, 0.05, z));
      if (point != null) {
        canvas.drawCircle(point, 3, paint);
        _drawText(canvas, 'Z ${z.toStringAsFixed(0)}', point, paper, 9);
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double size,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: 'PTSansNarrow',
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 220);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(BrigadeFieldsBlockoutPainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.showGuides != showGuides ||
      oldDelegate.overlayOnly != overlayOnly ||
      oldDelegate.gameplayGroundOnly != gameplayGroundOnly;
}
