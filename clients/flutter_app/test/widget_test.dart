import 'dart:async';
import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/animation_speed.dart';
import 'package:kolkhoz_app/src/app_settings.dart';
import 'package:kolkhoz_app/src/assignment_display.dart';
import 'package:kolkhoz_app/src/board_view.dart';
import 'package:kolkhoz_app/src/brigade_display.dart';
import 'package:kolkhoz_app/src/card_art_display.dart';
import 'package:kolkhoz_app/src/card_display.dart';
import 'package:kolkhoz_app/src/c_engine_action_codec.dart';
import 'package:kolkhoz_app/src/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/controller_display.dart';
import 'package:kolkhoz_app/src/design_tokens.dart';
import 'package:kolkhoz_app/src/engine_action_projection.dart';
import 'package:kolkhoz_app/src/game_constants.dart';
import 'package:kolkhoz_app/src/game_ui_state.dart';
import 'package:kolkhoz_app/src/hot_seat_display.dart';
import 'package:kolkhoz_app/src/kolkhoz_app.dart';
import 'package:kolkhoz_app/src/lower_bar_actions.dart';
import 'package:kolkhoz_app/src/online_game_models.dart';
import 'package:kolkhoz_app/src/online_table_projection.dart';
import 'package:kolkhoz_app/src/panel_title_display.dart';
import 'package:kolkhoz_app/src/phase_display.dart';
import 'package:kolkhoz_app/src/pixel_text.dart';
import 'package:kolkhoz_app/src/policy_model.dart';
import 'package:kolkhoz_app/src/player_panel_display.dart';
import 'package:kolkhoz_app/src/plot_display.dart';
import 'package:kolkhoz_app/src/render_model.dart';
import 'package:kolkhoz_app/src/rule_content.dart';
import 'package:kolkhoz_app/src/saved_game_store.dart';
import 'package:kolkhoz_app/src/table_display.dart';
import 'package:kolkhoz_app/src/table_projection_helpers.dart';
import 'package:kolkhoz_app/src/trump_actions.dart';
import 'package:kolkhoz_app/src/tutorial_display.dart';

void main() {
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
    expect(
      variantsFromJson(variantsToJson(KolkhozGameVariants.kolkhoz)).wreckerCard,
      isTrue,
    );
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
            appearance: KolkhozAppearance.dark,
          ),
        ),
      ),
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
    expect(find.byType(RailButton), findsNWidgets(7));
  });

  testWidgets('left rail reports selected panel', (tester) async {
    const tokens = defaultDesignTokens;
    final metrics = ResponsiveBoardMetrics.fromSize(
      const Size(844, 390),
      tokens,
    );
    String? selectedPanel;
    final utilityCalls = <String>[];

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
            appearance: KolkhozAppearance.dark,
            onPanelSelected: (panel) => selectedPanel = panel,
            onLanguageToggle: () => utilityCalls.add('language'),
            onAppearanceToggle: () => utilityCalls.add('appearance'),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Cellar'));
    await tester.tap(find.byTooltip('Switch to Russian'));
    await tester.tap(find.byTooltip('Switch to light mode'));
    expect(selectedPanel, panelPlot);
    expect(utilityCalls, ['language', 'appearance']);
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
        KolkhozPlayerController.heuristicAI,
        KolkhozPlayerController.human,
        KolkhozPlayerController.neuralAI,
      ]);

      expect(viewerSeatIDForControllers(controllers), 2);
      expect(renderControllerName(controllers[0]), controllerNeuralAI);
      expect(renderControllerName(controllers[1]), controllerHeuristicAI);
      expect(renderControllerName(controllers[2]), controllerHuman);
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
    expect(policy.native.hiddenSize, 512);
    expect(policy.native.layerCount, 2);
    expect(policy.native.headCount, 16);

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
    expect(decoded.variants.ordenNachalniku, isTrue);
    expect(decoded.variants.heroOfSovietUnion, isFalse);
    expect(decoded.controllers, payload.controllers);
    expect(decoded.actions, hasLength(3));
    expect(decoded.actions[1].handCard?.id, 'wheat-7');
    expect(decoded.actions[1].plotCard?.id, 'beet-10');
    expect(decoded.actions[1].plotZone, plotZoneHidden);
    expect(decoded.actions[2].targetSuit, 'potato');
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
    expect(model.viewer.seatID, 0);
    expect(model.table.phase, phasePlanning);
    expect(model.table.seats[0].hand.map((card) => card.id), ['wheat-13']);
    expect(model.table.seats[1].controller, controllerRemoteHuman);
    expect(model.table.seats[1].hiddenHandCount, 0);
    expect(model.table.jobs.first.reward?.id, 'wheat-9');
    expect(model.legalActions.single.engineAction.suit, 'wheat');
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
    );
    final actions = await client.fetchLegalActions(
      sessionID: created.sessionID,
      playerID: created.playerID,
    );
    final submitted = await client.submitAction(
      sessionID: created.sessionID,
      playerID: created.playerID,
      action: actions.single.engineAction,
    );

    expect(submitted.sessionID, created.sessionID);
    expect(httpClient.requests.map((request) => request.route), [
      'POST /sessions',
      'GET /sessions/11111111-1111-1111-1111-111111111111/players/0/actions',
      'POST /sessions/11111111-1111-1111-1111-111111111111/actions',
    ]);
    expect(
      jsonDecode(httpClient.requests.first.body)['variants']['deckType'],
      52,
    );
    expect(
      jsonDecode(httpClient.requests.last.body)['action']['kind'],
      kcActionSetTrump,
    );
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
      find.text('Remember, you must follow suit if able.'),
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
    final padding = handTrayOuterPadding(trailing: 20);
    final metrics = ResponsiveBoardMetrics(
      tokens: defaultDesignTokens,
      scale: 1,
      margin: 0,
    );

    expect(padding.left, 0);
    expect(padding.right, 36);
    expect(metrics.handTrayLayoutHeightForBoardHeight(420), 52);
    expect(metrics.handTrayLayoutHeightForBoardHeight(620), 172);
    expect(metrics.handTrayLayoutHeightForBoardHeight(970), 390);
    expect(metrics.handTrayLayoutHeightForBoardHeight(1400), 390);
    expect(metrics.handTrayVisibleHeightForBoardHeight(420), 66);
    expect(metrics.handTrayVisibleHeightForBoardHeight(620), 186);
    expect(metrics.handTrayVisibleHeightForBoardHeight(970), 404);
    expect(metrics.handTrayVisibleHeightForBoardHeight(1400), 404);
    expect(metrics.handTrayHeightForVisibleHeight(66), 52);
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
    expect(
      scaledHandTrayCardSize(defaultDesignTokens.card.large, 404).height,
      closeTo(298.2, 0.001),
    );
    expect(handTrayActionSingleWidth, lessThan(handTrayActionDoubleWidth));
    expect(
      handTrayProminentActionHeight,
      greaterThan(handTraySecondaryActionHeight),
    );
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
      northCardScrollMinHeight,
    );
    expect(
      northCardScrollHeight(columnHeight: 180, headerHeight: northHeaderHeight),
      130,
    );
  });

  test('options display helpers clamp menu spacing', () {
    expect(optionsPanelSurfaceMinHeight, 230);
    expect(optionsPanelSurfaceMaxHeight, 384);
    expect(optionsMenuSectionSpacing(100), optionsMenuSectionSpacingMin);
    expect(optionsMenuSectionSpacing(1000), optionsMenuSectionSpacingMax);
    expect(defaultGameAnimationSpeed, GameAnimationSpeed.normal);
    expect(GameAnimationSpeed.instant.automaticStepDelay, Duration.zero);
    expect(
      GameAnimationSpeed.fast.automaticStepDelay,
      const Duration(milliseconds: 170),
    );
    expect(
      GameAnimationSpeed.slow.cardFlightDuration,
      const Duration(milliseconds: 520),
    );
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

  testWidgets('chrome command labels use bitmap pixel text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 260,
          height: 80,
          child: ChromeAssetButton(
            label: 'NEW GAME',
            backgroundAsset: 'ios_resources/ui-button-primary.png',
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

  testWidgets('options menu controls report game-level actions', (
    tester,
  ) async {
    final calls = <String>[];
    GameAnimationSpeed? selectedSpeed;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 260,
          height: 270,
          child: OptionsMenuActions(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.ru,
            appearance: KolkhozAppearance.dark,
            animationSpeed: GameAnimationSpeed.normal,
            onNewGame: () => calls.add('new'),
            onTutorial: () => calls.add('tutorial'),
            onReturnToLobby: () => calls.add('menu'),
            onLanguageToggle: () => calls.add('language'),
            onAppearanceToggle: () => calls.add('appearance'),
            onAnimationSpeedChanged: (speed) => selectedSpeed = speed,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('НОВАЯ ИГРА'));
    await tester.tap(find.bySemanticsLabel('КАК ИГРАТЬ'));
    await tester.tap(find.bySemanticsLabel('ГЛАВНОЕ МЕНЮ'));
    await tester.tap(find.byTooltip('Switch to English'));
    await tester.tap(find.byTooltip('Включить светлую тему'));
    await tester.tap(find.bySemanticsLabel('МЕДЛЕННО'));

    expect(calls, ['new', 'tutorial', 'menu', 'language', 'appearance']);
    expect(selectedSpeed, GameAnimationSpeed.slow);
  });

  testWidgets('lobby footer controls are interactive', (tester) async {
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
            onHostOnline: (_, controllers) async => 'session',
            onJoinOnline: (_, _, _) async {},
            onPresetChanged: (_) {},
            onCustomVariantsChanged: (_) {},
            onPlayerControllersChanged: (_) {},
            onRulesPressed: () {},
            onOfflinePressed: () {},
            onOnlinePressed: () {},
            onTutorialPressed: () {},
            onLanguageToggle: () => calls.add('language'),
            onAppearanceToggle: () => calls.add('appearance'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('EN'));
    await tester.tap(find.text('LIGHT'));

    expect(calls, ['language', 'appearance']);
    expect(find.text('STANDARD'), findsNothing);
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
              onHostOnline: (_, controllers) async => 'session',
              onJoinOnline: (_, _, _) async {},
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

      expect(find.text('START GAME'), findsNothing);
      expect(find.text('HOST & PLAY'), findsOneWidget);

      await tester.tap(find.text('OFFLINE PLAY'));
      await tester.tap(find.text('ONLINE PLAY').first);
      await tester.tap(find.text('HOW TO PLAY'));

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
              onHostOnline: (_, controllers) async => 'session',
              onJoinOnline: (_, _, _) async {},
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

      await tester.tap(find.text('START GAME'));

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
              onHostOnline: (_, controllers) async => 'session',
              onJoinOnline: (_, _, _) async {},
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

      expect(find.text('RULES'), findsNothing);
      expect(find.text('HOW TO PLAY'), findsWidgets);
      await tester.tap(find.text('TUTORIAL'));

      expect(calls, ['offline', 'online', 'rules', 'start', 'tutorial']);
    },
  );

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
            showingRules: false,
            showingOnline: false,
            onHostOnline: (_, controllers) async => 'session',
            onJoinOnline: (_, _, _) async {},
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

    expect(find.text('HUMAN'), findsNothing);
    await tester.tap(find.bySemanticsLabel('P2 Neural'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BASIC'));
    await tester.pumpAndSettle();

    expect(changedControllers, isNotNull);
    expect(changedControllers![1], KolkhozPlayerController.heuristicAI);
  });

  testWidgets('online lobby host sends open seats as human controllers', (
    tester,
  ) async {
    List<KolkhozPlayerController>? hostedControllers;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: StandaloneLobby(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.ru,
            appearance: KolkhozAppearance.dark,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: true,
            onHostOnline: (_, controllers) async {
              hostedControllers = controllers;
              return 'session';
            },
            onJoinOnline: (_, _, _) async {},
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

    await tester.tap(find.text('ОТКРЫТО').first);
    await tester.tap(find.text('СОЗДАТЬ И ИГРАТЬ'));
    await tester.pump();

    expect(hostedControllers, isNotNull);
    expect(hostedControllers![0], KolkhozPlayerController.human);
    expect(hostedControllers![1], KolkhozPlayerController.human);
    expect(hostedControllers![2], KolkhozPlayerController.heuristicAI);
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

    expect(find.text('FIRST, READ THE TABLE'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-dot-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-next')));
    await tester.pump();
    expect(find.text('PICK THE TRUMP CROP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-back')));
    await tester.pump();
    expect(find.text('FIRST, READ THE TABLE'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-close')));
    expect(closed, isTrue);
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
                titleEn: 'Only step',
                titleRu: 'Один шаг',
                bodyEn: 'Body',
                bodyRu: 'Текст',
                tipEn: 'Tip',
                tipRu: 'Совет',
                calloutEn: 'Callout',
                calloutRu: 'Подсказка',
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

    expect(find.text('СНАЧАЛА ОСМОТРИТЕ СТОЛ'), findsOneWidget);
    expect(
      find.textContaining('Каждый год есть четыре работы'),
      findsOneWidget,
    );
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
      closeTo(494.1654, 0.0001),
    );
    expect(
      brigadePanelHeightForWidth(
        maxWidth: 1200,
        columnCount: 4,
        minCardWidth: 70,
        cardAspectRatio: 1.42,
      ),
      closeTo(502.1654, 0.0001),
    );
    expect(
      brigadePlayObjectMaxHeight(360, 106.6324),
      closeTo(215.3676, 0.0001),
    );
    expect(
      brigadePlayObjectFittingWidth(
        desiredWidth: 246.15,
        maxHeight: 215.3676,
        aspectRatio: 1.42,
      ),
      closeTo(151.6673, 0.0001),
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
  Trick? lastTrick,
  List<LegalAction>? legalActions,
}) {
  final base = runtimeModel();
  return TableViewModel(
    viewer: base.viewer,
    table: TableState(
      year: base.table.year,
      phase: phase,
      phasePrompt: base.table.phasePrompt,
      currentPlayerID: base.table.currentPlayerID,
      trump: base.table.trump,
      isFamine: base.table.isFamine,
      maxTricks: base.table.maxTricks,
      seats: base.table.seats,
      jobs: jobs,
      trick: base.table.trick,
      lastTrick: lastTrick ?? base.table.lastTrick,
      requisitionEvents: base.table.requisitionEvents,
      exiledByYear: base.table.exiledByYear,
      scoreboard: base.table.scoreboard,
      gameResult: base.table.gameResult,
    ),
    panels: base.panels,
    selection: selection,
    legalActions: legalActions ?? base.legalActions,
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

TableCard testCard({
  required String id,
  required String suit,
  required int value,
  String? rank,
  bool nomenclature = false,
}) {
  return TableCard(
    id: id,
    suit: suit,
    value: value,
    rank: rank ?? '$value',
    selected: false,
    highlighted: false,
    pending: false,
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

Map<String, Object?> onlineUpdateJson() {
  return {
    'sessionID': '11111111-1111-1111-1111-111111111111',
    'viewerID': 0,
    'actionLogCount': 0,
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
  });

  final String method;
  final Uri uri;
  final String body;

  String get route => '$method ${uri.path}';
}

class FakeOnlineHttpClient implements HttpClient {
  final requests = <FakeOnlineRequestRecord>[];

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return FakeOnlineHttpClientRequest(this, method, url);
  }

  FakeOnlineHttpClientResponse route(String method, Uri uri, String body) {
    requests.add(FakeOnlineRequestRecord(method: method, uri: uri, body: body));
    if (method == 'POST' && uri.path == '/sessions') {
      return FakeOnlineHttpClientResponse.json({
        'sessionID': '11111111-1111-1111-1111-111111111111',
        'playerID': 0,
        'update': onlineUpdateJson(),
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
    return client.route(method, uri, buffer.toString());
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
