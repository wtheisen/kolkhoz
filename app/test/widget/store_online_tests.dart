part of '../widget_test.dart';

void registerStoreAndOnlineTests() {
  testWidgets(
    'game controller owns four players and routes Central Planner reveals',
    (tester) async {
      final unloadedPolicy = Completer<KolkhozNativePolicyModel>().future;
      final store = GameController(
        autosaveEnabled: false,
        mediumPolicyLoader: unloadedPolicy,
        neuralPolicyLoader: unloadedPolicy,
      )..animationSpeed = GameAnimationSpeed.instant;
      addTearDown(store.dispose);
      expect(store.lifecycle, GameControllerLifecycle.lobby);
      expect(store.model, isNull);
      expect(store.lobby.seats, hasLength(4));
      expect(store.lobby.players, orderedEquals(store.players));

      store.addSpectator(const GameSpectator(id: 'viewer-1'));
      expect(store.lobby.spectators.single.id, 'viewer-1');
      store.removeSpectator('viewer-1');
      expect(store.lobby.spectators, isEmpty);

      store.configureLobby(
        variants: KolkhozGameVariants.kolkhoz,
        controllers: const [
          KolkhozPlayerController.human,
          KolkhozPlayerController.heuristicAI,
          KolkhozPlayerController.mediumAI,
          KolkhozPlayerController.neuralAI,
        ],
      );
      store.startGame(persist: false);

      expect(store.players, hasLength(4));
      expect(store.players[0], isA<HumanPlayer>());
      expect(store.players[1], isA<HeuristicAIPlayer>());
      expect(store.players[2], isA<NeuralAIPlayer>());
      expect(store.players[3], isA<NeuralAIPlayer>());
      expect(
        () => store.configureLobby(
          variants: KolkhozGameVariants.demoKolkhoz,
          controllers: store.controllers,
        ),
        throwsStateError,
      );
      await tester.pump(const Duration(milliseconds: 1));

      expect(store.error, isNull);
      expect(store.actionLog.single.kind, actionRevealReward);
      expect(store.presentationRevision, isNotNull);
      expect(store.lifecycle, GameControllerLifecycle.playing);

      store.returnToLobby();
      expect(store.lifecycle, GameControllerLifecycle.lobby);
      expect(store.model, isNull);
    },
  );

  testWidgets(
    'finished game keeps a portable snapshot and releases its local engine',
    (tester) async {
      final store = GameController(autosaveEnabled: false)
        ..animationSpeed = GameAnimationSpeed.instant;
      addTearDown(store.dispose);
      store.startGame(
        persist: false,
        variants: KolkhozGameVariants.demoKolkhoz,
        controllers: const [
          KolkhozPlayerController.human,
          KolkhozPlayerController.heuristicAI,
          KolkhozPlayerController.heuristicAI,
          KolkhozPlayerController.heuristicAI,
        ],
      );

      const priority = {
        actionRevealReward: 0,
        actionRevealTrump: 0,
        actionSubmitAssignments: 1,
        actionContinueAfterRequisition: 1,
        actionConfirmSwap: 1,
        actionSetTrump: 2,
        actionPlayCard: 2,
        actionAssign: 2,
        actionSwap: 3,
        actionUndoSwap: 4,
      };
      for (var guard = 0; guard < 1000; guard += 1) {
        final revision = store.presentationRevision;
        if (revision != null) {
          store.acknowledgeRevisionPresented(revision);
        }
        if (store.lifecycle == GameControllerLifecycle.finished) {
          break;
        }
        final actions = [...?store.model?.legalActions]
          ..sort(
            (left, right) =>
                (priority[left.kind] ?? 9).compareTo(priority[right.kind] ?? 9),
          );
        if (actions.isNotEmpty) {
          store.applyLegalAction(actions.first);
        }
        await tester.pump(const Duration(milliseconds: 1));
      }

      final finished = store.finishedGameLobby;
      expect(store.lifecycle, GameControllerLifecycle.finished);
      expect(store.hasActiveEngine, isFalse);
      expect(finished, isNotNull);
      expect(finished!.model.table.phase, phaseGameOver);
      expect(finished.gameLogActions, isNotEmpty);
      expect(
        finished.gameState.toJson()['state'],
        containsPair('phase', phaseGameOver),
      );

      final result = finished.result;
      store.setActivePanel(panelLog);
      expect(store.finishedGameLobby!.result, same(result));
      expect(store.model!.panels.active, panelLog);
      expect(store.hasActiveEngine, isFalse);
    },
  );

  test(
    'Start Online Game hands the controller draft to the server once',
    () async {
      final httpClient = FakeOnlineHttpClient();
      final store = GameController(
        autosaveEnabled: false,
        onlineHttpClient: httpClient,
        onlineWebSocketConnector: (_, _) async =>
            throw const SocketException('realtime unavailable'),
      );
      addTearDown(store.dispose);
      final draftVariants = KolkhozGameVariants.kolkhoz.copyWith(
        maxYears: 3,
        passCards: true,
      );
      const draftControllers = [
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.heuristicAI,
        KolkhozPlayerController.mediumAI,
      ];

      store.configureLobby(
        variants: draftVariants,
        controllers: draftControllers,
      );

      expect(httpClient.requests, isEmpty);

      await store.startOnlineGame(
        baseURL: Uri.parse('http://online.example'),
        ranked: false,
        browserJoinable: true,
      );

      final createRequest = httpClient.requests.singleWhere(
        (request) => request.route == 'POST /sessions',
      );
      final body = jsonDecode(createRequest.body) as Map<String, dynamic>;
      final variants = body['variants'] as Map<String, dynamic>;
      expect(variants['maxYears'], 3);
      expect(variants['passCards'], isTrue);
      expect(body['controllers'], [
        'human',
        'human',
        'heuristicAI',
        'mediumAI',
      ]);
      expect(store.isOnlineGame, isTrue);
      expect(
        () => store.configureLobby(
          variants: KolkhozGameVariants.littleKolkhoz,
          controllers: KolkhozPlayerController.defaultControllers,
        ),
        throwsStateError,
      );
    },
  );

  test('store auto-selects the only legal trick card', () {
    const play = EngineAction(
      kind: actionPlayCard,
      playerID: 0,
      card: EngineCard(suit: 'wheat', value: 9),
    );
    final model = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
      legalActions: const [
        LegalAction(kind: actionPlayCard, label: 'Play', engineAction: play),
      ],
    );

    final selected = autoSelectCards(const GameUiState(), model);

    expect(selected.selection.handCardID, 'wheat-9');
  });

  test('store auto-selects the top remaining assignment card', () {
    final wheat9 = testCard(id: 'wheat-9', suit: 'wheat', value: 9);
    final beet10 = testCard(id: 'beet-10', suit: 'beet', value: 10);
    final model = runtimeModelWith(
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
      lastTrick: Trick(
        plays: [
          TrickPlay(seatID: 0, card: wheat9),
          TrickPlay(seatID: 1, card: beet10),
        ],
        winnerSeatID: 0,
      ),
    );

    final selected = autoSelectCards(const GameUiState(), model);
    final manualSelection = autoSelectCards(
      const GameUiState().selectAssignmentCard('wheat-9'),
      model,
    );

    expect(selected.selection.assignmentCardID, 'beet-10');
    expect(manualSelection.selection.assignmentCardID, 'wheat-9');
  });

  test('completed games return to the lobby section they launched from', () {
    expect(KolkhozGameLaunchOrigin.created.returnsToJoinGame, isFalse);
    expect(KolkhozGameLaunchOrigin.joined.returnsToJoinGame, isTrue);
  });

  test('online gameplay fallback refreshes once per second', () {
    expect(onlineGameRefreshInterval, const Duration(seconds: 1));
    expect(onlineGameRealtimeRefreshInterval, const Duration(seconds: 15));
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
    const submitAssignments = EngineAction(
      kind: actionSubmitAssignments,
      playerID: 0,
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
      isNull,
    );
    expect(
      gameSoundCueForTransition(
        previous: assignment,
        next: assignment,
        previousActionCount: 0,
        actions: const [submitAssignments],
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

  test('face-card voices replace only the standard card-play sound', () {
    const voice = 'audio/voice_lines/jack-wheat.wav';
    expect(gameSoundCueWithVoiceOverride(GameSoundCue.cardPlay, voice), isNull);
    expect(
      gameSoundCueWithVoiceOverride(GameSoundCue.trickWin, voice),
      GameSoundCue.trickWin,
    );
    expect(
      gameSoundCueWithVoiceOverride(GameSoundCue.cardPlay, null),
      GameSoundCue.cardPlay,
    );
  });

  test('assignment work cues follow crop and layer saboteur damage', () {
    final model = runtimeModelWith(
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
    );
    const potato = EngineAction(
      kind: actionAssign,
      playerID: 0,
      card: EngineCard(suit: 'potato', value: 9),
      targetSuit: 'potato',
    );
    expect(
      assignmentWorkAssetsForTransition(
        previous: model,
        previousActionCount: 0,
        actions: const [potato],
      ),
      const ['audio/assignment_potato.wav'],
    );

    const saboteur = EngineAction(
      kind: actionAssign,
      playerID: 0,
      card: EngineCard(suit: wreckerSuit, value: 0),
      targetSuit: 'beet',
    );
    expect(
      assignmentWorkAssetsForTransition(
        previous: model,
        previousActionCount: 0,
        actions: const [saboteur],
      ),
      const ['audio/assignment_beet.wav', 'audio/assignment_saboteur.wav'],
    );
  });

  test('face-card voice cues follow rank, crop, and projected variant', () {
    final base = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
    );
    final ordinaryQueen = runtimeModelWith(
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
      trick: Trick(
        plays: [
          TrickPlay(
            seatID: 2,
            card: testCard(id: 'sunflower-12', suit: 'sunflower', value: 12),
          ),
        ],
        winnerSeatID: null,
      ),
    );
    const queenAction = EngineAction(
      kind: actionPlayCard,
      playerID: 2,
      card: EngineCard(suit: 'sunflower', value: 12),
    );
    expect(
      faceCardVoiceAssetForTransition(
        previous: base,
        next: ordinaryQueen,
        previousActionCount: 0,
        actions: const [queenAction],
      ),
      'audio/voice_lines/queen-sunflower.wav',
    );

    final nomenklaturaKing = runtimeModelWith(
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
      lastTrick: Trick(
        plays: [
          TrickPlay(
            seatID: 1,
            card: testCard(
              id: 'beet-13',
              suit: 'beet',
              value: 13,
              nomenclature: true,
            ),
          ),
        ],
        winnerSeatID: 1,
      ),
    );
    const kingAction = EngineAction(
      kind: actionPlayCard,
      playerID: 1,
      card: EngineCard(suit: 'beet', value: 13),
    );
    expect(
      faceCardVoiceAssetForTransition(
        previous: base,
        next: nomenklaturaKing,
        previousActionCount: 0,
        actions: const [kingAction],
      ),
      'audio/voice_lines/nomenklatura-king-beet.wav',
    );
  });

  testWidgets('face-card voice assets use their root bundle keys', (
    tester,
  ) async {
    expect(
      await rootBundle.load('assets/audio/voice_lines/jack-wheat.wav'),
      isNotNull,
    );
  });

  test(
    'saboteur voice alternates deterministically and ignores number cards',
    () {
      final yearOne = runtimeModelWith(
        phase: phaseTrick,
        selection: SelectionState.empty,
        jobs: runtimeModel().table.jobs,
        year: 1,
      );
      const saboteur = EngineAction(
        kind: actionPlayCard,
        playerID: 1,
        card: EngineCard(suit: wreckerSuit, value: 0),
      );
      expect(
        faceCardVoiceAssetForTransition(
          previous: yearOne,
          next: yearOne,
          previousActionCount: 0,
          actions: const [saboteur],
        ),
        'audio/voice_lines/saboteur-wrench.wav',
      );
      const numberCard = EngineAction(
        kind: actionPlayCard,
        playerID: 0,
        card: EngineCard(suit: 'wheat', value: 10),
      );
      expect(
        faceCardVoiceAssetForTransition(
          previous: yearOne,
          next: yearOne,
          previousActionCount: 0,
          actions: const [numberCard],
        ),
        isNull,
      );
    },
  );

  test('kolkhoz default includes saboteur without a duplicate preset', () {
    expect(KolkhozGameVariants.kolkhoz.wreckerCard, isTrue);
    expect(KolkhozGameVariants.kolkhoz.passCards, isFalse);
    expect(
      KolkhozGameVariants.kolkhoz.copyWith(passCards: true).passCards,
      isTrue,
    );
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
      'assets/ui/Icons/icon-settings-assist.png',
      'assets/ui/Icons/icon-settings-display.png',
      'assets/ui/Icons/icon-settings-rules.png',
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

    expect(findAssetImage('assets/ui/Icons/icon-year-2.png'), findsOneWidget);
    expect(findAssetImage('assets/ui/Icons/icon-menu.png'), findsOneWidget);
    expect(findAssetImage('assets/ui/Icons/icon-brigade.png'), findsOneWidget);
    expect(findAssetImage('assets/ui/Icons/icon-jobs.png'), findsOneWidget);
    expect(findAssetImage('assets/ui/Icons/icon-north.png'), findsOneWidget);
    expect(findAssetImage('assets/ui/Icons/icon-plot.png'), findsOneWidget);
    expect(findAssetImage('assets/ui/Icons/icon-game-log.png'), findsOneWidget);
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

  testWidgets('planning trump chooser waits for confirmation', (tester) async {
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
    expect(
      tester
          .widget<ActionIconButton>(
            find.byKey(const Key('hand-console-primary')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byType(TrumpSelectionButton).first);
    await tester.pump();
    expect(selectedAction, isNull);

    await tester.tap(find.byKey(const Key('hand-console-primary')));
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
    expect(opponentSections.first.value, '17');
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
                  'assets/ui/Icons/icon-medal-star.png',
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
      findsNWidgets(5),
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

  test('saved games migrate the legacy saboteur value to zero', () {
    final action = engineActionFromJson({
      'kind': actionPlayCard,
      'playerID': 0,
      'card': {'suit': wreckerSuit, 'value': 14},
    });

    expect(action.card?.id, 'wrecker-0');
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

  test('online North cards preserve the losing player', () {
    final json = onlineUpdateJson();
    final snapshot = json['snapshot'] as Map<String, Object?>;
    snapshot['exiled'] = onlineSuitCardsJson(
      count: finalGameYear + 1,
      cardsBySuit: {
        1: [onlineCardJson(2, 10)],
      },
    );
    snapshot['exiledPlayers'] = [
      for (var year = 0; year <= finalGameYear; year++)
        {
          'suit': year,
          'values': year == 1 ? [2] : <int>[],
        },
    ];

    final model = OnlineTableProjection(
      update: OnlineSessionUpdate.fromJson(json),
      playerID: 0,
      legalActions: const [],
    ).project();

    expect(model.table.exiledByYear[1]!.single.id, 'potato-10');
    expect(model.table.exiledByYear[1]!.single.ownerSeatID, 2);
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

  test('presentation queue separates committed and deferred revisions', () {
    final revisionOne = OnlineSessionUpdate.fromJson(
      onlineUpdateJson()..['actionLogCount'] = 1,
    );
    final revisionTwo = OnlineSessionUpdate.fromJson(
      onlineUpdateJson()..['actionLogCount'] = 2,
    );
    final queue = GameEventQueue()
      ..add(
        OnlineActionUpdate(
          revision: 1,
          action: const OnlineEngineAction(
            kind: kcActionSetTrump,
            playerID: 0,
            suit: 0,
          ),
          update: revisionOne,
        ),
      )
      ..defer(revisionOne)
      ..defer(revisionTwo);

    expect(queue.knownRevision(0), 1);
    expect(queue.takeNext()!.revision, 1);
    expect(queue.takeDeferred()!.actionLogCount, 2);
    expect(queue.isEmpty, isTrue);
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
    expect(findAssetImage('assets/ui/Icons/icon-year-1.png'), findsOneWidget);
    expect(
      findAssetImage('assets/ui/Icons/icon-crop-seal.png'),
      findsOneWidget,
    );
    expect(find.byType(PortraitFrame), findsOneWidget);
    expect(model.table.seats[0].name, 'Mira Petrov');
    expect(findAppText('Mira Petrov'), findsOneWidget);
    expect(findAppText('played'), findsOneWidget);
    expect(findAppText('10'), findsOneWidget);
    expect(
      findAssetImage('assets/ui/Icons/icon-sunflower.png'),
      findsOneWidget,
    );
  });

  testWidgets('local requisition advances and logs one event per timer tick', (
    tester,
  ) async {
    final store = LiveGameStore(autosaveEnabled: false)
      ..animationSpeed = GameAnimationSpeed.normal;
    store.startGame(
      persist: false,
      controllers: const [
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
      ],
    );

    const priority = {
      actionSubmitAssignments: 0,
      actionContinueAfterRequisition: 0,
      actionConfirmSwap: 0,
      actionSetTrump: 1,
      actionPlayCard: 1,
      actionAssign: 1,
      actionSwap: 2,
      actionUndoSwap: 3,
    };
    for (var guard = 0; guard < 250; guard += 1) {
      final model = store.model!;
      if (model.table.phase == phaseRequisition) break;
      final actions = [...model.legalActions]
        ..sort(
          (left, right) =>
              (priority[left.kind] ?? 9).compareTo(priority[right.kind] ?? 9),
        );
      expect(actions, isNotEmpty);
      store.applyLegalAction(actions.first);
      final revision = store.presentationRevision;
      if (revision != null) {
        store.acknowledgeRevisionPresented(revision);
      }
    }

    expect(store.model!.table.phase, phaseRequisition);
    expect(store.model!.table.requisitionEvents, isEmpty);
    expect(
      store.gameLogActions.where(
        (action) => action.kind == actionRequisitionEvent,
      ),
      isEmpty,
    );

    await tester.pump(GameAnimationSpeed.normal.automaticStepDelay);
    expect(store.model!.table.requisitionEvents, hasLength(1));
    expect(
      store.gameLogActions.where(
        (action) => action.kind == actionRequisitionEvent,
      ),
      hasLength(1),
    );

    await tester.pump(GameAnimationSpeed.normal.automaticStepDelay * 2);
    expect(store.model!.table.requisitionEvents, hasLength(1));

    store.acknowledgeRevisionPresented(store.presentationRevision!);
    await tester.pump(GameAnimationSpeed.normal.automaticStepDelay);
    expect(store.model!.table.requisitionEvents, hasLength(2));
    expect(
      store.gameLogActions.where(
        (action) => action.kind == actionRequisitionEvent,
      ),
      hasLength(2),
    );
    store.dispose();
  });

  testWidgets('game log renders individual requisition outcomes', (
    tester,
  ) async {
    final base = runtimeModel();
    final model = runtimeModelWith(
      phase: phaseRequisition,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 600,
          height: 400,
          child: GameLogPanel(
            model: model,
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            actions: const [
              EngineAction(
                kind: actionRequisitionEvent,
                playerID: 0,
                suit: 'wheat',
                card: EngineCard(suit: 'wheat', value: 9),
                requisitionKind: 1,
              ),
              EngineAction(
                kind: actionRequisitionEvent,
                playerID: -1,
                suit: 'potato',
                requisitionKind: 2,
              ),
            ],
            reactions: const [],
          ),
        ),
      ),
    );

    expect(findAppText('Requisition'), findsWidgets);
    expect(findAppText('lost'), findsWidgets);
    expect(findAppText('No matching card was found for'), findsWidgets);
    expect(findAppText('9'), findsWidgets);
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
    final leaderboard = await client.fetchLeaderboard();
    final recentGames = await client.fetchRecentGames();
    final publicProfile = await client.fetchPublicProfile('profile-user');
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
      'GET /leaderboard',
      'GET /results/recent',
      'GET /profiles/profile-user',
      'POST /sessions/matchmake',
      'GET /sessions/11111111-1111-1111-1111-111111111111',
      'GET /sessions/11111111-1111-1111-1111-111111111111/players/0/actions',
      'POST /sessions/11111111-1111-1111-1111-111111111111/actions',
    ]);
    expect(sessions, hasLength(2));
    expect(sessions.first.openSeats, [1]);
    expect(heartbeat.citizensOnline, 16);
    expect(status.citizensOnline, 16);
    expect(leaderboard.single.rank, 1);
    expect(leaderboard.single.displayName, 'Leader');
    expect(recentGames.single.sessionID, 'recent-game');
    expect(recentGames.single.won, isTrue);
    expect(recentGames.single.score, 123);
    expect(publicProfile.userID, 'profile-user');
    expect(publicProfile.rank, 4);
    expect(matched.playerID, 1);
    expect(sessions.first.expiresAt, 3601.0);
    expect(session.occupiedSeats, [0, 1]);
    expect(
      httpClient.requests
          .singleWhere(
            (request) => request.route.endsWith('/players/0/actions'),
          )
          .headers['X-Kolkhoz-Seat-Token'],
      ['seat-token-0'],
    );
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

  test('realtime snapshots wait for the active presentation', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final framesSent = Completer<void>();
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      final revisionOne = onlineUpdateJson()..['actionLogCount'] = 1;
      final revisionTwo = onlineUpdateJson()..['actionLogCount'] = 2;
      socket.add(
        jsonEncode({
          'type': 'committed',
          'revision': 1,
          'updates': {
            'sessionID': '11111111-1111-1111-1111-111111111111',
            'actionLogCount': 1,
            'updates': [
              {
                'revision': 1,
                'action': const OnlineEngineAction(
                  kind: kcActionSetTrump,
                  playerID: 0,
                  suit: 0,
                ).toJson(),
                'update': revisionOne,
              },
            ],
            'resyncUpdate': null,
          },
        }),
      );
      socket.add(jsonEncode({'type': 'state', 'update': revisionTwo}));
      socket.add(
        jsonEncode({
          'type': 'state',
          'update': onlineUpdateJson()..['actionLogCount'] = 0,
        }),
      );
      framesSent.complete();
    });
    final store = LiveGameStore(
      autosaveEnabled: false,
      onlineAccessTokenProvider: () async => 'access-token',
      onlineHttpClient: FakeOnlineHttpClient(),
      onlineWebSocketConnector: (_, headers) => WebSocket.connect(
        'ws://${server.address.address}:${server.port}',
        headers: headers,
      ),
    );
    addTearDown(store.dispose);

    await store.startOnlineGame(
      baseURL: Uri.parse('http://online.example'),
      ranked: false,
      browserJoinable: false,
    );
    await framesSent.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(store.onlineUpdate!.actionLogCount, 1);
    expect(store.presentationRevision, 1);
    expect(store.onlineUpdate!.legalActions, isEmpty);
    expect(store.model!.legalActions, isEmpty);
    store.acknowledgeRevisionPresented(1);
    expect(store.onlineUpdate!.actionLogCount, 2);
    expect(store.onlineUpdate!.legalActions, hasLength(1));
  });

  test(
    'realtime reconnect resumes after the latest accepted revision',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requestedUris = <Uri>[];
      final reconnected = Completer<void>();
      final openSockets = <WebSocket>[];
      var connectionCount = 0;
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        openSockets.add(socket);
        connectionCount += 1;
        if (connectionCount == 1) {
          for (final revision in [4, 2, 4]) {
            socket.add(
              jsonEncode({
                'type': 'state',
                'update': onlineUpdateJson()..['actionLogCount'] = revision,
              }),
            );
          }
          await socket.close();
        } else if (!reconnected.isCompleted) {
          reconnected.complete();
        }
      });
      addTearDown(() async {
        for (final socket in openSockets) {
          await socket.close();
        }
      });
      final store = LiveGameStore(
        autosaveEnabled: false,
        onlineAccessTokenProvider: () async => 'access-token',
        onlineHttpClient: FakeOnlineHttpClient(),
        onlineRealtimeReconnectDelay: Duration.zero,
        onlineWebSocketConnector: (uri, headers) {
          requestedUris.add(uri);
          return WebSocket.connect(
            'ws://${server.address.address}:${server.port}',
            headers: headers,
          );
        },
      );
      addTearDown(store.dispose);

      await store.startOnlineGame(
        baseURL: Uri.parse('http://online.example'),
        ranked: false,
        browserJoinable: false,
      );
      await reconnected.future.timeout(const Duration(seconds: 2));

      expect(store.onlineUpdate!.actionLogCount, 4);
      expect(requestedUris, hasLength(greaterThanOrEqualTo(2)));
      expect(requestedUris[0].queryParameters['afterRevision'], '0');
      expect(requestedUris[1].queryParameters['afterRevision'], '4');
    },
  );

  test('disconnected realtime keeps durable polling active', () async {
    final httpClient = FakeOnlineHttpClient();
    final store = LiveGameStore(
      autosaveEnabled: false,
      onlineAccessTokenProvider: () async => 'access-token',
      onlineHttpClient: httpClient,
      onlineRealtimeReconnectDelay: const Duration(milliseconds: 50),
      onlineWebSocketConnector: (_, _) async =>
          throw const SocketException('offline'),
    );
    addTearDown(store.dispose);

    await store.startOnlineGame(
      baseURL: Uri.parse('http://online.example'),
      ranked: false,
      browserJoinable: false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 1150));

    expect(
      httpClient.requests.where(
        (request) =>
            request.route ==
            'GET /sessions/11111111-1111-1111-1111-111111111111/actions',
      ),
      isNotEmpty,
    );
  });

  test('production realtime URI preserves the durable revision cursor', () {
    final secure = KolkhozOnlineClient(
      Uri.parse('https://online.kolkhoz.example/api/'),
    );
    final insecure = KolkhozOnlineClient(Uri.parse('http://127.0.0.1:8787'));

    expect(
      secure
          .realtimeURI(
            sessionID: 'session with spaces',
            playerID: 2,
            afterRevision: 47,
          )
          .toString(),
      'wss://online.kolkhoz.example/api/sessions/'
      'session%20with%20spaces/realtime?viewerID=2&afterRevision=47',
    );
    expect(
      insecure
          .realtimeURI(sessionID: 'abc', playerID: 0, afterRevision: 0)
          .scheme,
      'ws',
    );
  });

  test(
    'production realtime performs an authenticated websocket handshake',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requestSeen = Completer<HttpRequest>();
      final serverDone = Completer<void>();
      server.listen((request) async {
        requestSeen.complete(request);
        final socket = await WebSocketTransformer.upgrade(request);
        serverDone.complete();
        unawaited(socket.close());
      });
      final client = KolkhozOnlineClient(
        Uri.parse('http://${server.address.address}:${server.port}'),
        accessTokenProvider: () async => 'access-token',
      );

      final socket = await client.connectRealtime(
        sessionID: 'session-id',
        playerID: 3,
        seatToken: 'seat-token',
        afterRevision: 19,
      );
      socket.listen((_) {});
      final request = await requestSeen.future;

      expect(request.uri.path, '/sessions/session-id/realtime');
      expect(request.uri.queryParameters, {
        'viewerID': '3',
        'afterRevision': '19',
      });
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer access-token',
      );
      expect(request.headers.value('X-Kolkhoz-Seat-Token'), 'seat-token');
      await socket.close();
      await serverDone.future;
    },
  );

  test('production realtime decodes state catch-up and committed frames', () {
    final stateJson = onlineUpdateJson()..['actionLogCount'] = 7;
    final state = OnlineRealtimeFrame.decode(
      jsonEncode({'type': 'state', 'update': stateJson}),
    );
    final catchUp = OnlineRealtimeFrame.fromJson({
      'type': 'catchUp',
      'updates': {
        'sessionID': '11111111-1111-1111-1111-111111111111',
        'actionLogCount': 9,
        'updates': <Object?>[],
        'resyncUpdate': null,
      },
    });
    final committed = OnlineRealtimeFrame.decode(
      jsonEncode({
        'type': 'committed',
        'revision': 10,
        'updates': {
          'sessionID': '11111111-1111-1111-1111-111111111111',
          'actionLogCount': 10,
          'updates': <Object?>[],
          'resyncUpdate': null,
        },
      }),
    );

    expect(state.type, 'state');
    expect(state.update!.actionLogCount, 7);
    expect(state.updates, isNull);
    expect(catchUp.type, 'catchUp');
    expect(catchUp.updates!.actionLogCount, 9);
    expect(committed.type, 'committed');
    expect(committed.updates!.actionLogCount, 10);
  });
}
