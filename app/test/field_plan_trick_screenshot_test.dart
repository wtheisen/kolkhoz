import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/shared/art_direction.dart';
import 'package:kolkhoz_app/src/app/views/game/game_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_typography.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/shared/pixel_text.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/table_projection_helpers.dart';

import 'support/layout_scenarios.dart';

void main() {
  const devices = {
    'small': (size: Size(667, 375), scale: 2.0),
    'standard': (size: Size(852, 393), scale: 2.0),
    'large': (size: Size(932, 430), scale: 2.0),
  };

  testWidgets('field-plan trick screen across landscape sizes', (tester) async {
    expect(actionPanelForPhase(phaseSwap), panelBrigade);
    expect(actionPanelForPhase(phaseRequisition), panelBrigade);
    debugPaintBaselinesEnabled = false;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final model = fieldPlanFourCardTrickModel();

    PixelFontAtlasCache.instance.resetForTesting();
    await tester.runAsync(
      () => Future.wait([
        for (final variant in PixelTextVariant.values)
          for (final size in PixelTextSize.values)
            PixelFontAtlasCache.instance.load(variant: variant, size: size),
      ]),
    );
    await tester.runAsync(() async {
      final display = FontLoader(fieldPlanDisplayFontFamily)
        ..addFont(
          rootBundle.load(
            'assets/art/field_plan/shared/fonts/PTSansNarrow-Bold.ttf',
          ),
        );
      final body = FontLoader(fieldPlanBodyFontFamily)
        ..addFont(
          rootBundle.load('assets/art/field_plan/shared/fonts/PTSans-Bold.ttf'),
        );
      await Future.wait([display.load(), body.load()]);
    });

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final imageContext = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      await Future.wait([
        precacheImage(
          const AssetImage(
            'assets/art/field_plan/game/backgrounds/'
            'static-hero-brigade-underlay-v1.png',
          ),
          imageContext,
        ),
        precacheImage(
          const AssetImage(
            'assets/art/field_plan/game/backgrounds/'
            'static-hero-fields-underlay-v1.png',
          ),
          imageContext,
        ),
        precacheImage(
          const AssetImage(
            'assets/art/field_plan/game/backgrounds/'
            'static-hero-north-underlay-v1.png',
          ),
          imageContext,
        ),
        precacheImage(const AssetImage(fieldPlanSignAssetPath), imageContext),
        for (final portrait in fieldPlanPlayerPortraits)
          precacheImage(
            AssetImage(portrait.pathFor(KolkhozArtStyle.fieldPlan)),
            imageContext,
          ),
        for (final path in fieldPlanCardArtAssetPaths)
          precacheImage(AssetImage(path), imageContext),
      ]);
    });

    for (final MapEntry(key: name, value: device) in devices.entries) {
      final logicalSize = device.size;
      final renderScale = device.scale;
      await tester.binding.setSurfaceSize(
        Size(logicalSize.width * renderScale, logicalSize.height * renderScale),
      );
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(name),
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: const Key('field-plan-trick-screenshot'),
            child: Align(
              alignment: Alignment.topLeft,
              child: Transform.scale(
                scale: renderScale,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: logicalSize.width,
                  height: logicalSize.height,
                  child: KolkhozBoard(
                    model: model,
                    tokens: KolkhozAppearance.light.tokens,
                    language: KolkhozLanguage.en,
                    appearance: KolkhozAppearance.light,
                    animationSpeed: GameAnimationSpeed.instant,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BoardRail), findsOneWidget);
      expect(find.byType(TopInfoStrip), findsOneWidget);
      expect(
        find.byKey(const Key('production-static-hero-brigade')),
        findsOneWidget,
      );

      await expectLater(
        find.byKey(const Key('field-plan-trick-screenshot')),
        matchesGoldenFile(
          'layout_goldens/field_plan_trick__phone_landscape_$name.png',
        ),
      );
    }

    final fieldsModel = layoutScenarios
        .firstWhere((scenario) => scenario.name == 'assignment_jobs')
        .model;
    await tester.pumpWidget(
      MaterialApp(
        home: KolkhozBoard(
          model: fieldsModel,
          tokens: KolkhozAppearance.light.tokens,
          language: KolkhozLanguage.en,
          appearance: KolkhozAppearance.light,
          animationSpeed: GameAnimationSpeed.instant,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('production-static-hero-fields')),
      findsOneWidget,
    );

    final northModel = layoutScenarios
        .firstWhere((scenario) => scenario.name == 'sent_north_history')
        .model;
    await tester.pumpWidget(
      MaterialApp(
        home: KolkhozBoard(
          model: northModel,
          tokens: KolkhozAppearance.light.tokens,
          language: KolkhozLanguage.en,
          appearance: KolkhozAppearance.light,
          animationSpeed: GameAnimationSpeed.instant,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('production-static-hero-north')),
      findsOneWidget,
    );
  });

  testWidgets('assignment uses only job overlays on the Fields plate', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(932, 430));
    final model = layoutScenarios
        .firstWhere((scenario) => scenario.name == 'assignment_jobs')
        .model;

    await tester.pumpWidget(
      MaterialApp(
        home: KolkhozBoard(
          model: model,
          tokens: KolkhozAppearance.light.tokens,
          language: KolkhozLanguage.en,
          appearance: KolkhozAppearance.light,
          animationSpeed: GameAnimationSpeed.instant,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('production-static-hero-fields')),
      findsOneWidget,
    );
    for (final suit in displaySuitOrder) {
      expect(find.byKey(Key('static-hero-job-$suit')), findsOneWidget);
    }
  });
}
