import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/world_depth_camera.dart';

import '../tool/sync_world_depth_plates.dart';

void main() {
  test('Figma parser validates the near-world V2 stack', () {
    final response = _figmaResponse(includeM40: true);
    final plan = parseFigmaWorldDepthFrame(response, frameNodeId: '103:2');

    expect(plan.layers, hasLength(15));
    expect(plan.layers[5].id, 'R10');
    expect(plan.layers[5].worldZ, 30);
    expect(plan.layers.first.initialRect, [0.25, 0.1, 0.5, 0.5]);
    final camera =
        plan.manifestJson(SyncOptions.parse(const []))['camera']!
            as Map<String, Object>;
    expect(camera, worldDepthCameraCalibration.toManifestJson());
  });

  test('Figma parser fails closed when a required base plate disappears', () {
    final response = _figmaResponse(includeM40: false);

    expect(
      () => parseFigmaWorldDepthFrame(response, frameNodeId: '103:2'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('M40'),
        ),
      ),
    );
  });

  test('checked-in plate exports are registered transparent PNGs', () async {
    for (final id in requiredBaseLayerIds) {
      final file = File(
        'assets/art/field_plan/world_depth/${id.toLowerCase()}.png',
      );
      expect(await file.exists(), isTrue, reason: id);
      final info = PngInfo.read(await file.readAsBytes());
      expect(
        info.width,
        inInclusiveRange(defaultExportWidth - 2, defaultExportWidth + 2),
        reason: id,
      );
      // These plates remain legacy 1672 x 941 evidence while Flutter scales
      // them into the newer 1920 x 800 logical camera aperture.
      expect(info.height, inInclusiveRange(939, 943), reason: id);
      expect(info.hasAlpha, isTrue, reason: id);
    }
  });
}

Map<String, Object?> _figmaResponse({required bool includeM40}) {
  const ordered = <(String, double)>[
    ('U00', 7.75),
    ('N00', 7.75),
    ('N10', 7.40),
    ('N20', 6.70),
    ('M10', 3.20),
    ('R10', 30.00),
    ('T20', 2.65),
    ('T30', 2.25),
    ('T40', 1.85),
    ('B20', 1.05),
    ('B30', 0.35),
    ('B40', 0.15),
    ('M20', -0.35),
    ('M30', -0.70),
    ('M40', -1.25),
  ];
  final children = <Map<String, Object?>>[];
  for (final (id, z) in ordered) {
    if (id == 'M40' && !includeM40) continue;
    children.add({
      'id': 'node-$id',
      'name': '$id · Z ${z.toStringAsFixed(2)} · Test layer',
      'type': 'FRAME',
      'absoluteBoundingBox': {
        'x': 250.0,
        'y': 100.0,
        'width': 500.0,
        'height': 500.0,
      },
    });
  }
  return {
    'name': 'Kolkhoz world',
    'lastModified': '2026-07-14T00:00:00Z',
    'version': '1',
    'nodes': {
      '103:2': {
        'document': {
          'id': '103:2',
          'name': 'WORLD CAMERA VIEW · Near World V2 Runtime Plates',
          'absoluteBoundingBox': {
            'x': 0.0,
            'y': 0.0,
            'width': 1000.0,
            'height': 1000.0,
          },
          'children': children,
        },
      },
    },
  };
}
