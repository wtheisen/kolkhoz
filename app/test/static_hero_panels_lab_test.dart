import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/static_hero_panels_lab.dart';

void main() {
  testWidgets('tabs select three authored hero panels while hand persists', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const StaticHeroPanelsLabApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('static-hero-panel-brigade')), findsOneWidget);
    expect(find.byKey(const Key('static-hero-hand-tray')), findsOneWidget);
    expect(find.byKey(const Key('static-brigade-trick-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('static-hero-tab-fields')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('static-hero-panel-fields')), findsOneWidget);
    expect(find.byKey(const Key('static-fields-wheat-1')), findsOneWidget);
    expect(find.byKey(const Key('static-hero-hand-tray')), findsOneWidget);

    await tester.tap(find.byKey(const Key('static-hero-tab-north')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('static-hero-panel-north')), findsOneWidget);
    expect(find.byKey(const Key('static-north-y5-0')), findsOneWidget);
    expect(find.byKey(const Key('static-north-empty-year-3')), findsOneWidget);
    expect(find.byKey(const Key('static-hero-hand-tray')), findsOneWidget);
  });

  testWidgets('panel changes use a brief poster wipe', (tester) async {
    await _loadTestFonts(tester);
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const StaticHeroPanelsLabApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('static-hero-tab-fields')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('static-hero-poster-wipe')), findsWidgets);
    expect(find.byKey(const Key('static-hero-panel-fields')), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('static_hero_panels/transition.png'),
    );
  });

  testWidgets('horizontal flick navigates without a scrollable world', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const StaticHeroPanelsLabApp());
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const Key('static-hero-navigation-surface')),
      const Offset(-300, 0),
      1500,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('static-hero-panel-fields')), findsOneWidget);
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('compact landscape keeps navigation and cards on screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(680, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const StaticHeroPanelsLabApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('static-hero-tab-brigade')), findsOneWidget);
    expect(find.byKey(const Key('static-hero-tab-fields')), findsOneWidget);
    expect(find.byKey(const Key('static-hero-tab-north')), findsOneWidget);
    expect(find.byKey(const Key('static-hand-hand-wheat-13')), findsOneWidget);
  });

  testWidgets('captures the three authored desktop compositions', (
    tester,
  ) async {
    await _loadTestFonts(tester);
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const StaticHeroPanelsLabApp());
    await tester.pumpAndSettle();

    for (final panel in ['brigade', 'fields', 'north']) {
      if (panel != 'brigade') {
        await tester.tap(find.byKey(Key('static-hero-tab-$panel')));
        await tester.pumpAndSettle();
      }
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('static_hero_panels/$panel.png'),
      );
    }
  });

  testWidgets('captures all three compact compositions', (tester) async {
    await _loadTestFonts(tester);
    await tester.binding.setSurfaceSize(const Size(680, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const StaticHeroPanelsLabApp());
    await tester.pumpAndSettle();

    for (final panel in ['brigade', 'fields', 'north']) {
      if (panel != 'brigade') {
        await tester.tap(find.byKey(Key('static-hero-tab-$panel')));
        await tester.pumpAndSettle();
      }
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('static_hero_panels/${panel}_compact.png'),
      );
    }
  });
}

Future<void> _loadTestFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final display = FontLoader('PTSansNarrow')
      ..addFont(
        rootBundle.load(
          'assets/art/field_plan/shared/fonts/PTSansNarrow-Bold.ttf',
        ),
      );
    final body = FontLoader('PTSans')
      ..addFont(
        rootBundle.load(
          'assets/art/field_plan/shared/fonts/PTSans-Regular.ttf',
        ),
      );
    await Future.wait([display.load(), body.load()]);
  });
}
