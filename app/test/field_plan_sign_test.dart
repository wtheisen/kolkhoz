import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/board_view.dart';
import 'package:kolkhoz_app/src/field_plan_sign.dart';

void main() {
  test('calibrated field plan signs share top, bottom, and size', () {
    final rects = [
      for (final seatID in [1, 2, 3, 0]) fieldPlanSignRect(seatID),
    ];
    final reference = rects.first;

    for (final rect in rects.skip(1)) {
      expect(rect.top, closeTo(reference.top, 1e-12));
      expect(rect.bottom, closeTo(reference.bottom, 1e-12));
      expect(rect.width, closeTo(reference.width, 1e-12));
      expect(rect.height, closeTo(reference.height, 1e-12));
    }
  });

  testWidgets('field plan sign accepts generic content and uses sign art', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 180,
            height: 48,
            child: FieldPlanSign(child: Text('BORIS')),
          ),
        ),
      ),
    );

    expect(find.text('BORIS'), findsOneWidget);
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(FieldPlanSign),
        matching: find.byType(Image),
      ),
    );
    expect(
      (image.image as AssetImage).assetName,
      'assets/art/field_plan/shared/signs/field-sign.png',
    );
    expect(tester.getSize(find.byType(FieldPlanSign)), const Size(180, 48));
    expect(tester.takeException(), isNull);
  });
}
