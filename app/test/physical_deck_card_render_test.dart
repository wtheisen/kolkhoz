import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';

void main() {
  testWidgets('physical deck renders number, face, trump, and Saboteur cards', (
    tester,
  ) async {
    final podkova = FontLoader('Podkova')
      ..addFont(
        rootBundle.load(
          'assets/art/field_plan/shared/fonts/Podkova-Variable.ttf',
        ),
      );
    final bitter = FontLoader('Bitter')
      ..addFont(
        rootBundle.load(
          'assets/art/field_plan/shared/fonts/Bitter-Variable.ttf',
        ),
      );
    await tester.runAsync(() => Future.wait([podkova.load(), bitter.load()]));

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(
      () => Future.wait([
        PhysicalDeckCardContent.preloadLayouts(),
        for (final path in fieldPlanCardArtAssetPaths)
          precacheImage(AssetImage(path), context),
      ]),
    );

    final cards = [
      _card('wheat-7', 'wheat', 7, '7'),
      _card('potato-11', 'potato', 11, 'J'),
      _card('beet-12', 'beet', 12, 'Q'),
      _card('sunflower-13', 'sunflower', 13, 'K'),
      _card('wrecker-0', wreckerSuit, 0, 'S'),
    ];
    final size = _scaledCardSize(defaultDesignTokens.card.large, 5.6);
    await tester.binding.setSurfaceSize(const Size(2200, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: const Color(0xff252c2b),
          child: Center(
            child: RepaintBoundary(
              key: const Key('physical-deck-cards'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final card in cards)
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: GameCard(
                        card: card,
                        tokens: lightDesignTokens,
                        trump: card.suit == 'beet' ? 'beet' : null,
                        sizeOverride: size,
                        motionTracked: false,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PhysicalDeckCardContent), findsNWidgets(5));
    expect(find.byType(ErrorWidget), findsNothing);
    expect(
      find.byKey(const ValueKey('physical-deck-layout-sunflower-king')),
      findsOneWidget,
    );

    await expectLater(
      find.byKey(const Key('physical-deck-cards')),
      matchesGoldenFile('goldens/physical_deck_cards.png'),
    );
  });
}

TableCard _card(String id, String suit, int value, String rank) {
  return TableCard(
    id: id,
    suit: suit,
    value: value,
    rank: rank,
    selected: false,
    highlighted: false,
    pending: false,
    nomenclature: false,
  );
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
