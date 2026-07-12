import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/art_direction.dart';

void main() {
  test('legacy remains the safe default', () {
    expect(KolkhozArtStyle.fromEnvironmentValue(null), KolkhozArtStyle.legacy);
    expect(
      KolkhozArtStyle.fromEnvironmentValue('unknown'),
      KolkhozArtStyle.legacy,
    );
    expect(
      KolkhozArtStyle.fromEnvironmentValue(fieldPlanArtStyleValue),
      KolkhozArtStyle.fieldPlan,
    );
  });

  testWidgets('missing field-plan art falls back to the legacy asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ArtAssetImage(
          style: KolkhozArtStyle.fieldPlan,
          asset: ArtAssetRef(
            legacyPath: 'assets/ui/Icons/icon-check.png',
            fieldPlanPath: 'assets/art/field_plan/missing.png',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/ui/Icons/icon-check.png',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
