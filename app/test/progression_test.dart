import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/views/settings/game_settings_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/progression.dart';
import 'package:kolkhoz_app/src/app/profile/views/progression_overview.dart';

void main() {
  test('completed games advance challenges and unlock their rewards once', () {
    var state = const ProgressionState();
    for (var game = 0; game < 5; game += 1) {
      state = evaluateProgression(
        state,
        ProgressionGameSummary(
          won: game < 3,
          score: 100,
          fullFiveYearGame: true,
        ),
      ).state;
    }

    expect(state.isCompleted('achievement.first_game'), isTrue);
    expect(state.isCompleted('achievement.first_win'), isTrue);
    expect(state.isCompleted('achievement.century'), isTrue);
    expect(state.isCompleted('challenge.games_5'), isTrue);
    expect(state.isCompleted('challenge.wins_3'), isTrue);
    expect(state.isCompleted('challenge.score_500'), isTrue);
    expect(
      state.unlocks,
      containsAll({
        'unlock.card_back.harvest',
        'unlock.card_back.granary',
        'unlock.card_back.winter',
      }),
    );

    final repeated = evaluateProgression(
      state,
      const ProgressionGameSummary(
        won: true,
        score: 100,
        fullFiveYearGame: true,
      ),
    );
    expect(repeated.newCompletions, isEmpty);
  });

  test('short games do not advance the full-game win challenge', () {
    final update = evaluateProgression(
      const ProgressionState(),
      const ProgressionGameSummary(
        won: true,
        score: 40,
        fullFiveYearGame: false,
      ),
    );

    expect(update.state.progress['challenge.wins_3'], 0);
    expect(update.state.progress['achievement.first_win'], 1);
  });

  test('game events complete richer one-game achievements', () {
    final update = evaluateProgression(
      const ProgressionState(),
      const ProgressionGameSummary(
        won: true,
        score: 120,
        fullFiveYearGame: true,
        margin: 30,
        medals: 6,
        exiledPlotCards: 0,
        saboteurExiled: true,
      ),
    );

    expect(update.state.completed, contains('achievement.clear_victory'));
    expect(update.state.completed, contains('achievement.medalist'));
    expect(update.state.completed, contains('achievement.no_requisition'));
    expect(update.state.completed, contains('achievement.saboteur_exiled'));
    expect(update.state.progress['challenge.medals_25'], 6);
    expect(update.state.progress['challenge.score_1000'], 120);
  });

  test('progression state survives settings persistence', () {
    const state = ProgressionState(
      progress: {'challenge.games_5': 3},
      completed: {'achievement.first_game'},
      unlocks: {'unlock.card_back.harvest'},
    );
    final restored = KolkhozAppSettings.fromJson(
      const KolkhozAppSettings(progression: state).toJson(),
    );

    expect(restored.progression.progress['challenge.games_5'], 3);
    expect(restored.progression.completed, contains('achievement.first_game'));
    expect(restored.progression.unlocks, contains('unlock.card_back.harvest'));
  });

  test('offline and server-authoritative online progress merge additively', () {
    const offline = ProgressionState(
      progress: {'challenge.games_5': 2, 'challenge.score_500': 200},
      completed: {'achievement.first_game'},
    );
    const online = ProgressionState(
      progress: {'challenge.games_5': 3, 'challenge.score_500': 300},
      completed: {'achievement.first_win'},
      unlocks: {'unlock.card_back.harvest'},
    );

    final merged = mergeProgressionStates(offline, online);
    expect(merged.progress['challenge.games_5'], 5);
    expect(merged.progress['challenge.score_500'], 500);
    expect(merged.completed, containsAll(offline.completed));
    expect(merged.completed, containsAll(online.completed));
    expect(merged.unlocks, contains('unlock.card_back.harvest'));
  });

  test('online progression survives local settings persistence', () {
    const online = ProgressionState(
      progress: {'challenge.games_10': 4},
      completed: {'achievement.first_win'},
    );
    final restored = KolkhozAppSettings.fromJson(
      const KolkhozAppSettings(
        onlineProgression: online,
        onlineProgressionUserID: 'user-1',
      ).toJson(),
    );

    expect(restored.onlineProgression.progress['challenge.games_10'], 4);
    expect(
      restored.onlineProgression.completed,
      contains('achievement.first_win'),
    );
    expect(restored.onlineProgressionUserID, 'user-1');
  });

  test('generated profile portraits unlock from their assigned goals', () {
    expect(profilePortraitAssets, hasLength(8));
    expect(
      isProfilePortraitUnlocked(const ProgressionState(), 'worker-agronomist'),
      isFalse,
    );
    expect(
      isProfilePortraitUnlocked(
        const ProgressionState(completed: {'achievement.century'}),
        'worker-agronomist',
      ),
      isTrue,
    );
    expect(profilePortraitUnlockRequirements, {
      'worker-agronomist': 'achievement.century',
      'worker-mechanic': 'challenge.medals_25',
      'worker-beekeeper': 'achievement.saboteur_exiled',
      'worker-forewoman': 'challenge.games_10',
    });
  });

  testWidgets('progress overview groups challenges and achievements', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 700,
            child: ProgressionOverview(
              state: ProgressionState(
                progress: {'challenge.games_5': 3},
                completed: {'achievement.first_game'},
              ),
              tokens: defaultDesignTokens,
            ),
          ),
        ),
      ),
    );

    expect(find.text('ACTIVE CHALLENGES'), findsOneWidget);
    expect(find.text('3/5'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('ACHIEVEMENTS'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('ACHIEVEMENTS'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('progression-achievement.first_game')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DONE'), findsWidgets);
  });

  testWidgets('locked card backs are visible but cannot be selected', (
    tester,
  ) async {
    KolkhozCardBack? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OptionsCardBackPicker(
            selected: KolkhozCardBack.classic,
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            unlockedCardBacks: const {KolkhozCardBack.classic},
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.endsWith('icon-lock.png'),
      ),
      findsNWidgets(3),
    );
    await tester.tap(find.byTooltip('Harvest (locked)'));
    expect(selected, isNull);
  });
}
