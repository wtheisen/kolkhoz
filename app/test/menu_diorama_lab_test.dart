import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/menu_diorama_lab.dart';

void main() {
  testWidgets('keeps the living scene behind destination panels', (
    tester,
  ) async {
    await tester.pumpWidget(const MenuDioramaLabApp());
    await tester.pump();

    expect(find.byKey(const Key('menu-diorama-scene')), findsOneWidget);
    expect(find.byKey(const Key('menu-diorama-destination')), findsNothing);

    await tester.tap(find.byKey(const Key('menu-diorama-local')));
    await tester.pump();

    expect(find.byKey(const Key('menu-diorama-scene')), findsOneWidget);
    expect(find.byKey(const Key('menu-diorama-destination')), findsOneWidget);

    await tester.tap(find.byKey(const Key('menu-diorama-close')));
    await tester.pump();
    expect(find.byKey(const Key('menu-diorama-destination')), findsNothing);
  });

  testWidgets('reduced motion keeps paper layers at rest', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: MenuDioramaScene()),
      ),
    );
    await tester.pump();

    final far = tester.widget<Transform>(
      find
          .descendant(
            of: find.byKey(const Key('menu-diorama-far-layer')),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(far.transform.getTranslation().x, 0);
    expect(far.transform.getTranslation().y, 0);
  });

  testWidgets('pointer movement reveals different paper depths', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MenuDioramaScene()));
    await tester.pump();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 300));
    await mouse.moveTo(const Offset(760, 560));
    await tester.pump();

    Transform layerTransform(String key) => tester.widget<Transform>(
      find
          .descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Transform),
          )
          .first,
    );

    final farX = layerTransform(
      'menu-diorama-far-layer',
    ).transform.getTranslation().x;
    final nearX = layerTransform(
      'menu-diorama-near-layer',
    ).transform.getTranslation().x;
    expect(farX, isNot(0));
    expect(nearX.abs(), greaterThan(farX.abs()));
  });
}
