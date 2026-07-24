import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_typography.dart';

import 'support/layout_scenarios.dart';

void main() {
  testWidgets('production board renders all three static hero panels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadFonts(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final imageContext = tester.element(find.byType(SizedBox));
    await tester.runAsync(
      () => Future.wait([
        for (final panel in ['brigade', 'fields', 'north'])
          precacheImage(
            AssetImage(
              'assets/art/field_plan/game/backgrounds/'
              'static-hero-$panel-underlay-v1.png',
            ),
            imageContext,
          ),
      ]),
    );

    await _pumpBoard(tester, _scenario('trick_brigade').model);
    expect(
      find.byKey(const Key('production-static-hero-brigade')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('static-hero-trick-card-sunflower-12')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('static-hero-trick-card-sunflower-12')),
        matching: find.byType(MotionTrackedCard),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is MotionTrackedRegion &&
            widget.motionKey == playerCardMotionSourceKey(2),
      ),
      findsOneWidget,
    );
    final bot1TrickCard = tester.getCenter(
      find.byKey(const Key('static-hero-trick-card-sunflower-12')),
    );
    final bot2TrickCard = tester.getCenter(
      find.byKey(const Key('static-hero-trick-card-sunflower-8')),
    );
    expect((bot1TrickCard.dx - bot2TrickCard.dx).abs(), lessThan(2));
    expect(bot2TrickCard.dy, lessThan(bot1TrickCard.dy));
    await expectLater(
      find.byKey(const Key('production-board-capture')),
      matchesGoldenFile('static_hero_production/brigade.png'),
    );

    LegalAction? selectedAction;
    await _pumpBoard(
      tester,
      _scenario('assignment_jobs').model,
      onAction: (action) => selectedAction = action,
    );
    expect(
      find.byKey(const Key('production-static-hero-fields')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('static-hero-job-wheat')));
    expect(selectedAction?.kind, actionAssign);
    expect(selectedAction?.engineAction.targetSuit, 'wheat');
    await expectLater(
      find.byKey(const Key('production-board-capture')),
      matchesGoldenFile('static_hero_production/fields.png'),
    );

    await _pumpBoard(tester, _scenario('sent_north_history').model);
    expect(
      find.byKey(const Key('production-static-hero-north')),
      findsOneWidget,
    );
    for (var year = 1; year <= finalGameYear; year++) {
      expect(find.byKey(Key('static-hero-north-year-$year')), findsOneWidget);
    }
    await expectLater(
      find.byKey(const Key('production-board-capture')),
      matchesGoldenFile('static_hero_production/north.png'),
    );
  });

  testWidgets('brigade seats and trick cards rotate around the viewer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadFonts(tester);

    await _pumpBoard(tester, _withViewer(_scenario('trick_brigade').model, 2));
    final viewerPortrait = tester.getCenter(
      find.byKey(const Key('player-portrait-2-inspect')),
    );
    final lowerLeftPortrait = tester.getCenter(
      find.byKey(const Key('player-portrait-3-inspect')),
    );
    final upperRightPortrait = tester.getCenter(
      find.byKey(const Key('player-portrait-1-inspect')),
    );
    expect(viewerPortrait.dx, greaterThan(lowerLeftPortrait.dx));
    expect(viewerPortrait.dy, greaterThan(upperRightPortrait.dy));

    final upperRightTrickCard = tester.getCenter(
      find.byKey(const Key('static-hero-trick-card-sunflower-12')),
    );
    final viewerTrickCard = tester.getCenter(
      find.byKey(const Key('static-hero-trick-card-sunflower-8')),
    );
    expect((upperRightTrickCard.dx - viewerTrickCard.dx).abs(), lessThan(2));
    expect(viewerTrickCard.dy, greaterThan(upperRightTrickCard.dy));
  });
}

LayoutScenario _scenario(String name) =>
    layoutScenarios.firstWhere((scenario) => scenario.name == name);

TableViewModel _withViewer(TableViewModel model, int viewerSeatID) {
  return TableViewModel(
    viewer: Viewer(seatID: viewerSeatID, privacyMode: model.viewer.privacyMode),
    table: TableState(
      year: model.table.year,
      phase: model.table.phase,
      phasePrompt: model.table.phasePrompt,
      currentPlayerID: model.table.currentPlayerID,
      trump: model.table.trump,
      isFamine: model.table.isFamine,
      maxTricks: model.table.maxTricks,
      seats: [
        for (final seat in model.table.seats)
          Seat(
            id: seat.id,
            name: seat.name,
            controller: seat.controller,
            portraitAsset: seat.portraitAsset,
            isViewer: seat.id == viewerSeatID,
            isCurrentTurn: seat.isCurrentTurn,
            isBrigadeLeader: seat.isBrigadeLeader,
            hand: seat.hand,
            hiddenHandCount: seat.hiddenHandCount,
            plot: seat.plot,
            medals: seat.medals,
            visibleScore: seat.visibleScore,
            profileStats: seat.profileStats,
            profileUserID: seat.profileUserID,
            statusText: seat.statusText,
          ),
      ],
      jobs: model.table.jobs,
      trick: model.table.trick,
      lastTrick: model.table.lastTrick,
      requisitionEvents: model.table.requisitionEvents,
      exiledByYear: model.table.exiledByYear,
      scoreboard: model.table.scoreboard,
      gameResult: model.table.gameResult,
      finalYearTrumpCard: model.table.finalYearTrumpCard,
    ),
    panels: model.panels,
    selection: model.selection,
    legalActions: model.legalActions,
    seed: model.seed,
  );
}

Future<void> _pumpBoard(
  WidgetTester tester,
  TableViewModel model, {
  ValueChanged<LegalAction>? onAction,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: fieldPlanDisplayFontFamily),
      home: RepaintBoundary(
        key: const Key('production-board-capture'),
        child: KolkhozBoard(
          model: model,
          tokens: KolkhozAppearance.light.tokens,
          language: KolkhozLanguage.en,
          appearance: KolkhozAppearance.light,
          animationSpeed: GameAnimationSpeed.instant,
          onAction: onAction,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _loadFonts(WidgetTester tester) async {
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
}
