part of '../widget_test.dart';

void registerBoardTests() {
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

  test('phase panels open only the dedicated assignment surface', () {
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
      panelBrigade,
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
      panelBrigade,
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
    final selected = const GameUiState().selectHandCard('wheat-11');
    expect(selected.selection.handCardID, 'wheat-11');
    final cleared = selected.selectHandCard('wheat-11');
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
            onHandCardTap: (cardID) => selectedCardID = cardID,
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
            onHandCardTap: (cardID) => selectedCardID = cardID,
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
            onHandCardTap: (_) {},
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

  test('pass icons mirror for left-facing even years', () {
    expect(passIconFlipsHorizontally(2), isTrue);
    expect(passIconFlipsHorizontally(3), isFalse);
    expect(passIconFlipsHorizontally(4), isTrue);
    expect(passIconFlipsHorizontally(5), isFalse);
  });

  testWidgets('pass hand card waits for selection and confirmation', (
    tester,
  ) async {
    String? selectedCardID;
    LegalAction? confirmedAction;
    final passAction = testLegalAction(
      kind: actionPassCard,
      label: 'Pass',
      engineAction: const EngineAction(
        kind: actionPassCard,
        playerID: 0,
        card: EngineCard(suit: 'wheat', value: 11),
      ),
    );

    Widget tray(SelectionState selection) => MaterialApp(
      home: SizedBox(
        width: 520,
        height: 180,
        child: HandTray(
          model: runtimeModelWith(
            phase: phasePass,
            selection: selection,
            jobs: runtimeModel().table.jobs,
            legalActions: [passAction],
          ),
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          visibleTrayHeight: 150,
          onHandCardTap: (cardID) => selectedCardID = cardID,
          onAction: (action) => confirmedAction = action,
        ),
      ),
    );

    await tester.pumpWidget(tray(SelectionState.empty));
    expect(
      handConsoleConfirmAction(
        runtimeModelWith(
          phase: phasePass,
          selection: SelectionState.empty,
          jobs: runtimeModel().table.jobs,
          legalActions: [passAction],
        ),
      ),
      isNull,
    );
    await tester.tap(find.byType(GameCard));
    expect(selectedCardID, 'wheat-11');
    expect(confirmedAction, isNull);

    final selected = SelectionState.empty.copyWith(handCardID: 'wheat-11');
    await tester.pumpWidget(tray(selected));
    await tester.tap(find.byKey(const Key('hand-console-primary')));
    expect(confirmedAction, same(passAction));
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
    expect(previewSize.width, greaterThan(70));
  });

  testWidgets('brigade pulses only the card currently winning the trick', (
    tester,
  ) async {
    final base = runtimeModel();
    final leadCard = testCard(id: 'wheat-10', suit: 'wheat', value: 10);
    final winningCard = testCard(id: 'wheat-12', suit: 'wheat', value: 12);
    final model = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      trick: Trick(
        plays: [
          TrickPlay(seatID: 0, card: leadCard),
          TrickPlay(seatID: 1, card: winningCard),
        ],
        winnerSeatID: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 360,
          child: BrigadePanel(
            model: model,
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final winningCards = tester
        .widgetList<GameCard>(find.byType(GameCard))
        .where((card) => card.winningTrick)
        .toList();
    expect(winningCards, hasLength(1));
    expect(winningCards.single.card.id, winningCard.id);
    expect(
      find.byKey(const ValueKey('winning-trick-card-frame')),
      findsOneWidget,
    );
  });

  testWidgets('brigade keeps the winning card highlighted during assignment', (
    tester,
  ) async {
    final base = runtimeModel();
    final leadCard = testCard(id: 'wheat-10', suit: 'wheat', value: 10);
    final winningCard = testCard(id: 'wheat-12', suit: 'wheat', value: 12);
    final model = runtimeModelWith(
      phase: phaseAssignment,
      currentPlayerID: 1,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      trick: const Trick(plays: [], winnerSeatID: null),
      lastTrick: Trick(
        plays: [
          TrickPlay(seatID: 0, card: leadCard),
          TrickPlay(seatID: 1, card: winningCard),
        ],
        winnerSeatID: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 360,
          child: BrigadePanel(
            model: model,
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final winningCards = tester
        .widgetList<GameCard>(find.byType(GameCard))
        .where((card) => card.winningTrick)
        .toList();
    expect(winningCards, hasLength(1));
    expect(winningCards.single.card.id, winningCard.id);
    expect(
      find.byKey(const ValueKey('winning-trick-card-frame')),
      findsOneWidget,
    );
  });

  testWidgets('medals pulse when a player is one trick from Hero', (
    tester,
  ) async {
    final base = runtimeModel();
    final seats = [
      for (final seat in base.table.seats)
        seat.id == 1 ? seatWithMedals(seat, base.table.maxTricks - 1) : seat,
    ];
    final model = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      seats: seats,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 360,
          child: BrigadePanel(
            model: model,
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('hero-medal-warning')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 360,
          child: BrigadePanel(
            model: model,
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            heroOfSovietUnion: false,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('hero-medal-warning')), findsNothing);
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
      findAssetImage('assets/ui/Embellishments/art-tutorial-foreman.png'),
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
    final visibleStacks = visiblePlotStacks(
      [
        PlotStackState(revealed: [wheat9, beet10], hidden: [wheat9]),
      ],
      {'wheat-9'},
    );
    expect(visibleStacks.single.revealed, [beet10]);
    expect(visibleStacks.single.hidden, isEmpty);
  });

  testWidgets('swap selection frames plot and cellar cards', (tester) async {
    final card = testCard(id: 'wheat-9', suit: 'wheat', value: 9);

    Widget cardView({required bool hidden}) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: defaultDesignTokens.card.small.width,
          height: defaultDesignTokens.card.small.height,
          child: Stack(
            children: plotOverviewCardItems(
              cards: [card],
              stacks: const [],
              hiddenCards: hidden,
              cardSize: defaultDesignTokens.card.small,
              selectedCardID: card.id,
              selectable: true,
              zone: hidden ? plotZoneHidden : plotZoneRevealed,
              exiledCardIDs: const {},
              tokens: defaultDesignTokens,
              onPlotCardTap: (_, _) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(cardView(hidden: false));

    expect(
      find.byKey(ValueKey('swap-selected-plot-card-${card.id}')),
      findsOneWidget,
    );
    expect(
      tester.widgetList<GameCard>(find.byType(GameCard)).single.card.selected,
      isTrue,
    );

    await tester.pumpWidget(cardView(hidden: true));
    await tester.pump();

    expect(
      find.byKey(ValueKey('swap-selected-plot-card-${card.id}')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ScaledHighlightableCardBack>(
            find.byType(ScaledHighlightableCardBack),
          )
          .card
          .selected,
      isTrue,
    );
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

  testWidgets('north cards are compact, overlapped, and scroll vertically', (
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
                seats: const [],
                tokens: defaultDesignTokens,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('north-card-wheat-6'))).width,
      100 * northCardScaleFactor,
    );
    final firstTop = tester
        .getTopLeft(find.byKey(const ValueKey('north-card-wheat-6')))
        .dy;
    final secondTop = tester
        .getTopLeft(find.byKey(const ValueKey('north-card-wheat-7')))
        .dy;
    final cardHeight = tester
        .getSize(find.byKey(const ValueKey('north-card-wheat-6')))
        .height;
    expect(
      secondTop - firstTop,
      closeTo(cardHeight * northCardExposedFraction, 0.001),
    );
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -80));
    await tester.pump();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('north cards show the portrait of the player who lost them', (
    tester,
  ) async {
    final seats = runtimeModel().table.seats;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 100,
          height: 140,
          child: NorthCardStack(
            cards: [
              testCard(
                id: 'beet-10',
                suit: 'beet',
                value: 10,
                ownerSeatID: seats[2].id,
              ),
              testCard(id: 'wheat-6', suit: 'wheat', value: 6),
            ],
            seats: seats,
            tokens: defaultDesignTokens,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('north-card-beet-10-portrait')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('north-card-wheat-6-portrait')),
      findsNothing,
    );
  });

  test('options display helpers clamp menu spacing', () {
    expect(optionsPanelLocalPadding.top, 8);
    expect(optionsPanelSurfaceMinHeight, 230);
    expect(optionsMenuSectionSpacing(100), optionsMenuSectionSpacingMin);
    expect(optionsMenuSectionSpacing(1000), optionsMenuSectionSpacingMax);
    expect(
      const GameMotion(speed: GameAnimationSpeed.normal).trumpSelectorHop,
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
    expect(
      const GameMotion(speed: GameAnimationSpeed.normal).activeCardSlotPulse,
      const Duration(milliseconds: 1800),
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

  test('chrome command buttons use rail underlay assets', () {
    expect(chromeButtonPrimaryAsset, 'assets/ui/ui-nav-button-active.png');
    expect(chromeButtonSecondaryAsset, 'assets/ui/ui-nav-button-inactive.png');
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

    expect(zones['wheat-11'], const MotionZone.hand(0));
    expect(cards['wheat-11']?.rank, 'J');
  });

  test('game motion disables every gameplay duration for reduced motion', () {
    const motion = GameMotion(
      speed: GameAnimationSpeed.normal,
      disableAnimations: true,
    );

    expect(motion.enabled, isFalse);
    expect(motion.cardFlightDuration, Duration.zero);
    expect(motion.cardLandingHold, Duration.zero);
    expect(motion.cameraFocusIn, Duration.zero);
    expect(motion.cameraFocusOut, Duration.zero);
    expect(motion.gaugeDelta, Duration.zero);
    expect(motion.handInteraction, Duration.zero);
    expect(motion.medalAppear, Duration.zero);
    expect(motion.heroMedalPulse, Duration.zero);
    expect(motion.activeCardSlotPulse, Duration.zero);
    expect(motion.trumpSelectorFrame, Duration.zero);
    expect(motion.rewardFlip, Duration.zero);
  });

  test('planning rewards stay in the popup until planning ends', () {
    final rewards = [
      for (final job in runtimeModel().table.jobs)
        Job(
          suit: job.suit,
          hours: job.hours,
          requiredHours: job.requiredHours,
          claimed: job.claimed,
          reward: testCard(id: '${job.suit}-reward', suit: job.suit, value: 5),
          assignedCards: job.assignedCards,
          validAssignmentTarget: job.validAssignmentTarget,
          highlighted: job.highlighted,
        ),
    ];
    final planning = runtimeModelWith(
      phase: phasePlanning,
      selection: SelectionState.empty,
      jobs: rewards,
    );
    final trick = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: rewards,
    );
    final transition = GamePresentationTransition(
      id: 1,
      before: planning,
      after: trick,
      action: const EngineAction(
        kind: actionSetTrump,
        playerID: 0,
        suit: 'wheat',
      ),
    );

    expect(
      cardMotionZones(planning)['wheat-reward'],
      const MotionZone.rewardReveal('wheat'),
    );
    expect(
      cardMotionZones(trick)['wheat-reward'],
      const MotionZone.reward('wheat'),
    );
    expect(boardVisibleModelDuringTransition(trick, transition), planning);

    final previousGeometry = MotionGeometry({
      for (final (index, suit) in displaySuitOrder.indexed)
        rewardPileMotionSourceKey(suit): Rect.fromLTWH(
          100 + index * 60,
          300,
          42,
          58,
        ),
    });
    final currentGeometry = MotionGeometry({
      for (final (index, suit) in displaySuitOrder.indexed)
        jobGaugeMotionTargetKey(suit): Rect.fromLTWH(
          80 + index * 110,
          20,
          90,
          38,
        ),
    });
    final plan = planCardFlights(
      motionEnabled: true,
      minimumFlightDistance: GameMotion.minimumFlightDistance,
      previousModel: planning,
      nextModel: trick,
      previousZones: cardMotionZones(planning),
      nextZones: cardMotionZones(trick),
      previousCards: cardMotionCards(planning),
      nextCards: cardMotionCards(trick),
      previousGeometry: previousGeometry,
      currentGeometry: currentGeometry,
      geometry: const DefaultCardMotionGeometryResolver(defaultDesignTokens),
      transitionID: transition.id,
      assignmentCardIDs: const [],
      assignmentTargets: const {},
      suppressedCardIDs: const {},
      presentedAssignmentCardIDs: const {},
      initialFlightID: 0,
    );

    expect(plan.stages, hasLength(1));
    expect(plan.stages.single, hasLength(4));
    expect(
      plan.stages.single.map((flight) => flight.destinationZone),
      containsAll([
        for (final suit in displaySuitOrder) MotionZone.reward(suit),
      ]),
    );
  });

  test('card motion planning is pure and preserves assignment intent', () {
    final before = runtimeModelWith(
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
    );
    final card = before.table.seats.first.hand.single;
    final nextZones = <String, MotionZone>{};
    final nextCards = <String, TableCard>{};

    final assigning = planCardMotionChanges(
      previousModel: before,
      nextModel: before,
      nextZones: nextZones,
      previousCards: {card.id: card},
      nextCards: nextCards,
      assignmentTargets: {card.id: card.suit},
      suppressedCardIDs: const {},
      presentedAssignmentCardIDs: const {},
    );

    expect(assigning.nextZones[card.id], MotionZone.job(card.suit));
    expect(assigning.nextCards[card.id], card);
    expect(assigning.presentedAssignmentCardIDs, {card.id});
    expect(nextZones, isEmpty);
    expect(nextCards, isEmpty);
    expect(
      () => assigning.nextZones[card.id] = const MotionZone.hand(0),
      throwsUnsupportedError,
    );

    final after = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: before.table.jobs,
    );
    final leaving = planCardMotionChanges(
      previousModel: before,
      nextModel: after,
      nextZones: const {},
      previousCards: {card.id: card},
      nextCards: const {},
      assignmentTargets: const {},
      suppressedCardIDs: const {},
      presentedAssignmentCardIDs: {card.id},
    );

    expect(leaving.leavingAssignment, isTrue);
    expect(leaving.suppressedCardIDs, contains(card.id));
    expect(leaving.presentedAssignmentCardIDs, isEmpty);
  });

  test('opponent swaps keep both card flights face down', () {
    final base = runtimeModel();
    final swapModel = runtimeModelWith(
      phase: phaseSwap,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
    );
    final handCard = testCard(id: 'wheat-hand', suit: 'wheat', value: 9);
    final cellarCard = testCard(id: 'beet-cellar', suit: 'beet', value: 8);
    final plan = planCardFlights(
      motionEnabled: true,
      minimumFlightDistance: 1,
      previousModel: swapModel,
      nextModel: swapModel,
      previousZones: {
        handCard.id: const MotionZone.hand(1),
        cellarCard.id: const MotionZone.plotHidden(1),
      },
      nextZones: {
        handCard.id: const MotionZone.plotHidden(1),
        cellarCard.id: const MotionZone.hand(1),
      },
      previousCards: {handCard.id: handCard, cellarCard.id: cellarCard},
      nextCards: {handCard.id: handCard, cellarCard.id: cellarCard},
      previousGeometry: MotionGeometry({
        MotionAnchor.card(handCard.id): const Rect.fromLTWH(20, 20, 48, 68),
        MotionAnchor.card(cellarCard.id): const Rect.fromLTWH(220, 140, 48, 68),
      }),
      currentGeometry: MotionGeometry({
        MotionAnchor.card(handCard.id): const Rect.fromLTWH(220, 140, 48, 68),
        MotionAnchor.card(cellarCard.id): const Rect.fromLTWH(20, 20, 48, 68),
      }),
      geometry: const DefaultCardMotionGeometryResolver(defaultDesignTokens),
      transitionID: 1,
      assignmentCardIDs: const [],
      assignmentTargets: const {},
      suppressedCardIDs: const {},
      presentedAssignmentCardIDs: const {},
      initialFlightID: 0,
    );

    expect(plan.flights, hasLength(2));
    expect(plan.flights.every((flight) => flight.faceDown), isTrue);
    expect(
      cardFlightShouldBeFaceDown(
        previousZone: const MotionZone.hand(1),
        nextZone: const MotionZone.plotRevealed(1),
        previousModel: swapModel,
        nextModel: swapModel,
      ),
      isTrue,
    );
    expect(
      cardFlightShouldBeFaceDown(
        previousZone: const MotionZone.hand(0),
        nextZone: const MotionZone.plotHidden(0),
        previousModel: swapModel,
        nextModel: swapModel,
      ),
      isFalse,
    );
    final postSwapModel = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
    );
    expect(
      cardFlightShouldBeFaceDown(
        previousZone: const MotionZone.hand(1),
        nextZone: const MotionZone.plotHidden(1),
        previousModel: swapModel,
        nextModel: postSwapModel,
      ),
      isTrue,
      reason: 'bot swap privacy must survive the final swap phase boundary',
    );
  });

  testWidgets('face-down card flights render the card back', (tester) async {
    final card = testCard(id: 'hidden-swap-card', suit: 'wheat', value: 9);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: Stack(
            children: [
              FlyingCard(
                flight: CardFlight(
                  id: 1,
                  card: card,
                  from: const Rect.fromLTWH(20, 20, 48, 68),
                  to: const Rect.fromLTWH(220, 140, 48, 68),
                  destinationZone: const MotionZone.plotHidden(1),
                  faceDown: true,
                ),
                tokens: defaultDesignTokens,
                duration: const Duration(seconds: 1),
                onDone: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('flying-card-back-hidden-swap-card')),
      findsOneWidget,
    );
    expect(find.byType(GameCard), findsNothing);
  });

  testWidgets(
    'hidden requisition flips at its source before flying with a red frame',
    (tester) async {
      final card = testCard(
        id: 'hidden-requisition-card',
        suit: 'wheat',
        value: 9,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 320,
            height: 240,
            child: Stack(
              children: [
                FlyingCard(
                  flight: CardFlight(
                    id: 2,
                    card: card,
                    from: const Rect.fromLTWH(20, 20, 48, 68),
                    to: const Rect.fromLTWH(220, 140, 48, 68),
                    destinationZone: const MotionZone.northExile(),
                    revealBeforeFlight: true,
                    requisitioned: true,
                  ),
                  tokens: defaultDesignTokens,
                  duration: const Duration(milliseconds: 520),
                  onDone: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('flying-card-back-hidden-requisition-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('requisition-card-frame-hidden-requisition-card'),
        ),
        findsOneWidget,
      );
      Positioned flightPosition() => tester
          .widgetList<Positioned>(
            find.descendant(
              of: find.byType(FlyingCard),
              matching: find.byType(Positioned),
            ),
          )
          .firstWhere(
            (positioned) =>
                positioned.left != null &&
                positioned.top != null &&
                positioned.width == 48 &&
                positioned.height == 68,
          );
      var positioned = flightPosition();
      expect(positioned.left, 20);

      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('flying-card-face-hidden-requisition-card')),
        findsOneWidget,
      );
      positioned = flightPosition();
      expect(positioned.left, 20);

      await tester.pump(const Duration(milliseconds: 300));

      positioned = flightPosition();
      expect(positioned.left, greaterThan(20));
      expect(
        find.byKey(
          const ValueKey('requisition-card-frame-hidden-requisition-card'),
        ),
        findsOneWidget,
      );
    },
  );

  test('fourth card flight precedes prefilled assignment flights', () {
    final base = runtimeModel();
    final finalCard = base.table.seats[0].hand.single;
    final firstAssignment = testCard(
      id: 'sunflower-7',
      suit: 'sunflower',
      value: 7,
      pending: true,
    );
    final secondAssignment = testCard(
      id: 'wheat-8',
      suit: 'wheat',
      value: 8,
      pending: true,
    );
    final before = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
    );
    final after = runtimeModelWith(
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
    );
    final previousZones = {
      finalCard.id: const MotionZone.hand(0),
      firstAssignment.id: const MotionZone.trick(1),
      secondAssignment.id: const MotionZone.trick(2),
    };
    final nextZones = {finalCard.id: const MotionZone.trick(0)};
    final cards = {
      finalCard.id: finalCard,
      firstAssignment.id: firstAssignment,
      secondAssignment.id: secondAssignment,
    };
    final plan = planCardFlights(
      motionEnabled: true,
      minimumFlightDistance: GameMotion.minimumFlightDistance,
      previousModel: before,
      nextModel: after,
      previousZones: previousZones,
      nextZones: nextZones,
      previousCards: cards,
      nextCards: {finalCard.id: finalCard},
      previousGeometry: MotionGeometry({
        handCardMotionSourceKey(0): const Rect.fromLTWH(20, 220, 48, 68),
        trickCardMotionSourceKey(firstAssignment.id): const Rect.fromLTWH(
          150,
          100,
          48,
          68,
        ),
        trickCardMotionSourceKey(secondAssignment.id): const Rect.fromLTWH(
          210,
          100,
          48,
          68,
        ),
      }),
      currentGeometry: MotionGeometry({
        trickCardMotionTargetKey(0): const Rect.fromLTWH(90, 90, 48, 68),
        jobGaugeMotionTargetKey(firstAssignment.suit): const Rect.fromLTWH(
          280,
          20,
          90,
          38,
        ),
        jobGaugeMotionTargetKey(secondAssignment.suit): const Rect.fromLTWH(
          390,
          20,
          90,
          38,
        ),
      }),
      geometry: const DefaultCardMotionGeometryResolver(defaultDesignTokens),
      transitionID: 17,
      assignmentCardIDs: [firstAssignment.id, secondAssignment.id],
      assignmentTargets: {
        firstAssignment.id: firstAssignment.suit,
        secondAssignment.id: secondAssignment.suit,
      },
      suppressedCardIDs: const {},
      presentedAssignmentCardIDs: const {},
      initialFlightID: 0,
    );

    expect(plan.stages, hasLength(3));
    expect(plan.stages[0].map((flight) => flight.card.id), [finalCard.id]);
    expect(plan.stages[1].map((flight) => flight.card.id), [
      firstAssignment.id,
    ]);
    expect(plan.stages[2].map((flight) => flight.card.id), [
      secondAssignment.id,
    ]);
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

    final playedStaticCard = find.byWidgetPredicate(
      (widget) => widget is GameCard && widget.card.id == playedCard.id,
    );
    final staticCardOpacity = tester.widget<Opacity>(
      find.descendant(of: playedStaticCard, matching: find.byType(Opacity)),
    );
    expect(staticCardOpacity.opacity, 0);
    expect(find.byType(FlyingCard), findsNothing);

    await tester.pump();
    await tester.pump();

    expect(find.byType(FlyingCard), findsOneWidget);
  });

  testWidgets('trick landing shows its winner before the queue advances', (
    tester,
  ) async {
    final before = runtimeModel();
    final playedCard = before.table.seats[0].hand.single;
    final after = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: before.table.jobs,
      seats: [
        seatWithHand(before.table.seats[0], const []),
        ...before.table.seats.skip(1),
      ],
      trick: Trick(
        plays: [TrickPlay(seatID: 0, card: playedCard)],
        winnerSeatID: 0,
      ),
    );
    var model = before;
    GamePresentationTransition? transition;
    final completed = <int>[];
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
                model: model,
                tokens: defaultDesignTokens,
                speed: GameAnimationSpeed.normal,
                transition: transition,
                onTransitionComplete: completed.add,
                child: _CardMotionTestBoard(model: model),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    setMotionState(() {
      model = after;
      transition = GamePresentationTransition(
        id: 31,
        before: before,
        after: after,
        event: EngineTransitionEvent(
          kind: kcTransitionCardMoved,
          playerID: 0,
          card: EngineCardValue(
            suit: suitCode(playedCard.suit)!,
            value: playedCard.value,
          ),
          fromZone: kcObjectZoneHand,
          toZone: kcObjectZoneCurrentTrick,
          fromOwner: 0,
          toOwner: 0,
          targetSuit: -1,
        ),
      );
    });
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(FlyingCard), findsOneWidget);
    expect(completed, isEmpty);
    final flyingWinner = tester.widget<GameCard>(
      find.descendant(
        of: find.byType(FlyingCard),
        matching: find.byType(GameCard),
      ),
    );
    expect(flyingWinner.winningTrick, isTrue);
    expect(
      find.descendant(
        of: find.byType(FlyingCard),
        matching: find.byKey(const ValueKey('winning-trick-card-frame')),
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 521));

    expect(find.byType(FlyingCard), findsNothing);
    expect(
      find.byKey(const ValueKey('winning-trick-card-frame')),
      findsOneWidget,
    );
    expect(completed, isEmpty);

    await tester.pump(const Duration(milliseconds: 139));
    expect(completed, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(completed, [31]);
  });

  testWidgets('fourth trick card flies before assignment changes panels', (
    tester,
  ) async {
    final base = runtimeModel();
    final playedCard = base.table.seats[0].hand.single;
    final earlierPlays = [
      TrickPlay(
        seatID: 1,
        card: testCard(id: 'sunflower-7', suit: 'sunflower', value: 7),
      ),
      TrickPlay(
        seatID: 2,
        card: testCard(id: 'potato-8', suit: 'potato', value: 8),
      ),
      TrickPlay(
        seatID: 3,
        card: testCard(id: 'beet-10', suit: 'beet', value: 10),
      ),
    ];
    final before = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      trick: Trick(plays: earlierPlays, winnerSeatID: null),
    );
    final after = modelWithActivePanel(
      runtimeModelWith(
        phase: phaseAssignment,
        selection: SelectionState.empty,
        jobs: base.table.jobs,
        seats: [
          seatWithHand(base.table.seats[0], const []),
          ...base.table.seats.skip(1),
        ],
        trick: const Trick(plays: [], winnerSeatID: null),
        lastTrick: Trick(
          plays: [
            ...earlierPlays,
            TrickPlay(seatID: 0, card: playedCard),
          ],
          winnerSeatID: 0,
        ),
      ),
      panelJobs,
    );

    var model = before;
    GamePresentationTransition? transition;
    late StateSetter setMotionState;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setMotionState = setState;
            final visibleModel = boardVisibleModelDuringTransition(
              model,
              transition,
            );
            return SizedBox(
              width: 420,
              height: 280,
              child: CardMotionLayer(
                model: model,
                tokens: defaultDesignTokens,
                speed: GameAnimationSpeed.normal,
                transition: transition,
                child: visibleModel.panels.active == panelBrigade
                    ? _CardMotionTestBoard(model: visibleModel)
                    : const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    setMotionState(() {
      model = after;
      transition = GamePresentationTransition(
        id: 23,
        before: before,
        after: after,
        event: EngineTransitionEvent(
          kind: kcTransitionCardMoved,
          playerID: 0,
          card: EngineCardValue(
            suit: suitCode(playedCard.suit)!,
            value: playedCard.value,
          ),
          fromZone: kcObjectZoneHand,
          toZone: kcObjectZoneCurrentTrick,
          fromOwner: 0,
          toOwner: 0,
          targetSuit: -1,
        ),
      );
    });
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      boardVisibleModelDuringTransition(after, transition).panels.active,
      panelBrigade,
    );
    expect(find.byType(FlyingCard), findsOneWidget);
    expect(
      tester.widget<FlyingCard>(find.byType(FlyingCard)).flight.card.id,
      playedCard.id,
    );
  });

  test('prefilled assignment revision opens Fields before card motion', () {
    final after = modelWithActivePanel(
      runtimeModelWith(
        phase: phaseAssignment,
        selection: SelectionState.empty,
        jobs: runtimeModel().table.jobs,
      ),
      panelJobs,
    );
    final transition = GamePresentationTransition(
      id: 24,
      before: after,
      after: after,
      event: const EngineTransitionEvent(
        kind: kcTransitionAssignmentTargeted,
        playerID: 0,
        card: EngineCardValue(suit: 0, value: 11),
        fromZone: kcObjectZoneLastTrick,
        toZone: kcObjectZonePendingAssignment,
        fromOwner: 0,
        toOwner: 0,
        targetSuit: 0,
      ),
      assignmentCardIDs: const ['wheat-11'],
      assignmentTargets: const {'wheat-11': 'wheat'},
    );

    expect(
      boardVisibleModelDuringTransition(after, transition).panels.active,
      panelJobs,
    );
    final resolved = GamePresentationTransition(
      id: 25,
      before: after,
      after: after,
      event: const EngineTransitionEvent(
        kind: kcTransitionTrickResolved,
        playerID: 0,
        card: EngineCardValue(suit: -1, value: 0),
        fromZone: kcObjectZoneCurrentTrick,
        toZone: kcObjectZoneLastTrick,
        fromOwner: -1,
        toOwner: 0,
        targetSuit: -1,
      ),
    );
    final opened = GamePresentationTransition(
      id: 26,
      before: after,
      after: after,
      event: const EngineTransitionEvent(
        kind: kcTransitionAssignmentOpened,
        playerID: 0,
        card: EngineCardValue(suit: -1, value: 0),
        fromZone: kcObjectZoneLastTrick,
        toZone: kcObjectZonePendingAssignment,
        fromOwner: 0,
        toOwner: 0,
        targetSuit: -1,
      ),
    );

    expect(
      boardVisibleModelDuringTransition(after, resolved).panels.active,
      panelBrigade,
    );
    expect(
      boardVisibleModelDuringTransition(after, opened).panels.active,
      panelJobs,
    );
  });

  testWidgets('Fields pulses only cards assigned during the current trick', (
    tester,
  ) async {
    final base = runtimeModel();
    final pendingCard = testCard(
      id: 'wheat-pending',
      suit: 'wheat',
      value: 9,
      pending: true,
    );
    final committedCard = testCard(
      id: 'wheat-committed',
      suit: 'wheat',
      value: 8,
    );
    final model = modelWithActivePanel(
      runtimeModelWith(
        phase: phaseAssignment,
        selection: SelectionState.empty,
        jobs: [
          for (final job in base.table.jobs)
            job.suit == 'wheat'
                ? Job(
                    suit: job.suit,
                    hours: job.hours,
                    requiredHours: job.requiredHours,
                    claimed: job.claimed,
                    reward: job.reward,
                    assignedCards: [committedCard, pendingCard],
                    validAssignmentTarget: job.validAssignmentTarget,
                    highlighted: job.highlighted,
                  )
                : job,
        ],
      ),
      panelJobs,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 600,
          child: StaticHeroGamePanel(
            kind: StaticHeroGamePanelKind.fields,
            model: model,
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            showPlanningPanel: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('pending-assignment-card-pulse-wheat-pending')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('pending-assignment-card-pulse-wheat-committed'),
      ),
      findsNothing,
    );
  });

  testWidgets('all four sequential trick plays use stable zone anchors', (
    tester,
  ) async {
    final base = runtimeModel();
    final cards = [
      base.table.seats[0].hand.single,
      testCard(id: 'sunflower-7', suit: 'sunflower', value: 7),
      testCard(id: 'potato-8', suit: 'potato', value: 8),
      testCard(id: 'beet-10', suit: 'beet', value: 10),
    ];
    final plays = [
      for (final (seatID, card) in cards.indexed)
        TrickPlay(seatID: seatID, card: card),
    ];
    TableViewModel modelAfterPlays(int count) {
      final model = runtimeModelWith(
        phase: count == 4 ? phaseAssignment : phaseTrick,
        selection: SelectionState.empty,
        jobs: base.table.jobs,
        seats: [
          seatWithHand(
            base.table.seats[0],
            count == 0 ? base.table.seats[0].hand : const [],
          ),
          ...base.table.seats.skip(1),
        ],
        trick: count == 4
            ? const Trick(plays: [], winnerSeatID: null)
            : Trick(plays: plays.take(count).toList(), winnerSeatID: null),
        lastTrick: count == 4
            ? Trick(plays: plays, winnerSeatID: 0)
            : const Trick(plays: [], winnerSeatID: null),
      );
      return count == 4 ? modelWithActivePanel(model, panelJobs) : model;
    }

    var model = modelAfterPlays(0);
    GamePresentationTransition? transition;
    late StateSetter setMotionState;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setMotionState = setState;
            final visibleModel = boardVisibleModelDuringTransition(
              model,
              transition,
            );
            return SizedBox(
              width: 420,
              height: 280,
              child: CardMotionLayer(
                model: model,
                tokens: defaultDesignTokens,
                speed: GameAnimationSpeed.normal,
                transition: transition,
                child: _CardMotionTestBoard(model: visibleModel),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    for (var count = 1; count <= 4; count++) {
      final before = model;
      final after = modelAfterPlays(count);
      setMotionState(() {
        model = after;
        transition = GamePresentationTransition(
          id: 40 + count,
          before: before,
          after: after,
        );
      });
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(FlyingCard), findsOneWidget);
      expect(
        tester.widget<FlyingCard>(find.byType(FlyingCard)).flight.card.id,
        cards[count - 1].id,
      );
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(FlyingCard), findsNothing);
    }
  });

  testWidgets('reduced motion completes a card transition without a flight', (
    tester,
  ) async {
    final before = runtimeModel();
    final playedCard = before.table.seats[0].hand.single;
    final after = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: before.table.jobs,
      seats: [
        seatWithHand(before.table.seats[0], const []),
        ...before.table.seats.skip(1),
      ],
      trick: Trick(
        plays: [TrickPlay(seatID: 0, card: playedCard)],
        winnerSeatID: null,
      ),
    );
    var model = before;
    GamePresentationTransition? transition;
    final completed = <int>[];
    late StateSetter setMotionState;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) {
              setMotionState = setState;
              return SizedBox(
                width: 420,
                height: 280,
                child: CardMotionLayer(
                  model: model,
                  tokens: defaultDesignTokens,
                  speed: GameAnimationSpeed.normal,
                  transition: transition,
                  onTransitionComplete: completed.add,
                  child: _CardMotionTestBoard(model: model),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    setMotionState(() {
      model = after;
      transition = GamePresentationTransition(
        id: 21,
        before: before,
        after: after,
      );
    });
    await tester.pump();
    await tester.pump();

    expect(find.byType(FlyingCard), findsNothing);
    expect(completed, [21]);
  });

  testWidgets('disposing during a card flight cancels playback safely', (
    tester,
  ) async {
    final before = runtimeModel();
    final playedCard = before.table.seats[0].hand.single;
    final after = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: before.table.jobs,
      seats: [
        seatWithHand(before.table.seats[0], const []),
        ...before.table.seats.skip(1),
      ],
      trick: Trick(
        plays: [TrickPlay(seatID: 0, card: playedCard)],
        winnerSeatID: null,
      ),
    );
    var model = before;
    GamePresentationTransition? transition;
    final completed = <int>[];
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
                model: model,
                tokens: defaultDesignTokens,
                speed: GameAnimationSpeed.slow,
                transition: transition,
                onTransitionComplete: completed.add,
                child: _CardMotionTestBoard(model: model),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    setMotionState(() {
      model = after;
      transition = GamePresentationTransition(
        id: 22,
        before: before,
        after: after,
      );
    });
    await tester.pump();
    await tester.pump();
    expect(find.byType(FlyingCard), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));

    expect(tester.takeException(), isNull);
    expect(completed, isEmpty);
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

  testWidgets(
    'provisional assignments animate in action order without submit replay',
    (tester) async {
      final cards = [
        testCard(id: 'sunflower-7', suit: 'sunflower', value: 7),
        testCard(id: 'wheat-8', suit: 'wheat', value: 8),
      ];
      final before = runtimeModelWith(
        phase: phaseAssignment,
        selection: SelectionState.empty,
        jobs: runtimeModel().table.jobs,
        lastTrick: Trick(
          plays: [
            TrickPlay(seatID: 2, card: cards[0]),
            TrickPlay(seatID: 3, card: cards[1]),
          ],
          winnerSeatID: 2,
        ),
      );
      TableViewModel pendingModel(int count) => runtimeModelWith(
        phase: phaseAssignment,
        selection: SelectionState.empty,
        jobs: [
          for (final job in before.table.jobs)
            cards.take(count).any((card) => card.suit == job.suit)
                ? Job(
                    suit: job.suit,
                    hours: job.hours,
                    requiredHours: job.requiredHours,
                    claimed: job.claimed,
                    assignedCards: [
                      for (final card in cards.take(count))
                        if (card.suit == job.suit)
                          testCard(
                            id: card.id,
                            suit: card.suit,
                            value: card.value,
                            pending: true,
                          ),
                    ],
                    reward: job.reward,
                    validAssignmentTarget: job.validAssignmentTarget,
                    highlighted: job.highlighted,
                  )
                : job,
        ],
        lastTrick: before.table.lastTrick,
      );
      final pendingFirst = pendingModel(1);
      final pendingBoth = pendingModel(2);
      final after = runtimeModelWith(
        phase: phaseTrick,
        selection: SelectionState.empty,
        jobs: [
          for (final job in before.table.jobs)
            cards.any((card) => card.suit == job.suit)
                ? Job(
                    suit: job.suit,
                    hours: cards
                        .where((card) => card.suit == job.suit)
                        .fold(0, (total, card) => total + card.value),
                    requiredHours: job.requiredHours,
                    claimed: job.claimed,
                    assignedCards: [
                      for (final card in cards)
                        if (card.suit == job.suit) card,
                    ],
                    reward: job.reward,
                    validAssignmentTarget: job.validAssignmentTarget,
                    highlighted: job.highlighted,
                  )
                : job,
        ],
        lastTrick: const Trick(plays: [], winnerSeatID: null),
      );

      var currentModel = before;
      GamePresentationTransition? transition;
      final completedRevisions = <int>[];
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
                  transition: transition,
                  onTransitionComplete: completedRevisions.add,
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
        currentModel = pendingFirst;
        transition = GamePresentationTransition(
          id: 11,
          before: before,
          after: pendingFirst,
          assignmentCardIDs: [cards[0].id],
          assignmentTargets: {cards[0].id: cards[0].suit},
        );
      });
      await tester.pump();
      await tester.pump();
      expect(find.byType(FlyingCard), findsOneWidget);
      expect(
        tester.widget<FlyingCard>(find.byType(FlyingCard)).flight.card.id,
        cards[0].id,
      );
      expect(completedRevisions, isEmpty);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.byType(FlyingCard), findsOneWidget);
      expect(completedRevisions, isEmpty);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(FlyingCard), findsNothing);
      expect(completedRevisions, [11]);

      setMotionState(() {
        currentModel = pendingBoth;
        transition = GamePresentationTransition(
          id: 12,
          before: pendingFirst,
          after: pendingBoth,
          assignmentCardIDs: [cards[1].id],
          assignmentTargets: {cards[1].id: cards[1].suit},
        );
      });
      await tester.pump();
      await tester.pump();
      expect(find.byType(FlyingCard), findsOneWidget);
      expect(
        tester.widget<FlyingCard>(find.byType(FlyingCard)).flight.card.id,
        cards[1].id,
      );
      expect(completedRevisions, [11]);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.byType(FlyingCard), findsOneWidget);
      expect(completedRevisions, [11]);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(FlyingCard), findsNothing);
      expect(completedRevisions, [11, 12]);

      setMotionState(() {
        currentModel = after;
        transition = GamePresentationTransition(
          id: 13,
          before: pendingBoth,
          after: after,
        );
      });
      await tester.pump();
      await tester.pump();
      expect(find.byType(FlyingCard), findsNothing);
      expect(completedRevisions, [11, 12, 13]);
    },
  );

  testWidgets('assignment flights keep running while switching panels', (
    tester,
  ) async {
    final card = testCard(id: 'wheat-9', suit: 'wheat', value: 9);
    final base = runtimeModel();
    final before = runtimeModelWith(
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      lastTrick: Trick(
        plays: [TrickPlay(seatID: 1, card: card)],
        winnerSeatID: 1,
      ),
    );
    final after = runtimeModelWith(
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: [
        for (final job in base.table.jobs)
          job.suit == card.suit
              ? Job(
                  suit: job.suit,
                  hours: job.hours,
                  requiredHours: job.requiredHours,
                  claimed: job.claimed,
                  assignedCards: [
                    testCard(
                      id: card.id,
                      suit: card.suit,
                      value: card.value,
                      pending: true,
                    ),
                  ],
                  reward: job.reward,
                  validAssignmentTarget: job.validAssignmentTarget,
                  highlighted: job.highlighted,
                )
              : job,
      ],
      lastTrick: before.table.lastTrick,
    );
    var model = before;
    GamePresentationTransition? transition;
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
                model: model,
                tokens: defaultDesignTokens,
                speed: GameAnimationSpeed.slow,
                transition: transition,
                child: _ParallelAssignmentMotionTestBoard(card: card),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    setMotionState(() {
      model = after;
      transition = GamePresentationTransition(
        id: 31,
        before: before,
        after: after,
        assignmentCardIDs: [card.id],
        assignmentTargets: {card.id: card.suit},
      );
    });
    await tester.pump();
    await tester.pump();

    var flights = tester
        .widgetList<FlyingCard>(find.byType(FlyingCard))
        .toList();
    expect(flights, hasLength(2));
    expect(
      flights.singleWhere((flight) => flight.visible).flight.audiencePanel,
      panelBrigade,
    );

    setMotionState(() {
      model = modelWithActivePanel(after, panelJobs);
    });
    await tester.pump(const Duration(milliseconds: 200));

    flights = tester.widgetList<FlyingCard>(find.byType(FlyingCard)).toList();
    expect(flights, hasLength(2));
    expect(
      flights.singleWhere((flight) => flight.visible).flight.audiencePanel,
      panelJobs,
    );

    setMotionState(() {
      model = modelWithActivePanel(after, panelNorth);
    });
    await tester.pump(const Duration(milliseconds: 200));

    flights = tester.widgetList<FlyingCard>(find.byType(FlyingCard)).toList();
    expect(flights.where((flight) => flight.visible), isEmpty);
  });

  testWidgets('a revision without card motion completes after layout', (
    tester,
  ) async {
    GamePresentationTransition? transition;
    final completedRevisions = <int>[];
    late StateSetter setMotionState;
    final model = runtimeModel();

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setMotionState = setState;
            return SizedBox(
              width: 420,
              height: 280,
              child: CardMotionLayer(
                model: model,
                tokens: defaultDesignTokens,
                speed: GameAnimationSpeed.normal,
                transition: transition,
                onTransitionComplete: completedRevisions.add,
                child: _CardMotionTestBoard(model: model),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    setMotionState(
      () => transition = GamePresentationTransition(
        id: 2,
        before: model,
        after: model,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(completedRevisions, [2]);
  });

  testWidgets('an already active transition completes after initial layout', (
    tester,
  ) async {
    final model = runtimeModel();
    final completedTransitions = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 420,
          height: 280,
          child: CardMotionLayer(
            model: model,
            tokens: defaultDesignTokens,
            speed: GameAnimationSpeed.normal,
            transition: GamePresentationTransition(
              id: 7,
              before: model,
              after: model,
            ),
            onTransitionComplete: completedTransitions.add,
            child: _CardMotionTestBoard(model: model),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(completedTransitions, [7]);
  });

  testWidgets('field-plan requisition flies a local card to North', (
    tester,
  ) async {
    final before = runtimeModel();
    final card = before.table.seats[0].hand.single;
    final seat = before.table.seats[0];
    final after = runtimeModelWith(
      phase: phaseRequisition,
      selection: SelectionState.empty,
      jobs: before.table.jobs,
      seats: [seatWithHand(seat, const []), ...before.table.seats.skip(1)],
      requisitionEvents: [
        RequisitionEvent(
          seatID: seat.id,
          suit: card.suit,
          card: card,
          message: 'Requisitioned.',
        ),
      ],
      exiledByYear: {
        ...before.table.exiledByYear,
        before.table.year: [card],
      },
    );

    var currentModel = before;
    late StateSetter setMotionState;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setMotionState = setState;
            return SizedBox(
              width: 900,
              height: 600,
              child: CardMotionLayer(
                model: currentModel,
                tokens: defaultDesignTokens,
                speed: GameAnimationSpeed.normal,
                child: StaticHeroGamePanel(
                  kind: StaticHeroGamePanelKind.brigade,
                  model: currentModel,
                  tokens: defaultDesignTokens,
                  language: KolkhozLanguage.en,
                  showPlanningPanel: false,
                ),
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
    expect(plotSeatIDForMotionCard(after, card.id), 0);
  });

  testWidgets(
    'requisitioned card leaves its retained plot source immediately',
    (tester) async {
      final base = runtimeModel();
      final card = base.table.seats[0].hand.single;
      final seat = seatWithPlot(
        seatWithHand(base.table.seats[0], const []),
        PlotState(revealed: [card], hidden: const [], stacks: const []),
      );
      final before = runtimeModelWith(
        phase: phaseTrick,
        selection: SelectionState.empty,
        jobs: base.table.jobs,
        seats: [seat, ...base.table.seats.skip(1)],
      );
      final after = runtimeModelWith(
        phase: phaseRequisition,
        selection: SelectionState.empty,
        jobs: base.table.jobs,
        seats: [seat, ...base.table.seats.skip(1)],
        requisitionEvents: [
          RequisitionEvent(
            seatID: seat.id,
            suit: card.suit,
            card: card,
            message: 'Requisitioned.',
          ),
        ],
        exiledByYear: {
          ...base.table.exiledByYear,
          base.table.year: [card],
        },
      );

      var model = before;
      late StateSetter updateModel;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              updateModel = setState;
              return SizedBox(
                width: 900,
                height: 600,
                child: CardMotionLayer(
                  model: model,
                  tokens: defaultDesignTokens,
                  speed: GameAnimationSpeed.normal,
                  child: StaticHeroGamePanel(
                    kind: StaticHeroGamePanelKind.brigade,
                    model: model,
                    tokens: defaultDesignTokens,
                    language: KolkhozLanguage.en,
                    showPlanningPanel: false,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      updateModel(() => model = after);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(FlyingCard), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is GameCard && widget.card.id == card.id,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('field-plan requisition flies a redacted online card to North', (
    tester,
  ) async {
    final base = runtimeModel();
    final card = base.table.seats[0].hand.single;
    final before = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      seats: [
        seatWithHand(base.table.seats[0], const []),
        ...base.table.seats.skip(1),
      ],
    );
    final redactedOnlineModel = runtimeModelWith(
      phase: phaseRequisition,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      seats: before.table.seats,
      requisitionEvents: [
        RequisitionEvent(
          seatID: 2,
          suit: card.suit,
          card: card,
          message: 'Requisitioned.',
        ),
      ],
      exiledByYear: {
        ...base.table.exiledByYear,
        base.table.year: [card],
      },
    );

    var currentModel = before;
    late StateSetter setMotionState;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setMotionState = setState;
            return SizedBox(
              width: 900,
              height: 600,
              child: CardMotionLayer(
                model: currentModel,
                tokens: defaultDesignTokens,
                speed: GameAnimationSpeed.normal,
                child: StaticHeroGamePanel(
                  kind: StaticHeroGamePanelKind.brigade,
                  model: currentModel,
                  tokens: defaultDesignTokens,
                  language: KolkhozLanguage.en,
                  showPlanningPanel: false,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    setMotionState(() {
      currentModel = redactedOnlineModel;
    });
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(FlyingCard), findsOneWidget);
    expect(plotSeatIDForMotionCard(redactedOnlineModel, card.id), 2);
  });

  testWidgets('field-plan cellar cards flip for their owner on hover and tap', (
    tester,
  ) async {
    final base = runtimeModel();
    final localCard = testCard(id: 'beet-cellar', suit: 'beet', value: 8);
    final opponentCard = testCard(
      id: 'potato-cellar',
      suit: 'potato',
      value: 9,
    );
    final model = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      seats: [
        seatWithPlot(
          base.table.seats[0],
          PlotState(revealed: const [], hidden: [localCard], stacks: const []),
        ),
        seatWithPlot(
          base.table.seats[1],
          PlotState(
            revealed: const [],
            hidden: [opponentCard],
            stacks: const [],
          ),
        ),
        ...base.table.seats.skip(2),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 600,
          child: StaticHeroGamePanel(
            kind: StaticHeroGamePanelKind.brigade,
            model: model,
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            showPlanningPanel: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(InteractiveCardFlip), findsOneWidget);
    expect(find.byKey(ValueKey('cellar-back-${localCard.id}')), findsOneWidget);
    expect(
      find.byKey(ValueKey('cellar-face-${opponentCard.id}')),
      findsNothing,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(Key('static-hero-card-${localCard.id}'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.byKey(ValueKey('cellar-face-${localCard.id}')), findsOneWidget);

    await mouse.moveTo(const Offset(899, 599));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('cellar-back-${localCard.id}')), findsOneWidget);

    await tester.tap(find.byKey(Key('static-hero-card-${localCard.id}')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('cellar-face-${localCard.id}')), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets('field-plan played cards retain their trump artwork', (
    tester,
  ) async {
    final base = runtimeModel();
    final trumpCard = testCard(id: 'wheat-trump', suit: 'wheat', value: 10);
    final model = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      trick: Trick(
        plays: [TrickPlay(seatID: 1, card: trumpCard)],
        winnerSeatID: null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 600,
          child: StaticHeroGamePanel(
            kind: StaticHeroGamePanelKind.brigade,
            model: model,
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            showPlanningPanel: false,
          ),
        ),
      ),
    );

    final playedCard = find.descendant(
      of: find.byKey(Key('static-hero-trick-card-${trumpCard.id}')),
      matching: find.byType(GameCard),
    );
    expect(playedCard, findsOneWidget);
    expect(tester.widget<GameCard>(playedCard).trump, model.table.trump);
    expect(
      cardUsesTrumpTemplate(
        card: tester.widget<GameCard>(playedCard).card,
        trump: tester.widget<GameCard>(playedCard).trump,
      ),
      isTrue,
    );
    expect(
      tester.widget<GameCard>(playedCard).sizeOverride,
      defaultDesignTokens.card.large,
    );
    final highQualityScale = find.descendant(
      of: find.byKey(Key('static-hero-trick-card-${trumpCard.id}')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Transform && widget.filterQuality == FilterQuality.high,
      ),
    );
    expect(highQualityScale, findsOneWidget);
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

    expect(findAppText('17/40'), findsWidgets);
  });

  testWidgets('tapping a top job gauge opens its assigned-card column', (
    tester,
  ) async {
    final base = runtimeModel();
    final wheatJob = Job(
      suit: 'wheat',
      hours: 7,
      requiredHours: jobRequiredHours,
      claimed: false,
      reward: null,
      assignedCards: [testCard(id: 'wheat-7', suit: 'wheat', value: 7)],
      validAssignmentTarget: false,
      highlighted: false,
    );
    final model = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: [wheatJob, ...base.table.jobs.skip(1)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 500,
            child: TopInfoStrip(
              model: model,
              tokens: defaultDesignTokens,
              metrics: ResponsiveBoardMetrics.fromSize(
                const Size(800, 500),
                defaultDesignTokens,
              ),
              language: KolkhozLanguage.en,
              animationSpeed: defaultGameAnimationSpeed,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('job-gauge-button-wheat')));
    await tester.pump();

    final gauge = find.byKey(const ValueKey('job-gauge-button-wheat'));
    final overlay = find.byKey(const ValueKey('job-gauge-overlay-wheat'));
    expect(overlay, findsOneWidget);
    expect(find.byType(JobTile), findsOneWidget);
    expect(tester.getTopLeft(overlay).dx, greaterThanOrEqualTo(0));
    expect(
      tester.getTopLeft(overlay).dy,
      greaterThan(tester.getBottomLeft(gauge).dy),
    );

    await tester.tapAt(const Offset(700, 450));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('job-gauge-overlay-wheat')), findsNothing);
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
              testCard(id: 'wrecker-0', suit: wreckerSuit, value: 0),
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
      'assets/ui/Icons/icon-variant-saboteur.png',
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
    final controller = CardMotionController();
    final rootKey = GlobalKey();
    final wheat7 = testCard(id: 'wheat-7', suit: 'wheat', value: 7);
    final wheat8 = testCard(id: 'wheat-8', suit: 'wheat', value: 8);

    Widget gaugeWithCards(List<TableCard> cards, {bool claimed = false}) {
      return MaterialApp(
        home: CardMotionScope(
          controller: controller,
          frame: 0,
          rootKey: rootKey,
          activeCardIDs: const {},
          child: JobGauge(
            job: Job(
              suit: 'wheat',
              hours: cards
                  .where((card) => !card.pending)
                  .fold(10, (total, card) => total + card.value),
              requiredHours: jobRequiredHours,
              claimed: claimed,
              reward: testCard(id: 'wheat-1', suit: 'wheat', value: 1),
              assignedCards: cards,
              validAssignmentTarget: false,
              highlighted: false,
            ),
            highlighted: false,
            width: 118,
            height: 38,
            tokens: defaultDesignTokens,
          ),
        ),
      );
    }

    final pendingWheat7 = testCard(
      id: 'wheat-7',
      suit: 'wheat',
      value: 7,
      pending: true,
    );
    final pendingWheat8 = testCard(
      id: 'wheat-8',
      suit: 'wheat',
      value: 8,
      pending: true,
    );
    await tester.pumpWidget(gaugeWithCards(const []));
    await tester.pumpWidget(gaugeWithCards([pendingWheat7]));

    expect(findAppText('10/40'), findsWidgets);
    expect(findAppText('+7'), findsNothing);

    controller.recordJobCardArrival(
      const JobCardArrival(cardID: 'wheat-7', suit: 'wheat'),
    );
    await tester.pump();
    expect(findAppText('17/40'), findsWidgets);
    expect(findAppText('+7'), findsWidgets);
    await tester.pumpAndSettle();

    await tester.pumpWidget(gaugeWithCards([pendingWheat7, pendingWheat8]));
    expect(findAppText('17/40'), findsWidgets);

    controller.recordJobCardArrival(
      const JobCardArrival(cardID: 'wheat-8', suit: 'wheat'),
    );
    await tester.pump();
    expect(findAppText('25/40'), findsWidgets);
    expect(findAppText('+8'), findsWidgets);
    await tester.pumpAndSettle();

    await tester.pumpWidget(gaugeWithCards([wheat7, wheat8]));
    controller.recordJobCardArrival(
      const JobCardArrival(cardID: 'wheat-7', suit: 'wheat'),
    );
    controller.recordJobCardArrival(
      const JobCardArrival(cardID: 'wheat-8', suit: 'wheat'),
    );
    await tester.pump();
    expect(findAppText('+7'), findsNothing);
    expect(findAppText('+8'), findsNothing);

    await tester.pumpWidget(
      gaugeWithCards([
        wheat7,
        wheat8,
        testCard(id: 'wheat-15', suit: 'wheat', value: 15),
      ], claimed: true),
    );
    expect(findAppText('25/40'), findsWidgets);
    controller.recordJobCardArrival(
      const JobCardArrival(cardID: 'wheat-15', suit: 'wheat'),
    );
    await tester.pump();
    expect(findAppText('40/40'), findsWidgets);
  });

  test('AI card flights originate from the player info card', () {
    const badgeRect = Rect.fromLTWH(100, 40, 220, 88);
    final model = runtimeModel();
    final source = cardFlightSourceRect(
      cardID: 'sunflower-7',
      previousZone: const MotionZone.hand(2),
      nextZone: const MotionZone.trick(2),
      previousRects: MotionGeometry({
        const MotionAnchor.card('sunflower-7'): const Rect.fromLTWH(
          10,
          10,
          70,
          99,
        ),
        playerCardMotionSourceKey(2): badgeRect,
      }),
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
        previousZone: const MotionZone.hand(2),
        nextZone: const MotionZone.trick(1),
        previousRects: MotionGeometry({
          playerCardMotionSourceKey(2): badgeRect,
        }),
        model: model,
        tokens: defaultDesignTokens,
      ),
      isNull,
    );
    expect(
      cardFlightDurationScale(
        previousZone: const MotionZone.hand(2),
        nextZone: const MotionZone.trick(2),
        model: model,
      ),
      playerInfoCardFlightDurationScale,
    );
    expect(
      cardFlightDurationScale(
        previousZone: const MotionZone.hand(0),
        nextZone: const MotionZone.trick(0),
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

  test(
    'trick flights prefer the played card then fall back to hand anchors',
    () {
      const playerRect = Rect.fromLTWH(24, 208, 96, 42);
      const handRect = Rect.fromLTWH(18, 220, 280, 72);
      const playedCardRect = Rect.fromLTWH(360, 220, 42, 60);
      const trickRect = Rect.fromLTWH(220, 76, 42, 60);
      final exactCardSource = cardFlightSourceRect(
        cardID: 'wheat-11',
        previousZone: const MotionZone.hand(0),
        nextZone: const MotionZone.trick(0),
        previousRects: MotionGeometry({
          handCardMotionSourceKey(0): handRect,
          const MotionAnchor.card('wheat-11'): playedCardRect,
        }),
        model: runtimeModel(),
        tokens: defaultDesignTokens,
      );
      final stableHandSource = cardFlightSourceRect(
        cardID: 'wheat-11',
        previousZone: const MotionZone.hand(0),
        nextZone: const MotionZone.trick(0),
        previousRects: MotionGeometry({handCardMotionSourceKey(0): handRect}),
        model: runtimeModel(),
        tokens: defaultDesignTokens,
      );
      final source = cardFlightFallbackSourceRect(
        previousZone: const MotionZone.hand(0),
        nextZone: const MotionZone.trick(0),
        currentRects: MotionGeometry({
          playerCardMotionSourceKey(0): playerRect,
        }),
        tokens: defaultDesignTokens,
      );
      final destination = cardFlightDestinationRect(
        cardID: 'wheat-11',
        previousZone: const MotionZone.hand(0),
        nextZone: const MotionZone.trick(0),
        currentRects: MotionGeometry({trickCardMotionTargetKey(0): trickRect}),
        tokens: defaultDesignTokens,
      );

      expect(exactCardSource, playedCardRect);
      expect(stableHandSource, isNotNull);
      expect(stableHandSource!.center, handRect.center);
      expect(source, isNotNull);
      expect(source!.center, playerRect.center);
      expect(destination, isNotNull);
      expect(destination!.center, trickRect.center);
      expect(
        destination.height,
        closeTo(defaultDesignTokens.card.small.height, 0.001),
      );
    },
  );

  test('requisition card flights use the shared North motion route', () {
    const northIconRect = Rect.fromLTWH(8, 128, 42, 42);
    const oldTopTarget = Rect.fromLTWH(400, 0, 42, 42);
    final destination = cardFlightDestinationRect(
      cardID: 'wheat-9',
      previousZone: const MotionZone.plotRevealed(0),
      nextZone: const MotionZone.exiled(1),
      currentRects: MotionGeometry({
        northRailCardMotionTargetKey: northIconRect,
        northCardMotionTargetKey: oldTopTarget,
      }),
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
    expect(const MotionZone.plotStackRevealed(2, 0).seatID, 2);

    const plotRect = Rect.fromLTWH(120, 240, 320, 180);
    final fallbackSource = cardFlightFallbackSourceRect(
      previousZone: const MotionZone.plotRevealed(2),
      nextZone: const MotionZone.exiled(1),
      currentRects: MotionGeometry({plotCardMotionSourceKey(2): plotRect}),
      tokens: defaultDesignTokens,
    );

    expect(fallbackSource, isNotNull);
    expect(fallbackSource!.center, plotRect.center);
    expect(
      cardFlightDurationScale(
        previousZone: const MotionZone.plotRevealed(2),
        nextZone: const MotionZone.exiled(1),
        model: runtimeModel(),
      ),
      requisitionCardFlightDurationScale,
    );
    expect(
      cardFlightDurationScale(
        previousZone: const MotionZone.hand(2),
        nextZone: const MotionZone.northExile(),
        model: runtimeModel(),
      ),
      requisitionCardFlightDurationScale,
    );

    final card = testCard(id: 'hidden-wheat-9', suit: 'wheat', value: 9);
    final plan = planCardFlights(
      motionEnabled: true,
      minimumFlightDistance: GameMotion.minimumFlightDistance,
      previousModel: runtimeModel(),
      nextModel: runtimeModel(),
      previousZones: {card.id: const MotionZone.plotHidden(0)},
      nextZones: {card.id: const MotionZone.northExile()},
      previousCards: {card.id: card},
      nextCards: {card.id: card},
      previousGeometry: MotionGeometry({
        MotionAnchor.card(card.id): const Rect.fromLTWH(120, 240, 48, 68),
      }),
      currentGeometry: MotionGeometry({
        northRailCardMotionTargetKey: northIconRect,
      }),
      geometry: const DefaultCardMotionGeometryResolver(defaultDesignTokens),
      transitionID: 1,
      assignmentCardIDs: const [],
      assignmentTargets: const {},
      suppressedCardIDs: const {},
      presentedAssignmentCardIDs: const {},
      initialFlightID: 0,
    );

    expect(plan.flights.single.revealBeforeFlight, isTrue);
    expect(plan.flights.single.requisitioned, isTrue);
  });

  test('job assignment flights can target top gauges', () {
    const gaugeRect = Rect.fromLTWH(220, 12, 112, 38);
    const assignedCardRect = Rect.fromLTWH(16, 420, 74, 104);
    const trickCardRect = Rect.fromLTWH(260, 180, 136, 192);
    final source = cardFlightSourceRect(
      cardID: 'wheat-9',
      previousZone: const MotionZone.trick(1),
      nextZone: const MotionZone.job('wheat'),
      previousRects: MotionGeometry({
        const MotionAnchor.card('wheat-9'): assignedCardRect,
        trickCardMotionSourceKey('wheat-9'): trickCardRect,
      }),
      model: runtimeModel(),
      tokens: defaultDesignTokens,
    );
    final destination = cardFlightDestinationRect(
      cardID: 'wheat-9',
      previousZone: const MotionZone.trick(1),
      nextZone: const MotionZone.job('wheat'),
      currentRects: MotionGeometry({
        const MotionAnchor.card('wheat-9'): assignedCardRect,
        jobGaugeMotionTargetKey('wheat'): gaugeRect,
      }),
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
        previousZone: const MotionZone.trick(1),
        nextZone: const MotionZone.job('wheat'),
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

  test('claimed reward cards fly from their job gauge to the player plot', () {
    const gaugeRect = Rect.fromLTWH(220, 12, 112, 38);
    const plotCardRect = Rect.fromLTWH(96, 320, 74, 104);
    final model = runtimeModel();
    final source = cardFlightSourceRect(
      cardID: 'wheat-9',
      previousZone: const MotionZone.reward('wheat'),
      nextZone: const MotionZone.plotRevealed(2),
      previousRects: MotionGeometry({
        jobGaugeMotionTargetKey('wheat'): gaugeRect,
      }),
      model: model,
      tokens: defaultDesignTokens,
    );
    final destination = cardFlightDestinationRect(
      cardID: 'wheat-9',
      previousZone: const MotionZone.reward('wheat'),
      nextZone: const MotionZone.plotRevealed(2),
      currentRects: MotionGeometry({
        const MotionAnchor.card('wheat-9'): plotCardRect,
      }),
      tokens: defaultDesignTokens,
    );

    expect(source, isNotNull);
    expect(source!.center, gaugeRect.center);
    expect(source.width, closeTo(defaultDesignTokens.card.small.width, 0.001));
    expect(destination, plotCardRect);
  });

  testWidgets('active reward flight hides its revealed plot destination', (
    tester,
  ) async {
    final reward = testCard(id: 'wheat-reward-9', suit: 'wheat', value: 9);
    final controller = CardMotionController();
    final rootKey = GlobalKey();
    var activeCardIDs = {reward.id};
    var frame = 0;
    late StateSetter updateMotion;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateMotion = setState;
            return CardMotionScope(
              controller: controller,
              frame: frame,
              rootKey: rootKey,
              activeCardIDs: activeCardIDs,
              child: SizedBox(
                key: rootKey,
                width: 240,
                height: 160,
                child: Stack(
                  children: plotOverviewCardItems(
                    cards: [reward],
                    stacks: const [],
                    hiddenCards: false,
                    cardSize: defaultDesignTokens.card.small,
                    selectedCardID: null,
                    selectable: false,
                    zone: plotZoneRevealed,
                    exiledCardIDs: const {},
                    tokens: defaultDesignTokens,
                    onPlotCardTap: null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    final trackedReward = find.byWidgetPredicate(
      (widget) => widget is MotionTrackedCard && widget.card.id == reward.id,
    );
    expect(trackedReward, findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: trackedReward, matching: find.byType(Opacity)),
          )
          .opacity,
      0,
    );

    updateMotion(() {
      activeCardIDs = const {};
      frame += 1;
    });
    await tester.pump();

    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: trackedReward, matching: find.byType(Opacity)),
          )
          .opacity,
      1,
    );
  });

  test('job assignments produce parallel brigade and fields flights', () {
    const gaugeTarget = Rect.fromLTWH(220, 12, 74, 104);
    const fieldRect = Rect.fromLTWH(16, 220, 240, 160);
    final card = testCard(id: 'wheat-9', suit: 'wheat', value: 9);
    final plan = addParallelJobPanelFlights(
      plan: CardMotionPlan(
        transitionID: 9,
        stages: [
          [
            CardFlight(
              id: 4,
              card: card,
              from: const Rect.fromLTWH(300, 120, 74, 104),
              to: gaugeTarget,
              destinationZone: const MotionZone.job('wheat'),
            ),
          ],
        ],
        immediateJobArrivals: const [],
        presentedAssignmentCardIDs: {card.id},
        nextFlightID: 5,
      ),
      currentGeometry: MotionGeometry({
        jobFieldMotionTargetKey('wheat'): fieldRect,
      }),
      tokens: defaultDesignTokens,
    );

    final flights = plan.stages.single;
    expect(flights, hasLength(2));
    expect(flights[0].audiencePanel, panelBrigade);
    expect(flights[0].to, gaugeTarget);
    expect(flights[0].reportsJobArrival, isTrue);
    expect(flights[1].audiencePanel, panelJobs);
    expect(flights[1].to.center, fieldRect.center);
    expect(flights[1].reportsJobArrival, isFalse);
    expect(plan.nextFlightID, 6);
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

    expect(calls, ['new', 'tutorial', 'menu', 'language', 'appearance']);
    expect(confirmNewGame, isFalse);
    expect(confirmMainMenu, isFalse);
    expect(showInvalidTapHints, isFalse);
    expect(selectedSpeed, GameAnimationSpeed.slow);
    expect(selectedCardBack, isNull);
  });
}
