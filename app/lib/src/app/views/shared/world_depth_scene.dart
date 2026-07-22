import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:kolkhoz_app/src/app/views/game/game_controller/models/north_threat_state.dart';
import 'package:kolkhoz_app/src/app/views/shared/printed_underlay.dart';
import 'package:kolkhoz_app/src/app/views/shared/world_depth_camera.dart';
import 'package:kolkhoz_app/src/app/views/shared/world_depth_manifest.dart';

const northCalibrationAssetDirectory = 'assets/art/field_plan/world_lab_north';
const northRouteCardAssetDirectory =
    'assets/art/field_plan/world_lab_north_route_cards';
const railwaySleeperTileAssetPath =
    'assets/art/field_plan/world_lab_route_components/rail-sleeper-only.png';
const rm40Y0AssetDirectory = 'assets/art/field_plan/world_lab_rm40_y0';
const northRidgeWorldZ = 30.0;
const northValleyWorldZ = 16.0;
const northCorridorObjectsWorldZ = 12.5;
const northForegroundWorldZ = 11.0;
const northHybridTransitionStartZ = 2.65;
const northHybridTransitionEndZ = 3.0;
const worldDepthStationWorldZ = 4.85;
const worldDepthStationNearestDistance = 1.05;
const northRailwayTerminalWorldZ = 10.15;
const worldDepthStationPassageStartZ =
    worldDepthStationWorldZ - worldDepthStationNearestDistance;
const worldDepthStationPassageEndZ = 4.25;
const _northReferenceCameraZ = 3.0;
const rm40ReferenceCameraZ = 8.05;
const northRouteCardStartZ = 4.35;
const _railwayIntervalOverlap = 0.035;

@immutable
class NorthRouteCard {
  const NorthRouteCard({
    required this.id,
    required this.nodeId,
    required this.worldZ,
    required this.assetPath,
    this.supplementalAssetPath,
  });

  final String id;
  final String nodeId;
  final double worldZ;
  final String assetPath;
  final String? supplementalAssetPath;

  double get referenceCameraZ => worldZ - 1.2;
}

const northRouteCards = <NorthRouteCard>[
  NorthRouteCard(
    id: 'a01',
    nodeId: '225:22',
    worldZ: 4.72,
    assetPath: '$northRouteCardAssetDirectory/a01.png',
  ),
  NorthRouteCard(
    id: 'a02',
    nodeId: '225:21',
    worldZ: 4.92,
    assetPath: '$northRouteCardAssetDirectory/a02.png',
  ),
  NorthRouteCard(
    id: 'a03',
    nodeId: '225:20',
    worldZ: 5.14,
    assetPath: '$northRouteCardAssetDirectory/a03.png',
  ),
  NorthRouteCard(
    id: 'a04',
    nodeId: '225:19',
    worldZ: 5.36,
    assetPath: '$northRouteCardAssetDirectory/a04.png',
  ),
  NorthRouteCard(
    id: 'a05',
    nodeId: '225:18',
    worldZ: 5.60,
    assetPath: '$northRouteCardAssetDirectory/a05.png',
  ),
  NorthRouteCard(
    id: 'a06',
    nodeId: '225:17',
    worldZ: 5.84,
    assetPath: '$northRouteCardAssetDirectory/a06.png',
  ),
  NorthRouteCard(
    id: 'a07',
    nodeId: '225:16',
    worldZ: 6.10,
    assetPath: '$northRouteCardAssetDirectory/a07.png',
  ),
  NorthRouteCard(
    id: 'a08',
    nodeId: '225:15',
    worldZ: 6.36,
    assetPath: '$northRouteCardAssetDirectory/a08.png',
  ),
  NorthRouteCard(
    id: 'a09',
    nodeId: '225:14',
    worldZ: 6.64,
    assetPath: '$northRouteCardAssetDirectory/a09.png',
    supplementalAssetPath:
        '$northRouteCardAssetDirectory/a09-valley-floor-proof.png',
  ),
  NorthRouteCard(
    id: 'a10',
    nodeId: '225:13',
    worldZ: 6.92,
    assetPath: '$northRouteCardAssetDirectory/a10.png',
  ),
  NorthRouteCard(
    id: 'a11',
    nodeId: '225:12',
    worldZ: 7.22,
    assetPath: '$northRouteCardAssetDirectory/a11.png',
  ),
  NorthRouteCard(
    id: 'a12',
    nodeId: '225:11',
    worldZ: 7.49,
    assetPath: '$northRouteCardAssetDirectory/a12.png',
  ),
];

const _rm40Y0Layers = <WorldDepthLayer>[
  WorldDepthLayer(
    id: 'rm40-y0-snow',
    name: 'Completed snow ground',
    nodeId: '225:5',
    worldZ: 14.0,
    assetPath: '$rm40Y0AssetDirectory/snow-ground.png',
    initialRect: Rect.fromLTWH(0, 0, 1, 1),
  ),
  WorldDepthLayer(
    id: 'rm40-y0-forest',
    name: 'Forest mass',
    nodeId: '225:6',
    worldZ: 12.0,
    assetPath: '$rm40Y0AssetDirectory/forest.png',
    initialRect: Rect.fromLTWH(0, 0, 1, 1),
  ),
  WorldDepthLayer(
    id: 'rm40-y0-hut',
    name: 'Utility hut',
    nodeId: '225:7',
    worldZ: 10.0,
    assetPath: '$rm40Y0AssetDirectory/hut.png',
    initialRect: Rect.fromLTWH(0, 0, 1, 1),
  ),
  WorldDepthLayer(
    id: 'rm40-y0-foreground',
    name: 'Foreground terrain',
    nodeId: '225:10',
    worldZ: 8.7,
    assetPath: '$rm40Y0AssetDirectory/foreground-terrain.png',
    initialRect: Rect.fromLTWH(0, 0, 1, 1),
  ),
];

double worldDepthStationPassageProgress(double cameraZ) {
  final linear =
      ((cameraZ - worldDepthStationPassageStartZ) /
              (worldDepthStationPassageEndZ - worldDepthStationPassageStartZ))
          .clamp(0.0, 1.0)
          .toDouble();
  return linear * linear;
}

double northHybridOpacity(double cameraZ) =>
    ((cameraZ - northHybridTransitionStartZ) /
            (northHybridTransitionEndZ - northHybridTransitionStartZ))
        .clamp(0.0, 1.0)
        .toDouble();

double northForegroundPassageOffset({
  required double viewportHeight,
  required double cameraZ,
}) {
  final progress = ((cameraZ - _northReferenceCameraZ) / 2)
      .clamp(0.0, 1.0)
      .toDouble();
  return viewportHeight * 1.25 * progress * progress;
}

LinearGradient threatHazeGradient(
  NorthThreatState state, {
  bool diagnostic = false,
}) {
  final peakOpacity = diagnostic
      ? 0.72
      : (0.08 + state.haze * 0.12).clamp(0.0, 1.0).toDouble();
  final color = diagnostic ? const Color(0xfff9f0b8) : const Color(0xffd6d0b1);
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      color.withValues(alpha: 0),
      color.withValues(alpha: peakOpacity * 0.45),
      color.withValues(alpha: peakOpacity),
      color.withValues(alpha: peakOpacity * 0.58),
      color.withValues(alpha: 0),
    ],
    stops: const <double>[0, 0.24, 0.48, 0.72, 1],
  );
}

LinearGradient threatSmokeGradient(NorthThreatState state) {
  final peakOpacity = (state.smoke * 0.055).clamp(0.0, 1.0).toDouble();
  const color = Color(0xff563b35);
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      color.withValues(alpha: 0),
      color.withValues(alpha: peakOpacity * 0.62),
      color.withValues(alpha: peakOpacity),
      color.withValues(alpha: 0),
    ],
    stops: const <double>[0, 0.38, 0.64, 1],
  );
}

@immutable
class WorldDepthProjection {
  const WorldDepthProjection({
    required this.rect,
    required this.opacity,
    required this.scale,
  });

  final Rect rect;
  final double opacity;
  final double scale;
}

@immutable
class RailwaySleeperProjection {
  const RailwaySleeperProjection({
    required this.worldZ,
    required this.x,
    required this.y,
    required this.rotationRadians,
  });

  final double worldZ;
  final double x;
  final double y;
  final double rotationRadians;
}

double northRailwayRouteOffset(double worldZ) {
  double smoothStep(double start, double end) {
    final linear = ((worldZ - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
    return linear * linear * (3 - 2 * linear);
  }

  final initialDrift = 0.025 * smoothStep(worldDepthStationWorldZ, 6.35);
  final northwardTurn = 0.305 * smoothStep(6.0, northRailwayTerminalWorldZ);
  return initialDrift - northwardTurn;
}

double northRailwayRouteCenterX({
  required double worldZ,
  required double cameraZ,
  required double viewportWidth,
}) {
  final trackingWorldZ = math.max(
    worldDepthStationWorldZ,
    cameraZ + worldDepthStationNearestDistance,
  );
  final relativeOffset =
      northRailwayRouteOffset(worldZ) - northRailwayRouteOffset(trackingWorldZ);
  final distance = math.max(worldDepthStationNearestDistance, worldZ - cameraZ);
  final perspective = (worldDepthStationNearestDistance / distance)
      .clamp(0.0, 1.0)
      .toDouble();
  return viewportWidth * worldDepthCameraCalibration.vanishingPointX +
      relativeOffset * viewportWidth * perspective;
}

/// Projects stable world-space sleepers beyond the station toward North.
///
/// Before the camera reaches the station, sleepers begin at the station and
/// recede toward North. After the camera passes it, the railway fills the
/// foreground. The Brigade and Fields side of the station remains a dirt road.
List<RailwaySleeperProjection> projectNorthRailwaySleepers({
  required double cameraZ,
  required double horizonY,
  required double viewportWidth,
  required double viewportHeight,
}) {
  const sleeperSpacing = 0.28;
  const nearestDistance = worldDepthStationNearestDistance;
  const minimumScreenSpacing = 2.5;
  final groundHeight = viewportHeight - horizonY;
  final perspectiveExtent = groundHeight * nearestDistance;
  final firstIndex =
      (math.max(cameraZ + nearestDistance, worldDepthStationWorldZ) /
              sleeperSpacing)
          .ceil();
  final lastIndex = (northRailwayTerminalWorldZ / sleeperSpacing).floor();
  final candidates = <RailwaySleeperProjection>[];
  for (var index = firstIndex; index <= lastIndex; index++) {
    final worldZ = index * sleeperSpacing;
    final distance = worldZ - cameraZ;
    if (distance < nearestDistance || worldZ > northRailwayTerminalWorldZ) {
      continue;
    }
    final y = horizonY + perspectiveExtent / distance;
    if (y > horizonY && y <= viewportHeight) {
      const tangentDelta = 0.025;
      final farWorldZ = math.min(
        northRailwayTerminalWorldZ,
        worldZ + tangentDelta,
      );
      final nearWorldZ = math.max(
        worldDepthStationWorldZ,
        worldZ - tangentDelta,
      );
      double projectedY(double sampleWorldZ) {
        final sampleDistance = sampleWorldZ - cameraZ;
        return horizonY + perspectiveExtent / sampleDistance;
      }

      final farX = northRailwayRouteCenterX(
        worldZ: farWorldZ,
        cameraZ: cameraZ,
        viewportWidth: viewportWidth,
      );
      final nearX = northRailwayRouteCenterX(
        worldZ: nearWorldZ,
        cameraZ: cameraZ,
        viewportWidth: viewportWidth,
      );
      final tangentX = nearX - farX;
      final tangentY = projectedY(nearWorldZ) - projectedY(farWorldZ);
      candidates.add(
        RailwaySleeperProjection(
          worldZ: worldZ,
          x: northRailwayRouteCenterX(
            worldZ: worldZ,
            cameraZ: cameraZ,
            viewportWidth: viewportWidth,
          ),
          y: y,
          rotationRadians: (-math.atan2(
            tangentX,
            tangentY,
          )).clamp(-0.24, 0.24).toDouble(),
        ),
      );
    }
  }
  candidates.sort((a, b) => a.y.compareTo(b.y));
  final visible = <RailwaySleeperProjection>[];
  for (final candidate in candidates) {
    if (visible.isEmpty ||
        candidate.y - visible.last.y >= minimumScreenSpacing) {
      visible.add(candidate);
    }
  }
  return visible;
}

WorldDepthProjection projectWorldDepthLayer({
  required WorldDepthManifest manifest,
  required WorldDepthLayer layer,
  required double cameraZ,
}) {
  final viewport = manifest.viewportSize;
  final initialRect = Rect.fromLTWH(
    layer.initialRect.left * viewport.width,
    layer.initialRect.top * viewport.height,
    layer.initialRect.width * viewport.width,
    layer.initialRect.height * viewport.height,
  );
  final vanishingPoint = Offset(
    manifest.vanishingPoint.dx * viewport.width,
    manifest.vanishingPoint.dy * viewport.height,
  );
  final distance = layer.worldZ - cameraZ;
  final calibration = worldDepthCameraCalibration;
  final denominator = math.max(
    calibration.nearPlane,
    manifest.focalLength + distance,
  );
  final projectedScale = ((manifest.focalLength + layer.worldZ) / denominator)
      .clamp(calibration.minimumScale, calibration.maximumScale)
      .toDouble();
  final exitT = ((-distance) / calibration.plateExitDistance)
      .clamp(0.0, 1.0)
      .toDouble();
  final crossingScale =
      ((manifest.focalLength + layer.worldZ) / manifest.focalLength)
          .clamp(calibration.minimumScale, calibration.maximumScale)
          .toDouble();
  final exitedScale =
      ((manifest.focalLength + layer.worldZ) /
              math.max(
                calibration.nearPlane,
                manifest.focalLength - calibration.plateExitDistance,
              ))
          .clamp(calibration.minimumScale, calibration.maximumScale)
          .toDouble();
  final scale = distance >= 0
      ? projectedScale
      : crossingScale + (exitedScale - crossingScale) * exitT;
  final center = vanishingPoint + (initialRect.center - vanishingPoint) * scale;
  final size = initialRect.size * scale;
  final scaledRect = Rect.fromCenter(
    center: center,
    width: size.width,
    height: size.height,
  );
  final crossingCenter =
      vanishingPoint + (initialRect.center - vanishingPoint) * crossingScale;
  final crossingTop =
      crossingCenter.dy - initialRect.height * crossingScale / 2;
  final exitTop = crossingTop + (viewport.height - crossingTop) * exitT;
  final rect = distance >= 0
      ? scaledRect
      : scaledRect.translate(0, exitTop - scaledRect.top);
  final isVisible = exitT < 1 && rect.top < viewport.height && rect.bottom > 0;
  return WorldDepthProjection(
    rect: rect,
    opacity: isVisible ? 1 : 0,
    scale: scale,
  );
}

/// Projects one registered North calibration layer from the Fields reference.
///
/// Registered North plates share this projection contract with the corridor.
WorldDepthProjection projectNorthCalibrationLayer({
  required Size viewport,
  required double worldZ,
  required double cameraZ,
  double referenceCameraZ = _northReferenceCameraZ,
}) {
  final calibration = worldDepthCameraCalibration;
  final vanishingPoint = Offset(
    calibration.vanishingPointX * viewport.width,
    calibration.vanishingPointY * viewport.height,
  );
  final initialRect = Offset.zero & viewport;
  final numerator = calibration.focalLength + worldZ - referenceCameraZ;
  final distance = worldZ - cameraZ;
  final projectedScale =
      (numerator /
              math.max(
                calibration.nearPlane,
                calibration.focalLength + distance,
              ))
          .clamp(calibration.minimumScale, calibration.maximumScale)
          .toDouble();
  final exitT = ((-distance) / calibration.plateExitDistance)
      .clamp(0.0, 1.0)
      .toDouble();
  final crossingScale = (numerator / calibration.focalLength)
      .clamp(calibration.minimumScale, calibration.maximumScale)
      .toDouble();
  final exitedScale =
      (numerator /
              math.max(
                calibration.nearPlane,
                calibration.focalLength - calibration.plateExitDistance,
              ))
          .clamp(calibration.minimumScale, calibration.maximumScale)
          .toDouble();
  final scale = distance >= 0
      ? projectedScale
      : crossingScale + (exitedScale - crossingScale) * exitT;
  final center = vanishingPoint + (initialRect.center - vanishingPoint) * scale;
  final size = initialRect.size * scale;
  var rect = Rect.fromCenter(
    center: center,
    width: size.width,
    height: size.height,
  );
  if (distance < 0) {
    final crossingCenter =
        vanishingPoint + (initialRect.center - vanishingPoint) * crossingScale;
    final crossingTop = crossingCenter.dy - viewport.height * crossingScale / 2;
    final exitTop = crossingTop + (viewport.height - crossingTop) * exitT;
    rect = rect.translate(0, exitTop - rect.top);
  }
  final visible = exitT < 1 && rect.top < viewport.height && rect.bottom > 0;
  return WorldDepthProjection(
    rect: rect,
    opacity: visible ? 1 : 0,
    scale: scale,
  );
}

class WorldDepthScene extends StatelessWidget {
  const WorldDepthScene({
    required this.manifest,
    required this.cameraZ,
    required this.threatState,
    required this.atmosphereEnabled,
    this.corridorProofEnabled = false,
    this.showLegacyAssets = true,
    this.showPlateLabels = false,
    this.showCalibrationGuides = false,
    this.atmosphereDiagnostic = false,
    super.key,
  });

  final WorldDepthManifest manifest;
  final double cameraZ;
  final NorthThreatState threatState;
  final bool atmosphereEnabled;
  final bool corridorProofEnabled;
  final bool showLegacyAssets;
  final bool showPlateLabels;
  final bool showCalibrationGuides;
  final bool atmosphereDiagnostic;

  @override
  Widget build(BuildContext context) {
    final hybridOpacity = northHybridOpacity(cameraZ);
    final routeCardsOwnRailway =
        corridorProofEnabled &&
        (!showLegacyAssets || cameraZ >= northRouteCardStartZ);
    return ColoredBox(
      color: const Color(0xff091315),
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox.fromSize(
            size: manifest.viewportSize,
            child: RepaintBoundary(
              key: const Key('world-depth-scene-evidence'),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (!showLegacyAssets)
                    Positioned.fill(
                      child: corridorProofEnabled
                          ? _NorthRouteCardScene(
                              cameraZ: cameraZ,
                              threatState: threatState,
                              atmosphereEnabled: atmosphereEnabled,
                              atmosphereDiagnostic: atmosphereDiagnostic,
                              showLabels: showPlateLabels,
                            )
                          : const _RouteProceduralUnderpaint(),
                    ),
                  if (showLegacyAssets && hybridOpacity < 1)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 1 - hybridOpacity,
                        child: Image.asset(
                          manifest.layers
                              .singleWhere((layer) => layer.id == 'U00')
                              .assetPath,
                          key: const Key('world-depth-underpaint'),
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.none,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  if (showLegacyAssets && hybridOpacity == 0)
                    _NearWorldPlateStack(
                      manifest: manifest,
                      cameraZ: cameraZ,
                      showPlateLabels: showPlateLabels,
                    ),
                  if (showLegacyAssets &&
                      hybridOpacity > 0 &&
                      hybridOpacity < 1)
                    Opacity(
                      opacity: 1 - hybridOpacity,
                      child: _NearWorldPlateStack(
                        manifest: manifest,
                        cameraZ: cameraZ,
                        showPlateLabels: showPlateLabels,
                      ),
                    ),
                  if (showLegacyAssets && hybridOpacity > 0)
                    Positioned.fill(
                      child: Opacity(
                        opacity: hybridOpacity,
                        child: corridorProofEnabled
                            ? cameraZ < northRouteCardStartZ
                                  ? _ArtBackedNorthScene(
                                      cameraZ: cameraZ,
                                      threatState: threatState,
                                      atmosphereEnabled: atmosphereEnabled,
                                      atmosphereDiagnostic:
                                          atmosphereDiagnostic,
                                      showLabels: showPlateLabels,
                                    )
                                  : _NorthRouteCardScene(
                                      cameraZ: cameraZ,
                                      threatState: threatState,
                                      atmosphereEnabled: atmosphereEnabled,
                                      atmosphereDiagnostic:
                                          atmosphereDiagnostic,
                                      showLabels: showPlateLabels,
                                    )
                            : _ArtBackedNorthScene(
                                cameraZ: cameraZ,
                                threatState: threatState,
                                atmosphereEnabled: atmosphereEnabled,
                                atmosphereDiagnostic: atmosphereDiagnostic,
                                showLabels: showPlateLabels,
                              ),
                      ),
                    ),
                  _WorldRouteCorridor(
                    cameraZ: cameraZ,
                    showLabel: showPlateLabels,
                    paintRailway: !routeCardsOwnRailway,
                  ),
                  if (showCalibrationGuides)
                    Positioned.fill(
                      child: CustomPaint(
                        key: const Key('world-depth-calibration-guides'),
                        painter: WorldDepthCalibrationGuidePainter(
                          manifest: manifest,
                          cameraZ: cameraZ,
                          threatState: threatState,
                          atmosphereEnabled: atmosphereEnabled,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NearWorldPlateStack extends StatelessWidget {
  const _NearWorldPlateStack({
    required this.manifest,
    required this.cameraZ,
    required this.showPlateLabels,
  });

  final WorldDepthManifest manifest;
  final double cameraZ;
  final bool showPlateLabels;

  @override
  Widget build(BuildContext context) {
    final layers = manifest.layers.where((layer) => layer.id != 'U00').toList();
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        for (final layer in layers) ...[
          if (layer.id != 'R10')
            _DepthPlate(
              layer: layer,
              projection: projectWorldDepthLayer(
                manifest: manifest,
                layer: layer,
                cameraZ: cameraZ,
              ),
              showLabel: showPlateLabels,
            ),
        ],
      ],
    );
  }
}

class WorldDepthCalibrationGuidePainter extends CustomPainter {
  const WorldDepthCalibrationGuidePainter({
    required this.manifest,
    required this.cameraZ,
    required this.threatState,
    required this.atmosphereEnabled,
  });

  final WorldDepthManifest manifest;
  final double cameraZ;
  final NorthThreatState threatState;
  final bool atmosphereEnabled;

  @override
  void paint(Canvas canvas, Size size) {
    final calibration = worldDepthCameraCalibration;
    final viewport = Offset.zero & size;
    final vanishingPoint = Offset(
      calibration.vanishingPointX * size.width,
      calibration.vanishingPointY * size.height,
    );
    final guide = Paint()
      ..color = const Color(0xff47e6ff)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final faintGuide = Paint()
      ..color = const Color(0x9947e6ff)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.clipRect(viewport);
    canvas.drawRect(viewport.deflate(2), guide);
    canvas.drawLine(
      Offset(0, vanishingPoint.dy),
      Offset(size.width, vanishingPoint.dy),
      guide,
    );
    canvas.drawLine(Offset(size.width / 2, size.height), vanishingPoint, guide);
    canvas.drawLine(
      vanishingPoint.translate(-14, 0),
      vanishingPoint.translate(14, 0),
      guide,
    );
    canvas.drawLine(
      vanishingPoint.translate(0, -14),
      vanishingPoint.translate(0, 14),
      guide,
    );
    canvas.drawCircle(vanishingPoint, 7, guide);

    for (final layer
        in cameraZ < _northReferenceCameraZ
            ? manifest.layers
            : const <WorldDepthLayer>[]) {
      final projection = projectWorldDepthLayer(
        manifest: manifest,
        layer: layer,
        cameraZ: cameraZ,
      );
      if (!projection.rect.isFinite) continue;
      final color = switch (layer.id[0]) {
        'B' => const Color(0xfff5c94d),
        'F' => const Color(0xff68e48b),
        _ => const Color(0xffe889ff),
      };
      faintGuide.color = color.withValues(alpha: 0.72);
      canvas.drawRect(projection.rect, faintGuide);
      if (projection.rect.overlaps(viewport)) {
        _drawText(
          canvas,
          '${layer.id}  Z ${layer.worldZ.toStringAsFixed(2)}  '
          '×${projection.scale.toStringAsFixed(2)}',
          projection.rect.topLeft + const Offset(5, 4),
          color,
          15,
        );
      }
    }

    if (cameraZ >= _northReferenceCameraZ) {
      for (final entry in const <(String, double, Color)>[
        ('RIDGE', northRidgeWorldZ, Color(0xffe889ff)),
        ('VALLEY', northValleyWorldZ, Color(0xff68e48b)),
        ('OBJECTS', northCorridorObjectsWorldZ, Color(0xffff9d66)),
        ('FOREGROUND', northForegroundWorldZ, Color(0xffff5c78)),
      ]) {
        final projection = projectNorthCalibrationLayer(
          viewport: size,
          worldZ: entry.$2,
          cameraZ: cameraZ,
        );
        if (projection.opacity == 0 || !projection.rect.isFinite) continue;
        faintGuide.color = entry.$3.withValues(alpha: 0.72);
        canvas.drawRect(projection.rect, faintGuide);
        if (projection.rect.top > 90) {
          _drawText(
            canvas,
            '${entry.$1}  Z ${entry.$2.toStringAsFixed(2)}  '
            '×${projection.scale.toStringAsFixed(2)}',
            projection.rect.topLeft + const Offset(5, 4),
            entry.$3,
            15,
          );
        }
      }
    }

    _drawText(
      canvas,
      'HORIZON / VP  '
      '${calibration.vanishingPointX.toStringAsFixed(2)}, '
      '${calibration.vanishingPointY.toStringAsFixed(2)}',
      Offset(12, vanishingPoint.dy + 8),
      const Color(0xff47e6ff),
      16,
    );
    final nearest = calibration.nearestStop(cameraZ);
    _drawText(
      canvas,
      'CAMERA Z ${cameraZ.toStringAsFixed(3)}   '
      '${calibration.regionAt(cameraZ)}   '
      'NEAREST ${nearest.label} (${nearest.z.toStringAsFixed(1)})\n'
      'PITCH ${calibration.pitchDegrees.toStringAsFixed(1)}°   '
      'YAW ${calibration.yawDegrees.toStringAsFixed(1)}°   '
      'NEAR ${calibration.nearPlane.toStringAsFixed(2)}',
      Offset(16, size.height - 66),
      const Color(0xffffffff),
      17,
      background: const Color(0xcc091315),
    );
    final anchor = const Offset(
      NorthThreatState.baseAnchorX,
      NorthThreatState.baseAnchorY,
    );
    final anchorPaint = Paint()
      ..color = const Color(0xffffd447)
      ..strokeWidth = 3;
    canvas.drawLine(
      anchor.translate(-18, 0),
      anchor.translate(18, 0),
      anchorPaint,
    );
    canvas.drawLine(
      anchor.translate(0, -18),
      anchor.translate(0, 18),
      anchorPaint,
    );
    _drawText(
      canvas,
      'FIXED NORTH BASE  [836, 394]',
      anchor.translate(12, 10),
      const Color(0xffffd447),
      15,
      background: const Color(0xcc091315),
    );
    _drawText(
      canvas,
      'THREAT ${threatState.threat.toStringAsFixed(3)}  '
      'YEAR ${threatState.year.toStringAsFixed(2)}  '
      'H ${threatState.landmarkHeightFraction.toStringAsFixed(3)}  '
      'W ${threatState.landmarkWidthFraction.toStringAsFixed(3)}\n'
      'CONTRAST ${threatState.contrast.toStringAsFixed(3)}  '
      'HAZE ${threatState.haze.toStringAsFixed(3)}  '
      'OPACITY ${threatState.opacity.toStringAsFixed(3)}  '
      'WARMTH ${threatState.warmth.toStringAsFixed(3)}  '
      'SMOKE ${threatState.smoke.toStringAsFixed(3)}  '
      'ATM ${atmosphereEnabled ? 'ON' : 'OFF'}',
      const Offset(16, 16),
      const Color(0xffffe8aa),
      16,
      background: const Color(0xcc091315),
    );
    canvas.restore();
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize, {
    Color? background,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          backgroundColor: background,
          fontFamily: 'PTSansNarrow',
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(WorldDepthCalibrationGuidePainter oldDelegate) =>
      oldDelegate.cameraZ != cameraZ ||
      oldDelegate.manifest != manifest ||
      oldDelegate.threatState != threatState ||
      oldDelegate.atmosphereEnabled != atmosphereEnabled;
}

class _ArtBackedNorthScene extends StatelessWidget {
  const _ArtBackedNorthScene({
    required this.cameraZ,
    required this.threatState,
    required this.atmosphereEnabled,
    required this.atmosphereDiagnostic,
    required this.showLabels,
  });

  final double cameraZ;
  final NorthThreatState threatState;
  final bool atmosphereEnabled;
  final bool atmosphereDiagnostic;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(
          child: Image(
            image: AssetImage('$northCalibrationAssetDirectory/00-sky.png'),
            fit: BoxFit.fill,
          ),
        ),
        _NorthLandmark(threatState: threatState),
        _RegisteredNorthLayer(
          id: 'ridge',
          assetPath: '$northCalibrationAssetDirectory/20-ridge.png',
          worldZ: northRidgeWorldZ,
          cameraZ: cameraZ,
          showLabel: showLabels,
        ),
        _RegisteredNorthLayer(
          id: 'valley',
          assetPath: '$northCalibrationAssetDirectory/30-valley-fields.png',
          worldZ: northValleyWorldZ,
          cameraZ: cameraZ,
          showLabel: showLabels,
        ),
        _RegisteredNorthLayer(
          id: 'objects',
          assetPath: '$northCalibrationAssetDirectory/50-corridor-objects.png',
          worldZ: northCorridorObjectsWorldZ,
          cameraZ: cameraZ,
          showLabel: showLabels,
        ),
        _RegisteredNorthLayer(
          id: 'foreground',
          assetPath: '$northCalibrationAssetDirectory/60-foreground.png',
          worldZ: northForegroundWorldZ,
          cameraZ: cameraZ,
          passageExit: true,
          showLabel: showLabels,
        ),
        if (atmosphereEnabled) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ThreatAtmospherePainter(
                  state: threatState,
                  diagnostic: atmosphereDiagnostic,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NorthRouteCardScene extends StatelessWidget {
  const _NorthRouteCardScene({
    required this.cameraZ,
    required this.threatState,
    required this.atmosphereEnabled,
    required this.atmosphereDiagnostic,
    required this.showLabels,
  });

  final double cameraZ;
  final NorthThreatState threatState;
  final bool atmosphereEnabled;
  final bool atmosphereDiagnostic;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final viewport = Size(
      worldDepthCameraCalibration.viewportWidth,
      worldDepthCameraCalibration.viewportHeight,
    );
    double lowerBoundary(int index) => index == 0
        ? worldDepthStationWorldZ
        : (northRouteCards[index - 1].worldZ + northRouteCards[index].worldZ) /
              2;
    double upperBoundary(int index) => index == northRouteCards.length - 1
        ? (northRouteCards[index].worldZ + northRailwayTerminalWorldZ) / 2
        : (northRouteCards[index].worldZ + northRouteCards[index + 1].worldZ) /
              2;
    final terminalBoundary = upperBoundary(northRouteCards.length - 1);
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(child: _RouteProceduralUnderpaint()),
        Positioned.fill(
          child: _Rm40Y0TerminalScene(cameraZ: cameraZ, showLabels: showLabels),
        ),
        _WorldRouteCorridor(
          cameraZ: cameraZ,
          showLabel: false,
          railwayMinWorldZ: terminalBoundary,
          paintRoadAndStation: false,
          evidenceOwner: false,
        ),
        for (var index = northRouteCards.length - 1; index >= 0; index--) ...[
          _NorthRouteTerrainCard(
            card: northRouteCards[index],
            projection: projectNorthCalibrationLayer(
              viewport: viewport,
              worldZ: northRouteCards[index].worldZ,
              cameraZ: cameraZ,
              referenceCameraZ: northRouteCards[index].referenceCameraZ,
            ),
            showLabel: showLabels,
          ),
          _WorldRouteCorridor(
            key: Key('world-depth-route-segment-${northRouteCards[index].id}'),
            cameraZ: cameraZ,
            showLabel: false,
            railwayMinWorldZ: lowerBoundary(index),
            railwayMaxWorldZ: upperBoundary(index),
            paintRoadAndStation: false,
            evidenceOwner: false,
          ),
        ],
        if (atmosphereEnabled)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ThreatAtmospherePainter(
                  state: threatState,
                  diagnostic: atmosphereDiagnostic,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RouteProceduralUnderpaint extends StatelessWidget {
  const _RouteProceduralUnderpaint();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      key: Key('world-depth-new-pass-underpaint'),
      child: PrintedPaperSurface(
        color: Color(0xffd6cda9),
        textureOpacity: 0.30,
        child: CustomPaint(painter: _RouteUnderpaintPainter()),
      ),
    );
  }
}

class _RouteUnderpaintPainter extends CustomPainter {
  const _RouteUnderpaintPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = worldDepthCameraCalibration.vanishingPointY * size.height;
    canvas.drawRect(
      Rect.fromLTRB(0, horizon, size.width, size.height),
      Paint()..color = const Color(0xffc1ad72),
    );
    final farBand = Path()
      ..moveTo(0, horizon + size.height * 0.08)
      ..quadraticBezierTo(
        size.width * 0.23,
        horizon + size.height * 0.01,
        size.width * 0.46,
        horizon + size.height * 0.10,
      )
      ..quadraticBezierTo(
        size.width * 0.73,
        horizon + size.height * 0.18,
        size.width,
        horizon + size.height * 0.06,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(farBand, Paint()..color = const Color(0xffaaa368));
  }

  @override
  bool shouldRepaint(_RouteUnderpaintPainter oldDelegate) => false;
}

class _NorthRouteTerrainCard extends StatelessWidget {
  const _NorthRouteTerrainCard({
    required this.card,
    required this.projection,
    required this.showLabel,
  });

  final NorthRouteCard card;
  final WorldDepthProjection projection;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (projection.opacity <= 0) return const SizedBox.shrink();
    return Positioned.fromRect(
      rect: projection.rect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (card.supplementalAssetPath case final supplementalAssetPath?)
            Image.asset(
              supplementalAssetPath,
              key: Key('world-depth-route-card-${card.id}-supplement'),
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          Image.asset(
            card.assetPath,
            key: Key('world-depth-route-card-${card.id}'),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
          if (showLabel)
            Align(
              alignment: Alignment.topLeft,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xcc091315)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    '${card.id.toUpperCase()} · WORLD Z ${card.worldZ.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xffffdf83),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Rm40Y0TerminalScene extends StatelessWidget {
  const _Rm40Y0TerminalScene({required this.cameraZ, required this.showLabels});

  final double cameraZ;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final viewport = Size(
      worldDepthCameraCalibration.viewportWidth,
      worldDepthCameraCalibration.viewportHeight,
    );
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(child: _Rm40ProceduralSky()),
        for (final layer in _rm40Y0Layers)
          _Rm40DepthCard(
            layer: layer,
            projection: projectNorthCalibrationLayer(
              viewport: viewport,
              worldZ: layer.worldZ,
              cameraZ: cameraZ,
              referenceCameraZ: rm40ReferenceCameraZ,
            ),
            showLabel: showLabels,
          ),
      ],
    );
  }
}

class _Rm40ProceduralSky extends StatelessWidget {
  const _Rm40ProceduralSky();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        key: const Key('world-depth-layer-rm40-y0-sky'),
        width: 1920,
        height: 800,
        child: const PrintedPaperSurface(
          color: Color(0xffd4d2c8),
          textureOpacity: 0.32,
          child: CustomPaint(painter: _Rm40CloudPainter()),
        ),
      ),
    );
  }
}

class _Rm40CloudPainter extends CustomPainter {
  const _Rm40CloudPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xff9ca6aa);
    for (final spec in const <Rect>[
      Rect.fromLTWH(236, 90, 320, 22),
      Rect.fromLTWH(1230, 176, 270, 20),
      Rect.fromLTWH(1400, 86, 410, 24),
      Rect.fromLTWH(1820, 126, 180, 20),
    ]) {
      final path = Path()
        ..moveTo(spec.left, spec.top + spec.height * 0.65)
        ..lineTo(spec.left + spec.width * 0.19, spec.top + spec.height * 0.35)
        ..lineTo(spec.left + spec.width * 0.72, spec.top + spec.height * 0.40)
        ..lineTo(spec.right, spec.top + spec.height * 0.60)
        ..lineTo(spec.left + spec.width * 0.80, spec.top + spec.height * 0.78)
        ..lineTo(spec.left + spec.width * 0.22, spec.top + spec.height * 0.78)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_Rm40CloudPainter oldDelegate) => false;
}

class _Rm40DepthCard extends StatelessWidget {
  const _Rm40DepthCard({
    required this.layer,
    required this.projection,
    required this.showLabel,
  });

  final WorldDepthLayer layer;
  final WorldDepthProjection projection;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (projection.opacity <= 0) return const SizedBox.shrink();
    return Positioned.fromRect(
      rect: projection.rect,
      child: Opacity(
        opacity: projection.opacity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              layer.assetPath,
              key: Key('world-depth-layer-${layer.id}'),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
            if (showLabel)
              Align(
                alignment: Alignment.topLeft,
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xcc091315)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      '${layer.id.toUpperCase()} · Z ${layer.worldZ.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xffffdf83),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NorthLandmark extends StatelessWidget {
  const _NorthLandmark({required this.threatState});

  final NorthThreatState threatState;

  @override
  Widget build(BuildContext context) {
    final scaleX =
        threatState.landmarkWidthFraction /
        NorthThreatState.year3.landmarkWidthFraction;
    final scaleY =
        threatState.landmarkHeightFraction /
        NorthThreatState.year3.landmarkHeightFraction;
    final contrast = threatState.contrast / NorthThreatState.year3.contrast;
    final offset = 128 * (1 - contrast);
    return Positioned.fill(
      child: Transform(
        alignment: Alignment(
          NorthThreatState.baseAnchorX *
                  2 /
                  worldDepthCameraCalibration.viewportWidth -
              1,
          NorthThreatState.baseAnchorY *
                  2 /
                  worldDepthCameraCalibration.viewportHeight -
              1,
        ),
        transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
        child: Opacity(
          opacity: (threatState.opacity / NorthThreatState.year3.opacity).clamp(
            0.0,
            1.0,
          ),
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(<double>[
              contrast + threatState.warmth * 0.08,
              0,
              0,
              0,
              offset + threatState.warmth * 9,
              0,
              contrast,
              0,
              0,
              offset,
              0,
              0,
              contrast - threatState.warmth * 0.05,
              0,
              offset - threatState.warmth * 5,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: const Image(
              key: Key('world-depth-north-landmark'),
              image: AssetImage(
                '$northCalibrationAssetDirectory/10-north-landmark.png',
              ),
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisteredNorthLayer extends StatelessWidget {
  const _RegisteredNorthLayer({
    required this.id,
    required this.assetPath,
    required this.worldZ,
    required this.cameraZ,
    required this.showLabel,
    this.passageExit = false,
  });

  final String id;
  final String assetPath;
  final double worldZ;
  final double cameraZ;
  final bool showLabel;
  final bool passageExit;

  @override
  Widget build(BuildContext context) {
    final viewport = Size(
      worldDepthCameraCalibration.viewportWidth,
      worldDepthCameraCalibration.viewportHeight,
    );
    final projection = projectNorthCalibrationLayer(
      viewport: viewport,
      worldZ: worldZ,
      cameraZ: cameraZ,
    );
    if (projection.opacity == 0) return const SizedBox.shrink();
    final vanishingPoint = Offset(
      worldDepthCameraCalibration.vanishingPointX * viewport.width,
      worldDepthCameraCalibration.vanishingPointY * viewport.height,
    );
    final scaledCenter =
        vanishingPoint +
        ((Offset.zero & viewport).center - vanishingPoint) * projection.scale;
    final scaledTop = scaledCenter.dy - viewport.height * projection.scale / 2;
    final passageOffset = passageExit
        ? northForegroundPassageOffset(
            viewportHeight: viewport.height,
            cameraZ: cameraZ,
          )
        : 0.0;
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(0, projection.rect.top - scaledTop + passageOffset),
        child: Transform(
          alignment: Alignment(
            worldDepthCameraCalibration.vanishingPointX * 2 - 1,
            worldDepthCameraCalibration.vanishingPointY * 2 - 1,
          ),
          transform: Matrix4.diagonal3Values(
            projection.scale,
            projection.scale,
            1,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                assetPath,
                key: Key('world-depth-north-layer-$id'),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                gaplessPlayback: true,
              ),
              if (showLabel)
                Align(
                  alignment: Alignment.topLeft,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Color(0xcc091315)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        '${id.toUpperCase()} · Z ${worldZ.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xffffdf83),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreatAtmospherePainter extends CustomPainter {
  const _ThreatAtmospherePainter({
    required this.state,
    required this.diagnostic,
  });

  final NorthThreatState state;
  final bool diagnostic;

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = worldDepthCameraCalibration.vanishingPointY * size.height;
    final smokeRect = Rect.fromLTRB(
      0,
      math.max(0, horizon - size.height * 0.34),
      size.width,
      math.min(size.height, horizon + size.height * 0.18),
    );
    canvas.drawRect(
      smokeRect,
      Paint()..shader = threatSmokeGradient(state).createShader(smokeRect),
    );
    final hazeRect = Rect.fromLTRB(
      0,
      math.max(0, horizon - size.height * 0.20),
      size.width,
      math.min(size.height, horizon + size.height * 0.34),
    );
    canvas.drawRect(
      hazeRect,
      Paint()
        ..shader = threatHazeGradient(
          state,
          diagnostic: diagnostic,
        ).createShader(hazeRect),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(105, 48, 42, state.warmth * 0.055),
    );
  }

  @override
  bool shouldRepaint(_ThreatAtmospherePainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.diagnostic != diagnostic;
}

class _DepthPlate extends StatelessWidget {
  const _DepthPlate({
    required this.layer,
    required this.projection,
    required this.showLabel,
  });

  final WorldDepthLayer layer;
  final WorldDepthProjection projection;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (projection.opacity <= 0) return const SizedBox.shrink();
    return Positioned.fromRect(
      rect: projection.rect,
      child: Opacity(
        opacity: projection.opacity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SizedBox.expand(
              key: Key('world-depth-layer-${layer.id.toLowerCase()}'),
              child: Image.asset(
                layer.assetPath,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            ),
            if (showLabel)
              Align(
                alignment: Alignment.topLeft,
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xcc091315)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      '${layer.id} · Z ${layer.worldZ.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xffffdf83),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorldRouteCorridor extends StatelessWidget {
  const _WorldRouteCorridor({
    required this.cameraZ,
    required this.showLabel,
    this.railwayMinWorldZ = worldDepthStationWorldZ,
    this.railwayMaxWorldZ = northRailwayTerminalWorldZ,
    this.paintRailway = true,
    this.paintRoadAndStation = true,
    this.evidenceOwner = true,
    super.key,
  });

  final double cameraZ;
  final bool showLabel;
  final double railwayMinWorldZ;
  final double railwayMaxWorldZ;
  final bool paintRailway;
  final bool paintRoadAndStation;
  final bool evidenceOwner;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              key: evidenceOwner
                  ? const Key('world-depth-route-corridor')
                  : null,
              painter: _WorldRouteCorridorPainter(
                cameraZ: cameraZ,
                showLabel: showLabel,
                pass: _RouteCorridorPaintPass.underlay,
                railwayMinWorldZ: railwayMinWorldZ,
                railwayMaxWorldZ: railwayMaxWorldZ,
                paintRailway: paintRailway,
                paintRoadAndStation: paintRoadAndStation,
              ),
            ),
            if (paintRailway)
              _WorldRailwayRasterTiles(
                cameraZ: cameraZ,
                railwayMinWorldZ: railwayMinWorldZ,
                railwayMaxWorldZ: railwayMaxWorldZ,
              ),
            CustomPaint(
              painter: _WorldRouteCorridorPainter(
                cameraZ: cameraZ,
                showLabel: showLabel,
                pass: _RouteCorridorPaintPass.overlay,
                railwayMinWorldZ: railwayMinWorldZ,
                railwayMaxWorldZ: railwayMaxWorldZ,
                paintRailway: paintRailway,
                paintRoadAndStation: paintRoadAndStation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldRailwayRasterTiles extends StatelessWidget {
  const _WorldRailwayRasterTiles({
    required this.cameraZ,
    required this.railwayMinWorldZ,
    required this.railwayMaxWorldZ,
  });

  final double cameraZ;
  final double railwayMinWorldZ;
  final double railwayMaxWorldZ;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final calibration = worldDepthCameraCalibration;
        final horizonY = calibration.vanishingPointY * size.height;
        final groundHeight = size.height + 2 - horizonY;
        final sleepers =
            projectNorthRailwaySleepers(
                  cameraZ: cameraZ,
                  horizonY: horizonY,
                  viewportWidth: size.width,
                  viewportHeight: size.height,
                )
                .where(
                  (sleeper) =>
                      sleeper.worldZ >= railwayMinWorldZ &&
                      sleeper.worldZ <= railwayMaxWorldZ,
                )
                .toList();

        double xAt(double farHalfWidth, double nearHalfWidth, double y) {
          final t = ((y - horizonY) / groundHeight).clamp(0.0, 1.0);
          return farHalfWidth + (nearHalfWidth - farHalfWidth) * t;
        }

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (var index = 0; index < sleepers.length; index++)
              Builder(
                builder: (context) {
                  final sleeper = sleepers[index];
                  final gapAbove = index == 0
                      ? (sleepers.length > 1 ? sleepers[1].y - sleeper.y : 8.0)
                      : sleeper.y - sleepers[index - 1].y;
                  final gapBelow = index == sleepers.length - 1
                      ? gapAbove
                      : sleepers[index + 1].y - sleeper.y;
                  final perspective = ((sleeper.y - horizonY) / groundHeight)
                      .clamp(0.0, 1.0);
                  final availableHeight = (gapAbove + gapBelow) * 0.48;
                  final tileHeight = math.max(
                    5.0,
                    math.min(availableHeight, 10 + 30 * perspective),
                  );
                  final halfWidth = xAt(7, 52, sleeper.y);
                  return Positioned(
                    left: sleeper.x - halfWidth,
                    top: sleeper.y - tileHeight / 2,
                    width: halfWidth * 2,
                    height: tileHeight,
                    child: Transform.rotate(
                      angle: sleeper.rotationRadians,
                      child: Image.asset(
                        railwaySleeperTileAssetPath,
                        key: Key(
                          'world-depth-rail-tile-${sleeper.worldZ.toStringAsFixed(2)}',
                        ),
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

enum _RouteCorridorPaintPass { underlay, overlay }

class _WorldRouteCorridorPainter extends CustomPainter {
  const _WorldRouteCorridorPainter({
    required this.cameraZ,
    required this.showLabel,
    required this.pass,
    required this.railwayMinWorldZ,
    required this.railwayMaxWorldZ,
    required this.paintRailway,
    required this.paintRoadAndStation,
  });

  final double cameraZ;
  final bool showLabel;
  final _RouteCorridorPaintPass pass;
  final double railwayMinWorldZ;
  final double railwayMaxWorldZ;
  final bool paintRailway;
  final bool paintRoadAndStation;

  @override
  void paint(Canvas canvas, Size size) {
    final calibration = worldDepthCameraCalibration;
    final centerX = calibration.vanishingPointX * size.width;
    final horizonY = calibration.vanishingPointY * size.height;
    final bottomY = size.height + 2;
    final groundHeight = bottomY - horizonY;

    double groundY(double worldZ) {
      const nearestDistance = worldDepthStationNearestDistance;
      final distance = worldZ - cameraZ;
      if (distance <= nearestDistance) return bottomY;
      return (horizonY + groundHeight * nearestDistance / distance).clamp(
        horizonY,
        bottomY,
      );
    }

    double xAt(double farHalfWidth, double nearHalfWidth, double y) {
      final t = ((y - horizonY) / groundHeight).clamp(0.0, 1.0);
      return farHalfWidth + (nearHalfWidth - farHalfWidth) * t;
    }

    final stationGroundY = groundY(worldDepthStationWorldZ);
    final railwayNearWorldZ = math.max(
      railwayMinWorldZ - _railwayIntervalOverlap,
      math.max(
        worldDepthStationWorldZ,
        cameraZ + worldDepthStationNearestDistance,
      ),
    );
    final railwayFarWorldZ = math.min(
      railwayMaxWorldZ + _railwayIntervalOverlap,
      northRailwayTerminalWorldZ,
    );
    final routeSamples =
        <
          ({
            double x,
            double y,
            double ballastHalfWidth,
            double railHalfWidth,
            double railStrokeHalfWidth,
          })
        >[];
    if (paintRailway && railwayFarWorldZ > railwayNearWorldZ) {
      const routeSampleCount = 24;
      for (var index = 0; index <= routeSampleCount; index++) {
        final t = index / routeSampleCount;
        final worldZ =
            railwayFarWorldZ + (railwayNearWorldZ - railwayFarWorldZ) * t;
        final y = groundY(worldZ).clamp(horizonY, bottomY);
        routeSamples.add((
          x: northRailwayRouteCenterX(
            worldZ: worldZ,
            cameraZ: cameraZ,
            viewportWidth: size.width,
          ),
          y: y,
          ballastHalfWidth: xAt(4.5, 32, y),
          railHalfWidth: xAt(2.5, 28, y),
          railStrokeHalfWidth: xAt(0.65, 2.6, y),
        ));
      }
    }
    final stationPassageProgress = worldDepthStationPassageProgress(cameraZ);
    final stationVisualY =
        stationGroundY + size.height * 0.38 * stationPassageProgress;

    if (pass == _RouteCorridorPaintPass.underlay) {
      if (routeSamples.isNotEmpty) {
        final railwayFar = routeSamples.first;
        Path ballastPath(double widthScale) {
          final ballast = Path()
            ..moveTo(
              railwayFar.x - railwayFar.ballastHalfWidth * widthScale,
              railwayFar.y,
            );
          for (final sample in routeSamples.skip(1)) {
            ballast.lineTo(
              sample.x - sample.ballastHalfWidth * widthScale,
              sample.y,
            );
          }
          for (final sample in routeSamples.reversed) {
            ballast.lineTo(
              sample.x + sample.ballastHalfWidth * widthScale,
              sample.y,
            );
          }
          return ballast..close();
        }

        final contactPaint = Paint()..blendMode = BlendMode.multiply;
        canvas.drawPath(
          ballastPath(1),
          contactPaint..color = const Color(0x24887860),
        );
        canvas.drawPath(
          ballastPath(0.68),
          contactPaint..color = const Color(0x38887860),
        );
      }

      if (paintRoadAndStation && stationGroundY < bottomY) {
        final roadHalfWidthAtStation = xAt(26, 292, stationGroundY);
        final road = Path()
          ..moveTo(centerX - roadHalfWidthAtStation, stationGroundY)
          ..lineTo(centerX - 292, bottomY)
          ..lineTo(centerX + 292, bottomY)
          ..lineTo(centerX + roadHalfWidthAtStation, stationGroundY)
          ..close();
        canvas.drawPath(road, Paint()..color = const Color(0xff9c774e));
        canvas.drawPath(
          road,
          Paint()
            ..color = const Color(0xff27383a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
        final rutPaint = Paint()
          ..color = const Color(0xffc3a16a)
          ..strokeWidth = 3;
        canvas.drawLine(
          Offset(centerX - roadHalfWidthAtStation * 0.35, stationGroundY),
          Offset(centerX - 108, bottomY),
          rutPaint,
        );
        canvas.drawLine(
          Offset(centerX + roadHalfWidthAtStation * 0.35, stationGroundY),
          Offset(centerX + 108, bottomY),
          rutPaint,
        );
      }
      return;
    }

    if (routeSamples.isNotEmpty) {
      _paintVariableRail(canvas, routeSamples, side: -1);
      _paintVariableRail(canvas, routeSamples, side: 1);
    }

    if (routeSamples.isNotEmpty &&
        railwayMaxWorldZ >= northRailwayTerminalWorldZ &&
        cameraZ >= 7.0) {
      final railwayFar = routeSamples.first;
      _paintRailwayEndStop(
        canvas,
        centerX: railwayFar.x,
        terminalY: railwayFar.y,
        horizonY: horizonY,
        groundHeight: groundHeight,
        railHalfWidth: railwayFar.railHalfWidth,
      );
    }

    if (paintRoadAndStation && stationPassageProgress < 1) {
      _paintStation(
        canvas,
        centerX: centerX,
        stationY: stationVisualY,
        groundHeight: groundHeight,
        horizonY: horizonY,
        roadHalfWidth: xAt(26, 292, stationGroundY),
      );
    }

    if (paintRoadAndStation && showLabel) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'DIRT ROAD → STATION → NORTH RAILWAY',
          style: TextStyle(
            color: Color(0xffffdf83),
            backgroundColor: Color(0xcc091315),
            fontFamily: 'PTSansNarrow',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(centerX + 34, horizonY + 16));
    }
  }

  void _paintVariableRail(
    Canvas canvas,
    List<
      ({
        double x,
        double y,
        double ballastHalfWidth,
        double railHalfWidth,
        double railStrokeHalfWidth,
      })
    >
    samples, {
    required double side,
  }) {
    final rail = Path();
    final first = samples.first;
    rail.moveTo(
      first.x + side * first.railHalfWidth - first.railStrokeHalfWidth,
      first.y,
    );
    for (final sample in samples.skip(1)) {
      rail.lineTo(
        sample.x + side * sample.railHalfWidth - sample.railStrokeHalfWidth,
        sample.y,
      );
    }
    for (final sample in samples.reversed) {
      rail.lineTo(
        sample.x + side * sample.railHalfWidth + sample.railStrokeHalfWidth,
        sample.y,
      );
    }
    rail.close();
    canvas.drawPath(rail, Paint()..color = const Color(0xff243436));
  }

  void _paintRailwayEndStop(
    Canvas canvas, {
    required double centerX,
    required double terminalY,
    required double horizonY,
    required double groundHeight,
    required double railHalfWidth,
  }) {
    final perspective = ((terminalY - horizonY) / groundHeight)
        .clamp(0.0, 1.0)
        .toDouble();
    final postHeight = 7 + 23 * perspective;
    final strokeWidth = 2 + 5 * perspective;
    final halfWidth = railHalfWidth * 1.75;
    final paint = Paint()
      ..color = const Color(0xff172b2d)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(centerX - railHalfWidth, terminalY),
      Offset(centerX - railHalfWidth, terminalY - postHeight),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + railHalfWidth, terminalY),
      Offset(centerX + railHalfWidth, terminalY - postHeight),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - halfWidth, terminalY - postHeight),
      Offset(centerX + halfWidth, terminalY - postHeight),
      paint,
    );
  }

  void _paintStation(
    Canvas canvas, {
    required double centerX,
    required double stationY,
    required double groundHeight,
    required double horizonY,
    required double roadHalfWidth,
  }) {
    final perspective = ((stationY - horizonY) / groundHeight)
        .clamp(0.0, 1.0)
        .toDouble();
    final platformWidth = math.max(120.0, roadHalfWidth * 2.9);
    final width = platformWidth * 0.76;
    final height = 26 + 54 * perspective;
    final platformHeight = 7 + 13 * perspective;
    final left = centerX - width / 2;
    final building = Rect.fromLTWH(
      left,
      stationY - height - platformHeight,
      width,
      height,
    );
    final platform = Rect.fromLTWH(
      centerX - platformWidth / 2,
      stationY - platformHeight,
      platformWidth,
      platformHeight,
    );
    final outline = Paint()
      ..color = const Color(0xff223638)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 + perspective * 2;
    canvas.drawRect(platform, Paint()..color = const Color(0xffc7aa72));
    canvas.drawRect(platform, outline);
    canvas.drawRect(building, Paint()..color = const Color(0xffd6c18a));
    canvas.drawRect(building, outline);
    final roof = Path()
      ..moveTo(left - width * 0.06, building.top)
      ..lineTo(left + width * 0.16, building.top - height * 0.22)
      ..lineTo(left + width * 0.84, building.top - height * 0.22)
      ..lineTo(left + width * 1.06, building.top)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xff26393b));
    final door = Rect.fromLTWH(
      centerX - width * 0.08,
      building.bottom - height * 0.52,
      width * 0.16,
      height * 0.52,
    );
    canvas.drawRect(door, Paint()..color = const Color(0xff8a4034));
    final windowPaint = Paint()..color = const Color(0xff557f7b);
    final windowWidth = width * 0.1;
    final windowHeight = height * 0.25;
    for (final x in <double>[
      left + width * 0.18,
      left + width * 0.32,
      left + width * 0.58,
      left + width * 0.72,
    ]) {
      canvas.drawRect(
        Rect.fromLTWH(
          x,
          building.top + height * 0.28,
          windowWidth,
          windowHeight,
        ),
        windowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WorldRouteCorridorPainter oldDelegate) => true;
}
