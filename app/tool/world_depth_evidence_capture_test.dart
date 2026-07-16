import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/field_plan_world_lab.dart';
import 'package:kolkhoz_app/src/north_threat_state.dart';
import 'package:kolkhoz_app/src/world_depth_camera.dart';
import 'package:kolkhoz_app/src/world_depth_manifest.dart';
import 'package:kolkhoz_app/src/world_depth_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'capture actual Flutter North calibration evidence',
    (tester) async {
      final outputValue = Platform.environment['WORLD_DEPTH_EVIDENCE_DIR'];
      if (outputValue == null || outputValue.isEmpty) {
        fail('WORLD_DEPTH_EVIDENCE_DIR is required.');
      }
      final output = Directory(outputValue)..createSync(recursive: true);
      final frames = Directory('${output.path}/frames')
        ..createSync(recursive: true);
      final dolly = Directory('${output.path}/dolly')
        ..createSync(recursive: true);
      final fullDolly = Directory('${output.path}/complete-dolly')
        ..createSync(recursive: true);
      final stationDolly = Directory('${output.path}/station-dolly')
        ..createSync(recursive: true);
      final manifest = await WorldDepthManifest.load();
      await tester.runAsync(() async {
        final loader = FontLoader('PTSansNarrow')
          ..addFont(
            rootBundle.load(
              'assets/art/field_plan/shared/fonts/PTSansNarrow-Regular.ttf',
            ),
          )
          ..addFont(
            rootBundle.load(
              'assets/art/field_plan/shared/fonts/PTSansNarrow-Bold.ttf',
            ),
          );
        await loader.load();
      });
      await tester.binding.setSurfaceSize(const Size(1672, 941));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var assetsPrecached = false;

      Future<void> pump({
        required double cameraZ,
        required double threat,
        bool atmosphere = true,
        bool guides = true,
      }) async {
        await tester.pumpWidget(
          FieldPlanWorldLabApp(
            key: UniqueKey(),
            manifest: manifest,
            initialCameraZ: cameraZ,
            initialThreat: threat,
            initialAtmosphereEnabled: atmosphere,
            initialGuidesEnabled: guides,
          ),
        );
        await tester.pump();
        if (!assetsPrecached) {
          final context = tester.element(
            find.byKey(const Key('world-depth-scene-evidence')),
          );
          await tester.runAsync(() async {
            await Future.wait([
              for (final layer in manifest.layers)
                precacheImage(AssetImage(layer.assetPath), context),
              for (final name in const [
                '00-sky.png',
                '10-north-landmark.png',
                '20-ridge.png',
                '30-valley-fields.png',
                '50-corridor-objects.png',
                '60-foreground.png',
                '70-atmosphere.png',
              ])
                precacheImage(
                  AssetImage('assets/art/field_plan/world_lab_north/$name'),
                  context,
                ),
            ]);
          });
          assetsPrecached = true;
          await tester.pump();
        }
        await tester.pumpAndSettle(const Duration(milliseconds: 40));
      }

      Future<void> pumpScene({
        required double cameraZ,
        required double threat,
        bool atmosphere = true,
        bool guides = false,
        bool labels = false,
        bool atmosphereDiagnostic = false,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: WorldDepthScene(
              manifest: manifest,
              cameraZ: cameraZ,
              threatState: NorthThreatState.resolve(threat),
              atmosphereEnabled: atmosphere,
              showCalibrationGuides: guides,
              showPlateLabels: labels,
              atmosphereDiagnostic: atmosphereDiagnostic,
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 40));
      }

      Future<void> capture(File file) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('world-depth-scene-evidence')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
          image.dispose();
        });
      }

      for (final entry in const <(String, double)>[
        ('year-1', 0),
        ('year-3', 0.5),
        ('year-5', 1),
      ]) {
        await pump(cameraZ: 3, threat: entry.$2);
        await capture(File('${frames.path}/fields-z3-${entry.$1}.png'));
        await pump(cameraZ: 5, threat: entry.$2);
        await capture(File('${frames.path}/north-z5-${entry.$1}.png'));
      }

      for (var index = 0; index <= 40; index++) {
        final cameraZ = 3 + 2 * index / 40;
        await pump(cameraZ: cameraZ, threat: 0.5, guides: false);
        await capture(
          File(
            '${stationDolly.path}/frame-${index.toString().padLeft(3, '0')}.png',
          ),
        );
      }

      for (final entry in const <(String, double)>[
        ('menu-z-2', -2),
        ('menu-brigade-midpoint-z-1', -1),
        ('brigade-z0', 0),
        ('brigade-fields-midpoint-z1-5', 1.5),
        ('fields-z3', 3),
        ('fields-north-midpoint-z4', 4),
        ('north-z5', 5),
      ]) {
        await pump(cameraZ: entry.$2, threat: 0.5, guides: false);
        await capture(File('${frames.path}/${entry.$1}.png'));
      }

      await pump(cameraZ: 3, threat: 0.5, guides: false);
      await capture(File('${frames.path}/atmosphere-on.png'));
      await pump(cameraZ: 3, threat: 0.5, atmosphere: false, guides: false);
      await capture(File('${frames.path}/atmosphere-off.png'));
      await pump(cameraZ: 5, threat: 1, guides: false);
      await capture(File('${frames.path}/year-5-clean.png'));

      await pumpScene(cameraZ: 3, threat: 0.5, atmosphereDiagnostic: true);
      await capture(File('${frames.path}/atmosphere-feather-diagnostic.png'));

      for (final entry in const <(String, double)>[
        ('fields', 3),
        ('north', 5),
      ]) {
        await pumpScene(
          cameraZ: entry.$2,
          threat: 0.5,
          guides: true,
          labels: true,
        );
        await capture(
          File('${frames.path}/foreground-objects-${entry.$1}.png'),
        );
      }

      for (final entry in const <(String, double)>[
        ('year-3', 0.5),
        ('year-5', 1),
      ]) {
        for (var index = 0; index <= 16; index++) {
          final cameraZ = 3 + 2 * index / 16;
          await pump(cameraZ: cameraZ, threat: entry.$2, guides: false);
          await capture(
            File(
              '${dolly.path}/${entry.$1}-${index.toString().padLeft(2, '0')}.png',
            ),
          );
        }
      }

      for (var index = 0; index <= 28; index++) {
        final cameraZ = -2 + 7 * index / 28;
        await pump(cameraZ: cameraZ, threat: 0.5, guides: false);
        await capture(
          File(
            '${fullDolly.path}/menu-to-north-${index.toString().padLeft(2, '0')}.png',
          ),
        );
      }

      const encoder = JsonEncoder.withIndent('  ');
      final camera = <String, Object>{
        'schemaVersion': 1,
        'authority': 'app/lib/src/world_depth_camera.dart',
        'viewport': <double>[
          worldDepthCameraCalibration.viewportWidth,
          worldDepthCameraCalibration.viewportHeight,
        ],
        ...worldDepthCameraCalibration.toManifestJson(),
      };
      final threat = <String, Object>{
        'schemaVersion': 1,
        'authority': 'app/lib/src/north_threat_state.dart',
        'normalizedThreatRange': <double>[0, 1],
        'yearRange': <double>[1, 5],
        'baseAnchorPixels': <double>[
          NorthThreatState.baseAnchorX,
          NorthThreatState.baseAnchorY,
        ],
        'interpolation': 'piecewise-linear',
        'anchors': <String, Object>{
          'year1': NorthThreatState.year1.toJson(),
          'year3': NorthThreatState.year3.toJson(),
          'year5': NorthThreatState.year5.toJson(),
        },
        'cameraZIndependent': true,
        'atmosphereEnabledByDefault': true,
      };
      final layers = <String, Object>{
        'schemaVersion': 1,
        'authority': 'app/lib/src/world_depth_scene.dart',
        'referenceCameraZ': 3.0,
        'hybridTransition': <String, double>{
          'startZ': northHybridTransitionStartZ,
          'endZ': northHybridTransitionEndZ,
        },
        'layers': <String, Object>{
          'ridge': <String, Object>{'worldZ': northRidgeWorldZ},
          'valley': <String, Object>{'worldZ': northValleyWorldZ},
          'railway': <String, Object>{
            'startsAtWorldZ': worldDepthStationWorldZ,
            'projection': 'station-to-North ground mesh',
          },
          'station': <String, Object>{
            'worldZ': worldDepthStationWorldZ,
            'nearestDistance': worldDepthStationNearestDistance,
            'passageStartZ': worldDepthStationPassageStartZ,
            'passageEndZ': worldDepthStationPassageEndZ,
            'passageCurve': 'quadratic screen-space exit',
          },
          'dirtRoad': <String, Object>{
            'endsAtWorldZ': worldDepthStationWorldZ,
            'projection': 'Menu-and-Fields-to-station ground mesh',
          },
          'corridorObjects': <String, Object>{
            'worldZ': northCorridorObjectsWorldZ,
          },
          'foreground': <String, Object>{
            'worldZ': northForegroundWorldZ,
            'passageExit': 'quadratic screen-space offset',
          },
        },
        'atmosphere': <String, Object>{
          'hazeTreatment': 'five-stop feathered vertical gradient',
          'smokeTreatment': 'four-stop feathered vertical gradient',
          'rasterMatteComposited': false,
          'runtimeBlur': false,
          'saveLayerMask': false,
        },
      };
      await tester.runAsync(() async {
        await File(
          '${output.path}/camera-contract.json',
        ).writeAsString('${encoder.convert(camera)}\n', flush: true);
        await File(
          '${output.path}/threat-contract.json',
        ).writeAsString('${encoder.convert(threat)}\n', flush: true);
        await File(
          '${output.path}/layer-depth-contract.json',
        ).writeAsString('${encoder.convert(layers)}\n', flush: true);
      });
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
