import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/shared/art_direction.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_typography.dart';

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

  testWidgets('generated ledger actions are bundled and decode', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      await Future.wait([
        for (final asset in fieldPlanLedgerActions)
          precacheImage(
            AssetImage(asset.pathFor(KolkhozArtStyle.fieldPlan)),
            context,
          ),
      ]);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('generated field-plan player portraits are bundled and decode', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      await Future.wait([
        for (final asset in fieldPlanPlayerPortraits)
          precacheImage(
            AssetImage(asset.pathFor(KolkhozArtStyle.fieldPlan)),
            context,
          ),
      ]);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('generated brigade plot environment is bundled and decodes', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage(fieldPlanBrigadePlotBackgroundPath),
        context,
      );
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('generated fields environment is bundled and decodes', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage(fieldPlanFieldsBackgroundPath),
        context,
      );
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('generated North environment is bundled and decodes', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage(fieldPlanNorthBackgroundPath),
        context,
      );
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('generated field sign is bundled and decodes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      await precacheImage(const AssetImage(fieldPlanSignAssetPath), context);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('generated field-plan card art is bundled and decodes', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      await Future.wait([
        for (final path in fieldPlanCardArtAssetPaths)
          precacheImage(AssetImage(path), context),
      ]);
    });
    expect(tester.takeException(), isNull);
  });

  test('field-plan card mappings preserve incomplete-family fallbacks', () {
    expect(
      KolkhozCardBack.classic.assetPathFor(KolkhozArtStyle.fieldPlan),
      fieldPlanCardBackAssetPath,
    );
    expect(
      KolkhozCardBack.winter.iconAssetPathFor(KolkhozArtStyle.fieldPlan),
      fieldPlanCardBackAssetPath,
    );
    expect(
      KolkhozCardBack.classic.assetPathFor(KolkhozArtStyle.legacy),
      KolkhozCardBack.classic.assetPath,
    );
    expect(
      fieldPlanCardSuitAssetPath('beet'),
      'assets/art/field_plan/cards/suits/suit-beet.png',
    );
    expect(
      fieldPlanCardSuitAssetPath('beet', mip: true),
      'assets/art/field_plan/cards/suits/mip/suit-beet.png',
    );
    expect(
      fieldPlanCardFaceAssetPath(
        suit: 'wheat',
        rank: 'queen',
        nomenclature: false,
      ),
      'assets/art/field_plan/cards/faces/face-queen-wheat.png',
    );
    expect(
      fieldPlanCardFaceAssetPath(
        suit: 'wheat',
        rank: 'king',
        nomenclature: false,
      ),
      isNull,
    );
    expect(
      fieldPlanCardFaceAssetPath(
        suit: 'wheat',
        rank: 'queen',
        nomenclature: true,
      ),
      isNull,
    );
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
