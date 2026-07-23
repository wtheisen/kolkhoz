part of '../widget_test.dart';

void registerTutorialAndLayoutTests() {
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
                iconPath: 'assets/ui/Icons/icon-tutorial.png',
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
    expect(
      find.byKey(const Key('production-static-hero-brigade')),
      findsOneWidget,
    );
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
    expect(
      find.byKey(const Key('production-static-hero-brigade')),
      findsOneWidget,
    );
  });

  testWidgets('compact fallback keeps four seat columns in landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(667, 375));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrigadePanel(
            model: runtimeModel(),
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            compact: true,
          ),
        ),
      ),
    );

    final seatPositions = tester
        .widgetList<BrigadePlayerColumn>(find.byType(BrigadePlayerColumn))
        .map((seat) => tester.getTopLeft(find.byWidget(seat)))
        .toList();
    expect(seatPositions, hasLength(4));
    expect(seatPositions.map((position) => position.dy).toSet(), hasLength(1));
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
    expect(find.textContaining('PLAYER'), findsOneWidget);
    expect(find.textContaining('SCORE'), findsOneWidget);
    expect(find.textContaining('HAND'), findsOneWidget);
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
      id: 'wrecker-0',
      suit: wreckerSuit,
      value: 0,
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
    expect(faceAssetPath(jack), 'assets/ui/Cards/face-jack-wheat.png');
    expect(
      faceAssetPath(nomenklaturaQueen),
      'assets/ui/Cards/face-queen-beet-nomenklatura.png',
    );
    expect(genericFaceAssetPath(queen), 'assets/ui/Cards/face-queen.png');
    expect(faceRankName(wrecker), 'saboteur');
    expect(cardRankDisplayLabel(wrecker), 'S 0');
    expect(faceArtWidth(defaultDesignTokens.card.large), 31.5);
    expect(facePortraitArtWidth(jack, defaultDesignTokens.card.large), 63);
    expect(
      facePortraitArtWidth(wrecker, defaultDesignTokens.card.large),
      40.95,
    );
    expect(faceAssetPath(wrecker), 'assets/ui/Cards/face-wrecker.png');
    expect(genericFaceAssetPath(wrecker), 'assets/ui/Cards/face-wrecker.png');
    expect(portraitAssetPath(seat), 'assets/ui/worker1.png');
    expect(
      cardTemplateAssetPath(
        card: jack,
        tokens: defaultDesignTokens,
        trump: 'wheat',
      ),
      'assets/ui/Cards/card-template-dark.png',
    );
    expect(
      cardTemplateAssetPath(
        card: jack,
        tokens: lightDesignTokens,
        trump: 'beet',
      ),
      'assets/ui/Cards/card-template-light-no-overlay.png',
    );
    expect(
      cardTemplateAssetPath(
        card: jack,
        tokens: defaultDesignTokens,
        trump: null,
      ),
      'assets/ui/Cards/card-template-dark-no-overlay.png',
    );
    expect(cardUsesTrumpTemplate(card: wrecker, trump: 'beet'), isTrue);
    expect(
      cardTemplateAssetPath(
        card: wrecker,
        tokens: lightDesignTokens,
        trump: null,
      ),
      'assets/ui/Cards/card-template-light.png',
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
