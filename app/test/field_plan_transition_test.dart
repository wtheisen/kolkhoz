import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/game/game_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_world_scene.dart';


void main() {
  test('camera travel eases at both maps and moves faster between them', () {
    expect(fieldPlanCameraTravelProgress(0), 0);
    expect(fieldPlanCameraTravelProgress(0.2), closeTo(0.104, 0.0001));
    expect(fieldPlanCameraTravelProgress(0.5), 0.5);
    expect(fieldPlanCameraTravelProgress(0.8), closeTo(0.896, 0.0001));
    expect(fieldPlanCameraTravelProgress(1), 1);

    final middleTravel =
        fieldPlanCameraTravelProgress(0.6) - fieldPlanCameraTravelProgress(0.4);
    final plotTravel = fieldPlanCameraTravelProgress(0.2);
    final fieldsTravel = 1 - fieldPlanCameraTravelProgress(0.8);
    expect(middleTravel, greaterThan(plotTravel * 2));
    expect(middleTravel, greaterThan(fieldsTravel * 2));
  });

  test('camera settle duration scales with the remaining travel', () {
    expect(fieldPlanCameraTravelDuration(1), const Duration(milliseconds: 760));
    expect(
      fieldPlanCameraTravelDuration(0.5),
      const Duration(milliseconds: 380),
    );
  });

  test('world layout is readable and contains all playable surfaces', () {
    expect(fieldPlanWorldLayout.layers, hasLength(3));
    expect(
      fieldPlanWorldLayout.surfaces.map((surface) => surface.id),
      containsAll([
        'plot-0',
        'plot-1',
        'plot-2',
        'plot-3',
        'field-0',
        'field-1',
        'field-2',
        'field-3',
      ]),
    );
    expect(fieldPlanWorldLayout.prettyJson(), contains('brigade-overview'));
  });

  test('authored cameras put settled regions edge to edge', () {
    const size = Size(800, 400);
    final center = size.center(Offset.zero);
    final brigadeFromFields = fieldPlanWorldCameraMatrix(
      size: size,
      page: 0,
      cameraPosition: 1,
      parallax: 1,
    );
    final transformed = MatrixUtils.transformPoint(brigadeFromFields, center);
    expect(transformed.dx, closeTo(center.dx, 0.001));
    expect(transformed.dy, closeTo(-center.dy, 0.001));
  });

  test('focused surface center lands at the viewport center', () {
    const size = Size(800, 400);
    final surface = fieldPlanWorldLayout.surface('plot-0')!;
    final matrix = fieldPlanWorldCameraMatrix(
      size: size,
      page: 0,
      cameraPosition: 0,
      parallax: 1,
      focusSurface: surface,
      focusProgress: 1,
    );
    final surfaceCenter = Offset(
      surface.quad.center.dx * size.width,
      surface.quad.center.dy * size.height,
    );
    final transformed = MatrixUtils.transformPoint(matrix, surfaceCenter);
    expect(transformed.dx, closeTo(size.width / 2, 0.001));
    expect(transformed.dy, closeTo(size.height / 2, 0.001));
  });

  testWidgets('native world camera scrubs with the drag and settles', (
    tester,
  ) async {
    double? observedProgress;
    await tester.pumpWidget(
      MaterialApp(
        home: BrigadeFieldsCoordinator(
          active: true,
          builder: (context, page) {
            final progress = BrigadeFieldsScope.transitionProgressOf(context);
            observedProgress = progress;
            return ColoredBox(
              key: progress == null
                  ? Key('map-page-$page')
                  : const Key('map-transition-scrubbing'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('brigade-fields-swipe-surface'))),
    );
    await gesture.moveBy(const Offset(0, 220));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('map-transition-scrubbing')), findsOneWidget);
    final dragProgress = observedProgress!;

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('map-transition-scrubbing')), findsOneWidget);
    expect(observedProgress!, greaterThan(dragProgress));
    expect(observedProgress!, lessThan(1));

    final firstSnapProgress = observedProgress!;
    await tester.pump(const Duration(milliseconds: 100));
    expect(observedProgress!, greaterThan(firstSnapProgress));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-transition-scrubbing')), findsNothing);
    expect(find.byKey(const Key('map-page-1')), findsOneWidget);

    final shortReverseGesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('brigade-fields-swipe-surface'))),
    );
    await shortReverseGesture.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(find.byKey(const Key('map-transition-scrubbing')), findsOneWidget);
    await shortReverseGesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-page-1')), findsOneWidget);

    final reverseGesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('brigade-fields-swipe-surface'))),
    );
    await reverseGesture.moveBy(const Offset(0, -220));
    await reverseGesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-page-0')), findsOneWidget);

    final toFields = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('brigade-fields-swipe-surface'))),
    );
    await toFields.moveBy(const Offset(0, 220));
    await toFields.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-page-1')), findsOneWidget);

    final toNorth = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('brigade-fields-swipe-surface'))),
    );
    await toNorth.moveBy(const Offset(0, 220));
    await toNorth.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-page-2')), findsOneWidget);
  });
}
