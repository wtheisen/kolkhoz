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

  test('field plan overlays contain the calibrated plate coordinates', () {
    const boardSize = Size(1318, 734);
    final card = fieldPlanCardDestinationQuad(1, boardSize, Offset.zero);
    final sign = fieldPlanSignDestinationRect(1, boardSize, Offset.zero);

    expect(card.topLeft.dx, closeTo(282.98, 0.001));
    expect(card.topLeft.dy, closeTo(315.544, 0.001));
    expect(card.topRight.dx, closeTo(429.43, 0.001));
    expect(card.topRight.dy, closeTo(315.544, 0.001));
    expect(card.bottomRight.dx, closeTo(327.509, 0.001));
    expect(card.bottomRight.dy, closeTo(561.937, 0.001));
    expect(card.bottomLeft.dx, closeTo(123.666, 0.001));
    expect(card.bottomLeft.dy, closeTo(561.937, 0.001));
    expect(sign.left, closeTo(301.65, 0.001));
    expect(sign.top, closeTo(205.032, 0.001));
    expect(sign.width, closeTo(139.549, 0.001));
    expect(sign.height, closeTo(58.105, 0.001));
  });

  test('brigade plot overlays use plate coordinates', () {
    const plateSize = Size(1672, 941);

    expect(
      fieldPlanBackgroundRect(fieldPlanPlayerPortraitSourceRect(0), plateSize),
      const Rect.fromLTWH(589.718, 211.857, 93.743, 63.96),
    );
    expect(
      fieldPlanBackgroundRect(fieldPlanPlayerNameSourceRect(3), plateSize),
      const Rect.fromLTWH(1154.775, 532.293, 241.878, 80.359),
    );
    expect(
      fieldPlanBackgroundRect(fieldPlanPlotCardsSourceRect(1), plateSize),
      const Rect.fromLTWH(1033.278, 319.69, 332.018, 107.171),
    );
    expect(
      fieldPlanBackgroundRect(fieldPlanCellarCountSourceRect(2), plateSize),
      const Rect.fromLTWH(51.319, 616.2, 126.601, 69.916),
    );
    expect(
      fieldPlanBackgroundRect(fieldPlanJobSignSourceRect(3), plateSize),
      const Rect.fromLTWH(1323.521, 69.153, 240.712, 77.622),
    );
    expect(
      fieldPlanBackgroundRect(fieldPlanCrossroadsCardSourceRect(3), plateSize),
      const Rect.fromLTWH(617.99, 568.169, 194.557, 244.712),
    );
    expect(
      fieldPlanBackgroundRect(fieldPlanPlanningSourceRect(0), plateSize),
      const Rect.fromLTWH(634.746, 340.152, 382.792, 289.341),
    );

    final portrait = fieldPlanBackgroundDestinationQuad(
      fieldPlanPlayerPortraitSourceQuad(0),
      plateSize,
    );
    expect(portrait.topLeft, const Offset(601.499, 211.857));
    expect(portrait.topRight, const Offset(683.461, 212.534));
    expect(portrait.bottomRight, const Offset(671.229, 275.74));
    expect(portrait.bottomLeft, const Offset(589.718, 275.818));
  });

  test('fields overlays use the saved job pile and sign coordinates', () {
    const plateSize = Size(1672, 941);
    final wheatPile = fieldPlanBackgroundDestinationQuad(
      fieldPlanFieldsJobPileSourceQuad(0),
      plateSize,
    );
    final beetPile = fieldPlanBackgroundDestinationQuad(
      fieldPlanFieldsJobPileSourceQuad(3),
      plateSize,
    );
    final potatoSign = fieldPlanBackgroundDestinationQuad(
      fieldPlanFieldsJobSignSourceQuad(2),
      plateSize,
    );

    expect(wheatPile.topLeft, const Offset(313.035, 181.186));
    expect(wheatPile.bottomLeft, const Offset(110.111, 329.644));
    expect(beetPile.topRight, const Offset(1379.459, 515.95));
    expect(beetPile.bottomRight, const Offset(1653.82, 818.011));
    expect(potatoSign.topLeft, const Offset(488.552, 350.096));
    expect(potatoSign.bottomRight, const Offset(728.552, 428.096));
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
