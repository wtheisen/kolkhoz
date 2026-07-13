import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/animation_speed.dart';
import 'package:kolkhoz_app/src/app_settings.dart';
import 'package:kolkhoz_app/src/art_direction.dart';
import 'package:kolkhoz_app/src/board_view.dart';
import 'package:kolkhoz_app/src/field_plan_assets.dart';
import 'package:kolkhoz_app/src/field_plan_typography.dart';
import 'package:kolkhoz_app/src/pixel_text.dart';

import 'support/layout_scenarios.dart';

void main() {
  const devices = {
    'small': (size: Size(667, 375), scale: 2.0),
    'standard': (size: Size(852, 393), scale: 2.0),
    'large': (size: Size(932, 430), scale: 2.0),
  };

  testWidgets('field-plan trick screen across landscape sizes', (tester) async {
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
          const AssetImage(fieldPlanTrickFieldBackgroundPath),
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

      await expectLater(
        find.byKey(const Key('field-plan-trick-screenshot')),
        matchesGoldenFile(
          'layout_goldens/field_plan_trick__phone_landscape_$name.png',
        ),
      );
    }
  });
}
