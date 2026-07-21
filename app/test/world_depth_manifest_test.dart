import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/north_threat_state.dart';
import 'package:kolkhoz_app/src/world_depth_camera.dart';
import 'package:kolkhoz_app/src/world_depth_manifest.dart';
import 'package:kolkhoz_app/src/world_depth_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('checked-in Figma manifest preserves the near-world V2 stack', () async {
    final manifest = await WorldDepthManifest.load();

    expect(manifest.layers.map((layer) => layer.id), [
      'U00',
      'N00',
      'N10',
      'N20',
      'M10',
      'R10',
      'T20',
      'T30',
      'T40',
      'B20',
      'B30',
      'B40',
      'M20',
      'M30',
      'M40',
    ]);
    expect(manifest.stops.map((stop) => stop.z), [-2, 0, 3, 5, 8.05]);
  });

  test('camera contract owns stops and continuous route interpolation', () {
    final camera = worldDepthCameraCalibration;

    expect(camera.status, 'locked');
    expect(camera.viewportWidth, 1920);
    expect(camera.viewportHeight, 800);
    expect(camera.vanishingPointX, 0.5);
    expect(camera.vanishingPointY, 0.51625);
    expect(
      camera.viewportWidth * camera.vanishingPointX,
      NorthThreatState.baseAnchorX,
    );
    expect(
      camera.viewportHeight * camera.vanishingPointY,
      NorthThreatState.baseAnchorY,
    );
    expect(camera.stops.map((stop) => stop.id), [
      'menu',
      'brigade',
      'fields',
      'north',
      'camp',
    ]);
    expect(camera.zAtProgress(0), -2);
    expect(camera.zAtProgress(2 / 10.05), closeTo(0, 0.000001));
    expect(camera.zAtProgress(5 / 10.05), closeTo(3, 0.000001));
    expect(camera.zAtProgress(7 / 10.05), closeTo(5, 0.000001));
    expect(camera.zAtProgress(1), 8.05);
    expect(camera.zAtProgress(3.25 / 10.05), closeTo(1.25, 0.000001));
    expect(camera.progressAtZ(1.25), closeTo(3.25 / 10.05, 0.000001));
    expect(camera.zAtProgress(-1), camera.startZ);
    expect(camera.zAtProgress(2), camera.terminalZ);
  });

  test('stale generated camera metadata is rejected', () async {
    final source = await rootBundle.loadString(worldDepthManifestAssetPath);
    final json = jsonDecode(source) as Map<String, Object?>;
    final camera = json['camera']! as Map<String, Object?>;
    camera['vanishingPoint'] = <double>[0.5, 0.11];

    expect(
      () => WorldDepthManifest.fromJson(json),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('stale vanishing point'),
        ),
      ),
    );
  });

  test('railway sleepers begin at the station and continue toward North', () {
    final viewportWidth = worldDepthCameraCalibration.viewportWidth;
    final viewportHeight = worldDepthCameraCalibration.viewportHeight;
    final horizonY =
        viewportHeight * worldDepthCameraCalibration.vanishingPointY;
    final route = [-2.0, 0.0, 1.5, 3.0, 5.0].map(
      (cameraZ) => projectNorthRailwaySleepers(
        cameraZ: cameraZ,
        horizonY: horizonY,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
      ),
    );

    for (final sleepers in route) {
      expect(sleepers, isNotEmpty);
      expect(
        sleepers.every((sleeper) => sleeper.worldZ >= worldDepthStationWorldZ),
        isTrue,
      );
      expect(
        sleepers.every(
          (sleeper) => sleeper.worldZ <= northRailwayTerminalWorldZ,
        ),
        isTrue,
      );
      expect(sleepers.every((sleeper) => sleeper.worldZ.isFinite), isTrue);
      expect(sleepers.every((sleeper) => sleeper.x.isFinite), isTrue);
      expect(
        sleepers.every((sleeper) => sleeper.rotationRadians.isFinite),
        isTrue,
      );
      expect(
        sleepers.every(
          (sleeper) => sleeper.y > horizonY && sleeper.y <= viewportHeight,
        ),
        isTrue,
      );
    }

    final before = projectNorthRailwaySleepers(
      cameraZ: 0,
      horizonY: horizonY,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
    );
    final after = projectNorthRailwaySleepers(
      cameraZ: 0.2,
      horizonY: horizonY,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
    );
    final sharedWorldZ = before
        .map((sleeper) => sleeper.worldZ)
        .firstWhere(
          (worldZ) => after.any((sleeper) => sleeper.worldZ == worldZ),
        );
    final beforeY = before
        .singleWhere((sleeper) => sleeper.worldZ == sharedWorldZ)
        .y;
    final afterY = after
        .singleWhere((sleeper) => sleeper.worldZ == sharedWorldZ)
        .y;
    expect(afterY, greaterThan(beforeY));
    expect(
      before.map((sleeper) => sleeper.x.toStringAsFixed(3)).toSet().length,
      greaterThan(3),
    );
    expect(northRailwayRouteOffset(worldDepthStationWorldZ), 0);
    expect(northRailwayRouteOffset(6.6), greaterThan(0));
    expect(northRailwayRouteOffset(8.4), lessThan(0));
    expect(
      northRailwayRouteOffset(northRailwayTerminalWorldZ),
      lessThan(-0.25),
    );
  });

  test('railway has one fixed terminal beyond the playable camp camera', () {
    expect(northRailwayTerminalWorldZ, greaterThan(8.05));
    final viewportHeight = worldDepthCameraCalibration.viewportHeight;
    final terminalSleepers = projectNorthRailwaySleepers(
      cameraZ: 8.05,
      horizonY: viewportHeight * worldDepthCameraCalibration.vanishingPointY,
      viewportWidth: worldDepthCameraCalibration.viewportWidth,
      viewportHeight: viewportHeight,
    );
    expect(terminalSleepers, isNotEmpty);
    expect(
      terminalSleepers.every(
        (sleeper) => sleeper.worldZ <= northRailwayTerminalWorldZ,
      ),
      isTrue,
    );
    expect(
      terminalSleepers.first.x,
      lessThan(worldDepthCameraCalibration.viewportWidth * 0.49),
    );
    expect(
      northRailwayRouteCenterX(
        worldZ: northRailwayTerminalWorldZ,
        cameraZ: 8.05,
        viewportWidth: worldDepthCameraCalibration.viewportWidth,
      ),
      lessThan(worldDepthCameraCalibration.viewportWidth * 0.49),
    );
  });

  test(
    'station crosses the foreground continuously before railway takeover',
    () {
      expect(worldDepthStationWorldZ, 4.85);
      expect(worldDepthStationPassageStartZ, closeTo(3.8, 0.000001));
      expect(worldDepthStationPassageEndZ, 4.25);
      expect(worldDepthStationPassageProgress(3.75), 0);
      expect(
        worldDepthStationPassageProgress(4),
        closeTo(0.197530864, 0.000001),
      );
      expect(worldDepthStationPassageProgress(4.25), 1);
      expect(worldDepthStationPassageProgress(5), 1);
    },
  );

  test('foreground scales and moves more strongly than corridor objects', () {
    const viewport = Size(1920, 800);
    expect(northForegroundWorldZ, 11.0);
    expect(northForegroundWorldZ, lessThan(northCorridorObjectsWorldZ));

    final objectStart = projectNorthCalibrationLayer(
      viewport: viewport,
      worldZ: northCorridorObjectsWorldZ,
      cameraZ: 3,
    );
    final objectEnd = projectNorthCalibrationLayer(
      viewport: viewport,
      worldZ: northCorridorObjectsWorldZ,
      cameraZ: 5,
    );
    final foregroundStart = projectNorthCalibrationLayer(
      viewport: viewport,
      worldZ: northForegroundWorldZ,
      cameraZ: 3,
    );
    final foregroundEnd = projectNorthCalibrationLayer(
      viewport: viewport,
      worldZ: northForegroundWorldZ,
      cameraZ: 5,
    );

    expect(
      foregroundEnd.scale - foregroundStart.scale,
      greaterThan(objectEnd.scale - objectStart.scale),
    );
    expect(
      foregroundEnd.rect.bottom - foregroundStart.rect.bottom,
      greaterThan(objectEnd.rect.bottom - objectStart.rect.bottom),
    );
    expect(
      northForegroundPassageOffset(viewportHeight: viewport.height, cameraZ: 5),
      greaterThan(0),
    );
  });

  test('hybrid transition is continuous and preserves the approved bounds', () {
    expect(northHybridTransitionStartZ, 2.65);
    expect(northHybridTransitionEndZ, 3.0);
    expect(northHybridOpacity(2.64), 0);
    expect(northHybridOpacity(2.65), 0);
    expect(northHybridOpacity(2.825), closeTo(0.5, 0.000001));
    expect(northHybridOpacity(3), 1);
    expect(northHybridOpacity(3.01), 1);
  });

  test('twelve persistent terrain cards span station to camp', () {
    expect(northRouteCards, hasLength(12));
    expect(northRouteCards.first.id, 'a01');
    expect(northRouteCards.first.worldZ, greaterThan(northRouteCardStartZ));
    expect(northRouteCards.last.id, 'a12');
    expect(northRouteCards.last.worldZ, lessThan(rm40ReferenceCameraZ));
    expect(
      northRouteCards.map((card) => card.worldZ),
      orderedEquals(
        northRouteCards.map((card) => card.worldZ).toList()..sort(),
      ),
    );
    expect(
      northRouteCards.every(
        (card) => card.assetPath.contains('world_lab_north_route_cards'),
      ),
      isTrue,
    );
    expect(
      northRouteCards.map((card) => card.nodeId).toSet(),
      hasLength(northRouteCards.length),
    );
    expect(
      northRouteCards.every((card) => card.nodeId.startsWith('225:')),
      isTrue,
    );

    expect(rm40ReferenceCameraZ, greaterThan(northRouteCards.last.worldZ));
  });

  test('RM40 cards reproduce master registration at the Camp stop', () {
    const viewport = Size(1920, 800);
    for (final worldZ in [14.0, 12.0, 10.0, 9.1, 8.7]) {
      final atCamp = projectNorthCalibrationLayer(
        viewport: viewport,
        worldZ: worldZ,
        cameraZ: rm40ReferenceCameraZ,
        referenceCameraZ: rm40ReferenceCameraZ,
      );
      final before = projectNorthCalibrationLayer(
        viewport: viewport,
        worldZ: worldZ,
        cameraZ: 7.35,
        referenceCameraZ: rm40ReferenceCameraZ,
      );
      expect(atCamp.scale, closeTo(1, 0.000001));
      expect(atCamp.rect, Offset.zero & viewport);
      expect(before.scale, lessThan(1));
      expect(before.opacity, 1);
    }
  });

  test('pre-RM40 cards migrate from the authoring horizon', () {
    const viewport = Size(1920, 800);
    final projection = projectNorthCalibrationLayer(
      viewport: viewport,
      worldZ: northRouteCards.first.worldZ,
      cameraZ: northRouteCards.first.referenceCameraZ,
      referenceCameraZ: northRouteCards.first.referenceCameraZ,
      sourceVanishingPointY: worldDepthCardAuthoringVanishingPointY,
    );

    expect(projection.scale, 1);
    expect(
      projection.rect.top,
      closeTo(depthCardRegistrationOffsetY(viewport), 0.000001),
    );
    expect(projection.rect.top, closeTo(93, 0.000001));
  });

  test('snow basin begins below the projected RM40 hut contact', () {
    const viewport = Size(1920, 800);
    const cameraZ = 4.65;
    final card = northRouteCards.singleWhere((card) => card.id == 'a09');
    final hut = projectNorthCalibrationLayer(
      viewport: viewport,
      worldZ: 10,
      cameraZ: cameraZ,
      referenceCameraZ: rm40ReferenceCameraZ,
    );
    final aligned = alignValleyFloorBelowHut(
      valleyFloor: projectNorthCalibrationLayer(
        viewport: viewport,
        worldZ: card.worldZ,
        cameraZ: cameraZ,
        referenceCameraZ: card.referenceCameraZ,
        sourceVanishingPointY: worldDepthCardAuthoringVanishingPointY,
      ),
      hut: hut,
    );
    final hutGround = hut.rect.top + hut.rect.height * (551 / 800);
    final basinTop = aligned.rect.top + aligned.rect.height * (344 / 809);

    expect(basinTop, closeTo(hutGround + 2, 0.000001));
  });

  test('atmosphere haze is feathered and preserves year ordering', () {
    final year1 = threatHazeGradient(NorthThreatState.year1);
    final year3 = threatHazeGradient(NorthThreatState.year3);
    final year5 = threatHazeGradient(NorthThreatState.year5);

    for (final gradient in [year1, year3, year5]) {
      expect(gradient.colors.first.a, 0);
      expect(gradient.colors.last.a, 0);
      expect(gradient.stops, orderedEquals([0, 0.24, 0.48, 0.72, 1]));
    }
    expect(year1.colors[2].a, greaterThan(year3.colors[2].a));
    expect(year3.colors[2].a, greaterThan(year5.colors[2].a));

    final smoke1 = threatSmokeGradient(NorthThreatState.year1);
    final smoke3 = threatSmokeGradient(NorthThreatState.year3);
    final smoke5 = threatSmokeGradient(NorthThreatState.year5);
    for (final gradient in [smoke1, smoke3, smoke5]) {
      expect(gradient.colors.first.a, 0);
      expect(gradient.colors.last.a, 0);
    }
    expect(smoke5.colors[2].a, greaterThan(smoke3.colors[2].a));
    expect(smoke3.colors[2].a, greaterThan(smoke1.colors[2].a));
  });

  test('camera zero reproduces Figma and near plates grow faster', () async {
    final manifest = await WorldDepthManifest.load();
    final near = manifest.layers.singleWhere((layer) => layer.id == 'B40');
    final far = manifest.layers.singleWhere((layer) => layer.id == 'N00');

    final initial = projectWorldDepthLayer(
      manifest: manifest,
      layer: near,
      cameraZ: 0,
    );
    expect(initial.rect.left, closeTo(0, 0.001));
    expect(
      initial.rect.top,
      closeTo(depthCardRegistrationOffsetY(manifest.viewportSize), 0.001),
    );
    expect(initial.rect.width, closeTo(manifest.viewportSize.width, 0.001));

    double growth(WorldDepthLayer layer) {
      final before = projectWorldDepthLayer(
        manifest: manifest,
        layer: layer,
        cameraZ: 0,
      ).rect.width;
      final after = projectWorldDepthLayer(
        manifest: manifest,
        layer: layer,
        cameraZ: 0.2,
      ).rect.width;
      return after / before;
    }

    expect(growth(near), greaterThan(growth(far)));
  });

  test(
    'passed plates stay opaque while translating below the viewport',
    () async {
      final manifest = await WorldDepthManifest.load();
      final layer = manifest.layers.singleWhere((layer) => layer.id == 'B40');
      final before = projectWorldDepthLayer(
        manifest: manifest,
        layer: layer,
        cameraZ: layer.worldZ,
      );
      final exiting = projectWorldDepthLayer(
        manifest: manifest,
        layer: layer,
        cameraZ: layer.worldZ + 0.2,
      );
      final exited = projectWorldDepthLayer(
        manifest: manifest,
        layer: layer,
        cameraZ: layer.worldZ + worldDepthCameraCalibration.plateExitDistance,
      );

      expect(before.opacity, 1);
      expect(exiting.opacity, 1);
      expect(exiting.rect.top, greaterThan(before.rect.top));
      expect(exiting.rect.height, greaterThan(before.rect.height));
      expect(exited.rect.top, closeTo(manifest.viewportSize.height, 0.001));
      expect(exited.opacity, 0);
    },
  );

  test('passed plates exit at a constant screen-space rate', () async {
    final manifest = await WorldDepthManifest.load();
    final layer = manifest.layers.singleWhere((layer) => layer.id == 'B40');
    final projections = [0, 0.25, 0.5, 0.75].map((progress) {
      return projectWorldDepthLayer(
        manifest: manifest,
        layer: layer,
        cameraZ:
            layer.worldZ +
            worldDepthCameraCalibration.plateExitDistance * progress,
      );
    }).toList();

    final topSteps = [
      for (var index = 1; index < projections.length; index++)
        projections[index].rect.top - projections[index - 1].rect.top,
    ];
    final heightSteps = [
      for (var index = 1; index < projections.length; index++)
        projections[index].rect.height - projections[index - 1].rect.height,
    ];
    expect(topSteps[1], closeTo(topSteps[0], 0.001));
    expect(topSteps[2], closeTo(topSteps[0], 0.001));
    expect(heightSteps[1], closeTo(heightSteps[0], 0.001));
    expect(heightSteps[2], closeTo(heightSteps[0], 0.001));
  });

  test(
    'projection stays finite and scale-bounded over the supported path',
    () async {
      final manifest = await WorldDepthManifest.load();
      final camera = worldDepthCameraCalibration;

      for (var z = camera.startZ; z <= camera.terminalZ; z += 0.02) {
        for (final layer in manifest.layers) {
          final projection = projectWorldDepthLayer(
            manifest: manifest,
            layer: layer,
            cameraZ: z,
          );
          expect(
            projection.rect.left.isFinite,
            isTrue,
            reason: '${layer.id} $z',
          );
          expect(
            projection.rect.top.isFinite,
            isTrue,
            reason: '${layer.id} $z',
          );
          expect(
            projection.rect.width.isFinite,
            isTrue,
            reason: '${layer.id} $z',
          );
          expect(
            projection.rect.height.isFinite,
            isTrue,
            reason: '${layer.id} $z',
          );
          expect(
            projection.scale,
            inInclusiveRange(camera.minimumScale, camera.maximumScale),
            reason: '${layer.id} $z',
          );
        }
      }
    },
  );

  test('Camp is terminal after the North approach', () async {
    final manifest = await WorldDepthManifest.load();
    final camera = worldDepthCameraCalibration;
    expect(camera.stops[camera.stops.length - 2].id, 'north');
    expect(camera.stops[camera.stops.length - 2].z, 5);
    expect(camera.stops.last.id, 'camp');
    expect(camera.stops.last.z, camera.terminalZ);
    expect(northHybridOpacity(5), 1);
    expect(
      manifest.layers.singleWhere((layer) => layer.id == 'R10').worldZ,
      30,
    );
  });
}
