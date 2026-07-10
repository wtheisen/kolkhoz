import 'dart:async';
import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/animation_speed.dart';
import 'package:kolkhoz_app/src/app_settings.dart';
import 'package:kolkhoz_app/src/app_text.dart';
import 'package:kolkhoz_app/src/assignment_display.dart';
import 'package:kolkhoz_app/src/board_view.dart';
import 'package:kolkhoz_app/src/board/game_log_panel.dart';
import 'package:kolkhoz_app/src/brigade_display.dart';
import 'package:kolkhoz_app/src/card_art_display.dart';
import 'package:kolkhoz_app/src/card_display.dart';
import 'package:kolkhoz_app/src/c_engine_action_codec.dart';
import 'package:kolkhoz_app/src/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/controller_display.dart';
import 'package:kolkhoz_app/src/design_tokens.dart';
import 'package:kolkhoz_app/src/engine_action_projection.dart';
import 'package:kolkhoz_app/src/game_constants.dart';
import 'package:kolkhoz_app/src/game_sound.dart';
import 'package:kolkhoz_app/src/game_ui_state.dart';
import 'package:kolkhoz_app/src/hot_seat_display.dart';
import 'package:kolkhoz_app/src/kolkhoz_app.dart';
import 'package:kolkhoz_app/src/live_game_store.dart';
import 'package:kolkhoz_app/src/lower_bar_actions.dart';
import 'package:kolkhoz_app/src/online_game_models.dart';
import 'package:kolkhoz_app/src/online_table_projection.dart';
import 'package:kolkhoz_app/src/panel_title_display.dart';
import 'package:kolkhoz_app/src/phase_display.dart';
import 'package:kolkhoz_app/src/pixel_text.dart';
import 'package:kolkhoz_app/src/policy_model.dart';
import 'package:kolkhoz_app/src/player_profile_panel.dart';
import 'package:kolkhoz_app/src/player_panel_display.dart';
import 'package:kolkhoz_app/src/plot_display.dart';
import 'package:kolkhoz_app/src/render_model.dart';
import 'package:kolkhoz_app/src/rule_content.dart';
import 'package:kolkhoz_app/src/saved_game_store.dart';
import 'package:kolkhoz_app/src/table_display.dart';
import 'package:kolkhoz_app/src/table_projection_helpers.dart';
import 'package:kolkhoz_app/src/trump_actions.dart';
import 'package:kolkhoz_app/src/tutorial_display.dart';

Finder findAppText(String text, {bool skipOffstage = true}) {
  return find.byWidgetPredicate(
    (widget) =>
        (widget is Text && widget.data == text) ||
        (widget is PixelText && widget.text == text) ||
        (widget is EditableText && widget.controller.text == text),
    skipOffstage: skipOffstage,
  );
}

void main() {
  test('completed games return to the lobby section they launched from', () {
    expect(KolkhozGameLaunchOrigin.created.returnsToJoinGame, isFalse);
    expect(KolkhozGameLaunchOrigin.joined.returnsToJoinGame, isTrue);
  });

  test('online gameplay fallback refreshes once per second', () {
    expect(onlineGameRefreshInterval, const Duration(seconds: 1));
  });

  test('game sound cues follow authoritative action and phase transitions', () {
    final trick = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
    );
    final assignment = runtimeModelWith(
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
    );
    final requisition = runtimeModelWith(
      phase: phaseRequisition,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
    );
    const play = EngineAction(
      kind: actionPlayCard,
      playerID: 0,
      card: EngineCard(suit: 'wheat', value: 9),
    );
    const assign = EngineAction(
      kind: actionAssign,
      playerID: 0,
      card: EngineCard(suit: 'wheat', value: 9),
      targetSuit: 'wheat',
    );

    expect(
      gameSoundCueForTransition(
        previous: trick,
        next: trick,
        previousActionCount: 0,
        actions: const [play],
      ),
      GameSoundCue.cardPlay,
    );
    expect(
      gameSoundCueForTransition(
        previous: trick,
        next: assignment,
        previousActionCount: 0,
        actions: const [play],
      ),
      GameSoundCue.trickWin,
    );
    expect(
      gameSoundCueForTransition(
        previous: assignment,
        next: assignment,
        previousActionCount: 0,
        actions: const [assign],
      ),
      GameSoundCue.assignment,
    );
    expect(
      gameSoundCueForTransition(
        previous: assignment,
        next: requisition,
        previousActionCount: 1,
        actions: const [assign],
      ),
      GameSoundCue.requisition,
    );
  });

  test('kolkhoz default includes saboteur without a duplicate preset', () {
    expect(KolkhozGameVariants.kolkhoz.wreckerCard, isTrue);
    final englishPresetLabels = KolkhozGamePreset.values
        .map((preset) => presetTitle(preset, KolkhozLanguage.en))
        .toList();
    expect(englishPresetLabels, [
      'Kolkhoz',
      'Little Kolkhoz',
      'Camp Style',
      'Custom',
    ]);
    expect(englishPresetLabels, isNot(contains('Saboteur')));
    expect(OptionsMenuTab.values.map((tab) => tab.iconAsset), [
      'ios_resources/Icons/icon-settings-assist.png',
      'ios_resources/Icons/icon-settings-display.png',
      'ios_resources/Icons/icon-settings-rules.png',
    ]);
    expect(
      variantsFromJson(variantsToJson(KolkhozGameVariants.kolkhoz)).wreckerCard,
      isTrue,
    );
  });

  test('online failure status keeps auth failures actionable', () {
    expect(
      onlineFailureStatusMessage(
        const HttpException('{"error": "missing auth token"}'),
        KolkhozLanguage.en,
      ),
      'Sign in before joining online play.',
    );
    expect(
      onlineFailureStatusMessage(
        OnlineRequestException(
          statusCode: 401,
          uri: Uri.parse('https://online.kolkhoz.example/sessions'),
          responseBody: '{"error": "missing auth token"}',
          sentAuthorization: true,
        ),
        KolkhozLanguage.en,
      ),
      'Could not verify your online account. Try again.',
    );
    expect(
      onlineFailureStatusMessage(
        OnlineRequestException(
          statusCode: 401,
          uri: Uri.parse('https://online.kolkhoz.example/sessions'),
          responseBody: '{"error": "invalid auth token"}',
          sentAuthorization: true,
        ),
        KolkhozLanguage.en,
      ),
      'Online sign-in expired. Sign in again.',
    );
    expect(
      onlineFailureStatusMessage(
        const HttpException('{"error": "account sent north"}'),
        KolkhozLanguage.en,
      ),
      'Sent north: online play is locked for this account.',
    );
    expect(
      onlineFailureLocksOnlinePlay(
        const HttpException('{"error": "account sent north"}'),
      ),
      isTrue,
    );
    expect(
      onlineFailureLocksOnlinePlay(
        const HttpException('{"error": "seat unavailable"}'),
      ),
      isFalse,
    );
    expect(
      onlineFailureStatusMessage(
        const HttpException('{"error": "seat unavailable"}'),
        KolkhozLanguage.en,
      ),
      'The online server rejected the request. seat unavailable',
    );
  });

  test('app settings persist in-game menu control preferences', () {
    const settings = KolkhozAppSettings(
      language: KolkhozLanguage.en,
      appearance: KolkhozAppearance.light,
      cardBack: KolkhozCardBack.winter,
      confirmNewGame: false,
      confirmMainMenu: false,
      showInvalidTapHints: false,
      soundEnabled: false,
      displayName: 'Nadia',
      portraitAsset: 'worker3',
      profileStats: KolkhozProfileStats(
        offlinePlays: 12,
        offlineWins: 8,
        onlinePlays: 4,
        onlineWins: 1,
        casualRating: 1048,
        rating: 1125,
        totalWins: 9,
        totalLosses: 7,
      ),
      favoriteSetup: KolkhozFavoriteSetup(
        variants: KolkhozGameVariants.littleKolkhoz,
        controllers: [
          KolkhozPlayerController.human,
          KolkhozPlayerController.heuristicAI,
          KolkhozPlayerController.mediumAI,
          KolkhozPlayerController.neuralAI,
        ],
      ),
      lastStartedSetup: KolkhozFavoriteSetup(
        variants: KolkhozGameVariants.campStyle,
        controllers: [
          KolkhozPlayerController.human,
          KolkhozPlayerController.human,
          KolkhozPlayerController.mediumAI,
          KolkhozPlayerController.neuralAI,
        ],
        lobbySeats: ['local', 'online', 'mediumAI', 'hardAI'],
        browserJoinable: false,
      ),
    );

    final restored = KolkhozAppSettings.fromJson(settings.toJson());

    expect(restored.language, KolkhozLanguage.en);
    expect(restored.appearance, KolkhozAppearance.light);
    expect(restored.cardBack, KolkhozCardBack.winter);
    expect(restored.confirmNewGame, isFalse);
    expect(restored.confirmMainMenu, isFalse);
    expect(restored.showInvalidTapHints, isFalse);
    expect(restored.soundEnabled, isFalse);
    expect(restored.displayName, 'Nadia');
    expect(restored.portraitAsset, 'worker3');
    expect(restored.profileStats.offlinePlays, 12);
    expect(restored.profileStats.offlineWins, 8);
    expect(restored.profileStats.onlinePlays, 4);
    expect(restored.profileStats.onlineWins, 1);
    expect(restored.profileStats.casualRating, 1048);
    expect(restored.profileStats.rating, 1125);
    expect(restored.profileStats.totalWins, 9);
    expect(restored.profileStats.totalLosses, 7);
    expect(restored.favoriteSetup, isNotNull);
    expect(restored.favoriteSetup!.variants.deckType, 36);
    expect(
      restored.favoriteSetup!.controllers[1],
      KolkhozPlayerController.heuristicAI,
    );
    expect(restored.lastStartedSetup, isNotNull);
    expect(restored.lastStartedSetup!.variants.northernStyle, isTrue);
    expect(
      restored.lastStartedSetup!.controllers[1],
      KolkhozPlayerController.human,
    );
    expect(restored.lastStartedSetup!.lobbySeats[1], 'online');
    expect(restored.lastStartedSetup!.browserJoinable, isFalse);
    expect(const KolkhozAppSettings().confirmNewGame, isTrue);
    expect(const KolkhozAppSettings().confirmMainMenu, isTrue);
    expect(const KolkhozAppSettings().showInvalidTapHints, isTrue);
    expect(const KolkhozAppSettings().displayName, defaultProfileDisplayName);
    expect(const KolkhozAppSettings().cardBack, KolkhozCardBack.classic);
    expect(KolkhozCardBack.fromStoredValue('missing'), KolkhozCardBack.classic);
    expect(KolkhozAppearance.dark.toggleIconAsset, 'icon-appearance-light.png');
    expect(KolkhozAppearance.light.toggleIconAsset, 'icon-appearance-dark.png');
    expect(
      const KolkhozAppSettings().portraitAsset,
      defaultProfilePortraitAsset,
    );
    expect(const KolkhozAppSettings().profileStats.rating, 1000);
    expect(const KolkhozAppSettings().profileStats.casualRating, 1000);
  });

  test('profile stats track casual and ranked ratings separately', () {
    const stats = KolkhozProfileStats(casualRating: 1000, rating: 1200);

    final casualWin = stats.recordResult(online: true, won: true);
    expect(casualWin.casualRating, 1016);
    expect(casualWin.rating, 1200);
    expect(casualWin.casualPlays, 1);
    expect(casualWin.rankedPlays, 0);

    final rankedLoss = stats.recordResult(
      online: true,
      won: false,
      ranked: true,
    );
    expect(rankedLoss.casualRating, 1000);
    expect(rankedLoss.rating, 1184);
    expect(rankedLoss.casualPlays, 0);
    expect(rankedLoss.rankedPlays, 1);
  });

  test('profile stats parse casual rating from server json', () {
    final stats = profileStatsFromSupabaseJson({
      'casual_games': 3,
      'casual_wins': 2,
      'casual_rating': 1088,
      'ranked_games': 4,
      'ranked_wins': 1,
      'rating': 1172,
      'games_played': 7,
      'wins_total': 3,
    });

    expect(stats.casualPlays, 3);
    expect(stats.casualRating, 1088);
    expect(stats.rankedPlays, 4);
    expect(stats.rating, 1172);
  });

  testWidgets('card back scope drives hidden card art', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KolkhozCardBackScope(
          cardBack: KolkhozCardBack.granary,
          child: CardBackMini(tokens: defaultDesignTokens),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      KolkhozCardBack.granary.assetPath,
    );
  });

  testWidgets('game control confirmation resolves through navigator context', (
    tester,
  ) async {
    bool? confirmed;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                confirmed = await showGameControlConfirmation(
                  context: context,
                  language: KolkhozLanguage.en,
                  tokens: lightDesignTokens,
                  title: 'Main menu?',
                  message: 'Leave the current game and return to setup.',
                  confirmLabel: 'Main menu',
                );
              },
              child: const Text('Open confirmation'),
            );
          },
        ),
      ),
    );

    await tester.tap(findAppText('Open confirmation'));
    await tester.pumpAndSettle();

    expect(findAppText('Main menu?'), findsOneWidget);
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, lightDesignTokens.colors.panel);
    expect(dialog.titleTextStyle?.color, lightDesignTokens.colors.gold);
    expect(dialog.contentTextStyle?.color, lightDesignTokens.colors.cream);
    await tester.tap(findAppText('Main menu'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
  });

  testWidgets('session options use two columns on wide boards', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 900,
          height: 260,
          child: OptionsSessionControls(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
          ),
        ),
      ),
    );

    final newGameBottom = tester
        .getBottomLeft(find.byKey(const Key('command-surface-button')))
        .dy;
    final firstToggleTop = tester
        .getTopLeft(find.byType(OptionsSettingToggle).first)
        .dy;

    expect(firstToggleTop, lessThan(newGameBottom));
  });

  testWidgets('left rail uses generic icon assets', (tester) async {
    const tokens = defaultDesignTokens;
    final metrics = ResponsiveBoardMetrics.fromSize(
      const Size(844, 390),
      tokens,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: metrics.railWidth(844),
          height: 390,
          child: BoardRail(
            activePanel: panelBrigade,
            actionPanel: panelJobs,
            tokens: tokens,
            metrics: metrics,
            language: KolkhozLanguage.ru,
            year: 2,
          ),
        ),
      ),
    );

    expect(
      findAssetImage('ios_resources/Icons/icon-year-2.png'),
      findsOneWidget,
    );
    expect(findAssetImage('ios_resources/Icons/icon-menu.png'), findsOneWidget);
    expect(
      findAssetImage('ios_resources/Icons/icon-brigade.png'),
      findsOneWidget,
    );
    expect(findAssetImage('ios_resources/Icons/icon-jobs.png'), findsOneWidget);
    expect(
      findAssetImage('ios_resources/Icons/icon-north.png'),
      findsOneWidget,
    );
    expect(findAssetImage('ios_resources/Icons/icon-plot.png'), findsOneWidget);
    expect(
      findAssetImage('ios_resources/Icons/icon-game-log.png'),
      findsOneWidget,
    );
    expect(find.byType(RailStatusIcon), findsOneWidget);
    expect(find.byType(RailButton), findsNWidgets(6));
  });

  testWidgets('left rail reports selected panel', (tester) async {
    const tokens = defaultDesignTokens;
    final metrics = ResponsiveBoardMetrics.fromSize(
      const Size(844, 390),
      tokens,
    );
    String? selectedPanel;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: metrics.railWidth(844),
          height: 390,
          child: BoardRail(
            activePanel: panelBrigade,
            actionPanel: panelJobs,
            tokens: tokens,
            metrics: metrics,
            language: KolkhozLanguage.en,
            year: 3,
            onPanelSelected: (panel) => selectedPanel = panel,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Cellar'));
    expect(selectedPanel, panelPlot);
    expect(find.byTooltip('Switch to Russian'), findsNothing);
    expect(find.byTooltip('Switch to light mode'), findsNothing);
    expect(
      tester.getTopLeft(find.byTooltip('Year 3')).dy,
      lessThan(tester.getTopLeft(find.byTooltip('Brigade')).dy),
    );
    expect(
      tester.getBottomLeft(find.byTooltip('Menu')).dy,
      greaterThan(tester.getBottomLeft(find.byTooltip('Cellar')).dy),
    );
  });

  testWidgets('left rail exposes semantic buttons', (tester) async {
    const tokens = defaultDesignTokens;
    final metrics = ResponsiveBoardMetrics.fromSize(
      const Size(844, 390),
      tokens,
    );
    String? selectedPanel;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: metrics.railWidth(844),
          height: 390,
          child: BoardRail(
            activePanel: panelBrigade,
            actionPanel: panelJobs,
            tokens: tokens,
            metrics: metrics,
            language: KolkhozLanguage.en,
            year: 4,
            onPanelSelected: (panel) => selectedPanel = panel,
          ),
        ),
      ),
    );

    Semantics railSemantics(String label) {
      return tester.widget<Semantics>(
        find.descendant(
          of: find.byTooltip(label),
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.label == label,
          ),
        ),
      );
    }

    final brigade = railSemantics('Brigade');
    expect(brigade.properties.label, 'Brigade');
    expect(brigade.properties.button, isTrue);
    expect(brigade.properties.selected, isTrue);
    expect(brigade.properties.onTap, isNotNull);

    final cellar = railSemantics('Cellar');
    expect(cellar.properties.label, 'Cellar');
    expect(cellar.properties.button, isTrue);
    expect(cellar.properties.selected, isFalse);
    expect(cellar.properties.onTap, isNotNull);

    await tester.tap(find.bySemanticsLabel('Cellar'));
    expect(selectedPanel, panelPlot);
  });

  testWidgets('jobs require a selected assignment card before assigning', (
    tester,
  ) async {
    const tokens = defaultDesignTokens;
    LegalAction? assignedAction;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 640,
          height: 180,
          child: JobsPanel(
            model: assignmentModel(selectedCardID: null),
            tokens: tokens,
            language: KolkhozLanguage.en,
            onAction: (action) => assignedAction = action,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(JobTile).first);
    expect(assignedAction, isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 640,
          height: 180,
          child: JobsPanel(
            model: assignmentModel(selectedCardID: 'wheat-9'),
            tokens: tokens,
            language: KolkhozLanguage.en,
            onAction: (action) => assignedAction = action,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(JobTile).first);
    expect(assignedAction?.engineAction.card?.id, 'wheat-9');
    expect(assignedAction?.engineAction.targetSuit, 'wheat');
  });

  test('lower hand bar labels are runtime-model driven', () {
    final continueAction = testLegalAction(
      kind: actionContinueAfterRequisition,
      label: 'Continue',
    );
    final submitAction = testLegalAction(
      kind: actionSubmitAssignments,
      label: 'Commit work',
    );

    expect(lowerBarActionLabel(continueAction, tableYear: 3), 'Year 4');
    expect(lowerBarActionLabel(continueAction, tableYear: 5), 'Finish');
    expect(lowerBarActionLabel(submitAction, tableYear: 2), 'Confirm');
  });

  test(
    'lower hand bar actions are filtered and ordered by display priority',
    () {
      final swapAction = testLegalAction(kind: actionSwap, label: 'Swap');
      final confirmAction = testLegalAction(
        kind: actionConfirmSwap,
        label: 'Confirm',
      );
      final playAction = testLegalAction(kind: actionPlayCard, label: 'Play');
      final actions =
          [confirmAction, playAction, swapAction]
              .where((action) => lowerBarActionKinds.contains(action.kind))
              .toList(growable: false)
            ..sort(compareLowerBarActions);

      expect(actions, [swapAction, confirmAction]);
      expect(isProminentLowerBarAction(swapAction), isFalse);
      expect(isProminentLowerBarAction(confirmAction), isTrue);
    },
  );

  test('store rollback undo is limited to pending assignment edits', () {
    expect(actionCapturesUndoSnapshot(actionAssign), isTrue);
    expect(actionCapturesUndoSnapshot(actionPlayCard), isFalse);
    expect(actionCapturesUndoSnapshot(actionSwap), isFalse);
    expect(actionCapturesUndoSnapshot(actionUndoSwap), isFalse);
    expect(actionCapturesUndoSnapshot(actionConfirmSwap), isFalse);
    expect(actionCapturesUndoSnapshot(actionSubmitAssignments), isFalse);
    expect(actionCapturesUndoSnapshot(actionContinueAfterRequisition), isFalse);
  });

  test('assignment helper resolves selected card and job to real action', () {
    final model = assignmentModel(selectedCardID: 'wheat-9');
    final wheatJob = model.table.jobs.first;
    final beetJob = model.table.jobs.last;

    final wheatAction = assignmentActionForJob(model, wheatJob);
    expect(wheatAction?.engineAction.card?.id, 'wheat-9');
    expect(wheatAction?.engineAction.targetSuit, 'wheat');
    expect(assignmentActionForJob(model, beetJob), isNull);
    expect(
      assignmentActionForJob(assignmentModel(selectedCardID: null), wheatJob),
      isNull,
    );
  });

  test('assignment helper resolves a later selected trick card', () {
    final wheat9 = testCard(id: 'wheat-9', suit: 'wheat', value: 9);
    final beet10 = testCard(id: 'beet-10', suit: 'beet', value: 10);
    final model = runtimeModelWith(
      phase: phaseAssignment,
      selection: SelectionState.empty.copyWith(assignmentCardID: 'beet-10'),
      jobs: [
        Job(
          suit: 'wheat',
          hours: 0,
          requiredHours: jobRequiredHours,
          claimed: false,
          reward: null,
          assignedCards: [],
          validAssignmentTarget: true,
          highlighted: false,
        ),
      ],
      lastTrick: Trick(
        plays: [
          TrickPlay(seatID: 0, card: wheat9),
          TrickPlay(seatID: 1, card: beet10),
        ],
        winnerSeatID: 0,
      ),
      legalActions: [
        testLegalAction(
          kind: actionAssign,
          label: 'Assign',
          engineAction: const EngineAction(
            kind: actionAssign,
            playerID: 0,
            card: EngineCard(suit: 'beet', value: 10),
            targetSuit: 'wheat',
          ),
        ),
      ],
    );

    final action = assignmentActionForJob(model, model.table.jobs.first);

    expect(assignmentControlCards(model).map((card) => card.id), [
      'wheat-9',
      'beet-10',
    ]);
    expect(action?.engineAction.card?.id, 'beet-10');
    expect(action?.engineAction.targetSuit, 'wheat');
  });

  test(
    'controller display helpers derive viewer and render controller names',
    () {
      final controllers = KolkhozPlayerController.normalized([
        KolkhozPlayerController.neuralAI,
        KolkhozPlayerController.mediumAI,
        KolkhozPlayerController.human,
        KolkhozPlayerController.heuristicAI,
      ]);

      expect(viewerSeatIDForControllers(controllers), 2);
      expect(renderControllerName(controllers[0]), controllerNeuralAI);
      expect(renderControllerName(controllers[1]), controllerMediumAI);
      expect(renderControllerName(controllers[2]), controllerHuman);
      expect(renderControllerName(controllers[3]), controllerHeuristicAI);
      expect(
        seatNameForController(playerID: 2, controller: controllers[2]),
        'Player 3',
      );
      expect(
        seatNameForController(playerID: 1, controller: controllers[1]),
        'Bot 1',
      );
    },
  );

  test('bundled neural policy advances a neural C-engine turn', () async {
    final policy = await KolkhozNativePolicyModel.loadAsset(
      defaultNeuralPolicyAsset,
    );
    addTearDown(policy.dispose);
    expect(policy.native.inputSize, 200);
    expect(policy.native.hiddenSize, greaterThan(0));
    expect(policy.native.layerCount, greaterThan(0));
    expect(policy.native.layerSizes[0], policy.native.hiddenSize);
    expect(policy.native.headCount, greaterThan(0));

    final bridge = KolkhozCEngineBridge();
    Pointer<KCEngine>? selectedEngine;
    addTearDown(() {
      final engine = selectedEngine;
      if (engine != null) {
        bridge.freeEngine(engine);
      }
    });
    for (var seed = 1; seed < 200 && selectedEngine == null; seed += 1) {
      final engine = bridge.newEngine(
        seed: seed,
        controllers: [
          KolkhozPlayerController.human,
          KolkhozPlayerController.neuralAI,
          KolkhozPlayerController.neuralAI,
          KolkhozPlayerController.neuralAI,
        ],
      );
      if (bridge.phase(engine) == kcPhasePlanning &&
          bridge.currentPlayer(engine) != 0) {
        selectedEngine = engine;
      } else {
        bridge.freeEngine(engine);
      }
    }
    expect(selectedEngine, isNotNull);
    final engine = selectedEngine!;
    final action = bridge.policyAction(engine, policy.native);
    if (action == null) {
      fail('Policy did not select an action for a neural turn.');
    }
    final result = bridge.applyPolicyAction(engine, action);
    expect(result, 0);
  });

  test('policy model accepts flexible hidden layer sizes', () {
    final policy = KolkhozNativePolicyModel.fromJson({
      'backend': 'c-mlp',
      'input_size': 3,
      'hidden_layers': [4, 2],
      'hidden_weights': [
        List<double>.filled(12, 0.1),
        List<double>.filled(8, 0.2),
      ],
      'hidden_biases': [
        List<double>.filled(4, 0.0),
        List<double>.filled(2, 0.0),
      ],
      'output_weights': List<double>.filled(6, 0.3),
      'b2s': [0.0, 0.1, 0.2],
    });
    addTearDown(policy.dispose);

    expect(policy.native.inputSize, 3);
    expect(policy.native.hiddenSize, 4);
    expect(policy.native.layerCount, 2);
    expect(policy.native.layerSizes[0], 4);
    expect(policy.native.layerSizes[1], 2);
    expect(policy.native.headCount, 3);
  });

  test('policy model rejects inconsistent layer shapes', () {
    expect(
      () => KolkhozNativePolicyModel.fromJson({
        'backend': 'c-mlp',
        'input_size': 3,
        'hidden_layers': [4],
        'hidden_weights': [List<double>.filled(11, 0.1)],
        'hidden_biases': [List<double>.filled(4, 0.0)],
        'output_weights': List<double>.filled(4, 0.3),
        'b2s': [0.0],
      }),
      throwsFormatException,
    );
  });

  test('active viewer follows current or assignment human seat', () {
    final controllers = KolkhozPlayerController.normalized([
      KolkhozPlayerController.heuristicAI,
      KolkhozPlayerController.human,
      KolkhozPlayerController.human,
      KolkhozPlayerController.neuralAI,
    ]);

    expect(hasMultipleHumanControllers(controllers), isTrue);
    expect(
      activeViewerSeatIDForState(
        controllers: controllers,
        phase: phaseTrick,
        currentPlayerID: 2,
        assignmentWinnerID: null,
      ),
      2,
    );
    expect(
      activeViewerSeatIDForState(
        controllers: controllers,
        phase: phaseAssignment,
        currentPlayerID: 0,
        assignmentWinnerID: 1,
      ),
      1,
    );
    expect(
      activeViewerSeatIDForState(
        controllers: controllers,
        phase: phaseTrick,
        currentPlayerID: 0,
        assignmentWinnerID: null,
      ),
      1,
    );
  });

  testWidgets('hot seat ready button reports reveal intent', (tester) async {
    var ready = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 240,
          height: 80,
          child: HotSeatReadyButton(
            tokens: defaultDesignTokens,
            label: 'Ready',
            onPressed: () => ready = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('hot-seat-ready-button')));
    expect(ready, isTrue);
  });

  test('trump actions are filtered and filled in display suit order', () {
    final actions = [
      testLegalAction(
        kind: actionPlayCard,
        label: 'Play',
        engineAction: const EngineAction(
          kind: actionPlayCard,
          playerID: 0,
          card: EngineCard(suit: 'wheat', value: 7),
        ),
      ),
      testLegalAction(
        kind: actionSetTrump,
        label: 'Beet',
        engineAction: const EngineAction(
          kind: actionSetTrump,
          playerID: 0,
          suit: 'beet',
        ),
      ),
      testLegalAction(
        kind: actionSetTrump,
        label: 'Wheat',
        engineAction: const EngineAction(
          kind: actionSetTrump,
          playerID: 0,
          suit: 'wheat',
        ),
      ),
    ];

    final planningOptions = planningTrumpOptions(actions);
    expect(planningOptions.map((option) => option.suit), [
      'wheat',
      'sunflower',
      'potato',
      'beet',
    ]);
    expect(planningOptions.map((option) => option.enabled), [
      true,
      false,
      false,
      true,
    ]);
  });

  testWidgets('planning trump chooser renders in selector player column', (
    tester,
  ) async {
    const tokens = defaultDesignTokens;
    final metrics = ResponsiveBoardMetrics.fromSize(
      const Size(900, 520),
      tokens,
    );
    LegalAction? selectedAction;
    final model = runtimeModelWith(
      phase: phasePlanning,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
      legalActions: [
        for (final suit in displaySuitOrder)
          testLegalAction(
            kind: actionSetTrump,
            label: suit,
            engineAction: EngineAction(
              kind: actionSetTrump,
              playerID: 0,
              suit: suit,
            ),
          ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 520,
          child: BoardPlayArea(
            model: model,
            tokens: tokens,
            metrics: metrics,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            onAction: (action) => selectedAction = action,
          ),
        ),
      ),
    );

    expect(find.byType(PlanningTrumpPanel), findsOneWidget);
    expect(find.byType(TrumpSelectionButton), findsNWidgets(4));

    await tester.tap(find.byType(TrumpSelectionButton).first);
    expect(selectedAction?.kind, actionSetTrump);
    expect(selectedAction?.engineAction.suit, 'wheat');
  });

  testWidgets('game over panel occupies the hand tray area', (tester) async {
    const tokens = defaultDesignTokens;
    final calls = <String>[];
    final metrics = ResponsiveBoardMetrics.fromSize(
      const Size(900, 520),
      tokens,
    );
    final base = runtimeModelWith(
      phase: phaseGameOver,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
    );
    final opponentCellarCard = testCard(
      id: 'sunflower-12-game-over',
      suit: 'sunflower',
      value: 12,
      rank: 'Q',
    );
    final opponentPlotCard = testCard(
      id: 'wheat-3-game-over',
      suit: 'wheat',
      value: 3,
    );
    final opponentStackRevealedCard = testCard(
      id: 'beet-4-game-over',
      suit: 'beet',
      value: 4,
    );
    final opponentStackHiddenCard = testCard(
      id: 'potato-5-game-over',
      suit: 'potato',
      value: 5,
    );
    final seats = [
      base.table.seats[0],
      seatWithPlot(
        base.table.seats[1],
        PlotState(
          revealed: [opponentPlotCard],
          hidden: [opponentCellarCard],
          stacks: [
            PlotStackState(
              revealed: [opponentStackRevealedCard],
              hidden: [opponentStackHiddenCard],
            ),
          ],
        ),
      ),
      base.table.seats[2],
      base.table.seats[3],
    ];
    const gameOverScores = [
      Score(seatID: 0, visibleScore: 30, finalScore: 30),
      Score(seatID: 1, visibleScore: 10, finalScore: 10),
      Score(seatID: 2, visibleScore: 40, finalScore: 40),
      Score(seatID: 3, visibleScore: 20, finalScore: 20),
    ];
    final model = TableViewModel(
      viewer: base.viewer,
      table: TableState(
        year: base.table.year,
        phase: base.table.phase,
        phasePrompt: base.table.phasePrompt,
        currentPlayerID: base.table.currentPlayerID,
        trump: base.table.trump,
        isFamine: base.table.isFamine,
        maxTricks: base.table.maxTricks,
        seats: seats,
        jobs: base.table.jobs,
        trick: base.table.trick,
        lastTrick: base.table.lastTrick,
        requisitionEvents: base.table.requisitionEvents,
        exiledByYear: base.table.exiledByYear,
        scoreboard: gameOverScores,
        gameResult: const GameResult(winnerSeatID: 2, scores: gameOverScores),
      ),
      panels: base.panels,
      selection: base.selection,
      legalActions: base.legalActions,
    );
    final gameOverWinnerID =
        model.table.gameResult?.winnerSeatID ??
        inferredWinnerID(model.table.scoreboard);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 520,
          child: BoardPlayArea(
            model: model,
            tokens: tokens,
            metrics: metrics,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            onNewGame: () => calls.add('new'),
            onCopyGameResult: () => calls.add('copy'),
          ),
        ),
      ),
    );

    expect(find.byType(GameOverPlotPanel), findsOneWidget);
    expect(
      find.byKey(const Key('game-over-copy-result-button')),
      findsOneWidget,
    );
    expect(find.byType(PlotOverviewView), findsOneWidget);
    expect(find.byType(OpponentPlotPanel), findsNWidgets(3));
    expect(find.byType(LocalPlotColumn), findsNWidgets(2));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is GameCard && widget.card.id == opponentCellarCard.id,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ScaledHighlightableCardBack &&
            widget.card.id == opponentCellarCard.id,
      ),
      findsNothing,
    );
    final opponentSections = tester
        .widgetList<OpponentPlotMiniSection>(
          find.byType(OpponentPlotMiniSection),
        )
        .toList();
    expect(opponentSections.first.value, '12');
    expect(opponentSections.first.hidden, isFalse);
    expect(find.byType(GameOverFinalScoreStrip), findsOneWidget);
    expect(find.byType(PanelTitleRow), findsNothing);
    final scoreTiles = tester
        .widgetList<GameOverFinalScorePill>(find.byType(GameOverFinalScorePill))
        .toList();
    expect(
      scoreTiles.map((tile) => tile.score),
      orderedEquals([10, 20, 30, 40]),
    );
    final winnerTile = find.byKey(Key('game-over-score-$gameOverWinnerID'));
    expect(
      find.descendant(
        of: winnerTile,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ChromeButtonBackground &&
              widget.asset == chromeButtonPrimaryAsset,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: winnerTile,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'ios_resources/Icons/icon-medal-star.png',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ChromeButtonBackground &&
            widget.asset == chromeButtonSecondaryAsset,
      ),
      findsNWidgets(3),
    );
    expect(find.byType(HandTray), findsNothing);
    expect(
      tester.getSize(find.byType(GameOverPlotPanel)).height,
      greaterThan(520 - metrics.topInfoHeight - metrics.handTrayHeight),
    );
    expect(
      plotOverviewItemCount(
        [
          testCard(id: 'wheat-10', suit: 'wheat', value: 10),
          testCard(id: 'potato-7', suit: 'potato', value: 7),
        ],
        [
          PlotStackState(
            revealed: [testCard(id: 'wheat-8', suit: 'wheat', value: 8)],
            hidden: [testCard(id: 'beet-6', suit: 'beet', value: 6)],
          ),
        ],
      ),
      4,
    );
    expect(plotOverviewCardOverlap(tokens.card.large.width), lessThan(0));

    await tester.tap(find.byKey(const Key('game-over-copy-result-button')));
    expect(calls, ['copy']);

    calls.clear();
    await tester.tap(find.byKey(const Key('game-over-new-game-button')));
    expect(calls, ['new']);

    calls.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 520,
          child: BoardPlayArea(
            model: model,
            tokens: tokens,
            metrics: metrics,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            gameOverReturnsToLobby: true,
            onNewGame: () => calls.add('new'),
            onReturnToLobby: () => calls.add('menu'),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('game-over-main-menu-button')), findsOneWidget);
    expect(find.byKey(const Key('game-over-new-game-button')), findsNothing);

    await tester.tap(find.byKey(const Key('game-over-main-menu-button')));
    expect(calls, ['menu']);
  });

  testWidgets('plot panel keeps opponent stores above active player plot', (
    tester,
  ) async {
    final model = runtimeModelWith(
      phase: phaseSwap,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1048,
          height: 420,
          child: PlotPanel(model: model, tokens: defaultDesignTokens),
        ),
      ),
    );

    expect(find.byType(PlotOverviewView), findsOneWidget);
    expect(find.byType(OpponentPlotPanel), findsNWidgets(3));
    expect(find.byType(LocalPlotColumn), findsNWidgets(2));
    expect(findAppText('PRIVATE PLOT'), findsNothing);
    final opponentPanels = find.byType(OpponentPlotPanel);
    final opponentTop = tester.getTopLeft(opponentPanels.at(0)).dy;
    expect(tester.getTopLeft(opponentPanels.at(1)).dy, opponentTop);
    expect(tester.getTopLeft(opponentPanels.at(2)).dy, opponentTop);
    expect(
      tester.getTopLeft(find.byType(LocalPlotColumn).first).dy,
      greaterThan(opponentTop),
    );
    final opponentHeight = tester
        .getSize(find.byType(OpponentPlotPanel).first)
        .height;
    final overviewHeight = tester.getSize(find.byType(PlotOverviewView)).height;
    final localTop = tester.getTopLeft(find.byType(LocalPlotColumn).first).dy;
    final localHeight = tester
        .getSize(find.byType(LocalPlotColumn).first)
        .height;
    expect(
      opponentHeight,
      closeTo(
        (overviewHeight - (localTop - opponentTop - opponentHeight)) *
            defaultDesignTokens.layout.plot.opponentHeightFraction,
        1,
      ),
    );
    expect(localHeight, closeTo(opponentHeight, 1));
    expect(localTop - opponentTop, greaterThan(opponentHeight));
    expect(tester.takeException(), isNull);
  });

  testWidgets('requisition uses the normal plot overview layout', (
    tester,
  ) async {
    final model = runtimeModelWith(
      phase: phaseRequisition,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1048,
          height: 420,
          child: PlotPanel(model: model, tokens: defaultDesignTokens),
        ),
      ),
    );

    expect(findAppText('REQUISITION'), findsNothing);
    expect(find.byType(PlotOverviewView), findsOneWidget);
    expect(find.byType(OpponentPlotPanel), findsNWidgets(3));
    expect(find.byType(LocalPlotColumn), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('plot overview shows local cellar cards face up during swap', (
    tester,
  ) async {
    final base = runtimeModelWith(
      phase: phaseSwap,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
    );
    final localHiddenCard = testCard(id: 'beet-8', suit: 'beet', value: 8);
    final localHiddenCard2 = testCard(id: 'potato-7', suit: 'potato', value: 7);
    final localRevealedCard = testCard(id: 'wheat-6', suit: 'wheat', value: 6);
    final localStackCard = testCard(
      id: 'sunflower-5',
      suit: 'sunflower',
      value: 5,
    );
    final opponentHiddenCard = testCard(
      id: 'potato-9',
      suit: 'potato',
      value: 9,
    );
    final seats = [
      seatWithPlot(
        base.table.seats[0],
        PlotState(
          revealed: [localRevealedCard],
          hidden: [localHiddenCard, localHiddenCard2],
          stacks: [
            PlotStackState(revealed: [localStackCard], hidden: const []),
          ],
        ),
      ),
      seatWithPlot(
        base.table.seats[1],
        PlotState(
          revealed: const [],
          hidden: [opponentHiddenCard],
          stacks: const [],
        ),
      ),
      base.table.seats[2],
      base.table.seats[3],
    ];
    final model = TableViewModel(
      viewer: base.viewer,
      table: TableState(
        year: base.table.year,
        phase: base.table.phase,
        phasePrompt: base.table.phasePrompt,
        currentPlayerID: base.table.currentPlayerID,
        trump: base.table.trump,
        isFamine: base.table.isFamine,
        maxTricks: base.table.maxTricks,
        seats: seats,
        jobs: base.table.jobs,
        trick: base.table.trick,
        lastTrick: base.table.lastTrick,
        requisitionEvents: base.table.requisitionEvents,
        exiledByYear: base.table.exiledByYear,
        scoreboard: base.table.scoreboard,
        gameResult: base.table.gameResult,
      ),
      panels: base.panels,
      selection: base.selection,
      legalActions: base.legalActions,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1048,
          height: 420,
          child: PlotPanel(model: model, tokens: defaultDesignTokens),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is GameCard && widget.card.id == localHiddenCard.id,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ScaledHighlightableCardBack &&
            widget.card.id == localHiddenCard.id,
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is GameCard && widget.card.id == opponentHiddenCard.id,
      ),
      findsNothing,
    );
    final localColumns = tester
        .widgetList<LocalPlotColumn>(find.byType(LocalPlotColumn))
        .toList();
    expect(localColumns[0].value, 2);
    expect(localColumns[1].value, 11);
  });

  testWidgets('planning trump chooser animates AI selector focus', (
    tester,
  ) async {
    final base = runtimeModel();
    final legalActions = [
      for (final suit in displaySuitOrder)
        testLegalAction(
          kind: actionSetTrump,
          label: suit,
          engineAction: EngineAction(
            kind: actionSetTrump,
            playerID: 1,
            suit: suit,
          ),
        ),
    ];
    final aiModel = runtimeModelWith(
      phase: phasePlanning,
      currentPlayerID: 1,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      legalActions: legalActions,
    );
    final humanModel = runtimeModelWith(
      phase: phasePlanning,
      currentPlayerID: 0,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      legalActions: legalActions,
    );

    expect(planningTrumpSelectorIsAI(aiModel), isTrue);
    expect(planningTrumpSelectorIsAI(humanModel), isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: PlanningTrumpPanel(
          model: aiModel,
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          focusedSuit: 'wheat',
        ),
      ),
    );

    Iterable<TrumpSelectionButton> buttons() => tester
        .widgetList<TrumpSelectionButton>(find.byType(TrumpSelectionButton));

    expect(buttons().where((button) => button.aiFocused), hasLength(1));

    await tester.pumpWidget(
      MaterialApp(
        home: PlanningTrumpPanel(
          model: humanModel,
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          focusedSuit: null,
        ),
      ),
    );
    expect(buttons().where((button) => button.aiFocused), isEmpty);
  });

  test('c engine action codec encodes portable engine actions', () {
    final action = cEngineAction(
      const EngineAction(
        kind: actionSwap,
        playerID: 0,
        handCard: EngineCard(suit: 'wheat', value: 7),
        plotCard: EngineCard(suit: 'beet', value: 10),
        plotZone: plotZoneHidden,
      ),
    );

    expect(action, isNotNull);
    expect(action!.kind, kcActionSwap);
    expect(action.playerID, 0);
    expect(action.handCard.suit, 0);
    expect(action.handCard.value, 7);
    expect(action.plotCard.suit, 3);
    expect(action.plotCard.value, 10);
    expect(action.plotZone, 0);
    expect(action.suit, -1);
    expect(action.targetSuit, -1);

    final assignAction = cEngineAction(
      const EngineAction(
        kind: actionAssign,
        playerID: 0,
        card: EngineCard(suit: 'sunflower', value: 12),
        targetSuit: 'potato',
      ),
    );

    expect(assignAction, isNotNull);
    expect(assignAction!.kind, kcActionAssign);
    expect(assignAction.card.suit, 1);
    expect(assignAction.card.value, 12);
    expect(assignAction.targetSuit, 2);
  });

  test('c engine action codec rejects unknown action kinds', () {
    expect(
      cEngineAction(const EngineAction(kind: actionUnknown, playerID: 0)),
      isNull,
    );
  });

  test('saved game payload round trips variants controllers and actions', () {
    const payload = KolkhozSavedGamePayload(
      seed: 20260703,
      variants: KolkhozGameVariants.littleKolkhoz,
      controllers: [
        KolkhozPlayerController.human,
        KolkhozPlayerController.heuristicAI,
        KolkhozPlayerController.neuralAI,
        KolkhozPlayerController.human,
      ],
      actions: [
        EngineAction(kind: actionSetTrump, playerID: 0, suit: 'wheat'),
        EngineAction(
          kind: actionSwap,
          playerID: 0,
          handCard: EngineCard(suit: 'wheat', value: 7),
          plotCard: EngineCard(suit: 'beet', value: 10),
          plotZone: plotZoneHidden,
        ),
        EngineAction(
          kind: actionAssign,
          playerID: 3,
          card: EngineCard(suit: 'sunflower', value: 12),
          targetSuit: 'potato',
        ),
      ],
    );

    final decoded = KolkhozSavedGamePayload.fromJson(payload.toJson());

    expect(decoded.version, 1);
    expect(decoded.seed, 20260703);
    expect(decoded.variants.deckType, 36);
    expect(decoded.variants.maxYears, 5);
    expect(decoded.variants.ordenNachalniku, isTrue);
    expect(decoded.variants.heroOfSovietUnion, isFalse);
    expect(decoded.controllers, payload.controllers);
    expect(decoded.actions, hasLength(3));
    expect(decoded.actions[1].handCard?.id, 'wheat-7');
    expect(decoded.actions[1].plotCard?.id, 'beet-10');
    expect(decoded.actions[1].plotZone, plotZoneHidden);
    expect(decoded.actions[2].targetSuit, 'potato');
  });

  test('C engine clone preserves an undoable pre-action state', () {
    final bridge = KolkhozCEngineBridge();
    final engine = bridge.newEngine(
      seed: 20260706,
      controllers: const [
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
      ],
    );
    final clone = bridge.cloneEngine(engine);
    addTearDown(() {
      bridge.freeEngine(engine);
      bridge.freeEngine(clone);
    });

    final playerID = bridge.currentPlayer(engine);
    expect(bridge.phase(engine), kcPhasePlanning);
    expect(
      bridge.applyManual(
        engine,
        CEngineActionValue(
          kind: kcActionSetTrump,
          playerID: playerID,
          suit: 0,
          card: const EngineCardValue(suit: -1, value: 0),
          handCard: const EngineCardValue(suit: -1, value: 0),
          plotCard: const EngineCardValue(suit: -1, value: 0),
          plotZone: -1,
          targetSuit: -1,
        ),
      ),
      0,
    );
    expect(bridge.phase(engine), isNot(kcPhasePlanning));
    expect(bridge.phase(clone), kcPhasePlanning);
  });

  test('autosave store saves payloads and ignores corrupt files', () {
    final directory = Directory.systemTemp.createTempSync('kolkhoz-save-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/autosave.json');
    final store = KolkhozAutosaveStore(file);

    store.save(
      const KolkhozSavedGamePayload(
        seed: 42,
        variants: KolkhozGameVariants.kolkhoz,
        controllers: KolkhozPlayerController.defaultControllers,
        actions: [
          EngineAction(kind: actionSetTrump, playerID: 0, suit: 'beet'),
        ],
      ),
    );

    expect(store.load()?.seed, 42);
    expect(store.load()?.actions.single.suit, 'beet');

    file.writeAsStringSync('{not-json');
    expect(store.load(), isNull);
  });

  test('online update json projects to the table model', () {
    final update = OnlineSessionUpdate.fromJson(onlineUpdateJson());
    const legalActions = [
      OnlineEngineAction(kind: kcActionSetTrump, playerID: 0, suit: 0),
    ];

    final model = OnlineTableProjection(
      update: update,
      playerID: 0,
      legalActions: legalActions,
    ).project();

    expect(update.sessionID, '11111111-1111-1111-1111-111111111111');
    expect(update.inviteCode, 'ABCDE');
    expect(model.viewer.seatID, 0);
    expect(model.table.phase, phasePlanning);
    expect(model.table.seats[0].hand.map((card) => card.id), ['wheat-13']);
    expect(model.table.seats[1].controller, controllerRemoteHuman);
    expect(model.table.seats[1].hiddenHandCount, 0);
    expect(model.table.jobs.first.reward?.id, 'wheat-9');
    expect(model.legalActions.single.engineAction.suit, 'wheat');
  });

  test('online job cards preserve assignment trick rows', () {
    final json = onlineUpdateJson();
    final snapshot = json['snapshot'] as Map<String, Object?>;
    snapshot['jobBuckets'] = onlineSuitCardsJson(
      cardsBySuit: {
        0: [
          {...onlineCardJson(0, 9), 'assignmentRound': 3},
        ],
      },
    );

    final update = OnlineSessionUpdate.fromJson(json);
    final model = OnlineTableProjection(
      update: update,
      playerID: 0,
      legalActions: const [],
    ).project();

    final assignedCard = model.table.jobs
        .firstWhere((job) => job.suit == 'wheat')
        .assignedCards
        .single;
    expect(assignedCard.assignmentRound, 3);
  });

  test('online update carries authoritative lobby countdown state', () {
    final json = onlineUpdateJson();
    json['started'] = false;
    json['lobbyCountdownEndsAt'] =
        DateTime.now().millisecondsSinceEpoch / 1000 + 30;

    final update = OnlineSessionUpdate.fromJson(json);

    expect(update.started, isFalse);
    expect(update.lobbyCountdownSeconds, inInclusiveRange(29, 30));
  });

  testWidgets('game log groups actions and reactions by year and phase', (
    tester,
  ) async {
    final json = onlineUpdateJson();
    json['gameLogActions'] = [
      const OnlineEngineAction(
        kind: kcActionSetTrump,
        playerID: 0,
        suit: 0,
      ).toJson(),
      const OnlineEngineAction(
        kind: kcActionPlayCard,
        playerID: 0,
        card: OnlineEngineCard(suit: 1, value: 10),
      ).toJson(),
    ];
    json['playerProfiles'] = [
      {'playerID': 0, 'displayName': 'Mira Petrov', 'avatarURL': 'worker3'},
    ];
    json['reactions'] = [
      {
        'revision': 1,
        'playerID': 1,
        'reactionID': 'medal',
        'year': 1,
        'phase': kcPhasePlanning,
        'createdAt': 1.0,
      },
    ];
    final update = OnlineSessionUpdate.fromJson(json);
    final model = OnlineTableProjection(
      update: update,
      playerID: 0,
      legalActions: update.legalActions,
    ).project();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 600,
          height: 400,
          child: GameLogPanel(
            model: model,
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            actions: update.gameLogActions
                .map((action) => action.engineAction)
                .toList(),
            reactions: update.reactions,
          ),
        ),
      ),
    );

    expect(findAppText('Year 1'), findsOneWidget);
    expect(findAppText('Planning'), findsOneWidget);
    expect(
      findAssetImage('ios_resources/Icons/icon-year-1.png'),
      findsOneWidget,
    );
    expect(
      findAssetImage('ios_resources/Icons/icon-crop-seal.png'),
      findsOneWidget,
    );
    expect(find.byType(PortraitFrame), findsOneWidget);
    expect(model.table.seats[0].name, 'Mira Petrov');
    expect(findAppText('Mira Petrov'), findsOneWidget);
    expect(findAppText('played'), findsOneWidget);
    expect(findAppText('10'), findsOneWidget);
    expect(
      findAssetImage('ios_resources/Icons/icon-sunflower.png'),
      findsOneWidget,
    );
  });

  test('online swap projection hides raw swap combinations until selected', () {
    final json = onlineUpdateJson();
    final snapshot = json['snapshot'] as Map<String, Object?>;
    snapshot['phase'] = kcPhaseSwap;
    snapshot['currentPlayer'] = 0;
    snapshot['waitingPlayer'] = 0;
    snapshot['players'] = [
      onlinePlayerJson(
        id: 0,
        hand: [onlineCardJson(0, 7), onlineCardJson(2, 8)],
        hiddenPlot: [onlineCardJson(3, 10), onlineCardJson(2, 11)],
      ),
      onlinePlayerJson(id: 1),
      onlinePlayerJson(id: 2),
      onlinePlayerJson(id: 3),
    ];
    final update = OnlineSessionUpdate.fromJson(json);
    const legalActions = [
      OnlineEngineAction(
        kind: kcActionSwap,
        playerID: 0,
        handCard: OnlineEngineCard(suit: 0, value: 7),
        plotCard: OnlineEngineCard(suit: 3, value: 10),
        plotZone: 0,
      ),
      OnlineEngineAction(
        kind: kcActionSwap,
        playerID: 0,
        handCard: OnlineEngineCard(suit: 2, value: 8),
        plotCard: OnlineEngineCard(suit: 2, value: 11),
        plotZone: 0,
      ),
      OnlineEngineAction(kind: kcActionConfirmSwap, playerID: 0),
    ];

    final unselected = OnlineTableProjection(
      update: update,
      playerID: 0,
      legalActions: legalActions,
    ).project();

    expect(unselected.legalActions.map((action) => action.kind), [
      actionConfirmSwap,
    ]);
    expect(
      unselected.table.seats[0].hand.where((card) => card.highlighted),
      hasLength(2),
    );

    final selected = OnlineTableProjection(
      update: update,
      playerID: 0,
      legalActions: legalActions,
      uiState: GameUiState(
        selection: SelectionState.empty.copyWith(
          handCardID: 'wheat-7',
          plotCardID: 'beet-10',
          plotZone: plotZoneHidden,
        ),
      ),
    ).project();

    expect(selected.legalActions.map((action) => action.kind), [
      actionSwap,
      actionConfirmSwap,
    ]);
    expect(selected.legalActions.first.engineAction.handCard?.id, 'wheat-7');
    expect(selected.legalActions.first.engineAction.plotCard?.id, 'beet-10');
  });

  test('online engine actions convert from and to portable actions', () {
    final onlineAction = OnlineEngineAction.fromEngineAction(
      const EngineAction(
        kind: actionSwap,
        playerID: 0,
        handCard: EngineCard(suit: 'wheat', value: 7),
        plotCard: EngineCard(suit: 'beet', value: 10),
        plotZone: plotZoneHidden,
      ),
    );

    expect(onlineAction.kind, kcActionSwap);
    expect(onlineAction.handCard.suit, 0);
    expect(onlineAction.plotCard.suit, 3);
    expect(onlineAction.plotZone, 0);
    expect(onlineAction.engineAction.handCard?.id, 'wheat-7');
    expect(onlineAction.engineAction.plotCard?.id, 'beet-10');
  });

  test('online client uses online router compatible paths', () async {
    final httpClient = FakeOnlineHttpClient();

    final client = KolkhozOnlineClient(
      Uri.parse('http://127.0.0.1:8080'),
      httpClient: httpClient,
    );
    final created = await client.createSession(
      variants: KolkhozGameVariants.kolkhoz,
      controllers: KolkhozPlayerController.defaultControllers,
      ranked: false,
    );
    final heartbeat = await client.sendPresenceHeartbeat();
    final sessions = await client.fetchSessions();
    final status = await client.fetchServerStatus();
    final matched = await client.matchmakeSession(rankedOnly: true);
    final session = await client.fetchSession(created.sessionID);
    final actions = await client.fetchLegalActions(
      sessionID: created.sessionID,
      playerID: created.playerID,
      seatToken: created.seatToken,
    );
    final submitted = await client.submitAction(
      sessionID: created.sessionID,
      playerID: created.playerID,
      seatToken: created.seatToken,
      actionLogCount: created.update.actionLogCount,
      action: actions.single.engineAction,
    );

    expect(submitted.sessionID, created.sessionID);
    expect(created.seatToken, 'seat-token-0');
    expect(httpClient.requests.map((request) => request.route), [
      'POST /sessions',
      'POST /presence',
      'GET /sessions',
      'GET /metrics',
      'POST /sessions/matchmake',
      'GET /sessions/11111111-1111-1111-1111-111111111111',
      'GET /sessions/11111111-1111-1111-1111-111111111111/players/0/actions',
      'POST /sessions/11111111-1111-1111-1111-111111111111/actions',
    ]);
    expect(sessions, hasLength(2));
    expect(sessions.first.openSeats, [1]);
    expect(heartbeat.citizensOnline, 16);
    expect(status.citizensOnline, 16);
    expect(matched.playerID, 1);
    expect(sessions.first.expiresAt, 3601.0);
    expect(session.occupiedSeats, [0, 1]);
    expect(httpClient.requests[6].headers['X-Kolkhoz-Seat-Token'], [
      'seat-token-0',
    ]);
    expect(httpClient.requests.last.headers['X-Kolkhoz-Seat-Token'], [
      'seat-token-0',
    ]);
    expect(
      jsonDecode(httpClient.requests.first.body)['variants']['deckType'],
      52,
    );
    expect(jsonDecode(httpClient.requests.first.body)['ranked'], isFalse);
    expect(
      jsonDecode(httpClient.requests.last.body)['action']['kind'],
      kcActionSetTrump,
    );
    expect(jsonDecode(httpClient.requests.last.body)['actionLogCount'], 0);
  });

  test('online realtime refreshes keep the newest pending revision', () {
    expect(newestOnlineRevision(1, 3), 3);
    expect(newestOnlineRevision(5, 3), 5);
    expect(newestOnlineRevision(null, 3), isNull);
    expect(newestOnlineRevision(5, null), isNull);
  });

  test('runtime model is direct Dart state', () {
    final model = runtimeModel();

    expect(model.table.phase, phaseTrick);
    expect(model.table.seats, hasLength(4));
    expect(model.panels.active, panelBrigade);
    expect(model.table.jobs.map((job) => job.suit), displaySuitOrder);
  });

  test('selection state is copied independently from engine state', () {
    final selected = SelectionState.empty.copyWith(
      handCardID: 'wheat-7',
      plotCardID: 'beet-10',
      plotZone: plotZoneHidden,
    );

    expect(selected.handCardID, 'wheat-7');
    expect(selected.plotCardID, 'beet-10');
    expect(selected.plotZone, plotZoneHidden);

    final cleared = selected.copyWith(
      clearHandCardID: true,
      clearPlotCardID: true,
      clearPlotZone: true,
    );

    expect(cleared.handCardID, isNull);
    expect(cleared.plotCardID, isNull);
    expect(cleared.plotZone, isNull);
  });

  test('game ui state owns selection transitions', () {
    final swapSelection = const GameUiState()
        .activatePanel(panelPlot)
        .selectSwapHandCard('wheat-7')
        .selectSwapPlotCard('beet-10', plotZoneHidden);

    expect(swapSelection.activePanel, panelPlot);
    expect(swapSelection.selection.handCardID, 'wheat-7');
    expect(swapSelection.selection.plotCardID, 'beet-10');
    expect(swapSelection.selection.plotZone, plotZoneHidden);

    final afterSwap = swapSelection.clearSelectionAfterAction(actionSwap);

    expect(afterSwap.activePanel, panelPlot);
    expect(afterSwap.selection.handCardID, isNull);
    expect(afterSwap.selection.plotCardID, isNull);
    expect(afterSwap.selection.plotZone, isNull);

    final afterAssignment = const GameUiState()
        .selectAssignmentCard('wheat-9')
        .clearSelectionAfterAction(actionAssign);

    expect(afterAssignment.selection.assignmentCardID, isNull);
  });

  test('game ui state rejects unknown panel and plot zone identifiers', () {
    final emptyRejected = const GameUiState()
        .activatePanel('invented-panel')
        .selectSwapPlotCard('beet-10', 'discard');

    expect(emptyRejected.activePanel, isNull);
    expect(emptyRejected.selection.plotCardID, isNull);
    expect(emptyRejected.selection.plotZone, isNull);

    final existingState = const GameUiState()
        .activatePanel(panelPlot)
        .selectSwapPlotCard('beet-10', plotZoneHidden);

    final rejectedPanel = existingState.activatePanel('invented-panel');
    final rejectedPlot = existingState.selectSwapPlotCard('wheat-9', 'discard');

    expect(rejectedPanel.activePanel, panelPlot);
    expect(rejectedPlot.selection.plotCardID, 'beet-10');
    expect(rejectedPlot.selection.plotZone, plotZoneHidden);
  });

  test('game ui state toggles active panels back to phase default', () {
    final menuOpen = const GameUiState().togglePanel(panelOptions);
    expect(menuOpen.activePanel, panelOptions);

    final menuClosed = menuOpen.togglePanel(panelOptions);
    expect(menuClosed.activePanel, isNull);

    final plotOpen = menuClosed.togglePanel(panelPlot);
    expect(plotOpen.activePanel, panelPlot);
    expect(plotOpen.clearActivePanel().activePanel, isNull);
    expect(plotOpen.togglePanel('invented-panel').activePanel, panelPlot);
  });

  test('manual panel override clears when the game phase changes', () {
    final inspectingPlot = const GameUiState().togglePanel(panelPlot);

    expect(panelsForPhase(inspectingPlot, phaseTrick).active, panelPlot);
    expect(
      inspectingPlot
          .clearActivePanelAfterPhaseChange(
            previousPhase: phaseTrick,
            nextPhase: phaseTrick,
          )
          .activePanel,
      panelPlot,
    );

    final afterPhaseChange = inspectingPlot.clearActivePanelAfterPhaseChange(
      previousPhase: phaseTrick,
      nextPhase: phaseAssignment,
    );

    expect(afterPhaseChange.activePanel, isNull);
    expect(panelsForPhase(afterPhaseChange, phaseAssignment).active, panelJobs);
    expect(panelsForPhase(afterPhaseChange, phaseTrick).active, panelBrigade);
    expect(
      panelsForPhase(
        const GameUiState(),
        phaseAssignment,
        seats: [
          testSeat(id: 0, name: 'You', isViewer: true),
          testSeat(id: 1, name: 'Bot 1'),
        ],
        lastTrick: const Trick(plays: [], winnerSeatID: 1),
      ).active,
      panelBrigade,
    );
    expect(actionPanelForPhase(phaseAssignment), panelJobs);
  });

  test('phase panels only auto-open for viewers with phase actions', () {
    expect(
      panelsForPhase(
        const GameUiState(),
        phaseSwap,
        legalActions: const [],
      ).active,
      panelBrigade,
    );
    expect(
      panelsForPhase(
        const GameUiState(),
        phaseSwap,
        legalActions: [
          testLegalAction(kind: actionConfirmSwap, label: 'Confirm'),
        ],
      ).active,
      panelPlot,
    );
    expect(
      panelsForPhase(
        const GameUiState(),
        phaseAssignment,
        legalActions: const [],
      ).active,
      panelBrigade,
    );
    expect(
      panelsForPhase(
        const GameUiState(),
        phaseAssignment,
        legalActions: [testLegalAction(kind: actionAssign, label: 'Assign')],
      ).active,
      panelJobs,
    );
    expect(
      panelsForPhase(
        const GameUiState(),
        phaseRequisition,
        legalActions: const [],
      ).active,
      panelBrigade,
    );
    expect(
      panelsForPhase(
        const GameUiState(),
        phaseRequisition,
        legalActions: [
          testLegalAction(
            kind: actionContinueAfterRequisition,
            label: 'Continue',
          ),
        ],
      ).active,
      panelPlot,
    );
  });

  test('plot opponent row metrics reserve enough portrait label height', () {
    const tokens = defaultDesignTokens;
    final metrics = PlotPanelMetrics.fromSize(const Size(1048, 342), tokens);
    final availablePortraitColumnHeight =
        metrics.opponentHeight - (metrics.panelPadding * 2);

    expect(
      metrics.portraitSize + 3 + 20,
      lessThanOrEqualTo(availablePortraitColumnHeight),
    );
  });

  test('hand tray only taps engine-highlighted cards in swap', () {
    final swapModel = runtimeModelWith(
      phase: phaseSwap,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
    );
    final card = swapModel.table.seats.first.hand.first;

    expect(handCardCanReceiveTap(swapModel, card), isFalse);
    expect(
      handCardCanReceiveTap(
        swapModel,
        cardWithSelection(card, highlighted: true),
      ),
      isTrue,
    );

    expect(
      handCardCanReceiveTap(
        runtimeModelWith(
          phase: phaseAssignment,
          selection: SelectionState.empty,
          jobs: runtimeModel().table.jobs,
        ),
        cardWithSelection(card, highlighted: true),
      ),
      isFalse,
    );
  });

  test('hand display resolves trick card taps to real play actions', () {
    final playAction = testLegalAction(
      kind: actionPlayCard,
      label: 'Play',
      engineAction: const EngineAction(
        kind: actionPlayCard,
        playerID: 0,
        card: EngineCard(suit: 'wheat', value: 11),
      ),
    );
    final model = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
      legalActions: [playAction],
    );
    final card = model.table.seats.first.hand.first;

    expect(handCardPlayAction(model, card), same(playAction));
    expect(selectedHandCardPlayAction(model), isNull);
    expect(
      selectedHandCardPlayAction(
        runtimeModelWith(
          phase: phaseTrick,
          selection: SelectionState.empty.copyWith(handCardID: 'wheat-11'),
          jobs: runtimeModel().table.jobs,
          legalActions: [playAction],
        ),
      ),
      same(playAction),
    );
    expect(
      handCardPlayAction(
        runtimeModelWith(
          phase: phaseSwap,
          selection: SelectionState.empty,
          jobs: runtimeModel().table.jobs,
          legalActions: [playAction],
        ),
        card,
      ),
      isNull,
    );
  });

  test('game ui state toggles selected trick cards', () {
    final selected = const GameUiState().selectTrickHandCard('wheat-11');
    expect(selected.selection.handCardID, 'wheat-11');
    final cleared = selected.selectTrickHandCard('wheat-11');
    expect(cleared.selection.handCardID, isNull);
  });

  testWidgets('trick hand card tap selects before confirmed play', (
    tester,
  ) async {
    String? selectedCardID;
    LegalAction? confirmedAction;
    final playAction = testLegalAction(
      kind: actionPlayCard,
      label: 'Play',
      engineAction: const EngineAction(
        kind: actionPlayCard,
        playerID: 0,
        card: EngineCard(suit: 'wheat', value: 11),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 520,
          height: 180,
          child: HandTray(
            model: runtimeModelWith(
              phase: phaseTrick,
              selection: SelectionState.empty,
              jobs: runtimeModel().table.jobs,
              legalActions: [playAction],
            ),
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            visibleTrayHeight: 150,
            onTrickHandCardTap: (cardID) => selectedCardID = cardID,
            onAction: (action) => confirmedAction = action,
          ),
        ),
      ),
    );

    final handCard = find.byKey(const Key('hand-card-wheat-11'));
    expect(handCard, findsOneWidget);
    expect(find.byKey(const Key('hand-console')), findsOneWidget);
    expect(find.byKey(const Key('hand-console-primary')), findsOneWidget);
    expect(find.byKey(const Key('hand-console-secondary')), findsOneWidget);
    expect(tester.getSemantics(handCard).label, 'J Wheat, playable');
    final cardControl = tester.widget<HandCardControl>(
      find.byType(HandCardControl),
    );
    expect(cardControl.card.selected, isFalse);
    final focusable = tester.widget<FocusableActionDetector>(
      find.byType(FocusableActionDetector),
    );
    expect(focusable.mouseCursor, SystemMouseCursors.click);
    expect(focusable.actions, contains(ActivateIntent));

    await tester.tap(find.byType(GameCard));
    expect(selectedCardID, 'wheat-11');
    expect(confirmedAction, isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 520,
          height: 180,
          child: HandTray(
            model: runtimeModelWith(
              phase: phaseTrick,
              selection: SelectionState.empty.copyWith(handCardID: 'wheat-11'),
              jobs: runtimeModel().table.jobs,
              legalActions: [playAction],
            ),
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            visibleTrayHeight: 150,
            onTrickHandCardTap: (cardID) => selectedCardID = cardID,
            onAction: (action) => confirmedAction = action,
          ),
        ),
      ),
    );

    final selectedControl = tester.widget<HandCardControl>(
      find.byType(HandCardControl),
    );
    expect(selectedControl.card.selected, isTrue);
    final selectedSlide = tester.widget<AnimatedSlide>(
      find.descendant(
        of: find.byType(HandCardControl),
        matching: find.byType(AnimatedSlide),
      ),
    );
    expect(selectedSlide.offset.dy, lessThan(0));
    expect(tester.getSemantics(handCard).label, 'J Wheat, selected');
    final selectedGameCard = tester.widget<GameCard>(find.byType(GameCard));
    expect(
      selectedGameCard.selectedColorOverride,
      defaultDesignTokens.colors.goldBright,
    );
    expect(
      selectedGameCard.highlightColorOverride,
      defaultDesignTokens.colors.goldBright,
    );

    final primaryButton = tester.widget<ActionIconButton>(
      find.byKey(const Key('hand-console-primary')),
    );
    final secondaryButton = tester.widget<ActionIconButton>(
      find.byKey(const Key('hand-console-secondary')),
    );
    expect(primaryButton.label, 'Confirm');
    expect(primaryButton.onPressed, isNotNull);
    expect(secondaryButton.label, 'Undo');
    expect(secondaryButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('hand-console-primary')));
    expect(confirmedAction, same(playAction));
  });

  testWidgets('game log keeps the hand console read only', (tester) async {
    final playAction = testLegalAction(
      kind: actionPlayCard,
      label: 'Play',
      engineAction: const EngineAction(
        kind: actionPlayCard,
        playerID: 0,
        card: EngineCard(suit: 'wheat', value: 11),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 520,
          height: 180,
          child: HandTray(
            model: runtimeModelWith(
              phase: phaseTrick,
              selection: SelectionState.empty.copyWith(handCardID: 'wheat-11'),
              jobs: runtimeModel().table.jobs,
              legalActions: [playAction],
            ),
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            visibleTrayHeight: 150,
            onAction: (_) {},
            onTrickHandCardTap: (_) {},
            contentOverride: const SizedBox(key: Key('game-log-reactions')),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('game-log-reactions')), findsOneWidget);
    expect(find.byKey(const Key('hand-console')), findsOneWidget);
    expect(
      tester
          .widget<ActionIconButton>(
            find.byKey(const Key('hand-console-primary')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ActionIconButton>(
            find.byKey(const Key('hand-console-secondary')),
          )
          .onPressed,
      isNull,
    );
  });

  test('hand console status stays concise when tray height is compact', () {
    final waitingModel = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
      currentPlayerID: 1,
    );
    final assignmentModel = runtimeModelWith(
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
      lastTrick: const Trick(plays: [], winnerSeatID: 0),
    );

    expect(
      handConsoleStatus(waitingModel, KolkhozLanguage.en, compact: false),
      'Waiting for Bot to play',
    );
    expect(
      handConsoleStatus(waitingModel, KolkhozLanguage.en, compact: true),
      'Waiting for Bot',
    );
    expect(
      handConsoleStatus(assignmentModel, KolkhozLanguage.en, compact: false),
      'Assign the trick',
    );
  });

  test('swap console confirms only before selection or after staged swap', () {
    final confirmAction = testLegalAction(
      kind: actionConfirmSwap,
      label: 'Confirm',
    );
    final swapAction = testLegalAction(kind: actionSwap, label: 'Swap');
    final undoAction = testLegalAction(kind: actionUndoSwap, label: 'Undo');
    TableViewModel swapModel(List<LegalAction> actions) => runtimeModelWith(
      phase: phaseSwap,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
      legalActions: actions,
    );

    expect(handConsoleConfirmAction(swapModel([confirmAction])), confirmAction);
    expect(
      handConsoleConfirmAction(swapModel([swapAction, confirmAction])),
      isNull,
    );
    expect(
      handConsoleSecondaryAction(swapModel([swapAction, confirmAction])),
      swapAction,
    );
    expect(
      handConsoleConfirmAction(swapModel([undoAction, confirmAction])),
      confirmAction,
    );
    expect(
      handConsoleSecondaryAction(swapModel([undoAction, confirmAction])),
      undoAction,
    );
  });

  testWidgets('requisition console confirms left and opens North right', (
    tester,
  ) async {
    LegalAction? confirmedAction;
    String? selectedPanel;
    final continueAction = testLegalAction(
      kind: actionContinueAfterRequisition,
      label: 'Continue',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 520,
          height: 180,
          child: HandTray(
            model: runtimeModelWith(
              phase: phaseRequisition,
              selection: SelectionState.empty,
              jobs: runtimeModel().table.jobs,
              legalActions: [continueAction],
            ),
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            visibleTrayHeight: 150,
            onAction: (action) => confirmedAction = action,
            onPanelSelected: (panel) => selectedPanel = panel,
          ),
        ),
      ),
    );

    final primary = tester.widget<ActionIconButton>(
      find.byKey(const Key('hand-console-primary')),
    );
    final secondary = tester.widget<ActionIconButton>(
      find.byKey(const Key('hand-console-secondary')),
    );
    expect(primary.label, 'Continue');
    expect(secondary.label, 'The North');

    await tester.tap(find.byKey(const Key('hand-console-primary')));
    expect(confirmedAction, same(continueAction));
    await tester.tap(find.byKey(const Key('hand-console-secondary')));
    expect(selectedPanel, panelNorth);
  });

  testWidgets('brigade shows selected trick card as a pending play preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 360,
          child: BrigadePanel(
            model: runtimeModelWith(
              phase: phaseTrick,
              selection: SelectionState.empty.copyWith(handCardID: 'wheat-11'),
              jobs: runtimeModel().table.jobs,
            ),
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
          ),
        ),
      ),
    );

    expect(find.byType(PendingTrickPreview), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.byKey(const Key('pending-trick-card-preview')),
    );
    expect(opacity.opacity, pendingTrickPreviewOpacity);
    expect(findAppText('YOUR TURN'), findsNothing);
    final previewSize = tester.getSize(
      find.byKey(const Key('pending-trick-card-preview')),
    );
    expect(previewSize.width, greaterThan(130));
  });

  testWidgets('invalid trick hand-card taps can show a Foreman hint', (
    tester,
  ) async {
    var invalidTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 170,
          child: HandTray(
            model: runtimeModelWith(
              phase: phaseTrick,
              selection: SelectionState.empty,
              jobs: runtimeModel().table.jobs,
              legalActions: const [],
            ),
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            visibleTrayHeight: 150,
            onInvalidHandCardTap: () => invalidTaps += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(GameCard));
    expect(invalidTaps, 1);
  });

  test('hand tray uses green playable-card highlights in both appearances', () {
    final base = runtimeModel();
    final card = cardWithSelection(
      base.table.seats.first.hand.first,
      highlighted: true,
    );
    final trickModel = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
    );
    final swapModel = runtimeModelWith(
      phase: phaseSwap,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
    );
    final planningModel = runtimeModelWith(
      phase: phasePlanning,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
    );
    final potatoCard = testCard(id: 'potato-9', suit: 'potato', value: 9);

    expect(lightDesignTokens.colors.green, defaultDesignTokens.colors.green);
    expect(
      handTrayHighlightColor(
        trickModel,
        card,
        swapHighlightColor: defaultDesignTokens.colors.red,
        playableHighlightColor: defaultDesignTokens.colors.green,
      ),
      defaultDesignTokens.colors.green,
    );
    expect(
      handTrayHighlightColor(
        trickModel,
        card,
        swapHighlightColor: lightDesignTokens.colors.red,
        playableHighlightColor: lightDesignTokens.colors.green,
      ),
      lightDesignTokens.colors.green,
    );
    expect(
      handTrayHighlightColor(
        swapModel,
        card,
        swapHighlightColor: defaultDesignTokens.colors.red,
        playableHighlightColor: defaultDesignTokens.colors.green,
      ),
      defaultDesignTokens.colors.red,
    );
    expect(
      handTrayCard(
        planningModel,
        cardWithSelection(card, highlighted: false),
        planningTrumpFocusedSuit: 'wheat',
      ).highlighted,
      isTrue,
    );
    expect(
      handTrayCard(
        planningModel,
        potatoCard,
        planningTrumpFocusedSuit: 'wheat',
      ).highlighted,
      isFalse,
    );
    expect(
      handTrayHighlightColor(
        planningModel,
        cardWithSelection(card, highlighted: false),
        planningTrumpFocusedSuit: 'wheat',
        swapHighlightColor: defaultDesignTokens.colors.red,
        playableHighlightColor: defaultDesignTokens.colors.green,
      ),
      defaultDesignTokens.colors.green,
    );
  });

  testWidgets('Foreman hint bubble renders follow-suit reminder', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ForemanHintBubble(
          message: 'Remember, you must follow suit if able.',
          tokens: defaultDesignTokens,
        ),
      ),
    );

    expect(
      findAppText('Remember, you must follow suit if able.'),
      findsOneWidget,
    );
    expect(
      findAssetImage('ios_resources/Embellishments/art-tutorial-foreman.png'),
      findsOneWidget,
    );
  });

  test(
    'hand tray cards reflect selected hand state without mutating model',
    () {
      final selectedModel = runtimeModelWith(
        phase: phaseSwap,
        selection: SelectionState.empty.copyWith(handCardID: 'wheat-11'),
        jobs: runtimeModel().table.jobs,
      );
      final card = selectedModel.table.seats.first.hand.first;
      final selectedCard = handTrayCard(selectedModel, card);

      expect(card.selected, isFalse);
      expect(selectedCard.selected, isTrue);
      expect(selectedCard.highlighted, isFalse);

      final assignmentCard = handTrayCard(
        runtimeModelWith(
          phase: phaseAssignment,
          selection: SelectionState.empty,
          jobs: runtimeModel().table.jobs,
        ),
        cardWithSelection(card, highlighted: true),
      );

      expect(assignmentCard.highlighted, isFalse);
    },
  );

  test('hand display helpers own tray layout policy', () {
    final metrics = ResponsiveBoardMetrics(
      tokens: defaultDesignTokens,
      scale: 1,
      margin: 0,
    );

    expect(metrics.handTrayLayoutHeightForBoardHeight(420), 64);
    expect(metrics.handTrayLayoutHeightForBoardHeight(620), 184);
    expect(metrics.handTrayLayoutHeightForBoardHeight(970), 390);
    expect(metrics.handTrayLayoutHeightForBoardHeight(1400), 390);
    expect(metrics.handTrayVisibleHeightForBoardHeight(420), 78);
    expect(metrics.handTrayVisibleHeightForBoardHeight(620), 198);
    expect(metrics.handTrayVisibleHeightForBoardHeight(970), 404);
    expect(metrics.handTrayVisibleHeightForBoardHeight(1400), 404);
    expect(metrics.handTrayHeightForVisibleHeight(66), 64);
    expect(metrics.handTrayHeightForVisibleHeight(186), 172);
    expect(handTrayCardScale(66, defaultDesignTokens.card.large), 1);
    expect(
      handTrayCardScale(128, defaultDesignTokens.card.large),
      closeTo(1.2072, 0.001),
    );
    expect(
      handTrayCardScale(186, defaultDesignTokens.card.large),
      closeTo(1.7907, 0.001),
    );
    expect(handTrayCardScale(404, defaultDesignTokens.card.large), 3);
    final cardWidth = defaultDesignTokens.card.large.width;
    final fittedStride = handTrayCardStride(390, cardWidth, 5);
    final narrowStride = handTrayCardStride(120, cardWidth, 5);
    expect(fittedStride, cardWidth + handTrayCardSpacing);
    expect(narrowStride, cardWidth * handTrayCardMinimumExposedFraction);
    expect(handTrayCardRailWidth(cardWidth, narrowStride, 5), greaterThan(120));
    expect(handConsoleButtonScale(78), 1);
    expect(handConsoleButtonScale(150), 1);
    expect(
      scaledHandTrayCardSize(defaultDesignTokens.card.large, 404).height,
      closeTo(298.2, 0.001),
    );
    expect(handTrayActionIconSize, lessThan(handTrayActionButtonSize));
    expect(handTrayActionButtonSize, metrics.railButtonSize);
    expect(handTrayActionIconSize, metrics.railIconSize);
    expect(handTrayActionBarPadding, lessThan(handTrayActionButtonSize));
  });

  test('hand cards sort by display suit order then value', () {
    final cards = [
      testCard(id: 'beet-6', suit: 'beet', value: 6),
      testCard(id: 'wheat-12', suit: 'wheat', value: 12),
      testCard(id: 'wheat-7', suit: 'wheat', value: 7),
      testCard(id: 'potato-8', suit: 'potato', value: 8),
    ]..sort(compareCardsForHand);

    expect(cards.map((card) => card.id), [
      'wheat-7',
      'wheat-12',
      'potato-8',
      'beet-6',
    ]);
  });

  test('assignment control cards exclude already assigned trick cards', () {
    final wheat9 = testCard(id: 'wheat-9', suit: 'wheat', value: 9);
    final beet10 = testCard(id: 'beet-10', suit: 'beet', value: 10);
    final model = runtimeModelWith(
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: [
        Job(
          suit: 'wheat',
          hours: 9,
          requiredHours: jobRequiredHours,
          claimed: false,
          reward: null,
          assignedCards: [wheat9],
          validAssignmentTarget: true,
          highlighted: false,
        ),
      ],
      lastTrick: Trick(
        plays: [
          TrickPlay(seatID: 0, card: wheat9),
          TrickPlay(seatID: 1, card: beet10),
        ],
        winnerSeatID: 0,
      ),
    );

    expect(assignmentControlCards(model).map((card) => card.id), ['beet-10']);
    expect(visibleAssignmentTrick(model).plays.map((play) => play.card.id), [
      'beet-10',
    ]);
    expect(
      assignmentControlCards(
        runtimeModelWith(
          phase: phaseTrick,
          selection: SelectionState.empty,
          jobs: model.table.jobs,
          lastTrick: model.table.lastTrick,
        ),
      ),
      isEmpty,
    );
  });

  test('assignment command bar is only visible for human assignment turns', () {
    final wheat9 = testCard(id: 'wheat-9', suit: 'wheat', value: 9);
    final base = runtimeModel();
    final humanAssignment = runtimeModelWith(
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      lastTrick: Trick(
        plays: [TrickPlay(seatID: 0, card: wheat9)],
        winnerSeatID: 0,
      ),
    );
    final aiAssignment = runtimeModelWith(
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      lastTrick: Trick(
        plays: [TrickPlay(seatID: 1, card: wheat9)],
        winnerSeatID: 1,
      ),
    );
    final remoteAssignment = runtimeModelWith(
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      seats: [
        base.table.seats[0],
        seatWithController(
          base.table.seats[1],
          controller: controllerRemoteHuman,
        ),
        base.table.seats[2],
        base.table.seats[3],
      ],
      lastTrick: Trick(
        plays: [TrickPlay(seatID: 1, card: wheat9)],
        winnerSeatID: 1,
      ),
    );

    expect(assignmentCommandBarVisible(humanAssignment), isTrue);
    expect(assignmentCommandBarVisible(aiAssignment), isFalse);
    expect(assignmentControlCards(remoteAssignment), isNotEmpty);
    expect(assignmentCommandBarVisible(remoteAssignment), isFalse);
    final cardWidth = defaultDesignTokens.card.large.width;
    expect(handTrayAssignmentCardStride(cardWidth), lessThan(cardWidth));
    expect(handTrayAssignmentBarWidth(cardWidth, 4), lessThan(290));
  });

  testWidgets('assignment cards use the same responsive size as hand cards', (
    tester,
  ) async {
    final card = testCard(id: 'wheat-9', suit: 'wheat', value: 9);
    const visibleHeight = 150.0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 180,
          child: AssignmentCommandBar(
            cards: [card],
            selectedCardID: null,
            trump: 'wheat',
            tokens: defaultDesignTokens,
            visibleTrayHeight: visibleHeight,
          ),
        ),
      ),
    );

    final expected = scaledHandTrayCardSize(
      defaultDesignTokens.card.large,
      visibleHeight,
    );
    final assignmentCard = tester.widget<GameCard>(find.byType(GameCard));
    expect(assignmentCard.sizeOverride?.width, expected.width);
    expect(assignmentCard.sizeOverride?.height, expected.height);
  });

  testWidgets('hand and assignment cards share one vertical baseline', (
    tester,
  ) async {
    final base = runtimeModel();
    final assignmentCard = testCard(id: 'beet-10', suit: 'beet', value: 10);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 180,
          child: HandTray(
            model: runtimeModelWith(
              phase: phaseAssignment,
              selection: SelectionState.empty,
              jobs: base.table.jobs,
              lastTrick: Trick(
                plays: [TrickPlay(seatID: 1, card: assignmentCard)],
                winnerSeatID: 0,
              ),
            ),
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            visibleTrayHeight: 150,
          ),
        ),
      ),
    );

    final handCardID = base.table.seats.first.hand.first.id;
    final handCard = find.byWidgetPredicate(
      (widget) => widget is GameCard && widget.card.id == handCardID,
    );
    final assignment = find.byWidgetPredicate(
      (widget) => widget is GameCard && widget.card.id == assignmentCard.id,
    );
    expect(tester.getTopLeft(handCard).dy, tester.getTopLeft(assignment).dy);
  });

  test('job display helpers order jobs and size tiles', () {
    final jobs = [emptyVisualJob('beet'), emptyVisualJob('wheat')];

    expect(jobsInDisplayOrder(jobs).map((job) => job.suit), [
      'wheat',
      'sunflower',
      'potato',
      'beet',
    ]);
    expect(jobsTileSpacing(100), jobsTileSpacingMin);
    expect(jobsTileSpacing(1000), jobsTileSpacingMax);
    expect(
      jobsTileHeight(
        availableHeight: 20,
        assignmentPhase: true,
        tokens: defaultDesignTokens.layout.jobs,
      ),
      defaultDesignTokens.layout.jobs.assignmentMinTileHeight,
    );
    expect(assignedJobCardRowCount(8), 2);
    expect(
      assignedJobCardRowWidth(
        rowCardCount: 4,
        cardSize: defaultDesignTokens.card.large,
      ),
      lessThan(defaultDesignTokens.card.large.width * 4),
    );
    expect(
      assignedJobCardsContentSize(
        cardCount: 8,
        cardSize: defaultDesignTokens.card.large,
      ).height,
      lessThan(defaultDesignTokens.card.large.height * 2),
    );
    expect(
      assignedJobTrickRows([
        for (var index = 0; index < 6; index += 1)
          testCard(id: 'wheat-$index', suit: 'wheat', value: index + 6),
      ]).map((row) => row.length),
      [4, 2],
    );
    final splitRoundRows = assignedJobTrickRows([
      testCard(id: 'wheat-6', suit: 'wheat', value: 6, assignmentRound: 1),
      testCard(id: 'wheat-7', suit: 'wheat', value: 7, assignmentRound: 2),
      testCard(id: 'wheat-8', suit: 'wheat', value: 8, assignmentRound: 2),
    ]);
    expect(splitRoundRows.map((row) => row.map((card) => card.id).toList()), [
      ['wheat-6'],
      ['wheat-7', 'wheat-8'],
    ]);
    final thirdRoundRows = assignedJobTrickRows([
      testCard(id: 'wheat-9', suit: 'wheat', value: 9, assignmentRound: 3),
    ]);
    expect(thirdRoundRows.map((row) => row.length), [0, 0, 1]);
    expect(
      assignedJobCardRowsContentSize(
        rows: splitRoundRows,
        cardSize: defaultDesignTokens.card.large,
      ).height,
      greaterThan(defaultDesignTokens.card.large.height),
    );
    final assignedCardSize = assignedJobCardSizeForRows(
      availableSize: const Size(420, 260),
      rows: splitRoundRows,
      tokens: defaultDesignTokens,
    );
    expect(assignedCardSize.width, defaultDesignTokens.card.medium.width);
    expect(assignedCardSize.height, defaultDesignTokens.card.medium.height);
    final jobWithPendingAssignment = Job(
      suit: 'wheat',
      hours: 11,
      requiredHours: jobRequiredHours,
      claimed: false,
      reward: null,
      assignedCards: [
        testCard(id: 'wheat-11', suit: 'wheat', value: 11),
        testCard(id: 'beet-12', suit: 'beet', value: 12, pending: true),
      ],
      validAssignmentTarget: true,
      highlighted: false,
    );
    expect(pendingAssignedJobHours(jobWithPendingAssignment), 12);
    expect(displayedJobHours(jobWithPendingAssignment), 23);
    final fullWidth = assignedJobCardsContentSize(
      cardCount: 5,
      cardSize: defaultDesignTokens.card.large,
    ).width;
    expect(
      assignedJobCardLeft(
        indexInRow: 0,
        rowCardCount: 1,
        fullWidth: fullWidth,
        cardSize: defaultDesignTokens.card.large,
      ),
      closeTo((fullWidth - defaultDesignTokens.card.large.width) / 2, 0.001),
    );
    expect(
      assignedJobCardSize(
        availableSize: const Size(420, 260),
        cardCount: 8,
        tokens: defaultDesignTokens,
      ),
      defaultDesignTokens.card.large,
    );
    expect(
      assignedJobCardSize(
        availableSize: const Size(120, 130),
        cardCount: 8,
        tokens: defaultDesignTokens,
      ),
      defaultDesignTokens.card.small,
    );
  });

  testWidgets('job cards fit narrow columns and retain trick row offsets', (
    tester,
  ) async {
    final cards = [
      for (var index = 0; index < 4; index += 1)
        testCard(
          id: 'wheat-${index + 6}',
          suit: 'wheat',
          value: index + 6,
          assignmentRound: 3,
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 120,
            height: 180,
            child: AssignedJobCardStack(
              cards: cards,
              tokens: defaultDesignTokens,
              trump: null,
            ),
          ),
        ),
      ),
    );

    final stackRect = tester.getRect(find.byType(AssignedJobCardStack));
    final cardFinders = [
      for (final card in cards)
        find.byKey(ValueKey('assigned-job-card-${card.id}')),
    ];
    for (final cardFinder in cardFinders) {
      final cardRect = tester.getRect(cardFinder);
      expect(cardRect.left, greaterThanOrEqualTo(stackRect.left));
      expect(cardRect.right, lessThanOrEqualTo(stackRect.right));
      expect(cardRect.height, lessThan(defaultDesignTokens.card.large.height));
    }
    expect(
      tester.getTopLeft(cardFinders.first).dy - stackRect.top,
      greaterThan(tester.getSize(cardFinders.first).height),
    );
    expect(tester.takeException(), isNull);
  });

  test('plot display helpers hide exiled cards and project selection', () {
    final wheat9 = testCard(id: 'wheat-9', suit: 'wheat', value: 9);
    final beet10 = testCard(id: 'beet-10', suit: 'beet', value: 10);
    final selected = selectedPlotCard(wheat9, 'wheat-9');

    expect(selected.selected, isTrue);
    expect(wheat9.selected, isFalse);
    expect(selectedPlotCard(beet10, 'wheat-9'), same(beet10));
    expect(visiblePlotCards([wheat9, beet10], {'wheat-9'}), [beet10]);
  });

  testWidgets('plot stack mini exposes revealed and hidden stack cards', (
    tester,
  ) async {
    final metrics = PlotPanelMetrics.fromSize(
      const Size(640, 360),
      defaultDesignTokens,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlotStackMini(
          stack: PlotStackState(
            revealed: [testCard(id: 'wheat-7', suit: 'wheat', value: 7)],
            hidden: [
              testCard(id: 'beet-8', suit: 'beet', value: 8),
              testCard(id: 'potato-9', suit: 'potato', value: 9),
            ],
          ),
          index: 0,
          metrics: metrics,
          tokens: defaultDesignTokens,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('plot-stack-mini-0')), findsOneWidget);
    expect(find.byType(CardBackMini), findsOneWidget);
  });

  test('table display helpers centralize score and local seat policy', () {
    const scores = [
      Score(seatID: 0, visibleScore: 3, finalScore: null),
      Score(seatID: 1, visibleScore: 4, finalScore: 9),
      Score(seatID: 2, visibleScore: 8, finalScore: null),
    ];
    final seats = [
      testSeat(id: 0, name: 'AI', controller: controllerHeuristicAI),
      testSeat(id: 1, name: 'Remote', controller: controllerRemoteHuman),
      testSeat(
        id: 2,
        name: 'Local Human',
        controller: controllerHuman,
        isViewer: true,
      ),
    ];
    final base = runtimeModel();
    final model = TableViewModel(
      viewer: const Viewer(seatID: 2, privacyMode: viewerPrivacyNone),
      table: TableState(
        year: base.table.year,
        phase: base.table.phase,
        phasePrompt: base.table.phasePrompt,
        currentPlayerID: 1,
        trump: base.table.trump,
        isFamine: base.table.isFamine,
        maxTricks: base.table.maxTricks,
        seats: seats,
        jobs: base.table.jobs,
        trick: base.table.trick,
        lastTrick: base.table.lastTrick,
        requisitionEvents: base.table.requisitionEvents,
        exiledByYear: base.table.exiledByYear,
        scoreboard: base.table.scoreboard,
        gameResult: base.table.gameResult,
      ),
      panels: base.panels,
      selection: base.selection,
      legalActions: base.legalActions,
    );

    expect(finalScoreValue(scores[0]), 3);
    expect(finalScoreForSeat(scores, 1), 9);
    expect(inferredWinnerID(scores), 1);
    expect(isHumanControlledSeat(model.table.seats[1]), isTrue);
    expect(isLocalHumanSeat(model.table.seats[1]), isFalse);
    expect(localSeat(model).id, 2);
    expect(seatDisplayName(model.table.seats[2]), 'You');
  });

  test('player panel display helpers clamp compact layout metrics', () {
    expect(playerPanelOuterInset(100), 5);
    expect(playerPanelOuterInset(1000), 7);
    expect(playerPanelPortraitSize(160, 48), 36);
    expect(playerPanelRowSpacing(100), 3);
    expect(playerPanelRowSpacing(1000), 5);
    expect(playerPanelStatColumnWidth(100), 44);
    expect(playerPanelContentNaturalWidth(100), 99);
    expect(playerPanelCellarCardSpacing(100), -5);
    expect(playerPanelContentLeft(300), 105);
    expect(playerPanelContentRight(300), 258);
    expect(playerPanelPortraitLeft(300, 72), 18);
    expect(playerPanelPortraitTop(120, 72), 24);
    expect(playerPanelNameTop(120), 34.8);
    expect(playerPanelScoreTop(120), 26.4);
    expect(playerPanelLowerStatsTop(120), 61.2);
    expect(playerPanelScale(106.6324), closeTo(2.2215, 0.001));
    expect(playerPanelPortraitSize(273.5, 106.6324), closeTo(78.1971, 0.001));
    expect(playerPanelRowSpacing(273.5, 106.6324), closeTo(11.1075, 0.001));
    expect(
      playerPanelStatColumnWidth(273.5, 106.6324),
      closeTo(111.0754, 0.001),
    );
    expect(
      playerPanelContentNaturalWidthForSize(273.5, 106.6324),
      closeTo(241.2583, 0.001),
    );
    expect(
      playerPanelCellarCardSpacing(273.5, 106.6324),
      closeTo(-13.3291, 0.001),
    );
  });

  test('north display helpers keep requisition scroll height bounded', () {
    expect(
      northCardScrollHeight(columnHeight: 80, headerHeight: northHeaderHeight),
      30,
    );
    expect(
      northCardScrollHeight(columnHeight: 180, headerHeight: northHeaderHeight),
      130,
    );
  });

  testWidgets('short north panel keeps five columns within its height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 640,
          height: 120,
          child: NorthPanel(
            model: runtimeModel(),
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
          ),
        ),
      ),
    );

    expect(find.byType(NorthYearColumn), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('north cards fill their column width and scroll vertically', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 160,
            child: NorthCardScrollRegion(
              child: NorthCardStack(
                cards: [
                  testCard(id: 'wheat-6', suit: 'wheat', value: 6),
                  testCard(id: 'wheat-7', suit: 'wheat', value: 7),
                  testCard(id: 'wheat-8', suit: 'wheat', value: 8),
                ],
                tokens: defaultDesignTokens,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('north-card-wheat-6'))).width,
      100,
    );
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -80));
    await tester.pump();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });

  test('options display helpers clamp menu spacing', () {
    expect(optionsPanelLocalPadding.top, 8);
    expect(optionsPanelSurfaceMinHeight, 230);
    expect(optionsMenuSectionSpacing(100), optionsMenuSectionSpacingMin);
    expect(optionsMenuSectionSpacing(1000), optionsMenuSectionSpacingMax);
    expect(
      planningTrumpAiSelectorHopDuration,
      const Duration(milliseconds: 230),
    );
    expect(defaultGameAnimationSpeed, GameAnimationSpeed.normal);
    expect(GameAnimationSpeed.instant.automaticStepDelay, Duration.zero);
    expect(
      GameAnimationSpeed.fast.automaticStepDelay,
      const Duration(milliseconds: 340),
    );
    expect(
      GameAnimationSpeed.normal.automaticStepDelay,
      const Duration(milliseconds: 600),
    );
    expect(
      GameAnimationSpeed.normal.automaticTrumpSelectionDelay,
      const Duration(milliseconds: 2200),
    );
    expect(
      GameAnimationSpeed.normal.cardFlightDuration,
      const Duration(milliseconds: 520),
    );
    expect(
      GameAnimationSpeed.slow.cardFlightDuration,
      const Duration(milliseconds: 1040),
    );
    expect(cardSlotPulseDuration, const Duration(milliseconds: 1800));
  });

  test('board backgrounds avoid mode-specific gradients', () {
    expect(boardBackdropDecoration(defaultDesignTokens).gradient, isNull);
    expect(boardBackdropDecoration(lightDesignTokens).gradient, isNull);
    expect(playAreaBackdropDecoration(defaultDesignTokens).gradient, isNull);
    expect(playAreaBackdropDecoration(lightDesignTokens).gradient, isNull);
  });

  test('chrome text style avoids collapsed variable font axes', () {
    expect(kolkhozFontStyle.fontFamily, 'Handjet');
    expect(kolkhozFontStyle.fontVariations, isNull);
  });

  test('chrome command buttons use rail underlay assets', () {
    expect(chromeButtonPrimaryAsset, 'ios_resources/ui-nav-button-active.png');
    expect(
      chromeButtonSecondaryAsset,
      'ios_resources/ui-nav-button-inactive.png',
    );
  });

  test('chrome rail underlays expose tiled nine-slice configs', () {
    final plain = chromeButtonNineSliceConfig(chromeButtonSecondaryAsset);
    expect(plain, isNotNull);
    expect(plain!.left, 96);
    expect(plain.top, 96);
    expect(plain.right, 96);
    expect(plain.bottom, 96);

    expect(
      chromeButtonNineSliceConfig(chromeButtonPrimaryCurrentAsset),
      isNull,
    );
    expect(
      chromeButtonNineSliceConfig(chromeButtonSecondaryCurrentAsset),
      isNull,
    );
  });

  testWidgets('chrome command labels use bitmap pixel text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 260,
          height: 80,
          child: ChromeAssetButton(
            label: 'NEW GAME',
            backgroundAsset: chromeButtonPrimaryAsset,
            tokens: defaultDesignTokens,
            textColor: defaultDesignTokens.colors.onAccent,
            textSize: PixelTextSize.headline,
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ChromeScaledLabel &&
            widget.text == 'NEW GAME' &&
            widget.size == PixelTextSize.headline,
      ),
      findsOneWidget,
    );
  });

  test('card motion helpers report primary card zones', () {
    final model = runtimeModel();
    final zones = cardMotionZones(model);
    final cards = cardMotionCards(model);

    expect(zones['wheat-11'], 'hand:0');
    expect(cards['wheat-11']?.rank, 'J');
  });

  testWidgets('card motion layer draws hand-to-trick flights', (tester) async {
    final before = runtimeModel();
    final playedCard = before.table.seats[0].hand.single;
    final after = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: before.table.jobs,
      seats: [
        seatWithHand(before.table.seats[0], const []),
        before.table.seats[1],
        before.table.seats[2],
        before.table.seats[3],
      ],
      trick: Trick(
        plays: [TrickPlay(seatID: 0, card: playedCard)],
        winnerSeatID: null,
      ),
    );

    var currentModel = before;
    late StateSetter setMotionState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setMotionState = setState;
            return SizedBox(
              width: 420,
              height: 280,
              child: CardMotionLayer(
                model: currentModel,
                tokens: defaultDesignTokens,
                speed: GameAnimationSpeed.normal,
                child: _CardMotionTestBoard(model: currentModel),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    setMotionState(() {
      currentModel = after;
    });
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(FlyingCard), findsOneWidget);
  });

  testWidgets('card motion layer draws redacted remote trick flights', (
    tester,
  ) async {
    final before = runtimeModel();
    final remoteCard = testCard(id: 'sunflower-7', suit: 'sunflower', value: 7);
    final after = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: before.table.jobs,
      trick: Trick(
        plays: [TrickPlay(seatID: 2, card: remoteCard)],
        winnerSeatID: null,
      ),
    );

    var currentModel = before;
    late StateSetter setMotionState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setMotionState = setState;
            return SizedBox(
              width: 420,
              height: 280,
              child: CardMotionLayer(
                model: currentModel,
                tokens: defaultDesignTokens,
                speed: GameAnimationSpeed.normal,
                child: _CardMotionTestBoard(model: currentModel),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    setMotionState(() {
      currentModel = after;
    });
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(FlyingCard), findsOneWidget);
  });

  testWidgets('top job gauge includes pending assignment hours', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobGauge(
          job: Job(
            suit: 'wheat',
            hours: 10,
            requiredHours: jobRequiredHours,
            claimed: false,
            reward: null,
            assignedCards: [
              testCard(id: 'wheat-7', suit: 'wheat', value: 7, pending: true),
            ],
            validAssignmentTarget: false,
            highlighted: false,
          ),
          highlighted: false,
          width: 101,
          height: 38,
          tokens: defaultDesignTokens,
        ),
      ),
    );

    expect(findAppText('17/40'), findsOneWidget);
  });

  testWidgets('job gauge marks a pile containing the saboteur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobGauge(
          job: Job(
            suit: 'wheat',
            hours: 21,
            requiredHours: jobRequiredHours,
            claimed: false,
            reward: testCard(id: 'wheat-1', suit: 'wheat', value: 1),
            assignedCards: [
              testCard(id: 'wrecker-14', suit: wreckerSuit, value: 14),
            ],
            validAssignmentTarget: false,
            highlighted: false,
          ),
          highlighted: false,
          width: 101,
          height: 38,
          tokens: defaultDesignTokens,
        ),
      ),
    );

    final saboteurIcon = tester.widget<Image>(
      find.byKey(const ValueKey('job-gauge-wrecker-wheat')),
    );
    expect(
      (saboteurIcon.image as AssetImage).assetName,
      'ios_resources/Icons/icon-variant-saboteur.png',
    );
    expect(
      find.byKey(const ValueKey('job-gauge-reward-wheat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('job-gauge-reward-suit-wheat')),
      findsOneWidget,
    );
    expect(find.byType(MiniRewardCard), findsNothing);
    expect(findAppText('21/40'), findsOneWidget);
  });

  testWidgets('job gauge delta waits for assignment flight to finish', (
    tester,
  ) async {
    Widget gaugeWithHours(int hours, {bool claimed = false}) {
      return MaterialApp(
        home: JobGauge(
          job: Job(
            suit: 'wheat',
            hours: hours,
            requiredHours: jobRequiredHours,
            claimed: claimed,
            reward: testCard(id: 'wheat-1', suit: 'wheat', value: 1),
            assignedCards: const [],
            validAssignmentTarget: false,
            highlighted: false,
          ),
          highlighted: false,
          animationSpeed: GameAnimationSpeed.normal,
          width: 118,
          height: 38,
          tokens: defaultDesignTokens,
        ),
      );
    }

    await tester.pumpWidget(gaugeWithHours(10));
    await tester.pumpWidget(gaugeWithHours(17));
    await tester.pumpWidget(gaugeWithHours(25));

    expect(findAppText('25/40'), findsOneWidget);
    expect(findAppText('+7'), findsNothing);
    expect(findAppText('+8'), findsNothing);

    await tester.pump(
      jobGaugeDeltaRevealDelay(GameAnimationSpeed.normal) -
          const Duration(milliseconds: 1),
    );
    expect(findAppText('+7'), findsNothing);
    expect(findAppText('+8'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(findAppText('+7'), findsOneWidget);
    expect(findAppText('+8'), findsNothing);

    await tester.pump(jobGaugeDeltaRevealStagger);
    expect(findAppText('+7'), findsOneWidget);
    expect(findAppText('+8'), findsOneWidget);

    await tester.pump(jobGaugeDeltaDuration + jobGaugeDeltaRevealStagger);
    expect(findAppText('+7'), findsNothing);
    expect(findAppText('+8'), findsNothing);

    await tester.pumpWidget(gaugeWithHours(40, claimed: true));
    expect(findAppText('40/40'), findsOneWidget);
  });

  test('AI card flights originate from the player info card', () {
    const badgeRect = Rect.fromLTWH(100, 40, 220, 88);
    final model = runtimeModel();
    final source = cardFlightSourceRect(
      cardID: 'sunflower-7',
      previousZone: 'hand:2',
      nextZone: 'trick:2',
      previousRects: {
        'sunflower-7': const Rect.fromLTWH(10, 10, 70, 99),
        playerCardMotionSourceKey(2): badgeRect,
      },
      model: model,
      tokens: defaultDesignTokens,
    );

    expect(source, isNotNull);
    expect(source!.center, badgeRect.center);
    expect(source.width, defaultDesignTokens.card.small.width);
    expect(
      source.height,
      closeTo(defaultDesignTokens.card.small.height, 0.001),
    );
    expect(
      cardFlightSourceRect(
        cardID: 'sunflower-7',
        previousZone: 'hand:2',
        nextZone: 'trick:1',
        previousRects: {playerCardMotionSourceKey(2): badgeRect},
        model: model,
        tokens: defaultDesignTokens,
      ),
      isNull,
    );
    expect(
      cardFlightDurationScale(
        previousZone: 'hand:2',
        nextZone: 'trick:2',
        model: model,
      ),
      playerInfoCardFlightDurationScale,
    );
    expect(
      cardFlightDurationScale(
        previousZone: 'hand:0',
        nextZone: 'trick:0',
        model: model,
      ),
      1,
    );
    expect(
      scaledDuration(
        const Duration(milliseconds: 520),
        playerInfoCardFlightDurationScale,
      ),
      const Duration(milliseconds: 780),
    );
  });

  test('requisition card flights target the north rail icon', () {
    const northIconRect = Rect.fromLTWH(8, 128, 42, 42);
    final destination = cardFlightDestinationRect(
      cardID: 'wheat-9',
      previousZone: 'plot:0:revealed',
      nextZone: 'exiled:1',
      currentRects: {northCardMotionTargetKey: northIconRect},
      tokens: defaultDesignTokens,
    );

    expect(destination, isNotNull);
    expect(destination!.center, northIconRect.center);
    expect(
      destination.width,
      closeTo(defaultDesignTokens.card.small.width, 0.001),
    );
    expect(
      destination.height,
      closeTo(defaultDesignTokens.card.small.height, 0.001),
    );
    expect(plotZoneSeatID('plot:2:stack:0:revealed'), 2);

    const plotRect = Rect.fromLTWH(120, 240, 320, 180);
    final fallbackSource = cardFlightFallbackSourceRect(
      previousZone: 'plot:2:revealed',
      nextZone: 'exiled:1',
      currentRects: {plotCardMotionSourceKey(2): plotRect},
      tokens: defaultDesignTokens,
    );

    expect(fallbackSource, isNotNull);
    expect(fallbackSource!.center, plotRect.center);
    expect(
      cardFlightDurationScale(
        previousZone: 'plot:2:revealed',
        nextZone: 'exiled:1',
        model: runtimeModel(),
      ),
      requisitionCardFlightDurationScale,
    );
  });

  test('job assignment flights can target top gauges', () {
    const gaugeRect = Rect.fromLTWH(220, 12, 112, 38);
    const assignedCardRect = Rect.fromLTWH(16, 420, 74, 104);
    const trickCardRect = Rect.fromLTWH(260, 180, 136, 192);
    final source = cardFlightSourceRect(
      cardID: 'wheat-9',
      previousZone: 'trick:1',
      nextZone: 'job:wheat',
      previousRects: {
        'wheat-9': assignedCardRect,
        trickCardMotionSourceKey('wheat-9'): trickCardRect,
      },
      model: runtimeModel(),
      tokens: defaultDesignTokens,
    );
    final destination = cardFlightDestinationRect(
      cardID: 'wheat-9',
      previousZone: 'trick:1',
      nextZone: 'job:wheat',
      currentRects: {
        'wheat-9': assignedCardRect,
        jobGaugeMotionTargetKey('wheat'): gaugeRect,
      },
      tokens: defaultDesignTokens,
    );

    expect(source, trickCardRect);
    expect(destination, isNotNull);
    expect(destination!.center, gaugeRect.center);
    expect(
      destination.width,
      closeTo(defaultDesignTokens.card.small.width, 0.001),
    );
    expect(
      cardFlightDurationScale(
        previousZone: 'trick:1',
        nextZone: 'job:wheat',
        model: runtimeModel(),
      ),
      jobAssignmentCardFlightDurationScale,
    );
    expect(
      scaledDuration(
        const Duration(milliseconds: 520),
        jobAssignmentCardFlightDurationScale,
      ),
      const Duration(milliseconds: 1040),
    );
  });

  testWidgets('options panel tabs expose game controls and settings', (
    tester,
  ) async {
    final calls = <String>[];
    GameAnimationSpeed? selectedSpeed;
    bool? confirmNewGame;
    bool? confirmMainMenu;
    bool? showInvalidTapHints;
    KolkhozCardBack? selectedCardBack;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 520,
          height: 430,
          child: OptionsPanel(
            model: runtimeModel(),
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            animationSpeed: GameAnimationSpeed.normal,
            onNewGame: () => calls.add('new'),
            onTutorial: () => calls.add('tutorial'),
            onReturnToLobby: () => calls.add('menu'),
            onConfirmNewGameChanged: (value) => confirmNewGame = value,
            onConfirmMainMenuChanged: (value) => confirmMainMenu = value,
            onShowInvalidTapHintsChanged: (value) =>
                showInvalidTapHints = value,
            onLanguageToggle: () => calls.add('language'),
            onAppearanceToggle: () => calls.add('appearance'),
            onCardBackChanged: (cardBack) => selectedCardBack = cardBack,
            onAnimationSpeedChanged: (speed) => selectedSpeed = speed,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('NEW GAME'));
    await tester.tap(find.bySemanticsLabel('HOW TO PLAY'));
    await tester.tap(find.bySemanticsLabel('MAIN MENU'));
    await tester.tap(find.bySemanticsLabel('Confirm new game'));
    await tester.tap(find.bySemanticsLabel('Confirm main menu'));

    await tester.tap(find.bySemanticsLabel('Assist'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Invalid-tap hints'));

    await tester.tap(find.bySemanticsLabel('Display'));
    await tester.pump();
    await tester.tap(find.byTooltip('Switch to Russian'));
    await tester.tap(find.byTooltip('Switch to light mode'));
    await tester.tap(find.bySemanticsLabel('SLOW'));
    await tester.tap(find.bySemanticsLabel('Winter'));

    expect(calls, ['new', 'tutorial', 'menu', 'language', 'appearance']);
    expect(confirmNewGame, isFalse);
    expect(confirmMainMenu, isFalse);
    expect(showInvalidTapHints, isFalse);
    expect(selectedSpeed, GameAnimationSpeed.slow);
    expect(selectedCardBack, KolkhozCardBack.winter);
  });

  testWidgets('lobby utility icon row controls are interactive', (
    tester,
  ) async {
    final calls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: StandaloneLobby(
            tokens: lightDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.light,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.custom,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: false,
            onHostOnline: (_, controllers, enterImmediately, _, _) async =>
                'session',
            onJoinOnline: (_, _, _) async {},
            onEnterOnlineGame: () {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () => calls.add('language'),
            onAppearanceToggle: () => calls.add('appearance'),
            onSettingsPressed: () => calls.add('settings'),
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Language'));
    await tester.tap(find.bySemanticsLabel('Theme'));
    await tester.tap(find.bySemanticsLabel('Settings'));

    expect(calls, ['language', 'appearance', 'settings']);
    expect(findAppText('STANDARD'), findsNothing);
  });

  testWidgets('custom lobby allows selecting the number of years', (
    tester,
  ) async {
    KolkhozGameVariants? changedVariants;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: StandaloneLobby(
            tokens: lightDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.light,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.custom,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: false,
            onHostOnline: (_, _, _, _, _) async => 'session',
            onJoinOnline: (_, _, _) async {},
            onEnterOnlineGame: () {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (variants) {
              changedVariants = variants;
            },
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('5 Year Plan'));
    await tester.pump();
    expect(find.bySemanticsLabel('1 Year Plan'), findsOneWidget);
    expect(find.bySemanticsLabel('2 Year Plan'), findsOneWidget);
    expect(find.bySemanticsLabel('3 Year Plan'), findsOneWidget);
    expect(find.bySemanticsLabel('4 Year Plan'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('2 Year Plan'));

    expect(changedVariants?.maxYears, 2);
  });

  testWidgets('lobby settings display tab exposes card back choices', (
    tester,
  ) async {
    KolkhozCardBack? selectedCardBack;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 520,
          child: StandaloneLobby(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            cardBack: KolkhozCardBack.classic,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: false,
            showingProfile: true,
            initialSettingsTab: KolkhozSettingsTab.display,
            onHostOnline: (_, _, _, _, _) async => 'session',
            onJoinOnline: (_, _, _) async {},
            onEnterOnlineGame: () {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
            onCardBackChanged: (cardBack) => selectedCardBack = cardBack,
          ),
        ),
      ),
    );

    expect(findAppText('CARD BACKS'), findsOneWidget);
    expect(find.bySemanticsLabel('Classic'), findsOneWidget);
    expect(find.bySemanticsLabel('Harvest'), findsOneWidget);
    expect(find.bySemanticsLabel('Granary'), findsOneWidget);
    expect(find.bySemanticsLabel('Winter'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Granary'));
    await tester.pump();

    expect(selectedCardBack, KolkhozCardBack.granary);
  });

  testWidgets('light active variant rows use high contrast text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: StandaloneLobby(
            tokens: lightDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.light,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.custom,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: false,
            onHostOnline: (_, controllers, enterImmediately, _, _) async =>
                'session',
            onJoinOnline: (_, _, _) async {},
            onEnterOnlineGame: () {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
          ),
        ),
      ),
    );

    final swapDescription = KolkhozLanguage.en.t(
      KolkhozText.variantSwapDescription,
    );
    final swapBodyFinder = find.byWidgetPredicate(
      (widget) =>
          widget is PixelText &&
          widget.text == swapDescription &&
          widget.color == lightDesignTokens.colors.activeSurfaceText,
    );

    expect(swapBodyFinder, findsOneWidget);
  });

  testWidgets('light prominent profile stat tiles use high contrast text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          child: PlayerProfileStatsGrid(
            tokens: lightDesignTokens,
            groups: const [
              PlayerProfileStatGroup(
                label: 'Ranked',
                stats: [
                  PlayerProfileStat(
                    label: 'RATING',
                    value: '1842',
                    prominent: true,
                  ),
                  PlayerProfileStat(label: 'games', value: '3'),
                  PlayerProfileStat(label: 'wins', value: '2'),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Ranked')).style?.color,
      lightDesignTokens.colors.activeSurfaceTextMuted,
    );
    expect(
      tester.widget<Text>(find.text('games')).style?.color,
      lightDesignTokens.colors.activeSurfaceTextMuted,
    );
    expect(
      tester.widget<Text>(find.text('1842')).style?.color,
      lightDesignTokens.colors.activeSurfaceText,
    );
  });

  testWidgets(
    'lobby uses left nav and tutorial starts from how-to-play panel',
    (tester) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 844,
            height: 390,
            child: StandaloneLobby(
              tokens: lightDesignTokens,
              language: KolkhozLanguage.en,
              appearance: KolkhozAppearance.light,
              onStart: () => calls.add('start'),
              selectedPreset: KolkhozGamePreset.kolkhoz,
              customVariants: KolkhozGameVariants.kolkhoz,
              playerControllers: KolkhozPlayerController.defaultControllers,
              showingRules: false,
              showingOnline: true,
              onHostOnline: (_, controllers, enterImmediately, _, _) async =>
                  'session',
              onJoinOnline: (_, _, _) async {},
              onEnterOnlineGame: () {},
              onPresetChanged: (_) {},
              onCustomVariantsChanged: (_) {},
              onPlayerControllersChanged: (_) {},
              onRulesPressed: () => calls.add('rules'),
              onOfflinePressed: () => calls.add('offline'),
              onOnlinePressed: () => calls.add('online'),
              onTutorialPressed: () => calls.add('tutorial'),
              onLanguageToggle: () {},
              onAppearanceToggle: () {},
            ),
          ),
        ),
      );

      expect(findAppText('START GAME'), findsNothing);
      expect(findAppText('HOST GAME'), findsNothing);
      expect(findAppText('INVITE CODE'), findsOneWidget);

      await tester.tap(findAppText('CREATE GAME'));
      await tester.tap(findAppText('JOIN GAME').first);
      await tester.tap(findAppText('HOW TO PLAY'));

      expect(calls, ['offline', 'online', 'rules']);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 844,
            height: 390,
            child: StandaloneLobby(
              tokens: lightDesignTokens,
              language: KolkhozLanguage.en,
              appearance: KolkhozAppearance.light,
              onStart: () => calls.add('start'),
              selectedPreset: KolkhozGamePreset.kolkhoz,
              customVariants: KolkhozGameVariants.kolkhoz,
              playerControllers: KolkhozPlayerController.defaultControllers,
              showingRules: false,
              showingOnline: false,
              onHostOnline: (_, controllers, enterImmediately, _, _) async =>
                  'session',
              onJoinOnline: (_, _, _) async {},
              onEnterOnlineGame: () {},
              onPresetChanged: (_) {},
              onCustomVariantsChanged: (_) {},
              onPlayerControllersChanged: (_) {},
              onRulesPressed: () => calls.add('rules'),
              onOfflinePressed: () => calls.add('offline'),
              onOnlinePressed: () => calls.add('online'),
              onTutorialPressed: () => calls.add('tutorial'),
              onLanguageToggle: () {},
              onAppearanceToggle: () {},
            ),
          ),
        ),
      );

      await tester.tap(findAppText('ADD PLAYERS'));
      await tester.pumpAndSettle();
      expect(findAppText('52 CARDS / 5 YEARS'), findsNothing);
      expect(find.byTooltip('Kolkhoz'), findsOneWidget);
      expect(find.byTooltip('52 Card Deck'), findsOneWidget);
      expect(find.byTooltip('5 Year Plan'), findsOneWidget);
      expect(find.byTooltip('Exchange Soap for an Awl'), findsOneWidget);
      expect(find.byTooltip('Enemy of the People'), findsOneWidget);
      final backCenter = tester.getCenter(findAppText('BACK TO SETUP')).dy;
      final startCenter = tester
          .getCenter(findAppText('START OFFLINE GAME'))
          .dy;
      expect((backCenter - startCenter).abs(), lessThan(8));

      await tester.tap(find.bySemanticsLabel('P2 Hard'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.bySemanticsLabel('P3 Hard'));
      await tester.tap(find.bySemanticsLabel('P3 Hard'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.bySemanticsLabel('P4 Hard'));
      await tester.tap(find.bySemanticsLabel('P4 Hard'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(findAppText('START OFFLINE GAME'));
      await tester.tap(findAppText('START OFFLINE GAME'));

      expect(calls, ['offline', 'online', 'rules', 'start']);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 844,
            height: 390,
            child: StandaloneLobby(
              tokens: lightDesignTokens,
              language: KolkhozLanguage.en,
              appearance: KolkhozAppearance.light,
              onStart: () => calls.add('start'),
              selectedPreset: KolkhozGamePreset.kolkhoz,
              customVariants: KolkhozGameVariants.kolkhoz,
              playerControllers: KolkhozPlayerController.defaultControllers,
              showingRules: true,
              showingOnline: false,
              onHostOnline: (_, controllers, enterImmediately, _, _) async =>
                  'session',
              onJoinOnline: (_, _, _) async {},
              onEnterOnlineGame: () {},
              onPresetChanged: (_) {},
              onCustomVariantsChanged: (_) {},
              onPlayerControllersChanged: (_) {},
              onRulesPressed: () => calls.add('rules'),
              onOfflinePressed: () => calls.add('offline'),
              onOnlinePressed: () => calls.add('online'),
              onTutorialPressed: () => calls.add('tutorial'),
              onLanguageToggle: () {},
              onAppearanceToggle: () {},
            ),
          ),
        ),
      );

      expect(findAppText('RULES'), findsNothing);
      expect(findAppText('HOW TO PLAY'), findsWidgets);
      await tester.tap(findAppText('TUTORIAL'));

      expect(calls, ['offline', 'online', 'rules', 'start', 'tutorial']);
    },
  );

  testWidgets('profile panel edits display name and portrait', (tester) async {
    String? displayName;
    String? portraitAsset;
    var signedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 520,
          child: StandaloneLobby(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: false,
            showingProfile: true,
            cloudConfigured: true,
            cloudReady: true,
            cloudSignedIn: true,
            cloudEmail: 'mira@example.com',
            cloudAuthMessage: 'Profile loaded.',
            displayName: 'Mira',
            portraitAsset: 'worker1',
            profileStats: const KolkhozProfileStats(
              offlinePlays: 12,
              offlineWins: 8,
              onlinePlays: 4,
              onlineWins: 1,
              casualRating: 1048,
              rating: 1125,
              totalWins: 9,
              totalLosses: 7,
            ),
            onHostOnline: (_, _, _, _, _) async => 'session',
            onJoinOnline: (_, _, _) async {},
            onEnterOnlineGame: () {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
            onDisplayNameChanged: (value) => displayName = value,
            onPortraitChanged: (value) => portraitAsset = value,
            onCloudSignOut: () async => signedOut = true,
          ),
        ),
      ),
    );

    expect(findAppText('Signed in as mira@example.com'), findsOneWidget);
    expect(findAppText('Profile loaded.'), findsNothing);
    expect(findAppText('SIGN OUT'), findsOneWidget);
    expect(findAppText('DISPLAY NAME'), findsNothing);
    expect(findAppText('STATS'), findsOneWidget);
    expect(findAppText('OFFLINE'), findsOneWidget);
    expect(findAppText('Casual'), findsOneWidget);
    expect(findAppText('Ranked'), findsOneWidget);
    expect(findAppText('RATING'), findsNWidgets(2));
    expect(findAppText('1048'), findsOneWidget);
    expect(findAppText('1125'), findsOneWidget);
    expect(findAppText('Mira'), findsWidgets);

    final displayNameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == 'Mira',
    );
    await tester.enterText(displayNameField, 'Nadia');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('worker1'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('worker3'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(findAppText('SIGN OUT'));
    await tester.tap(findAppText('SIGN OUT'));
    await tester.pump();

    expect(displayName, 'Nadia');
    expect(portraitAsset, 'worker3');
    expect(signedOut, isTrue);
  });

  testWidgets('profile panel hides player card and stats while signed out', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 520,
          child: StandaloneLobby(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: false,
            showingProfile: true,
            cloudConfigured: true,
            cloudReady: true,
            cloudSignedIn: false,
            displayName: 'Mira',
            portraitAsset: 'worker1',
            profileStats: const KolkhozProfileStats(rating: 1125),
            onHostOnline: (_, _, _, _, _) async => 'session',
            onJoinOnline: (_, _, _) async {},
            onEnterOnlineGame: () {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
          ),
        ),
      ),
    );

    expect(findAppText('STATS'), findsNothing);
    expect(findAppText('Mira'), findsNothing);
    expect(findAppText('1125'), findsNothing);
    expect(find.bySemanticsLabel('worker1'), findsNothing);
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('profile account creation requires matching passwords', (
    tester,
  ) async {
    String? signUpEmail;
    String? signUpPassword;

    Finder textFieldWithLabel(String label) {
      return find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
    }

    Finder commandButton(String label) {
      return find.byWidgetPredicate(
        (widget) => widget is ChromeAssetButton && widget.label == label,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 560,
          child: StandaloneLobby(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: false,
            showingProfile: true,
            cloudConfigured: true,
            cloudReady: true,
            onHostOnline: (_, _, _, _, _) async => 'session',
            onJoinOnline: (_, _, _) async {},
            onEnterOnlineGame: () {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
            onCloudSignIn: (_, _) async {},
            onCloudSignUp: (email, password) async {
              signUpEmail = email;
              signUpPassword = password;
            },
          ),
        ),
      ),
    );

    await tester.enterText(textFieldWithLabel('EMAIL'), 'mira@example.com');
    await tester.enterText(textFieldWithLabel('PASSWORD'), 'tractor-1');
    await tester.enterText(textFieldWithLabel('CONFIRM PASSWORD'), 'tractor-2');
    await tester.ensureVisible(commandButton('Create'));
    await tester.tap(commandButton('Create'));
    await tester.pump();

    expect(findAppText('Passwords do not match.'), findsOneWidget);
    expect(signUpEmail, isNull);

    await tester.enterText(textFieldWithLabel('CONFIRM PASSWORD'), 'tractor-1');
    await tester.tap(commandButton('Create'));
    await tester.pump();

    expect(signUpEmail, 'mira@example.com');
    expect(signUpPassword, 'tractor-1');
  });

  testWidgets('offline lobby seat icons open controller chooser', (
    tester,
  ) async {
    List<KolkhozPlayerController>? changedControllers;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: StandaloneLobby(
            tokens: lightDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.light,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            displayName: 'Mira',
            portraitAsset: 'worker4',
            profileStats: const KolkhozProfileStats(
              casualRating: 1048,
              rating: 1125,
            ),
            showingRules: false,
            showingOnline: false,
            onHostOnline: (_, controllers, enterImmediately, _, _) async =>
                'session',
            onJoinOnline: (_, _, _) async {},
            onEnterOnlineGame: () {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (controllers) {
              changedControllers = controllers;
            },
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
          ),
        ),
      ),
    );

    expect(findAppText('HUMAN'), findsNothing);
    await tester.tap(findAppText('ADD PLAYERS'));
    await tester.pumpAndSettle();
    expect(findAppText('Mira'), findsOneWidget);
    expect(findAppText('Ranked 1125  Casual 1048'), findsOneWidget);
    expect(findAssetImage('ios_resources/worker4.png'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('P2 Easy'));
    await tester.pumpAndSettle();

    expect(changedControllers, isNotNull);
    expect(changedControllers![1], KolkhozPlayerController.heuristicAI);
  });

  testWidgets('offline lobby can save and use a favorite setup', (
    tester,
  ) async {
    var saveCalls = 0;
    var useCalls = 0;

    Finder commandButton(String label) {
      return find.byWidgetPredicate(
        (widget) => widget is ChromeAssetButton && widget.label == label,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: StandaloneLobby(
            tokens: lightDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.light,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            favoriteSetup: const KolkhozFavoriteSetup(
              variants: KolkhozGameVariants.littleKolkhoz,
              controllers: [
                KolkhozPlayerController.human,
                KolkhozPlayerController.heuristicAI,
                KolkhozPlayerController.mediumAI,
                KolkhozPlayerController.neuralAI,
              ],
            ),
            showingRules: false,
            showingOnline: false,
            onHostOnline: (_, controllers, enterImmediately, _, _) async =>
                'session',
            onJoinOnline: (_, _, _) async {},
            onEnterOnlineGame: () {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
            onSaveFavoriteSetup: () => saveCalls += 1,
            onUseFavoriteSetup: () => useCalls += 1,
          ),
        ),
      ),
    );

    await tester.tap(commandButton('Save Favorite'));
    await tester.pump();
    await tester.tap(commandButton('Use Favorite'));
    await tester.pump();

    expect(saveCalls, 1);
    expect(useCalls, 1);
    await tester.tap(findAppText('ADD PLAYERS'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('P2 Easy'), findsOneWidget);
  });

  testWidgets('lobby resumes last started setup on seat screen', (
    tester,
  ) async {
    var starts = 0;
    List<KolkhozPlayerController>? rememberedControllers;
    List<String>? rememberedSeats;
    bool? rememberedVisibility;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: StandaloneLobby(
            tokens: lightDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.light,
            onStart: () => starts += 1,
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            lastStartedSetup: const KolkhozFavoriteSetup(
              variants: KolkhozGameVariants.kolkhoz,
              controllers: [
                KolkhozPlayerController.human,
                KolkhozPlayerController.heuristicAI,
                KolkhozPlayerController.mediumAI,
                KolkhozPlayerController.neuralAI,
              ],
              lobbySeats: ['local', 'easyAI', 'mediumAI', 'hardAI'],
              browserJoinable: false,
            ),
            showingRules: false,
            showingOnline: false,
            onHostOnline: (_, controllers, enterImmediately, _, _) async =>
                'session',
            onJoinOnline: (_, _, _) async {},
            onEnterOnlineGame: () {},
            onRememberStartedSetup: (controllers, lobbySeats, browserJoinable) {
              rememberedControllers = controllers;
              rememberedSeats = lobbySeats;
              rememberedVisibility = browserJoinable;
            },
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
          ),
        ),
      ),
    );

    expect(findAppText('ADD PLAYERS'), findsNothing);
    expect(findAppText('START OFFLINE GAME'), findsOneWidget);
    expect(findAppText('PRIVATE'), findsOneWidget);
    expect(find.bySemanticsLabel('P2 Easy'), findsOneWidget);

    await tester.tap(findAppText('START OFFLINE GAME'));
    await tester.pump();

    expect(starts, 1);
    expect(rememberedControllers, isNotNull);
    expect(rememberedControllers![1], KolkhozPlayerController.heuristicAI);
    expect(rememberedSeats, ['local', 'easyAI', 'mediumAI', 'hardAI']);
    expect(rememberedVisibility, isFalse);
  });

  testWidgets('create lobby can mark seats online and wait after hosting', (
    tester,
  ) async {
    List<KolkhozPlayerController>? changedControllers;
    List<KolkhozPlayerController>? hostedControllers;
    bool? enterImmediately;
    bool? ranked;
    var enterCalls = 0;
    var showingOnline = false;
    String? hostedInviteCode;
    OnlineSessionUpdate? hostedUpdate;
    List<String>? rememberedSeats;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 844,
            height: 390,
            child: StandaloneLobby(
              tokens: lightDesignTokens,
              language: KolkhozLanguage.en,
              appearance: KolkhozAppearance.light,
              onStart: () {},
              selectedPreset: KolkhozGamePreset.kolkhoz,
              customVariants: KolkhozGameVariants.kolkhoz,
              playerControllers: KolkhozPlayerController.defaultControllers,
              showingRules: false,
              showingOnline: showingOnline,
              hostedInviteCode: hostedInviteCode,
              onlineSessionUpdate: hostedUpdate,
              showHostedInviteCode: hostedInviteCode != null,
              onHostOnline:
                  (
                    _,
                    controllers,
                    enterImmediatelyValue,
                    rankedValue,
                    browserJoinableValue,
                  ) async {
                    hostedControllers = controllers;
                    enterImmediately = enterImmediatelyValue;
                    ranked = rankedValue;
                    expect(browserJoinableValue, isFalse);
                    final updateJson = onlineUpdateJson();
                    updateJson['started'] = false;
                    updateJson['controllers'] = [
                      'human',
                      'human',
                      'neuralAI',
                      'neuralAI',
                    ];
                    updateJson['playerProfiles'] = [
                      {
                        'playerID': 0,
                        'userID': '11111111-1111-1111-1111-111111111111',
                        'displayName': 'Mira',
                        'avatarURL': 'worker3',
                        'stats': {'online_games': 4, 'online_wins': 2},
                      },
                    ];
                    setState(() {
                      hostedInviteCode = 'ABCDE';
                      hostedUpdate = OnlineSessionUpdate.fromJson(updateJson);
                    });
                    return 'session';
                  },
              onJoinOnline: (_, _, _) async {},
              onEnterOnlineGame: () => enterCalls += 1,
              onRememberStartedSetup: (_, lobbySeats, browserJoinable) {
                rememberedSeats = lobbySeats;
                expect(browserJoinable, isFalse);
              },
              onPresetChanged: (_) {},
              onCustomVariantsChanged: (_) {},
              onPlayerControllersChanged: (controllers) {
                changedControllers = controllers;
              },
              onRulesPressed: () {},
              onOfflinePressed: () => setState(() => showingOnline = false),
              onOnlinePressed: () => setState(() => showingOnline = true),
              onTutorialPressed: () {},
              onLanguageToggle: () {},
              onAppearanceToggle: () {},
            ),
          ),
        ),
      ),
    );

    expect(findAppText('ADD PLAYERS'), findsOneWidget);
    expect(findAppText('START OFFLINE GAME'), findsNothing);

    await tester.tap(findAppText('ADD PLAYERS'));
    await tester.pumpAndSettle();
    expect(findAppText('START OFFLINE GAME'), findsOneWidget);
    expect(findAppText('VISIBILITY'), findsOneWidget);
    expect(findAppText('PUBLIC'), findsOneWidget);

    await tester.tap(findAppText('PUBLIC'));
    await tester.pump();
    expect(findAppText('PUBLIC'), findsOneWidget);
    expect(findAppText('PRIVATE'), findsNothing);

    await tester.tap(find.bySemanticsLabel('P2 Online'));
    await tester.pumpAndSettle();
    expect(findAppText('START ONLINE GAME'), findsOneWidget);
    final p3Hotseat = find.bySemanticsLabel('P3 Hotseat');
    expect(p3Hotseat, findsOneWidget);
    expect(
      tester.getSemantics(p3Hotseat).flagsCollection.isEnabled.toBoolOrNull(),
      isFalse,
    );
    await tester.tap(findAppText('PUBLIC'));
    await tester.pump();
    expect(findAppText('PRIVATE'), findsOneWidget);

    await tester.tap(findAppText('JOIN GAME'));
    await tester.pumpAndSettle();
    await tester.tap(findAppText('CREATE GAME'));
    await tester.pumpAndSettle();
    expect(findAppText('START ONLINE GAME'), findsOneWidget);

    await tester.ensureVisible(find.bySemanticsLabel('P3 Hard'));
    await tester.tap(find.bySemanticsLabel('P3 Hard'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.bySemanticsLabel('P4 Hard'));
    await tester.tap(find.bySemanticsLabel('P4 Hard'));
    await tester.pumpAndSettle();

    expect(changedControllers, isNotNull);
    expect(changedControllers![1], KolkhozPlayerController.human);
    expect(findAppText('START ONLINE GAME'), findsOneWidget);
    expect(findAppText('RANKED'), findsNothing);
    expect(findAppText('CASUAL'), findsNothing);
    expect(findAppText('PRIVATE'), findsOneWidget);

    await tester.ensureVisible(findAppText('START ONLINE GAME'));
    await tester.tap(findAppText('START ONLINE GAME'));
    await tester.pump();

    expect(hostedControllers, isNotNull);
    expect(hostedControllers![0], KolkhozPlayerController.human);
    expect(hostedControllers![1], KolkhozPlayerController.human);
    expect(hostedControllers![2], KolkhozPlayerController.neuralAI);
    expect(enterImmediately, isFalse);
    expect(ranked, isFalse);
    expect(enterCalls, 0);
    expect(rememberedSeats, ['local', 'online', 'hardAI', 'hardAI']);
    await tester.pumpAndSettle();
    expect(showingOnline, isFalse);
    expect(findAppText('YOUR INVITE CODE'), findsNothing);
    expect(find.bySemanticsLabel('INVITE CODE ABCDE'), findsOneWidget);
    expect(find.bySemanticsLabel('Waiting for players'), findsWidgets);
    expect(find.textContaining('Searching for Player'), findsOneWidget);
    expect(findAppText('Mira'), findsOneWidget);
  });

  testWidgets('online ban state does not disable the create-game button', (
    tester,
  ) async {
    var hostCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: StandaloneLobby(
            tokens: lightDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.light,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: false,
            onHostOnline: (_, _, _, _, _) async {
              hostCalls += 1;
              throw const HttpException('{"error": "account sent north"}');
            },
            onJoinOnline: (_, _, _) async {},
            onEnterOnlineGame: () {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
          ),
        ),
      ),
    );

    await tester.tap(findAppText('ADD PLAYERS'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('P2 Online'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.bySemanticsLabel('P3 Hard'));
    await tester.tap(find.bySemanticsLabel('P3 Hard'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.bySemanticsLabel('P4 Hard'));
    await tester.tap(find.bySemanticsLabel('P4 Hard'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(findAppText('START ONLINE GAME'));
    await tester.tap(findAppText('START ONLINE GAME'));
    await tester.pump();

    expect(hostCalls, 1);
    expect(
      findAppText('Sent north: online play is locked for this account.'),
      findsOneWidget,
    );
    expect(
      findAppText('SENT NORTH: ONLINE PLAY IS LOCKED FOR THIS ACCOUNT.'),
      findsNothing,
    );

    await tester.tap(findAppText('START ONLINE GAME'));
    await tester.pump();

    expect(hostCalls, 2);
  });

  testWidgets('demo lobby locks setup while signed out', (tester) async {
    var presetChanges = 0;
    var controllerChanges = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 430,
          child: StandaloneLobby(
            tokens: lightDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.light,
            demoMode: true,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.custom,
            customVariants: KolkhozGameVariants.campStyle,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: false,
            onHostOnline: (_, controllers, enterImmediately, _, _) async =>
                'session',
            onJoinOnline: (_, _, _) async {},
            onEnterOnlineGame: () {},
            onPresetChanged: (_) => presetChanges += 1,
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) => controllerChanges += 1,
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
          ),
        ),
      ),
    );

    expect(
      findAppText('Demo mode: 2-year Kolkhoz with easy AI.'),
      findsNothing,
    );
    expect(findAppText('DEMO MODE'), findsOneWidget);
    expect(findAppText('2-year Kolkhoz with easy AI'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is PixelText && widget.text == '52 CARD DECK',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is PixelText && widget.text == '2 YEAR PLAN',
      ),
      findsOneWidget,
    );
    expect(KolkhozGameVariants.demoKolkhoz.wreckerCard, isTrue);

    await tester.tap(find.bySemanticsLabel('Little Kolkhoz'));
    await tester.pumpAndSettle();

    expect(presetChanges, 0);
    expect(controllerChanges, 0);
    expect(findAppText('MEDIUM'), findsNothing);
  });

  testWidgets('online lobby shows readable connection failures', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: StandaloneLobby(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: true,
            hostedInviteCode: 'ABCDE',
            onHostOnline: (_, _, _, _, _) async => 'session',
            onJoinOnline: (_, _, _) async {
              throw const SocketException('denied');
            },
            onEnterOnlineGame: () {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
          ),
        ),
      ),
    );

    expect(findAppText('YOUR INVITE CODE'), findsOneWidget);
    expect(findAppText('ABCDE'), findsOneWidget);
    expect(findAppText('COPY CODE'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.tap(findAppText('ASSIGN GAME'));
    await tester.pump();

    expect(
      findAppText('Could not reach the online server. Try again in a moment.'),
      findsOneWidget,
    );
    expect(find.textContaining('SocketException'), findsNothing);
  });

  testWidgets(
    'online lobby lists real server sessions instead of dummy games',
    (tester) async {
      final httpClient = FakeOnlineHttpClient();
      var matchmakeCalled = false;
      bool? matchmakeRankedOnly;
      bool? matchmakeComradesOnly;

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 844,
            height: 390,
            child: StandaloneLobby(
              tokens: defaultDesignTokens,
              language: KolkhozLanguage.en,
              appearance: KolkhozAppearance.dark,
              onStart: () {},
              selectedPreset: KolkhozGamePreset.kolkhoz,
              customVariants: KolkhozGameVariants.kolkhoz,
              playerControllers: KolkhozPlayerController.defaultControllers,
              showingRules: false,
              showingOnline: true,
              onHostOnline: (_, _, _, _, _) async => 'session',
              onJoinOnline: (_, _, _) async {},
              onMatchmakeOnline: (_, rankedOnly, comradesOnly) async {
                matchmakeCalled = true;
                matchmakeRankedOnly = rankedOnly;
                matchmakeComradesOnly = comradesOnly;
                return 'ABCDE';
              },
              onEnterOnlineGame: () {},
              onPresetChanged: (_) {},
              onCustomVariantsChanged: (_) {},
              onPlayerControllersChanged: (_) {},
              onRulesPressed: () {},
              onOfflinePressed: () {},
              onOnlinePressed: () {},
              onTutorialPressed: () {},
              onLanguageToggle: () {},
              onAppearanceToggle: () {},
              onlineClientFactory: () => KolkhozOnlineClient(
                Uri.parse('http://127.0.0.1:8080'),
                httpClient: httpClient,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp(r'Mira')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'ABCDE - Mira')), findsNothing);
      expect(findAppText('ABCDE'), findsNothing);
      expect(findAppText('16 Citizens Online'), findsOneWidget);
      expect(findAppText('Refresh in 15s'), findsOneWidget);
      expect(findAppText('RANKED'), findsNothing);
      expect(findAppText('COMRADES'), findsNothing);
      expect(find.byTooltip('Ranked'), findsOneWidget);
      expect(find.byTooltip('Casual'), findsOneWidget);
      expect(find.byTooltip('Comrade'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byTooltip('Casual'),
          matching: findAssetImage(
            'ios_resources/Icons/icon-foreman-misha.png',
          ),
        ),
        findsOneWidget,
      );
      expect(findAppText('1 open'), findsNothing);
      expect(find.textContaining('Learning Table'), findsNothing);
      expect(
        httpClient.requests.map((request) => request.route),
        contains('GET /sessions'),
      );

      await tester.tap(findAppText('ASSIGN GAME'));
      await tester.pump();

      expect(matchmakeCalled, isTrue);
      expect(matchmakeRankedOnly, isTrue);
      expect(matchmakeComradesOnly, isFalse);
    },
  );

  testWidgets('online lobby invite code entry changes assign action to join', (
    tester,
  ) async {
    final httpClient = EmptySessionsFakeOnlineHttpClient();
    String? joinedInviteCode;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: StandaloneLobby(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: true,
            onHostOnline: (_, _, _, _, _) async => 'session',
            onJoinOnline: (_, inviteCode, _) async {
              joinedInviteCode = inviteCode;
            },
            onMatchmakeOnline: (_, _, _) async => 'MATCH',
            onEnterOnlineGame: () {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
            onlineClientFactory: () => KolkhozOnlineClient(
              Uri.parse('http://127.0.0.1:8080'),
              httpClient: httpClient,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(findAppText('No open games'), findsOneWidget);
    expect(findAppText('16 Citizens Online'), findsOneWidget);
    expect(findAppText('Refresh in 15s'), findsOneWidget);
    expect(findAppText('ASSIGN GAME'), findsOneWidget);

    final inviteField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'INVITE CODE',
    );
    await tester.enterText(inviteField, 'abcde');
    await tester.pump();

    expect(findAppText('ASSIGN GAME'), findsNothing);
    expect(findAppText('JOIN GAME'), findsWidgets);

    await tester.tap(findAppText('JOIN GAME').last);
    await tester.pump();

    expect(joinedInviteCode, 'abcde');
  });

  testWidgets('online ban state disables the assign button', (tester) async {
    final httpClient = FakeOnlineHttpClient();
    var matchmakeCalls = 0;
    String? joinedInviteCode;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: StandaloneLobby(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: true,
            onHostOnline: (_, _, _, _, _) async => 'session',
            onJoinOnline: (_, inviteCode, _) async {
              joinedInviteCode = inviteCode;
            },
            onMatchmakeOnline: (_, _, _) async {
              matchmakeCalls += 1;
              throw const HttpException('{"error": "account sent north"}');
            },
            onEnterOnlineGame: () {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
            onlineClientFactory: () => KolkhozOnlineClient(
              Uri.parse('http://127.0.0.1:8080'),
              httpClient: httpClient,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp(r'Mira')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'ABCDE - Mira')), findsNothing);

    await tester.tap(findAppText('ASSIGN GAME'));
    await tester.pump();

    expect(matchmakeCalls, 1);
    expect(joinedInviteCode, isNull);
    expect(
      findAppText('SENT NORTH: ONLINE PLAY IS LOCKED FOR THIS ACCOUNT.'),
      findsOneWidget,
    );
    expect(
      findAppText('Sent north: online play is locked for this account.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'ABCDE - Mira')), findsNothing);

    await tester.tap(
      findAppText('SENT NORTH: ONLINE PLAY IS LOCKED FOR THIS ACCOUNT.'),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(matchmakeCalls, 1);
    expect(joinedInviteCode, isNull);

    final inviteField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'INVITE CODE',
    );
    await tester.enterText(inviteField, 'abcde');
    await tester.pump();

    expect(findAppText('JOIN GAME'), findsWidgets);
    expect(
      findAppText('SENT NORTH: ONLINE PLAY IS LOCKED FOR THIS ACCOUNT.'),
      findsNothing,
    );
    expect(
      findAppText('Sent north: online play is locked for this account.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'ABCDE - Mira')), findsNothing);

    await tester.tap(findAppText('JOIN GAME').last);
    await tester.pump();

    expect(matchmakeCalls, 1);
    expect(joinedInviteCode, 'abcde');
  });

  testWidgets('online ban state hides the public game browser', (tester) async {
    final httpClient = BannedSessionsFakeOnlineHttpClient();
    String? joinedInviteCode;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: StandaloneLobby(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: true,
            onHostOnline: (_, _, _, _, _) async => 'session',
            onJoinOnline: (_, inviteCode, _) async {
              joinedInviteCode = inviteCode;
            },
            onMatchmakeOnline: (_, _, _) async => 'MATCH',
            onEnterOnlineGame: () {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
            onlineClientFactory: () => KolkhozOnlineClient(
              Uri.parse('http://127.0.0.1:8080'),
              httpClient: httpClient,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp(r'ABCDE - Mira')), findsNothing);
    expect(
      findAppText('Sent north: online play is locked for this account.'),
      findsOneWidget,
    );
    expect(
      findAppText('SENT NORTH: ONLINE PLAY IS LOCKED FOR THIS ACCOUNT.'),
      findsOneWidget,
    );

    final inviteField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'INVITE CODE',
    );
    await tester.enterText(inviteField, 'abcde');
    await tester.pump();
    await tester.tap(findAppText('JOIN GAME').last);
    await tester.pump();

    expect(joinedInviteCode, 'abcde');
  });

  testWidgets('online waiting room holds joined players through countdown', (
    tester,
  ) async {
    var enterCalls = 0;
    var cancelCalls = 0;
    int? kickedPlayerID;
    final updateJson = onlineUpdateJson();
    updateJson['started'] = false;
    updateJson['controllers'] = ['human', 'human', 'human', 'neuralAI'];
    updateJson['playerProfiles'] = [
      {
        'playerID': 0,
        'userID': '11111111-1111-1111-1111-111111111111',
        'displayName': 'Mira',
        'avatarURL': 'worker3',
        'stats': {'rating': 1110},
      },
      {
        'playerID': 1,
        'userID': '22222222-2222-4222-8222-222222222222',
        'displayName': 'Nadia',
        'avatarURL': 'worker2',
        'stats': {'rating': 980},
      },
    ];
    updateJson['seatPresence'] = [
      {'playerID': 0, 'connected': true},
      {'playerID': 1, 'connected': true},
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: StandaloneLobby(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: true,
            hostedInviteCode: 'ABCDE',
            onlineSessionUpdate: OnlineSessionUpdate.fromJson(updateJson),
            showHostedInviteCode: true,
            onHostOnline: (_, _, _, _, _) async => 'session',
            onJoinOnline: (_, _, _) async {},
            onKickOnlinePlayer: (playerID) async => kickedPlayerID = playerID,
            onEnterOnlineGame: () => enterCalls += 1,
            onCancelOnlineGame: () => cancelCalls += 1,
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
          ),
        ),
      ),
    );

    expect(findAppText('YOUR INVITE CODE'), findsOneWidget);
    expect(findAppText('ABCDE'), findsWidgets);
    expect(findAppText('Mira'), findsOneWidget);
    expect(findAppText('Nadia'), findsOneWidget);
    expect(find.textContaining('Searching for Player'), findsOneWidget);
    expect(findAppText('KICK'), findsOneWidget);
    expect(find.byKey(const Key('online-waiting-cancel')), findsOneWidget);
    expect(find.bySemanticsLabel('Waiting for players'), findsWidgets);

    await tester.tap(find.byKey(const Key('online-waiting-cancel')));
    await tester.pump();

    expect(cancelCalls, 1);

    await tester.tap(findAppText('KICK'));
    await tester.pump();

    expect(kickedPlayerID, 1);

    updateJson['playerProfiles'] = [
      ...(updateJson['playerProfiles'] as List<Object?>),
      {
        'playerID': 2,
        'userID': '33333333-3333-4333-8333-333333333333',
        'displayName': 'Oksana',
        'avatarURL': 'worker3',
        'stats': {'rating': 990},
      },
    ];
    updateJson['lobbyCountdownEndsAt'] =
        DateTime.now().millisecondsSinceEpoch / 1000 + 30;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: StandaloneLobby(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: true,
            hostedInviteCode: 'ABCDE',
            onlineSessionUpdate: OnlineSessionUpdate.fromJson(updateJson),
            showHostedInviteCode: true,
            onHostOnline: (_, _, _, _, _) async => 'session',
            onJoinOnline: (_, _, _) async {},
            onKickOnlinePlayer: (playerID) async => kickedPlayerID = playerID,
            onEnterOnlineGame: () => enterCalls += 1,
            onCancelOnlineGame: () => cancelCalls += 1,
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () {},
            onAppearanceToggle: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Game starts in'), findsWidgets);
    expect(find.byKey(const Key('waiting-room-countdown')), findsOneWidget);
    expect(find.byKey(const Key('waiting-room-enter-game')), findsNothing);
    expect(enterCalls, 0);
  });

  testWidgets('tutorial walkthrough advances, backs up, and closes', (
    tester,
  ) async {
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: TutorialWalkthroughOverlay(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            onClose: () => closed = true,
          ),
        ),
      ),
    );

    expect(findAppText('WELCOME TO THE COLLECTIVE'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-dot-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-next')));
    await tester.pump();
    expect(findAppText('READ THE WORK BOARD'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-back')));
    await tester.pump();
    expect(findAppText('WELCOME TO THE COLLECTIVE'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-close')));
    expect(closed, isTrue);
  });

  testWidgets('tutorial auto-advances when the live game satisfies a step', (
    tester,
  ) async {
    Widget wrap(TableViewModel model) => MaterialApp(
      home: SizedBox(
        width: 844,
        height: 390,
        child: TutorialWalkthroughOverlay(
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          onClose: () {},
          model: model,
        ),
      ),
    );

    // Base model: trump chosen, trick phase, no cards played yet.
    await tester.pumpWidget(wrap(runtimeModel()));

    // Step through to the "play a card" step, which waits on cardPlayed.
    for (var taps = 0; taps < 3; taps += 1) {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
    }
    expect(findAppText('PLAY A CARD'), findsOneWidget);

    // A card lands on the table: the step should advance on its own.
    await tester.pumpWidget(wrap(runtimeModelWithTrickPlay()));
    await tester.pump();
    expect(findAppText('TAKING THE TRICK'), findsOneWidget);

    // Let the celebration flash timer finish so no timers are pending.
    await tester.pump(const Duration(milliseconds: 1700));
  });

  testWidgets('tutorial collapses out of the way while a play is pending', (
    tester,
  ) async {
    Widget wrap(TableViewModel model) => MaterialApp(
      home: SizedBox(
        width: 844,
        height: 390,
        child: TutorialWalkthroughOverlay(
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          onClose: () {},
          model: model,
        ),
      ),
    );

    await tester.pumpWidget(wrap(runtimeModel()));
    expect(findAppText('WELCOME TO THE COLLECTIVE'), findsOneWidget);

    // Selecting a trick card folds the panel into the corner badge.
    await tester.pumpWidget(wrap(runtimeModelWithSelectedHandCard()));
    await tester.pump();
    expect(findAppText('WELCOME TO THE COLLECTIVE'), findsNothing);
    expect(find.byKey(const Key('tutorial-expand')), findsOneWidget);

    // The badge can be re-opened manually.
    await tester.tap(find.byKey(const Key('tutorial-expand')));
    await tester.pump();
    expect(findAppText('WELCOME TO THE COLLECTIVE'), findsOneWidget);

    // Clearing the pending play keeps the panel open.
    await tester.pumpWidget(wrap(runtimeModel()));
    await tester.pump();
    expect(findAppText('WELCOME TO THE COLLECTIVE'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-expand')), findsNothing);
  });

  testWidgets('tutorial walkthrough done closes on final step', (tester) async {
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: TutorialWalkthroughOverlay(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            onClose: () => closed = true,
            steps: const [
              TutorialStepContent(
                titleKey: KolkhozText.tutorialStep1Title,
                bodyKey: KolkhozText.tutorialStep1Body,
                tipKey: KolkhozText.tutorialStep1Tip,
                calloutKey: KolkhozText.tutorialStep1Callout,
                iconPath: 'ios_resources/Icons/icon-tutorial.png',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tutorial-next')));
    expect(closed, isTrue);
  });

  testWidgets('tutorial walkthrough follows selected language', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: TutorialWalkthroughOverlay(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.ru,
            onClose: () {},
          ),
        ),
      ),
    );

    expect(findAppText('ДОБРО ПОЖАЛОВАТЬ В КОЛХОЗ'), findsOneWidget);
    expect(find.textContaining('Это настоящая игра, товарищ'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ChromeScaledLabel && widget.text == 'Далее',
      ),
      findsOneWidget,
    );
  });

  test('board content width caps extra-wide desktop layouts', () {
    expect(boardPlayableContentWidth(900), 900);
    expect(boardPlayableContentWidth(1800), boardContentWidthMax);
  });

  test('compact board shell is portrait-only', () {
    expect(
      shouldUseCompactBoardShell(contentWidth: 430, contentHeight: 760),
      isTrue,
    );
    expect(
      shouldUseCompactBoardShell(contentWidth: 667, contentHeight: 375),
      isFalse,
    );
  });

  testWidgets('narrow board uses compact grid and bottom toolbar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: KolkhozBoard(
          model: runtimeModel(),
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          appearance: KolkhozAppearance.dark,
        ),
      ),
    );

    expect(find.byType(CompactBoardShell), findsOneWidget);
    expect(find.byType(BoardRail), findsNothing);
    expect(find.byType(CompactBoardToolbar), findsOneWidget);
    expect(find.byType(BrigadePlayerColumn), findsNWidgets(4));
    expect(
      tester.getSize(find.byType(CompactBoardToolbar)).height,
      compactBoardToolbarCollapsedHeight,
    );

    await tester.tap(find.byKey(const Key('compact-toolbar-resize-handle')));
    await tester.pump();

    expect(
      tester.getSize(find.byType(CompactBoardToolbar)).height,
      compactBoardToolbarExpandedHeight,
    );
  });

  testWidgets('landscape phone keeps the side rail layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(667, 375));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: KolkhozBoard(
          model: runtimeModel(),
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          appearance: KolkhozAppearance.dark,
        ),
      ),
    );

    expect(find.byType(CompactBoardShell), findsNothing);
    expect(find.byType(CompactBoardToolbar), findsNothing);
    expect(find.byType(BoardRail), findsOneWidget);
  });

  testWidgets('player portrait expands in-game player info in place', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KolkhozBoard(
          model: runtimeModel(),
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          appearance: KolkhozAppearance.dark,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('player-portrait-0-inspect')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const Key('player-info-panel-0')), findsOneWidget);
    expect(findAppText('PLAYER'), findsOneWidget);
    expect(findAppText('SCORE'), findsOneWidget);
    expect(findAppText('HAND'), findsOneWidget);
  });

  test('brigade display helpers project column geometry', () {
    final spacing = brigadeColumnSpacing(1200);
    expect(spacing, 14);
    expect(
      brigadeExpandedColumnWidth(
        maxWidth: 1200,
        columnCount: 4,
        spacing: spacing,
      ),
      closeTo(289.5, 0.0001),
    );
    expect(brigadeColumnHeight(640), 632);
    expect(brigadeColumnContentWidth(289.5), 273.5);
    expect(brigadePlayerPanelWidth(289.5), 273.5);
    expect(brigadePlayerPanelHeight(273.5), closeTo(106.6324, 0.0001));
    expect(
      brigadePlayObjectWidth(columnWidth: 289.5, minWidth: 70),
      closeTo(246.15, 0.0001),
    );
    expect(brigadePlayObjectHeight(100, 1.42), 142);
    expect(
      brigadeContentColumnHeight(
        playerPanelHeight: 106.6324,
        playObjectHeight: 349.533,
      ),
      closeTo(480.1654, 0.0001),
    );
    expect(
      brigadePanelHeightForWidth(
        maxWidth: 1200,
        columnCount: 4,
        minCardWidth: 70,
        cardAspectRatio: 1.42,
      ),
      closeTo(488.1654, 0.0001),
    );
    expect(
      brigadePlayObjectMaxHeight(360, 106.6324),
      closeTo(229.3676, 0.0001),
    );
    expect(
      brigadePlayObjectFittingWidth(
        desiredWidth: 246.15,
        maxHeight: 229.3676,
        aspectRatio: 1.42,
      ),
      closeTo(161.5265, 0.0001),
    );
  });

  test('phase display helpers provide UI labels without engine projection', () {
    final model = runtimeModel();
    expect(hotSeatPhaseLine(model), 'Year 1 - Trick');
    expect(
      hotSeatPhaseLine(model, language: KolkhozLanguage.ru),
      'Год 1 - Взятка',
    );
  });

  test('card art display helpers project asset paths and pip positions', () {
    final jack = testCard(id: 'wheat-11', suit: 'wheat', value: 11, rank: 'J');
    final queen = testCard(id: 'beet-12', suit: 'beet', value: 12, rank: 'Q');
    final nomenklaturaQueen = testCard(
      id: 'beet-12',
      suit: 'beet',
      value: 12,
      rank: 'Q',
      nomenclature: true,
    );
    final wrecker = testCard(
      id: 'wrecker-14',
      suit: wreckerSuit,
      value: 14,
      rank: 'S',
    );
    final seat = testSeat(id: 0, name: 'You');

    expect(faceRankName(jack), 'jack');
    expect(cardRankDisplayLabel(jack), 'J 11');
    expect(cardRankDisplayLabel(queen), 'Q 12');
    expect(
      cardRankDisplayLabel(testCard(id: 'wheat-10', suit: 'wheat', value: 10)),
      '10',
    );
    expect(faceAssetPath(jack), 'ios_resources/Cards/face-jack-wheat.png');
    expect(
      faceAssetPath(nomenklaturaQueen),
      'ios_resources/Cards/face-queen-beet-nomenklatura.png',
    );
    expect(genericFaceAssetPath(queen), 'ios_resources/Cards/face-queen.png');
    expect(faceRankName(wrecker), 'saboteur');
    expect(cardRankDisplayLabel(wrecker), 'S 14');
    expect(faceArtWidth(defaultDesignTokens.card.large), 31.5);
    expect(facePortraitArtWidth(jack, defaultDesignTokens.card.large), 63);
    expect(
      facePortraitArtWidth(wrecker, defaultDesignTokens.card.large),
      40.95,
    );
    expect(faceAssetPath(wrecker), 'ios_resources/Cards/face-wrecker.png');
    expect(
      genericFaceAssetPath(wrecker),
      'ios_resources/Cards/face-wrecker.png',
    );
    expect(portraitAssetPath(seat), 'ios_resources/worker1.png');
    expect(
      cardTemplateAssetPath(
        card: jack,
        tokens: defaultDesignTokens,
        trump: 'wheat',
      ),
      'ios_resources/Cards/card-template-dark.png',
    );
    expect(
      cardTemplateAssetPath(
        card: jack,
        tokens: lightDesignTokens,
        trump: 'beet',
      ),
      'ios_resources/Cards/card-template-light-no-overlay.png',
    );
    expect(
      cardTemplateAssetPath(
        card: jack,
        tokens: defaultDesignTokens,
        trump: null,
      ),
      'ios_resources/Cards/card-template-dark-no-overlay.png',
    );
    expect(cardUsesTrumpTemplate(card: wrecker, trump: 'beet'), isTrue);
    expect(
      cardTemplateAssetPath(
        card: wrecker,
        tokens: lightDesignTokens,
        trump: null,
      ),
      'ios_resources/Cards/card-template-light-no-overlay.png',
    );
    expect(pipPositions(12), hasLength(10));
    expect(
      pixelTextSizeForCardRank(defaultDesignTokens.card.small),
      PixelTextSize.xSmall,
    );
    expect(
      pixelTextSizeForCardRank(defaultDesignTokens.card.large),
      PixelTextSize.cardRank,
    );
    expect(pixelTextScaleForCardRank(defaultDesignTokens.card.large), 1);
    expect(
      pixelTextSizeForCardFaceValue(defaultDesignTokens.card.large),
      PixelTextSize.caption2,
    );
    expect(cardCornerHorizontalInset(defaultDesignTokens.card.large), 0);
    expect(
      cardTopCornerVerticalInset(defaultDesignTokens.card.large),
      closeTo(-0.5964, 0.001),
    );
    expect(cardBottomCornerVerticalInset(defaultDesignTokens.card.large), 0);
    expect(
      cardFaceValueRankGap(defaultDesignTokens.card.large),
      closeTo(3.84, 0.001),
    );
    expect(
      cardCornerRankSuitGap(defaultDesignTokens.card.large),
      closeTo(0.1, 0.001),
    );
    expect(
      cardBottomCornerRankSuitGap(defaultDesignTokens.card.large),
      closeTo(0.8, 0.001),
    );
    expect(
      cardCornerSuitOutwardOffset(defaultDesignTokens.card.large),
      closeTo(1.2, 0.001),
    );
    expect(
      cardCornerSuitVisualSize(jack, defaultDesignTokens.card.large),
      closeTo(11, 0.001),
    );
    expect(
      cardCornerSuitVisualSize(wrecker, defaultDesignTokens.card.large),
      closeTo(16.5, 0.001),
    );
    expect(
      cardCornerSuitTowardRankOffset(defaultDesignTokens.card.large),
      closeTo(2.5, 0.001),
    );
    expect(
      cardBottomCornerRankDownOffset(defaultDesignTokens.card.large),
      closeTo(2, 0.001),
    );
    expect(
      cardCornerRankVisualHeight(defaultDesignTokens.card.large),
      closeTo(28, 0.001),
    );
    final oversizedCard = scaledHandTrayCardSize(
      defaultDesignTokens.card.large,
      404,
    );
    expect(pixelTextSizeForCardRank(oversizedCard), PixelTextSize.cardRank);
    expect(pixelTextScaleForCardRank(oversizedCard), cardRankTextMaxScale);
    expect(cardCornerRankVisualHeight(oversizedCard), closeTo(40.6, 0.001));
  });

  test('panel title display helpers scale and fade predictably', () {
    expect(panelTitleScale(100), panelTitleScaleMin);
    expect(panelTitleScale(520), 1);
    expect(panelTitleIconSize(520), panelTitleIconSizeBase);
    expect(panelTitleHorizontalPadding(260), 9 * panelTitleScaleMin);
    expect(panelTitleOrnamentOpacity(300, urgent: false), 0);
    expect(panelTitleOrnamentOpacity(520, urgent: false), 0.52);
    expect(panelTitleOrnamentOpacity(520, urgent: true), 0.42);
  });

  test('hot seat display helpers clamp size and choose local player', () {
    final base = runtimeModel();
    final remoteCurrentModel = TableViewModel(
      viewer: base.viewer,
      table: TableState(
        year: base.table.year,
        phase: base.table.phase,
        phasePrompt: base.table.phasePrompt,
        currentPlayerID: 1,
        trump: base.table.trump,
        isFamine: base.table.isFamine,
        maxTricks: base.table.maxTricks,
        seats: [
          testSeat(id: 0, name: 'Local', controller: controllerHuman),
          testSeat(id: 1, name: 'Remote', controller: controllerRemoteHuman),
          testSeat(id: 2, name: 'AI'),
          testSeat(id: 3, name: 'AI 2'),
        ],
        jobs: base.table.jobs,
        trick: base.table.trick,
        lastTrick: base.table.lastTrick,
        requisitionEvents: base.table.requisitionEvents,
        exiledByYear: base.table.exiledByYear,
        scoreboard: base.table.scoreboard,
        gameResult: base.table.gameResult,
      ),
      panels: base.panels,
      selection: base.selection,
      legalActions: base.legalActions,
    );

    expect(hotSeatPanelWidth(100), hotSeatPanelMinWidth);
    expect(hotSeatPanelWidth(1000), hotSeatPanelMaxWidth);
    expect(hotSeatPortraitSlotSize(100), hotSeatPortraitMinSize);
    expect(hotSeatPortraitSlotSize(1000), hotSeatPortraitMaxSize);
    expect(hotSeatPrivacyPlayer(remoteCurrentModel).id, 0);
  });

  test('selected swap action requires exact hand plot and zone match', () {
    final selection = SelectionState.empty.copyWith(
      handCardID: 'wheat-7',
      plotCardID: 'beet-10',
      plotZone: plotZoneHidden,
    );

    expect(isSelectedSwapAction(selection, swapAction()), isTrue);
    expect(
      isSelectedSwapAction(
        selection.copyWith(clearHandCardID: true),
        swapAction(),
      ),
      isFalse,
    );
    expect(
      isSelectedSwapAction(
        selection,
        swapAction(plotCard: const EngineCardValue(suit: 3, value: 11)),
      ),
      isFalse,
    );
    expect(isSelectedSwapAction(selection, swapAction(plotZone: 1)), isFalse);
  });

  test('engine action exposure follows viewer seat instead of seat zero', () {
    expect(
      shouldExposeActionForViewer(
        action: playAction(playerID: 2),
        selection: SelectionState.empty,
        viewerSeatID: 2,
      ),
      isTrue,
    );
    expect(
      shouldExposeActionForViewer(
        action: playAction(playerID: 0),
        selection: SelectionState.empty,
        viewerSeatID: 2,
      ),
      isFalse,
    );
    expect(
      shouldExposeActionForViewer(
        action: const CEngineActionValue(
          kind: kcActionContinueAfterRequisition,
          playerID: -1,
          suit: -1,
          card: EngineCardValue(suit: -1, value: 0),
          handCard: EngineCardValue(suit: -1, value: 0),
          plotCard: EngineCardValue(suit: -1, value: 0),
          plotZone: -1,
          targetSuit: -1,
        ),
        selection: SelectionState.empty,
        viewerSeatID: 2,
      ),
      isTrue,
    );
  });

  test('raw engine actions drive swap and play card affordances', () {
    final actions = [
      playAction(card: const EngineCardValue(suit: 1, value: 12)),
      swapAction(),
      swapAction(
        handCard: const EngineCardValue(suit: 2, value: 8),
        plotCard: const EngineCardValue(suit: 0, value: 9),
        plotZone: 1,
      ),
      swapAction(
        handCard: const EngineCardValue(suit: 3, value: 6),
        plotCard: const EngineCardValue(suit: 2, value: 11),
        plotZone: 0,
      ),
    ];

    expect(handActionCardIDs(actions, 0), {
      'sunflower-12',
      'wheat-7',
      'potato-8',
      'beet-6',
    });
    expect(plotActionCardIDs(actions, plotZoneHidden), {
      'beet-10',
      'potato-11',
    });
    expect(plotActionCardIDs(actions, plotZoneHidden, playerID: 0), {
      'beet-10',
      'potato-11',
    });
    expect(plotActionCardIDs(actions, plotZoneHidden, playerID: 1), isEmpty);
    expect(plotActionCardIDs(actions, plotZoneRevealed), {'wheat-9'});
  });
}

CEngineActionValue swapAction({
  EngineCardValue handCard = const EngineCardValue(suit: 0, value: 7),
  EngineCardValue plotCard = const EngineCardValue(suit: 3, value: 10),
  int plotZone = 0,
}) {
  return CEngineActionValue(
    kind: kcActionSwap,
    playerID: 0,
    suit: -1,
    card: const EngineCardValue(suit: -1, value: 0),
    handCard: handCard,
    plotCard: plotCard,
    plotZone: plotZone,
    targetSuit: -1,
  );
}

CEngineActionValue playAction({
  int playerID = 0,
  EngineCardValue card = const EngineCardValue(suit: 0, value: 7),
}) {
  return CEngineActionValue(
    kind: kcActionPlayCard,
    playerID: playerID,
    suit: -1,
    card: card,
    handCard: const EngineCardValue(suit: -1, value: 0),
    plotCard: const EngineCardValue(suit: -1, value: 0),
    plotZone: -1,
    targetSuit: -1,
  );
}

TableViewModel runtimeModel() {
  final seats = [
    testSeat(id: 0, name: 'You', isViewer: true, isCurrentTurn: true),
    testSeat(id: 1, name: 'Bot 1'),
    testSeat(id: 2, name: 'Bot 2'),
    testSeat(id: 3, name: 'Bot 3'),
  ];
  return TableViewModel(
    viewer: const Viewer(seatID: 0, privacyMode: viewerPrivacyNone),
    table: TableState(
      year: 1,
      phase: phaseTrick,
      phasePrompt: const Prompt(
        title: 'Play',
        body: 'Play a card to the current trick.',
      ),
      currentPlayerID: 0,
      trump: 'wheat',
      isFamine: false,
      maxTricks: 4,
      seats: seats,
      jobs: const [
        Job(
          suit: 'wheat',
          hours: 0,
          requiredHours: jobRequiredHours,
          claimed: false,
          reward: null,
          assignedCards: [],
          validAssignmentTarget: false,
          highlighted: false,
        ),
        Job(
          suit: 'sunflower',
          hours: 0,
          requiredHours: jobRequiredHours,
          claimed: false,
          reward: null,
          assignedCards: [],
          validAssignmentTarget: false,
          highlighted: false,
        ),
        Job(
          suit: 'potato',
          hours: 0,
          requiredHours: jobRequiredHours,
          claimed: false,
          reward: null,
          assignedCards: [],
          validAssignmentTarget: false,
          highlighted: false,
        ),
        Job(
          suit: 'beet',
          hours: 0,
          requiredHours: jobRequiredHours,
          claimed: false,
          reward: null,
          assignedCards: [],
          validAssignmentTarget: false,
          highlighted: false,
        ),
      ],
      trick: const Trick(plays: [], winnerSeatID: null),
      lastTrick: const Trick(plays: [], winnerSeatID: null),
      requisitionEvents: const [],
      exiledByYear: {
        for (var year = 1; year <= finalGameYear; year++) year: const [],
      },
      scoreboard: [
        for (var seatID = 0; seatID < kolkhozPlayerCount; seatID++)
          Score(seatID: seatID, visibleScore: 0, finalScore: null),
      ],
      gameResult: null,
    ),
    panels: const Panels(active: panelBrigade, available: availableGamePanels),
    selection: const SelectionState(
      handCardID: null,
      plotCardID: null,
      plotZone: null,
      assignmentCardID: null,
    ),
    legalActions: [],
  );
}

TableViewModel assignmentModel({required String? selectedCardID}) {
  return runtimeModelWith(
    phase: phaseAssignment,
    selection: SelectionState.empty.copyWith(
      assignmentCardID: selectedCardID,
      clearAssignmentCardID: selectedCardID == null,
    ),
    jobs: const [
      Job(
        suit: 'wheat',
        hours: 0,
        requiredHours: jobRequiredHours,
        claimed: false,
        reward: null,
        assignedCards: [],
        validAssignmentTarget: true,
        highlighted: false,
      ),
      Job(
        suit: 'sunflower',
        hours: 0,
        requiredHours: jobRequiredHours,
        claimed: false,
        reward: null,
        assignedCards: [],
        validAssignmentTarget: true,
        highlighted: false,
      ),
      Job(
        suit: 'potato',
        hours: 0,
        requiredHours: jobRequiredHours,
        claimed: false,
        reward: null,
        assignedCards: [],
        validAssignmentTarget: false,
        highlighted: false,
      ),
      Job(
        suit: 'beet',
        hours: 0,
        requiredHours: jobRequiredHours,
        claimed: false,
        reward: null,
        assignedCards: [],
        validAssignmentTarget: false,
        highlighted: false,
      ),
    ],
    legalActions: [
      testLegalAction(
        kind: actionAssign,
        label: 'Assign',
        engineAction: const EngineAction(
          kind: actionAssign,
          playerID: 0,
          card: EngineCard(suit: 'wheat', value: 9),
          targetSuit: 'wheat',
        ),
      ),
      testLegalAction(
        kind: actionAssign,
        label: 'Assign',
        engineAction: const EngineAction(
          kind: actionAssign,
          playerID: 0,
          card: EngineCard(suit: 'wheat', value: 9),
          targetSuit: 'sunflower',
        ),
      ),
    ],
  );
}

TableViewModel runtimeModelWith({
  required String phase,
  required SelectionState selection,
  required List<Job> jobs,
  int? year,
  GameResult? gameResult,
  int? currentPlayerID,
  List<Seat>? seats,
  Trick? trick,
  Trick? lastTrick,
  List<LegalAction>? legalActions,
}) {
  final base = runtimeModel();
  return TableViewModel(
    viewer: base.viewer,
    table: TableState(
      year: year ?? base.table.year,
      phase: phase,
      phasePrompt: base.table.phasePrompt,
      currentPlayerID: currentPlayerID ?? base.table.currentPlayerID,
      trump: base.table.trump,
      isFamine: base.table.isFamine,
      maxTricks: base.table.maxTricks,
      seats: seats ?? base.table.seats,
      jobs: jobs,
      trick: trick ?? base.table.trick,
      lastTrick: lastTrick ?? base.table.lastTrick,
      requisitionEvents: base.table.requisitionEvents,
      exiledByYear: base.table.exiledByYear,
      scoreboard: base.table.scoreboard,
      gameResult: gameResult ?? base.table.gameResult,
    ),
    panels: base.panels,
    selection: selection,
    legalActions: legalActions ?? base.legalActions,
  );
}

Seat seatWithHand(Seat seat, List<TableCard> hand) {
  return Seat(
    id: seat.id,
    name: seat.name,
    controller: seat.controller,
    portraitAsset: seat.portraitAsset,
    isViewer: seat.isViewer,
    isCurrentTurn: seat.isCurrentTurn,
    isBrigadeLeader: seat.isBrigadeLeader,
    hand: hand,
    hiddenHandCount: seat.hiddenHandCount,
    plot: seat.plot,
    medals: seat.medals,
    visibleScore: seat.visibleScore,
    statusText: seat.statusText,
  );
}

Seat seatWithController(Seat seat, {required String controller}) {
  return Seat(
    id: seat.id,
    name: seat.name,
    controller: controller,
    portraitAsset: seat.portraitAsset,
    isViewer: seat.isViewer,
    isCurrentTurn: seat.isCurrentTurn,
    isBrigadeLeader: seat.isBrigadeLeader,
    hand: seat.hand,
    hiddenHandCount: seat.hiddenHandCount,
    plot: seat.plot,
    medals: seat.medals,
    visibleScore: seat.visibleScore,
    statusText: seat.statusText,
  );
}

TableViewModel runtimeModelWithSelectedHandCard() {
  return runtimeModelWith(
    phase: phaseTrick,
    selection: const SelectionState(
      handCardID: 'wheat-9',
      plotCardID: null,
      plotZone: null,
      assignmentCardID: null,
    ),
    jobs: runtimeModel().table.jobs,
  );
}

TableViewModel runtimeModelWithTrickPlay() {
  return runtimeModelWith(
    phase: phaseTrick,
    selection: SelectionState.empty,
    jobs: runtimeModel().table.jobs,
    lastTrick: const Trick(
      plays: [
        TrickPlay(
          seatID: 0,
          card: TableCard(
            id: 'wheat-9',
            suit: 'wheat',
            value: 9,
            rank: '9',
            selected: false,
            highlighted: false,
            pending: false,
          ),
        ),
      ],
      winnerSeatID: null,
    ),
  );
}

Seat testSeat({
  required int id,
  required String name,
  String? controller,
  bool isViewer = false,
  bool isCurrentTurn = false,
}) {
  return Seat(
    id: id,
    name: name,
    controller:
        controller ?? (id == 0 ? controllerHuman : controllerHeuristicAI),
    portraitAsset: 'worker${id + 1}',
    isViewer: isViewer,
    isCurrentTurn: isCurrentTurn,
    isBrigadeLeader: false,
    hand: id == 0
        ? const [
            TableCard(
              id: 'wheat-11',
              suit: 'wheat',
              value: 11,
              rank: 'J',
              selected: false,
              highlighted: false,
              pending: false,
            ),
          ]
        : const [],
    hiddenHandCount: id == 0 ? 0 : 1,
    plot: const PlotState(revealed: [], hidden: [], stacks: []),
    medals: 0,
    visibleScore: 0,
  );
}

Seat seatWithPlot(Seat seat, PlotState plot) {
  return Seat(
    id: seat.id,
    name: seat.name,
    controller: seat.controller,
    portraitAsset: seat.portraitAsset,
    isViewer: seat.isViewer,
    isCurrentTurn: seat.isCurrentTurn,
    isBrigadeLeader: seat.isBrigadeLeader,
    hand: seat.hand,
    hiddenHandCount: seat.hiddenHandCount,
    plot: plot,
    medals: seat.medals,
    visibleScore: seat.visibleScore,
    statusText: seat.statusText,
  );
}

TableCard testCard({
  required String id,
  required String suit,
  required int value,
  String? rank,
  bool pending = false,
  int? assignmentRound,
  bool nomenclature = false,
}) {
  return TableCard(
    id: id,
    suit: suit,
    value: value,
    rank: rank ?? '$value',
    selected: false,
    highlighted: false,
    pending: pending,
    assignmentRound: assignmentRound,
    nomenclature: nomenclature,
  );
}

LegalAction testLegalAction({
  required String kind,
  required String label,
  EngineAction? engineAction,
}) {
  return LegalAction(
    kind: kind,
    label: label,
    engineAction: engineAction ?? EngineAction(kind: kind, playerID: 0),
  );
}

Finder findAssetImage(String assetName) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == assetName,
  );
}

class _CardMotionTestBoard extends StatelessWidget {
  const _CardMotionTestBoard({required this.model});

  final TableViewModel model;

  @override
  Widget build(BuildContext context) {
    final hand = model.table.seats[0].hand;
    final trick = model.table.trick.plays;
    final handCard = hand.isEmpty ? null : hand.first;
    final trickPlay = trick.isEmpty ? null : trick.first;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 24,
          top: 208,
          child: MotionTrackedRegion(
            motionKey: playerCardMotionSourceKey(2),
            child: const SizedBox(width: 96, height: 42),
          ),
        ),
        if (handCard != null)
          Positioned(
            left: 24,
            top: 24,
            child: GameCard(
              card: handCard,
              tokens: defaultDesignTokens,
              trump: model.table.trump,
              sizeOverride: defaultDesignTokens.card.small,
            ),
          ),
        if (trickPlay != null)
          Positioned(
            left: 260,
            top: 96,
            child: GameCard(
              card: trickPlay.card,
              tokens: defaultDesignTokens,
              trump: model.table.trump,
              sizeOverride: defaultDesignTokens.card.small,
            ),
          ),
      ],
    );
  }
}

Map<String, Object?> onlineUpdateJson({int viewerID = 0}) {
  return {
    'sessionID': '11111111-1111-1111-1111-111111111111',
    'inviteCode': 'ABCDE',
    'viewerID': viewerID,
    'actionLogCount': 0,
    'isViewerTurn': true,
    'legalActions': [
      const OnlineEngineAction(
        kind: kcActionSetTrump,
        playerID: 0,
        suit: 0,
      ).toJson(),
    ],
    'variants': variantsToJson(KolkhozGameVariants.kolkhoz),
    'controllers': ['human', 'human', 'heuristicAI', 'neuralAI'],
    'snapshot': {
      'year': 1,
      'phase': kcPhasePlanning,
      'currentPlayer': 0,
      'waitingPlayer': 0,
      'waitingForExternalAction': true,
      'lead': 0,
      'trumpSelector': 0,
      'trump': -1,
      'trickCount': 0,
      'isFamine': false,
      'players': [
        onlinePlayerJson(
          id: 0,
          hand: [onlineCardJson(0, 13)],
          hiddenPlot: [onlineCardJson(1, 7)],
        ),
        onlinePlayerJson(id: 1),
        onlinePlayerJson(id: 2),
        onlinePlayerJson(id: 3),
      ],
      'jobPiles': onlineSuitCardsJson(),
      'revealedJobs': onlineSuitCardsJson(
        cardsBySuit: {
          0: [onlineCardJson(0, 9)],
        },
      ),
      'claimedJobs': <int>[],
      'workHours': [
        for (var suit = 0; suit < 4; suit++) {'suit': suit, 'value': 0},
      ],
      'jobBuckets': onlineSuitCardsJson(),
      'accumulatedJobCards': onlineSuitCardsJson(),
      'currentTrick': <Object?>[],
      'lastTrick': <Object?>[],
      'lastWinner': -1,
      'exiled': onlineSuitCardsJson(count: 6),
      'pendingAssignments': <Object?>[],
      'requisitionEvents': <Object?>[],
      'scores': [
        for (var playerID = 0; playerID < kolkhozPlayerCount; playerID++)
          {
            'playerID': playerID,
            'visibleScore': playerID,
            'finalScore': playerID,
          },
      ],
      'winnerID': -1,
      'swapConfirmed': <int>[],
      'swapCount': <int>[],
    },
  };
}

Map<String, Object?> onlinePlayerJson({
  required int id,
  List<Map<String, Object?>> hand = const [],
  List<Map<String, Object?>> revealedPlot = const [],
  List<Map<String, Object?>> hiddenPlot = const [],
}) {
  return {
    'id': id,
    'hand': hand,
    'revealedPlot': revealedPlot,
    'hiddenPlot': hiddenPlot,
    'medals': 0,
    'bankedMedals': 0,
    'brigadeLeader': id == 0,
    'wonTrickThisYear': false,
    'stacks': <Object?>[],
  };
}

List<Map<String, Object?>> onlineSuitCardsJson({
  int count = 4,
  Map<int, List<Map<String, Object?>>> cardsBySuit = const {},
}) {
  return [
    for (var suit = 0; suit < count; suit++)
      {'suit': suit, 'cards': cardsBySuit[suit] ?? <Object?>[]},
  ];
}

Map<String, Object?> onlineCardJson(int suit, int value) {
  return {'suit': suit, 'value': value};
}

class FakeOnlineRequestRecord {
  FakeOnlineRequestRecord({
    required this.method,
    required this.uri,
    required this.body,
    required this.headers,
  });

  final String method;
  final Uri uri;
  final String body;
  final Map<String, List<Object>> headers;

  String get route => '$method ${uri.path}';
}

class FakeOnlineHttpClient implements HttpClient {
  final requests = <FakeOnlineRequestRecord>[];

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return FakeOnlineHttpClientRequest(this, method, url);
  }

  FakeOnlineHttpClientResponse route(
    String method,
    Uri uri,
    String body,
    Map<String, List<Object>> headers,
  ) {
    requests.add(
      FakeOnlineRequestRecord(
        method: method,
        uri: uri,
        body: body,
        headers: headers,
      ),
    );
    if (method == 'POST' && uri.path == '/sessions') {
      return FakeOnlineHttpClientResponse.json({
        'sessionID': '11111111-1111-1111-1111-111111111111',
        'inviteCode': 'ABCDE',
        'playerID': 0,
        'seatToken': 'seat-token-0',
        'update': onlineUpdateJson(),
      });
    }
    if (method == 'POST' && uri.path == '/sessions/matchmake') {
      return FakeOnlineHttpClientResponse.json({
        'sessionID': '11111111-1111-1111-1111-111111111111',
        'inviteCode': 'ABCDE',
        'playerID': 1,
        'seatToken': 'seat-token-1',
        'update': onlineUpdateJson(viewerID: 1),
      });
    }
    if (method == 'POST' && uri.path == '/presence') {
      return FakeOnlineHttpClientResponse.json({
        'service': {
          'activeSessions': 1,
          'activeSeats': 3,
          'connectedHumanSeats': 1,
          'profiledBotSeats': 15,
          'citizensOnline': 16,
        },
      });
    }
    if (method == 'GET' && uri.path == '/sessions') {
      return FakeOnlineHttpClientResponse.json([
        {
          'sessionID': '11111111-1111-1111-1111-111111111111',
          'inviteCode': 'ABCDE',
          'openSeats': [1],
          'occupiedSeats': [0],
          'controllers': ['human', 'human', 'heuristicAI', 'heuristicAI'],
          'playerProfiles': [
            {
              'playerID': 0,
              'userID': '11111111-1111-1111-1111-111111111111',
              'displayName': 'Mira',
              'avatarURL': 'worker3',
              'stats': {'online_games': 4, 'online_wins': 2},
            },
          ],
          'actionLogCount': 0,
          'createdAt': 1.0,
          'expiresAt': 3601.0,
        },
        {
          'sessionID': '22222222-2222-2222-2222-222222222222',
          'inviteCode': 'FGHIJ',
          'openSeats': [2],
          'occupiedSeats': [0, 1],
          'controllers': ['human', 'human', 'human', 'heuristicAI'],
          'playerProfiles': [
            {
              'playerID': 0,
              'userID': '22222222-2222-2222-2222-222222222222',
              'displayName': 'Oleg',
              'avatarURL': 'worker2',
              'stats': {'online_games': 1, 'online_wins': 0},
            },
          ],
          'ranked': false,
          'actionLogCount': 3,
          'createdAt': 2.0,
          'expiresAt': 3602.0,
        },
      ]);
    }
    if (method == 'GET' && uri.path == '/comrades') {
      return FakeOnlineHttpClientResponse.json({
        'userID': 'current-user',
        'comradeCode': 'SELF',
        'comrades': [
          {
            'userID': '11111111-1111-1111-1111-111111111111',
            'displayName': 'Mira',
            'avatarURL': 'worker3',
            'comradeCode': 'MIRA',
            'stats': {'online_games': 4, 'online_wins': 2},
          },
        ],
      });
    }
    if (method == 'GET' && uri.path == '/metrics') {
      return FakeOnlineHttpClientResponse.json({
        'service': {
          'activeSessions': 1,
          'activeSeats': 3,
          'connectedHumanSeats': 1,
          'profiledBotSeats': 15,
          'citizensOnline': 16,
        },
      });
    }
    if (method == 'GET' &&
        uri.path == '/sessions/11111111-1111-1111-1111-111111111111') {
      return FakeOnlineHttpClientResponse.json({
        'sessionID': '11111111-1111-1111-1111-111111111111',
        'inviteCode': 'ABCDE',
        'openSeats': <int>[],
        'occupiedSeats': [0, 1],
        'controllers': ['human', 'human', 'heuristicAI', 'heuristicAI'],
        'playerProfiles': [
          {
            'playerID': 0,
            'userID': '11111111-1111-1111-1111-111111111111',
            'displayName': 'Mira',
            'avatarURL': 'worker3',
            'stats': {'online_games': 4, 'online_wins': 2},
          },
        ],
        'actionLogCount': 0,
        'createdAt': 1.0,
        'expiresAt': 3601.0,
      });
    }
    if (method == 'GET' &&
        uri.path ==
            '/sessions/11111111-1111-1111-1111-111111111111/players/0/actions') {
      return FakeOnlineHttpClientResponse.json([
        const OnlineEngineAction(
          kind: kcActionSetTrump,
          playerID: 0,
          suit: 0,
        ).toJson(),
      ]);
    }
    if (method == 'POST' &&
        uri.path == '/sessions/11111111-1111-1111-1111-111111111111/actions') {
      return FakeOnlineHttpClientResponse.json(onlineUpdateJson());
    }
    return FakeOnlineHttpClientResponse.json({'error': 'missing'}, status: 404);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class EmptySessionsFakeOnlineHttpClient extends FakeOnlineHttpClient {
  @override
  FakeOnlineHttpClientResponse route(
    String method,
    Uri uri,
    String body,
    Map<String, List<Object>> headers,
  ) {
    if (method == 'GET' && uri.path == '/sessions') {
      requests.add(
        FakeOnlineRequestRecord(
          method: method,
          uri: uri,
          body: body,
          headers: headers,
        ),
      );
      return FakeOnlineHttpClientResponse.json([]);
    }
    return super.route(method, uri, body, headers);
  }
}

class BannedSessionsFakeOnlineHttpClient extends FakeOnlineHttpClient {
  @override
  FakeOnlineHttpClientResponse route(
    String method,
    Uri uri,
    String body,
    Map<String, List<Object>> headers,
  ) {
    if (method == 'GET' && uri.path == '/sessions') {
      requests.add(
        FakeOnlineRequestRecord(
          method: method,
          uri: uri,
          body: body,
          headers: headers,
        ),
      );
      return FakeOnlineHttpClientResponse.json({
        'error': 'account sent north',
      }, status: 403);
    }
    return super.route(method, uri, body, headers);
  }
}

class FakeOnlineHttpClientRequest implements HttpClientRequest {
  FakeOnlineHttpClientRequest(this.client, this.method, this.uri);

  final FakeOnlineHttpClient client;
  @override
  final String method;
  @override
  final Uri uri;
  final buffer = StringBuffer();
  int _contentLength = -1;

  @override
  final HttpHeaders headers = FakeOnlineHttpHeaders();

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  void add(List<int> data) {
    buffer.write(utf8.decode(data));
  }

  @override
  void write(Object? object) {
    buffer.write(object);
  }

  @override
  Future<HttpClientResponse> close() async {
    return client.route(
      method,
      uri,
      buffer.toString(),
      (headers as FakeOnlineHttpHeaders).values,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeOnlineHttpHeaders implements HttpHeaders {
  final values = <String, List<Object>>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = [value];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeOnlineHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  FakeOnlineHttpClientResponse(this.body, {required this.statusCode});

  factory FakeOnlineHttpClientResponse.json(Object? json, {int status = 200}) {
    return FakeOnlineHttpClientResponse(
      utf8.encode(jsonEncode(json)),
      statusCode: status,
    );
  }

  final List<int> body;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([body]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
