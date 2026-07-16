import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/field_plan_world_lab.dart';
import 'package:kolkhoz_app/src/world_depth_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WorldDepthManifest manifest;
  setUpAll(() async => manifest = await WorldDepthManifest.load());

  testWidgets('scrolling and dragging coast without snapping', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(FieldPlanWorldLabApp(manifest: manifest));
    await tester.pumpAndSettle();

    final scene = find.byKey(const Key('field-plan-depth-scene'));
    expect(find.byKey(const Key('world-depth-underpaint')), findsOneWidget);
    final brigade = find.byKey(const Key('world-depth-layer-b20'));
    final before = tester.getSize(brigade).width;

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(scene),
        scrollDelta: const Offset(0, 120),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final earlyScroll = tester.getSize(brigade).width;
    await tester.pump(const Duration(milliseconds: 100));
    final coastingScroll = tester.getSize(brigade).width;

    expect(earlyScroll, greaterThan(before));
    expect(coastingScroll, greaterThan(earlyScroll));
    await tester.pumpAndSettle();
    expect(find.textContaining('MENU · Z -1.50'), findsOneWidget);

    await tester.fling(scene, const Offset(0, 100), 1000);
    final dragRelease = tester.getSize(brigade).width;
    await tester.pump(const Duration(milliseconds: 100));
    final coastingDrag = tester.getSize(brigade).width;

    expect(coastingDrag, greaterThan(dragRelease));
    await tester.pumpAndSettle();

    final after = tester.getSize(brigade).width;
    expect(after, greaterThan(before));
  });

  testWidgets('camera scrubber is continuous across the complete route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(FieldPlanWorldLabApp(manifest: manifest));
    await tester.pump();

    final slider = tester.widget<Slider>(
      find.byKey(const Key('camera-z-scrubber')),
    );
    expect(slider.min, -2);
    expect(slider.max, 8.05);
    expect(slider.divisions, isNull);

    slider.onChanged!(1.25);
    await tester.pump();
    expect(find.text('1.250'), findsOneWidget);

    await tester.tap(find.byKey(const Key('camera-stop-north')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('5.000'), findsOneWidget);
    expect(find.textContaining('NORTH · Z 5.00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('camera-stop-camp')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('8.050'), findsOneWidget);
    expect(find.textContaining('CAMP · Z 8.05'), findsOneWidget);

    slider.onChanged!(8);
    await tester.pump();
    expect(find.text('8.000'), findsOneWidget);
    expect(find.textContaining('CAMP · Z 8.00'), findsOneWidget);
  });

  testWidgets('one road-station-rail corridor survives the renderer handoff', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FieldPlanWorldLabApp(manifest: manifest, initialCameraZ: 1.5),
    );
    await tester.pump();

    const corridor = Key('world-depth-route-corridor');
    expect(find.byKey(corridor), findsOneWidget);

    final slider = tester.widget<Slider>(
      find.byKey(const Key('camera-z-scrubber')),
    );
    slider.onChanged!(2.8);
    await tester.pump();
    expect(find.byKey(corridor), findsOneWidget);

    slider.onChanged!(5);
    await tester.pump();
    expect(find.byKey(corridor), findsOneWidget);
  });

  testWidgets('temporary proof plates can replace the generated North scene', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FieldPlanWorldLabApp(manifest: manifest, initialCameraZ: 3),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('world-depth-layer-proof-depth-00-far')),
      findsNothing,
    );
    expect(find.byKey(const Key('world-depth-route-corridor')), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle-corridor-proof')));
    await tester.pump();

    expect(
      find.byKey(const Key('world-depth-layer-proof-depth-00-far')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('world-depth-layer-proof-underpaint')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('world-depth-layer-proof-depth-01')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('world-depth-layer-proof-depth-06')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('world-depth-layer-proof-depth-07-near')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('world-depth-route-corridor')), findsNothing);
    expect(find.textContaining('8 DEPTH PLATES'), findsOneWidget);

    final slider = tester.widget<Slider>(
      find.byKey(const Key('camera-z-scrubber')),
    );
    slider.onChanged!(8.05);
    await tester.pump();

    expect(
      find.byKey(const Key('world-depth-layer-proof-depth-07-near')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('world-depth-layer-proof-depth-00-far')),
      findsOneWidget,
    );
  });

  testWidgets('calibration guides toggle without changing plate geometry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(FieldPlanWorldLabApp(manifest: manifest));
    await tester.pump();

    final brigade = find.byKey(const Key('world-depth-layer-b20'));
    final before = tester.getRect(brigade);
    expect(
      find.byKey(const Key('world-depth-calibration-guides')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('toggle-calibration-guides')));
    await tester.pump();
    expect(
      find.byKey(const Key('world-depth-calibration-guides')),
      findsNothing,
    );
    expect(tester.getRect(brigade), before);
  });

  testWidgets('threat and atmosphere controls do not change camera Z', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FieldPlanWorldLabApp(manifest: manifest, initialCameraZ: 3),
    );
    await tester.pump();

    final threatSlider = tester.widget<Slider>(
      find.byKey(const Key('north-threat-scrubber')),
    );
    threatSlider.onChanged!(1);
    await tester.pump();
    expect(find.text('3.000'), findsOneWidget);
    expect(find.text('1.000 / Y5.00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('north-atmosphere-toggle')));
    await tester.pump();
    expect(find.text('3.000'), findsOneWidget);
  });
}
