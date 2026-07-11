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

  testWidgets('medals pulse when a player is one trick from Hero', (
    tester,
  ) async {
    final base = runtimeModel();
    final seats = [
      for (final seat in base.table.seats)
        seat.id == 1 ? seatWithMedals(seat, 3) : seat,
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

  testWidgets('requisition flies a newly plotted hand card to North', (
    tester,
  ) async {
    final before = runtimeModel();
    final card = before.table.seats[0].hand.single;
    final seat = before.table.seats[0];
    final after = runtimeModelWith(
      phase: phaseRequisition,
      selection: SelectionState.empty,
      jobs: before.table.jobs,
      seats: [
        seatWithPlot(
          seatWithHand(seat, const []),
          PlotState(revealed: const [], hidden: [card], stacks: const []),
        ),
        ...before.table.seats.skip(1),
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
              width: 420,
              height: 280,
              child: CardMotionLayer(
                model: currentModel,
                tokens: defaultDesignTokens,
                speed: GameAnimationSpeed.normal,
                child: const _RequisitionMotionTestBoard(),
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

    final redactedOnlineModel = runtimeModelWith(
      phase: phaseRequisition,
      selection: SelectionState.empty,
      jobs: before.table.jobs,
      requisitionEvents: [
        RequisitionEvent(
          seatID: 2,
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
    expect(plotSeatIDForMotionCard(redactedOnlineModel, card.id), 2);
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
}
