/// Artistically locked camera contract for the continuous 2.5D journey.
///
/// Keep the sync tool, runtime projection, and tests tied to this single
/// instance.
const worldDepthCameraCalibration = WorldDepthCameraCalibration(
  status: 'locked',
  viewportWidth: 1920,
  viewportHeight: 800,
  focalLength: 2,
  // Register the horizon to the current RM40 forest/snow seam and fixed North
  // base at y=413 on the 800px authoring plate. RM40's railway ends inside the
  // camp and is not an infinite vanishing-point line.
  vanishingPointX: 0.5,
  vanishingPointY: 0.51625,
  pitchDegrees: 0,
  yawDegrees: 0,
  startZ: -2,
  terminalZ: 8.05,
  nearPlane: 0.08,
  minimumScale: 0.04,
  maximumScale: 8,
  plateExitDistance: 0.55,
  stops: [
    WorldDepthStop(id: 'menu', label: 'MENU', z: -2),
    WorldDepthStop(id: 'brigade', label: 'BRIGADE', z: 0),
    WorldDepthStop(id: 'fields', label: 'FIELDS', z: 3),
    WorldDepthStop(id: 'north', label: 'NORTH', z: 5),
    WorldDepthStop(id: 'camp', label: 'CAMP', z: 8.05),
  ],
);

/// Vanishing-point Y used when the pre-RM40 depth cards were authored.
///
/// Their registration is migrated to [worldDepthCameraCalibration] at runtime;
/// RM40 was authored directly in the current camera and must not receive the
/// migration a second time.
const worldDepthCardAuthoringVanishingPointY = 0.40;

class WorldDepthStop {
  const WorldDepthStop({
    required this.id,
    required this.label,
    required this.z,
  });

  final String id;
  final String label;
  final double z;

  Map<String, Object> toJson() => {'id': id, 'label': label, 'z': z};
}

class WorldDepthCameraCalibration {
  const WorldDepthCameraCalibration({
    required this.status,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.focalLength,
    required this.vanishingPointX,
    required this.vanishingPointY,
    required this.pitchDegrees,
    required this.yawDegrees,
    required this.startZ,
    required this.terminalZ,
    required this.nearPlane,
    required this.minimumScale,
    required this.maximumScale,
    required this.plateExitDistance,
    required this.stops,
  });

  final String status;
  final double viewportWidth;
  final double viewportHeight;
  final double focalLength;
  final double vanishingPointX;
  final double vanishingPointY;
  final double pitchDegrees;
  final double yawDegrees;
  final double startZ;
  final double terminalZ;
  final double nearPlane;
  final double minimumScale;
  final double maximumScale;
  final double plateExitDistance;
  final List<WorldDepthStop> stops;

  double clampZ(double z) => z.clamp(startZ, terminalZ).toDouble();

  double zAtProgress(double progress) =>
      startZ + (terminalZ - startZ) * progress.clamp(0, 1).toDouble();

  double progressAtZ(double z) =>
      ((clampZ(z) - startZ) / (terminalZ - startZ)).clamp(0, 1).toDouble();

  WorldDepthStop nearestStop(double z) => stops.reduce(
    (best, stop) => (stop.z - z).abs() < (best.z - z).abs() ? stop : best,
  );

  String regionAt(double z) {
    final clamped = clampZ(z);
    for (var index = 0; index < stops.length - 1; index++) {
      final from = stops[index];
      final to = stops[index + 1];
      if (clamped < to.z) return '${from.label} → ${to.label}';
    }
    return stops.last.label;
  }

  Map<String, Object> toManifestJson() => {
    'status': status,
    'initialZ': startZ,
    'terminalZ': terminalZ,
    'focalLength': focalLength,
    'vanishingPoint': [vanishingPointX, vanishingPointY],
    'pitchDegrees': pitchDegrees,
    'yawDegrees': yawDegrees,
    'nearPlane': nearPlane,
    'minimumScale': minimumScale,
    'maximumScale': maximumScale,
    'plateExitDistance': plateExitDistance,
    'stops': stops.map((stop) => stop.toJson()).toList(),
  };
}
