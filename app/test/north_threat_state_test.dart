import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/north_threat_state.dart';
import 'package:kolkhoz_app/src/world_depth_camera.dart';

void main() {
  const viewport = Size(1920, 800);

  test('threat anchors resolve exactly at Years 1, 3, and 5', () {
    expect(
      NorthThreatState.resolve(0).toJson(),
      NorthThreatState.year1.toJson(),
    );
    expect(
      NorthThreatState.resolve(0.5).toJson(),
      NorthThreatState.year3.toJson(),
    );
    expect(
      NorthThreatState.resolve(1).toJson(),
      NorthThreatState.year5.toJson(),
    );
  });

  test('threat interpolates continuously between approved anchors', () {
    final year2 = NorthThreatState.resolve(0.25);
    final year4 = NorthThreatState.resolve(0.75);

    expect(year2.year, 2);
    expect(year2.landmarkHeightFraction, closeTo(0.26, 0.000001));
    expect(year2.landmarkWidthFraction, closeTo(0.20, 0.000001));
    expect(year2.smoke, closeTo(0.26, 0.000001));
    expect(year4.year, 4);
    expect(year4.landmarkHeightFraction, closeTo(0.42, 0.000001));
    expect(year4.landmarkWidthFraction, closeTo(0.29, 0.000001));
    expect(year4.smoke, closeTo(0.65, 0.000001));
  });

  test('North landmark grows upward from its fixed base', () {
    for (final state in [
      NorthThreatState.year1,
      NorthThreatState.year3,
      NorthThreatState.year5,
    ]) {
      final rect = state.landmarkRect(viewport);
      expect(rect.bottomCenter, const Offset(960, 413));
      expect(
        rect.height,
        closeTo(viewport.height * state.landmarkHeightFraction, 0.001),
      );
      expect(
        rect.width,
        closeTo(viewport.width * state.landmarkWidthFraction, 0.001),
      );
    }
    expect(
      NorthThreatState.year5.landmarkRect(viewport).top,
      closeTo(13, 0.001),
    );
  });

  test('camera Z and resolved threat state are independent', () {
    final state = NorthThreatState.resolve(0.63).toJson();
    for (final cameraZ in [3.0, 4.0, 5.0]) {
      expect(worldDepthCameraCalibration.clampZ(cameraZ), cameraZ);
      expect(NorthThreatState.resolve(0.63).toJson(), state);
    }
    expect(worldDepthCameraCalibration.clampZ(5), 5);
    expect(NorthThreatState.resolve(0).threat, 0);
    expect(NorthThreatState.resolve(1).threat, 1);
    expect(worldDepthCameraCalibration.clampZ(5), 5);
  });
}
