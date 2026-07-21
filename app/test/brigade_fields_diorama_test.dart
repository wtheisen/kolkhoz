import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/brigade_fields_diorama_lab.dart';
import 'package:kolkhoz_app/src/diorama/brigade_fields_diorama.dart';

void main() {
  test('hero stops rise and tilt above the travel camera', () {
    const path = BrigadeFieldsCameraPath();
    final brigade = path.poseAt(0);
    final travel = path.poseAt(0.25);
    final fields = path.poseAt(BrigadeFieldsCameraPath.fieldsProgress);
    final north = path.poseAt(1);

    expect(brigade.height, greaterThan(travel.height));
    expect(fields.height, greaterThan(travel.height));
    expect(north.height, greaterThan(travel.height));
    expect(brigade.pitchRadians, greaterThan(travel.pitchRadians));
    expect(fields.pitchRadians, greaterThan(travel.pitchRadians));
    expect(north.pitchRadians, greaterThan(travel.pitchRadians));
    expect(brigade.height, fields.height);
    expect(fields.height, north.height);
    expect(brigade.pitchRadians, fields.pitchRadians);
  });

  test('route centerline remains centered under the shared projector', () {
    const viewport = Size(1200, 500);
    final pose = const BrigadeFieldsCameraPath().poseAt(0.5);
    final projector = DioramaProjector(pose: pose, viewport: viewport);
    final point = projector.project(DioramaPoint(0, 0, pose.routeZ + 10));

    expect(point, isNotNull);
    expect(point!.dx, closeTo(viewport.width / 2, 0.0001));
    expect(point.dy, greaterThan(0));
    expect(point.dy, lessThan(viewport.height));
  });

  test('sticky stops resist lightly and strong flicks cross the route', () {
    expect(
      brigadeFieldsResistedDelta(progress: 0.02, delta: 0.1),
      lessThan(0.1),
    );
    expect(
      brigadeFieldsResistedDelta(progress: 0.65, delta: 0.1),
      closeTo(0.1, 0.0001),
    );
    expect(brigadeFieldsSnapTarget(0.07, 0), 0);
    expect(brigadeFieldsSnapTarget(0.93, 0), 1);
    expect(brigadeFieldsSnapTarget(0.12, 0), 0.12);
    expect(brigadeFieldsSnapTarget(0.88, 0), 0.88);
    expect(
      brigadeFieldsSnapTarget(0.12, 2),
      BrigadeFieldsCameraPath.fieldsProgress,
    );
    expect(
      brigadeFieldsSnapTarget(0.88, -2),
      BrigadeFieldsCameraPath.fieldsProgress,
    );
    expect(brigadeFieldsSnapTarget(0.65, 0), 0.65);
  });

  test('homography maps a card into a finite ground quad', () {
    final transform = dioramaHomographyToQuad(const Size(100, 140), const [
      Offset(30, 20),
      Offset(90, 20),
      Offset(110, 120),
      Offset(10, 120),
    ]);

    expect(transform, isNotNull);
    expect(transform!.storage.every((value) => value.isFinite), isTrue);
  });

  test('homography maps every source corner onto a wide ground trapezoid', () {
    const source = Size(853, 1259);
    const quad = [
      Offset(350, 300),
      Offset(850, 300),
      Offset(1500, 700),
      Offset(-300, 700),
    ];
    final transform = dioramaHomographyToQuad(source, quad)!;
    final sourceCorners = [
      Offset.zero,
      const Offset(853, 0),
      const Offset(853, 1259),
      const Offset(0, 1259),
    ];

    for (var index = 0; index < quad.length; index++) {
      final mapped = MatrixUtils.transformPoint(
        transform,
        sourceCorners[index],
      );
      expect(mapped.dx, closeTo(quad[index].dx, 0.001));
      expect(mapped.dy, closeTo(quad[index].dy, 0.001));
    }
  });

  testWidgets('lab exposes continuous travel and real physical cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const BrigadeFieldsDioramaLabApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('diorama-world-paint')), findsOneWidget);
    expect(find.textContaining('BRIGADE HERO'), findsOneWidget);
    expect(
      find.byKey(const Key('diorama-trick-card-wheat-11')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('diorama-field-card-sunflower-7')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('diorama-hand-card-hand-wheat-13')),
      findsOneWidget,
    );

    final slider = tester.widget<Slider>(
      find.byKey(const Key('diorama-camera-scrubber')),
    );
    slider.onChanged!(0.25);
    await tester.pump();
    expect(find.textContaining('TRAVEL'), findsOneWidget);

    final scene = find.byKey(
      const Key('brigade-fields-diorama-scroll-surface'),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(scene),
        scrollDelta: const Offset(0, 90),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    final movedSlider = tester.widget<Slider>(
      find.byKey(const Key('diorama-camera-scrubber')),
    );
    expect(movedSlider.value, greaterThan(0.25));

    tester
        .widget<Slider>(find.byKey(const Key('diorama-camera-scrubber')))
        .onChanged!(BrigadeFieldsCameraPath.fieldsProgress);
    await tester.pump();
    expect(find.textContaining('FIELDS HERO'), findsOneWidget);
    bool rendersAsset(String filename) => find
        .byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName.endsWith(filename),
        )
        .evaluate()
        .isNotEmpty;
    expect(rendersAsset('field-ground-v1.png'), isTrue);
    expect(rendersAsset('crop-row-wheat-v1.png'), isTrue);
    expect(rendersAsset('crop-row-sunflower-v1.png'), isTrue);
    expect(rendersAsset('fields-crop-surface-v1.png'), isFalse);

    tester
        .widget<Slider>(find.byKey(const Key('diorama-camera-scrubber')))
        .onChanged!(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('NORTH HERO'), findsOneWidget);
    expect(find.byKey(const Key('diorama-world-paint')), findsOneWidget);
    expect(
      find.byKey(const Key('diorama-unified-north-railway')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('diorama-north-ground-far')), findsOneWidget);
    expect(find.byKey(const Key('north-barracks-year-1')), findsOneWidget);
    expect(find.byKey(const Key('north-barracks-year-3')), findsOneWidget);
    expect(find.byKey(const Key('north-card-spread-year-3')), findsOneWidget);
    expect(find.byKey(const Key('north-empty-year-mark-3')), findsOneWidget);
    expect(rendersAsset('north-forest-edge-v1.png'), isTrue);
    expect(rendersAsset('north-barracks-front-texture-v1.png'), isTrue);
    expect(rendersAsset('north-barracks-roof-texture-v1.png'), isTrue);

    await tester.tap(find.byKey(const Key('diorama-north-next-year')));
    await tester.pump();
    expect(find.byKey(const Key('north-barracks-year-4')), findsOneWidget);
    expect(
      find.byKey(const Key('north-year-4-card-north-y4-beet-k')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('diorama-north-next-year')));
    await tester.pump();
    expect(find.byKey(const Key('north-barracks-year-5')), findsOneWidget);
    expect(
      find.byKey(const Key('north-year-5-card-north-y5-potato-a')),
      findsOneWidget,
    );

    final shortcuts = tester.widget<CallbackShortcuts>(
      find.byType(CallbackShortcuts),
    );
    expect(
      shortcuts.bindings,
      contains(const SingleActivator(LogicalKeyboardKey.digit1)),
    );
    expect(
      shortcuts.bindings,
      contains(const SingleActivator(LogicalKeyboardKey.digit3)),
    );
  });

  testWidgets('one projector owns both sides of the station passage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const BrigadeFieldsDioramaLabApp());
    await tester.pump(const Duration(milliseconds: 100));

    final slider = find.byKey(const Key('diorama-camera-scrubber'));
    tester.widget<Slider>(slider).onChanged!(0.50);
    await tester.pump();
    expect(find.byKey(const Key('diorama-world-paint')), findsOneWidget);
    expect(
      find.byKey(const Key('diorama-unified-north-railway')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.endsWith(
              'north-station-v1.png',
            ),
      ),
      findsOneWidget,
    );

    tester.widget<Slider>(slider).onChanged!(0.70);
    await tester.pump();
    expect(find.byKey(const Key('diorama-world-paint')), findsOneWidget);
    expect(
      find.byKey(const Key('diorama-unified-north-railway')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('diorama-north-ground-near')), findsOneWidget);
  });

  testWidgets('the physical trick travels, assigns, and returns rewards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const BrigadeFieldsDioramaLabApp());
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('diorama-send-trick')));
    await tester.pump();
    expect(
      find.byKey(const Key('diorama-traveling-worker-card-wheat-11')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 6300));
    expect(
      find.byKey(const Key('diorama-staging-card-wheat-11')),
      findsOneWidget,
    );

    const assignments = [
      ('wheat-11', 'wheat'),
      ('sunflower-8', 'sunflower'),
      ('potato-10', 'potato'),
      ('beet-6', 'beet'),
    ];
    for (final assignment in assignments) {
      tester
          .widget<DioramaWorldCard>(
            find.byKey(Key('diorama-staging-card-${assignment.$1}')),
          )
          .onTap!();
      await tester.pump();
      tester
          .widget<DioramaFieldTarget>(
            find.byKey(Key('diorama-field-target-${assignment.$2}')),
          )
          .onTap();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(
        find.byKey(Key('diorama-assigned-card-${assignment.$1}')),
        findsOneWidget,
      );
    }

    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(const Key('diorama-returning-reward-card-reward-wheat')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 6300));
    expect(
      find.byKey(const Key('diorama-won-reward-card-reward-wheat')),
      findsOneWidget,
    );
    expect(find.text('THE WINNING PLOT HAS ITS REWARDS'), findsOneWidget);
  });

  test('camera pitch stays below a near-overhead view', () {
    const path = BrigadeFieldsCameraPath();
    for (var index = 0; index <= 20; index++) {
      final pose = path.poseAt(index / 20);
      expect(pose.pitchRadians, lessThan(math.pi / 3));
    }
  });
}
