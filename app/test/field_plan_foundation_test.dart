import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/art_direction.dart';
import 'package:kolkhoz_app/src/field_plan_assets.dart';
import 'package:kolkhoz_app/src/field_plan_typography.dart';

void main() {
  testWidgets('generated navigation pictograms are bundled and decode', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      await Future.wait([
        for (final asset in fieldPlanGlobalNavigationPictograms)
          precacheImage(
            AssetImage(asset.pathFor(KolkhozArtStyle.fieldPlan)),
            context,
          ),
      ]);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('generated ledger illustrations are bundled and decode', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      await Future.wait([
        for (final asset in fieldPlanLedgerIllustrations)
          precacheImage(
            AssetImage(asset.pathFor(KolkhozArtStyle.fieldPlan)),
            context,
          ),
      ]);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('field-plan fonts render English and Cyrillic', (tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      final display = FontLoader(fieldPlanDisplayFontFamily)
        ..addFont(
          rootBundle.load(
            'assets/art/field_plan/shared/fonts/PTSansNarrow-Bold.ttf',
          ),
        );
      final body = FontLoader(fieldPlanBodyFontFamily)
        ..addFont(
          rootBundle.load(
            'assets/art/field_plan/shared/fonts/PTSans-Regular.ttf',
          ),
        );
      await Future.wait([display.load(), body.load()]);
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            Text('CREATE GAME', style: fieldPlanDisplayTextStyle),
            Text('СОЗДАТЬ ИГРУ', style: fieldPlanDisplayTextStyle),
            Text('План колхоза', style: fieldPlanBodyTextStyle),
          ],
        ),
      ),
    );
    expect(find.text('СОЗДАТЬ ИГРУ'), findsOneWidget);
    expect(find.text('План колхоза'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
