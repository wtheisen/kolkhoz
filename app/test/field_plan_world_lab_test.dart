import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/field_plan_world_lab.dart';
import 'package:kolkhoz_app/src/world_depth_manifest.dart';
import 'package:kolkhoz_app/src/world_depth_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WorldDepthManifest manifest;
  setUpAll(() async => manifest = await WorldDepthManifest.load());

  testWidgets('macOS lab excludes unstable descendant semantics', (
    tester,
  ) async {
    await tester.pumpWidget(FieldPlanWorldLabApp(manifest: manifest));

    expect(
      find.byKey(const Key('world-depth-lab-semantics-boundary')),
      findsOneWidget,
    );
    expect(find.byType(FieldPlanWorldLabScreen), findsOneWidget);
  });

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

  testWidgets('route infrastructure can be hidden without removing terrain', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FieldPlanWorldLabApp(
        manifest: manifest,
        initialCameraZ: 5.5,
        initialCorridorProofEnabled: true,
        initialLegacyAssetsEnabled: false,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('world-depth-route-corridor')), findsOneWidget);
    expect(find.byKey(const Key('world-depth-route-card-a07')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'world-depth-rail-tile-',
            ),
      ),
      findsWidgets,
    );

    await tester.tap(find.byKey(const Key('toggle-route-infrastructure')));
    await tester.pump();

    expect(find.byKey(const Key('world-depth-route-corridor')), findsNothing);
    expect(find.byKey(const Key('world-depth-route-card-a07')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'world-depth-rail-tile-',
            ),
      ),
      findsNothing,
    );
  });

  testWidgets('legacy toggle isolates the new world pass', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FieldPlanWorldLabApp(
        manifest: manifest,
        initialCameraZ: 0,
        initialCorridorProofEnabled: true,
        initialLegacyAssetsEnabled: false,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('world-depth-underpaint')), findsNothing);
    expect(find.byKey(const Key('world-depth-layer-b20')), findsNothing);
    expect(
      find.byKey(const Key('world-depth-new-pass-underpaint')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('world-depth-route-card-a01')), findsOneWidget);
    expect(find.byKey(const Key('world-depth-route-corridor')), findsOneWidget);
    expect(
      find.byKey(const Key('world-depth-route-segment-a01')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('world-depth-route-segment-a12')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('world-depth-layer-rm40-y0-sky')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('world-depth-layer-rm40-y0-snow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('world-depth-layer-rm40-y0-forest')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('world-depth-layer-rm40-y0-hut')),
      findsOneWidget,
    );
    expect(find.textContaining('NEW PASS ONLY'), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle-legacy-assets')));
    await tester.pump();

    expect(find.byKey(const Key('world-depth-underpaint')), findsOneWidget);
    expect(find.byKey(const Key('world-depth-layer-b20')), findsOneWidget);
    expect(
      find.byKey(const Key('world-depth-new-pass-underpaint')),
      findsNothing,
    );
    expect(find.byKey(const Key('world-depth-route-card-a01')), findsNothing);
    expect(find.textContaining('NEW PASS ONLY'), findsNothing);
  });

  testWidgets('persistent terrain cards are passed before the RM40 stack', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FieldPlanWorldLabApp(manifest: manifest, initialCameraZ: 3),
    );
    await tester.pump();

    expect(find.byKey(const Key('world-depth-route-card-a01')), findsNothing);
    expect(find.byKey(const Key('world-depth-route-corridor')), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle-corridor-proof')));
    await tester.pump();

    expect(find.byKey(const Key('world-depth-route-card-a01')), findsNothing);
    expect(find.byKey(const Key('world-depth-route-corridor')), findsOneWidget);
    expect(
      find.textContaining('12 PERSISTENT TERRAIN CARDS · ROUTE PROOF'),
      findsOneWidget,
    );

    final slider = tester.widget<Slider>(
      find.byKey(const Key('camera-z-scrubber')),
    );
    slider.onChanged!(northRouteCardStartZ);
    await tester.pump();
    expect(find.byKey(const Key('world-depth-route-card-a01')), findsOneWidget);
    expect(find.byKey(const Key('world-depth-route-card-a12')), findsOneWidget);
    expect(
      find.byKey(const Key('world-depth-route-card-a09-supplement')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('world-depth-route-corridor')), findsOneWidget);

    slider.onChanged!(5.5);
    await tester.pump();
    expect(find.byKey(const Key('world-depth-route-card-a01')), findsNothing);
    expect(find.byKey(const Key('world-depth-route-card-a07')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'world-depth-rail-tile-',
            ),
      ),
      findsWidgets,
    );

    slider.onChanged!(8.05);
    await tester.pump();

    expect(find.byKey(const Key('world-depth-route-card-a12')), findsNothing);
    expect(
      find.byKey(const Key('world-depth-layer-rm40-y0-sky')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('world-depth-layer-rm40-y0-snow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('world-depth-layer-rm40-y0-forest')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('world-depth-layer-rm40-y0-hut')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('world-depth-layer-rm40-y0-railway')),
      findsNothing,
    );
    expect(find.byKey(const Key('world-depth-route-corridor')), findsOneWidget);
    expect(
      find.byKey(const Key('world-depth-layer-rm40-y0-foreground')),
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
