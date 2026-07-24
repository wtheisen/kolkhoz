import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/board/board_widgets.dart';
import 'package:kolkhoz_app/src/design_tokens.dart';
import 'package:kolkhoz_app/src/field_plan_assets.dart';
import 'package:kolkhoz_app/src/field_plan_typography.dart';
import 'package:kolkhoz_app/src/pixel_text.dart';
import 'package:kolkhoz_app/src/render_model.dart';

void main() {
  testWidgets('renders Steam marketing number cards from production widgets', (
    tester,
  ) async {
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
      await display.load();
    });

    for (final card in const [
      TableCard(
        id: 'steam-wheat-10',
        suit: 'wheat',
        value: 10,
        rank: '10',
        selected: false,
        highlighted: false,
        pending: false,
        nomenclature: false,
      ),
      TableCard(
        id: 'steam-sunflower-9',
        suit: 'sunflower',
        value: 9,
        rank: '9',
        selected: false,
        highlighted: false,
        pending: false,
        nomenclature: false,
      ),
    ]) {
      final key = ValueKey('steam-card-${card.suit}-${card.value}');
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: GameCard(
                card: card,
                tokens: lightDesignTokens,
                sizeOverride: _scaledCardSize(lightDesignTokens.card.large, 5),
                motionTracked: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byKey(key));
      await tester.runAsync(
        () => precacheImage(
          AssetImage(fieldPlanCardSuitAssetPath(card.suit)!),
          context,
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('steam_card_faces/${card.suit}-${card.value}.png'),
      );
    }
  });
}

TokenCardSize _scaledCardSize(TokenCardSize size, double scale) {
  return TokenCardSize(
    width: size.width * scale,
    height: size.height * scale,
    faceInset: size.faceInset * scale,
    cornerWidth: size.cornerWidth * scale,
    cornerHeight: size.cornerHeight * scale,
    cornerRankFontSize: size.cornerRankFontSize * scale,
    cornerSuitSize: size.cornerSuitSize * scale,
    topCornerRankSuitSpacing: size.topCornerRankSuitSpacing * scale,
    bottomCornerRankSuitSpacing: size.bottomCornerRankSuitSpacing * scale,
    topCornerSuitXOffset: size.topCornerSuitXOffset * scale,
    bottomCornerSuitXOffset: size.bottomCornerSuitXOffset * scale,
    pipSize: size.pipSize * scale,
  );
}
