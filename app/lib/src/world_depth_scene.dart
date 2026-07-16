import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'north_threat_state.dart';
import 'world_depth_camera.dart';
import 'world_depth_manifest.dart';

const northCalibrationAssetDirectory = 'assets/art/field_plan/world_lab_north';
const corridorProofAssetDirectory =
    'assets/art/field_plan/world_lab_corridor_proof';
const northRidgeWorldZ = 30.0;
const northValleyWorldZ = 16.0;
const northCorridorObjectsWorldZ = 12.5;
const northForegroundWorldZ = 11.0;
const northHybridTransitionStartZ = 2.65;
const northHybridTransitionEndZ = 3.0;
const worldDepthStationWorldZ = 4.85;
const worldDepthStationNearestDistance = 1.05;
const worldDepthStationPassageStartZ =
    worldDepthStationWorldZ - worldDepthStationNearestDistance;
const worldDepthStationPassageEndZ = 4.25;
const _northReferenceCameraZ = 3.0;

const _corridorProofUnderpaint = WorldDepthLayer(
  id: 'proof-underpaint',
  name: 'Completed forest and snow backing',
  nodeId: 'depth-infill-00',
  worldZ: 9.0,
  assetPath: '$corridorProofAssetDirectory/underpaint-far.png',
  initialRect: Rect.fromLTWH(0, 0, 1, 1),
);

const _corridorProofLayers = <WorldDepthLayer>[
  WorldDepthLayer(
    id: 'proof-depth-00-far',
    name: 'Forest and camp',
    nodeId: 'depth-estimate-00',
    worldZ: 9.0,
    assetPath: '$corridorProofAssetDirectory/band-00-far.png',
    initialRect: Rect.fromLTWH(0, 0, 1, 0.4452709883103082),
  ),
  WorldDepthLayer(
    id: 'proof-depth-01',
    name: 'Distant snow country',
    nodeId: 'depth-estimate-01',
    worldZ: 7.8,
    assetPath: '$corridorProofAssetDirectory/band-01-mid.png',
    initialRect: Rect.fromLTWH(0, 0.34537725823591925, 1, 0.12433581296493093),
  ),
  WorldDepthLayer(
    id: 'proof-depth-02',
    name: 'Far snow farms',
    nodeId: 'depth-estimate-02',
    worldZ: 7.2,
    assetPath: '$corridorProofAssetDirectory/band-02-mid.png',
    initialRect: Rect.fromLTWH(0, 0.37619553666312433, 1, 0.13177470775770456),
  ),
  WorldDepthLayer(
    id: 'proof-depth-03',
    name: 'Near snow farms',
    nodeId: 'depth-estimate-03',
    worldZ: 6.6,
    assetPath: '$corridorProofAssetDirectory/band-03-mid.png',
    initialRect: Rect.fromLTWH(0, 0.39744952178533477, 1, 0.16259298618490967),
  ),
  WorldDepthLayer(
    id: 'proof-depth-04',
    name: 'Far fields',
    nodeId: 'depth-estimate-04',
    worldZ: 6.0,
    assetPath: '$corridorProofAssetDirectory/band-04-mid.png',
    initialRect: Rect.fromLTWH(0, 0.42826780021253985, 1, 0.1997874601487779),
  ),
  WorldDepthLayer(
    id: 'proof-depth-05',
    name: 'Middle fields',
    nodeId: 'depth-estimate-05',
    worldZ: 5.4,
    assetPath: '$corridorProofAssetDirectory/band-05-mid.png',
    initialRect: Rect.fromLTWH(0, 0.4303931987247609, 1, 0.30393198724760895),
  ),
  WorldDepthLayer(
    id: 'proof-depth-06',
    name: 'Near fields',
    nodeId: 'depth-estimate-06',
    worldZ: 4.8,
    assetPath: '$corridorProofAssetDirectory/band-06-mid.png',
    initialRect: Rect.fromLTWH(0, 0.43251859723698194, 1, 0.4442082890541977),
  ),
  WorldDepthLayer(
    id: 'proof-depth-07-near',
    name: 'Station approach',
    nodeId: 'depth-estimate-07',
    worldZ: 4.2,
    assetPath: '$corridorProofAssetDirectory/band-07-near.png',
    initialRect: Rect.fromLTWH(0, 0.43889479277364507, 1, 0.5611052072263549),
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
  const RailwaySleeperProjection({required this.worldZ, required this.y});

  final double worldZ;
  final double y;
}

/// Projects stable world-space sleepers beyond the station toward North.
///
/// Before the camera reaches the station, sleepers begin at the station and
/// recede toward North. After the camera passes it, the railway fills the
/// foreground. The Brigade and Fields side of the station remains a dirt road.
List<RailwaySleeperProjection> projectNorthRailwaySleepers({
  required double cameraZ,
  required double horizonY,
  required double viewportHeight,
}) {
  const sleeperSpacing = 0.55;
  const nearestDistance = worldDepthStationNearestDistance;
  const farthestDistance = 72.0;
  const minimumScreenSpacing = 2.5;
  final groundHeight = viewportHeight - horizonY;
  final perspectiveExtent = groundHeight * nearestDistance;
  final firstIndex =
      (math.max(cameraZ + nearestDistance, worldDepthStationWorldZ) /
              sleeperSpacing)
          .ceil();
  final lastIndex = ((cameraZ + farthestDistance) / sleeperSpacing).floor();
  final candidates = <RailwaySleeperProjection>[];
  for (var index = firstIndex; index <= lastIndex; index++) {
    final worldZ = index * sleeperSpacing;
    final distance = worldZ - cameraZ;
    if (distance < nearestDistance || distance > farthestDistance) continue;
    final y = horizonY + perspectiveExtent / distance;
    if (y > horizonY && y <= viewportHeight) {
      candidates.add(RailwaySleeperProjection(worldZ: worldZ, y: y));
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
}) {
  final calibration = worldDepthCameraCalibration;
  final vanishingPoint = Offset(
    calibration.vanishingPointX * viewport.width,
    calibration.vanishingPointY * viewport.height,
  );
  final initialRect = Offset.zero & viewport;
  final numerator = calibration.focalLength + worldZ - _northReferenceCameraZ;
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

WorldDepthProjection projectCorridorProofLayer({
  required Size viewport,
  required WorldDepthLayer layer,
  required double cameraZ,
}) {
  final calibration = worldDepthCameraCalibration;
  final initialRect = Rect.fromLTWH(
    layer.initialRect.left * viewport.width,
    layer.initialRect.top * viewport.height,
    layer.initialRect.width * viewport.width,
    layer.initialRect.height * viewport.height,
  );
  final vanishingPoint = Offset(
    calibration.vanishingPointX * viewport.width,
    calibration.vanishingPointY * viewport.height,
  );
  final numerator =
      calibration.focalLength + layer.worldZ - _northReferenceCameraZ;
  final distance = layer.worldZ - cameraZ;
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
  final bool showPlateLabels;
  final bool showCalibrationGuides;
  final bool atmosphereDiagnostic;

  @override
  Widget build(BuildContext context) {
    final hybridOpacity = northHybridOpacity(cameraZ);
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
                  if (hybridOpacity < 1)
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
                  if (hybridOpacity == 0)
                    _NearWorldPlateStack(
                      manifest: manifest,
                      cameraZ: cameraZ,
                      showPlateLabels: showPlateLabels,
                    ),
                  if (hybridOpacity > 0 && hybridOpacity < 1)
                    Opacity(
                      opacity: 1 - hybridOpacity,
                      child: _NearWorldPlateStack(
                        manifest: manifest,
                        cameraZ: cameraZ,
                        showPlateLabels: showPlateLabels,
                      ),
                    ),
                  if (hybridOpacity > 0)
                    Opacity(
                      opacity: hybridOpacity,
                      child: corridorProofEnabled
                          ? _CorridorProofScene(
                              cameraZ: cameraZ,
                              threatState: threatState,
                              atmosphereEnabled: atmosphereEnabled,
                              atmosphereDiagnostic: atmosphereDiagnostic,
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
                  if (!corridorProofEnabled)
                    _WorldRouteCorridor(
                      cameraZ: cameraZ,
                      showLabel: showPlateLabels,
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

class _CorridorProofScene extends StatelessWidget {
  const _CorridorProofScene({
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _DepthPlate(
          layer: _corridorProofUnderpaint,
          projection: projectCorridorProofLayer(
            viewport: viewport,
            layer: _corridorProofUnderpaint,
            cameraZ: cameraZ,
          ),
          showLabel: showLabels,
        ),
        for (final layer in _corridorProofLayers)
          _DepthPlate(
            layer: layer,
            projection: projectCorridorProofLayer(
              viewport: viewport,
              layer: layer,
              cameraZ: cameraZ,
            ),
            showLabel: showLabels,
          ),
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
  const _WorldRouteCorridor({required this.cameraZ, required this.showLabel});

  final double cameraZ;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          key: const Key('world-depth-route-corridor'),
          painter: _WorldRouteCorridorPainter(
            cameraZ: cameraZ,
            showLabel: showLabel,
          ),
        ),
      ),
    );
  }
}

class _WorldRouteCorridorPainter extends CustomPainter {
  const _WorldRouteCorridorPainter({
    required this.cameraZ,
    required this.showLabel,
  });

  final double cameraZ;
  final bool showLabel;

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
    final railwayEndY = stationGroundY.clamp(horizonY, bottomY);
    final stationPassageProgress = worldDepthStationPassageProgress(cameraZ);
    final stationVisualY =
        stationGroundY + size.height * 0.38 * stationPassageProgress;

    final ballast = Path()
      ..moveTo(centerX - 18, horizonY)
      ..lineTo(centerX - xAt(18, 292, railwayEndY), railwayEndY)
      ..lineTo(centerX + xAt(18, 292, railwayEndY), railwayEndY)
      ..lineTo(centerX + 18, horizonY)
      ..close();
    canvas.drawPath(ballast, Paint()..color = const Color(0xffdec286));
    canvas.drawPath(
      ballast,
      Paint()
        ..color = const Color(0xff192d2f)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final railPaint = Paint()
      ..color = const Color(0xff172b2d)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(centerX - 6, horizonY),
      Offset(centerX - xAt(6, 64, railwayEndY), railwayEndY),
      railPaint,
    );
    canvas.drawLine(
      Offset(centerX + 6, horizonY),
      Offset(centerX + xAt(6, 64, railwayEndY), railwayEndY),
      railPaint,
    );

    for (final sleeper in projectNorthRailwaySleepers(
      cameraZ: cameraZ,
      horizonY: horizonY,
      viewportHeight: size.height,
    )) {
      if (sleeper.y > railwayEndY) continue;
      final t = ((sleeper.y - horizonY) / groundHeight).clamp(0.0, 1.0);
      final halfWidth = xAt(11, 91, sleeper.y);
      final sleeperPaint = Paint()
        ..color = const Color(0xff203234)
        ..strokeWidth = 1 + 4 * t
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(
        Offset(centerX - halfWidth, sleeper.y),
        Offset(centerX + halfWidth, sleeper.y),
        sleeperPaint,
      );
    }

    if (stationGroundY < bottomY) {
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

    if (stationPassageProgress < 1) {
      _paintStation(
        canvas,
        centerX: centerX,
        stationY: stationVisualY,
        groundHeight: groundHeight,
        horizonY: horizonY,
        roadHalfWidth: xAt(26, 292, stationGroundY),
      );
    }

    if (showLabel) {
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
