part of '../widget_test.dart';

void registerLobbyAndProfileTests() {
  test('leaderboard settings tab title is localized', () {
    expect(
      KolkhozSettingsTab.leaderboard.title(KolkhozLanguage.en),
      'LEADERBOARD',
    );
    expect(
      KolkhozSettingsTab.leaderboard.title(KolkhozLanguage.ru),
      'ТАБЛИЦА ЛИДЕРОВ',
    );
  });

  testWidgets('narrow preset tabs reserve space between icons and labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 667,
          height: 375,
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
    await tester.pumpAndSettle();

    final kolkhozTab = find.byKey(const ValueKey('field-plan-preset-kolkhoz'));
    expect(kolkhozTab, findsOneWidget);
    final icon = find.descendant(of: kolkhozTab, matching: find.byType(Image));
    final text = find.descendant(
      of: kolkhozTab,
      matching: find.text('KOLKHOZ'),
    );
    expect(icon, findsOneWidget);
    expect(text, findsOneWidget);
    expect(tester.getRect(icon).overlaps(tester.getRect(text)), isFalse);

    expect(
      find.byKey(const ValueKey('field-plan-preset-custom')),
      findsOneWidget,
    );
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

  testWidgets('custom variant grid marks enabled options with a medal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(667, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 667,
          height: 375,
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

    String backgroundAsset(String label) {
      final background = find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == label,
        ),
        matching: find.byType(ChromeButtonBackground),
      );
      return tester.widget<ChromeButtonBackground>(background).asset;
    }

    expect(
      backgroundAsset('Enemy of the People'),
      chromeButtonSecondaryCurrentAsset,
    );
    expect(backgroundAsset('Pass'), chromeButtonSecondaryAsset);
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

    expect(findAppText('CARD BACKS'), findsNothing);
    expect(selectedCardBack, isNull);
  });

  testWidgets('lobby leaderboard renders players from the online client', (
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
            cardBack: KolkhozCardBack.classic,
            onStart: () {},
            selectedPreset: KolkhozGamePreset.kolkhoz,
            customVariants: KolkhozGameVariants.kolkhoz,
            playerControllers: KolkhozPlayerController.defaultControllers,
            showingRules: false,
            showingOnline: false,
            showingProfile: true,
            initialSettingsTab: KolkhozSettingsTab.leaderboard,
            cloudSignedIn: true,
            menuRemoteConnection: testMenuRemoteConnection(
              FakeOnlineHttpClient(),
            ),
            profileController: testProfileController(FakeOnlineHttpClient()),
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

    await tester.pumpAndSettle();

    expect(findAppText('Leader'), findsOneWidget);
    expect(findAppText('1000'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is PixelText && widget.text == '1',
      ),
      findsOneWidget,
    );
    expect(findAppText('CASUAL'), findsWidgets);
    expect(findAppText('RANKED'), findsWidgets);
    expect(findAppText('COMRADES'), findsWidgets);
    expect(find.byTooltip('IN GAME'), findsOneWidget);
    expect(find.byTooltip('COMRADE'), findsOneWidget);
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

      await tester.tap(findAppText('CREATE GAME').first);
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
      expect(find.bySemanticsLabel('Kolkhoz'), findsOneWidget);
      expect(find.bySemanticsLabel('52 Card Deck'), findsOneWidget);
      expect(find.bySemanticsLabel('5 Year Plan'), findsOneWidget);
      expect(find.bySemanticsLabel('Exchange Soap for an Awl'), findsOneWidget);
      expect(find.bySemanticsLabel('Enemy of the People'), findsOneWidget);
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
    var accountDeleted = false;
    KolkhozIdentityRuntime.instance.setTestState(
      identity: const KolkhozPlayerIdentity(
        id: 'player-mira',
        displayName: 'Mira',
        guest: false,
        portable: true,
        provider: 'game_center',
      ),
    );

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
            onCloudDeleteAccount: () async => accountDeleted = true,
          ),
        ),
      ),
    );

    expect(find.text('GAME CENTER — CONNECTED'), findsOneWidget);
    expect(findAppText('Profile loaded.'), findsNothing);
    expect(find.text('DELETE ACCOUNT'), findsOneWidget);
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
    await tester.ensureVisible(find.text('DELETE ACCOUNT'));
    await tester.tap(find.text('DELETE ACCOUNT'));
    await tester.pumpAndSettle();
    expect(find.text('DELETE YOUR ACCOUNT?'), findsOneWidget);
    expect(
      find.textContaining('Purchases and histories are not transferred'),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('DELETE ACCOUNT'),
      ),
    );
    await tester.pumpAndSettle();
    expect(accountDeleted, isTrue);

    expect(displayName, 'Nadia');
    expect(portraitAsset, 'worker3');
  });

  testWidgets('profile panel hides player card and stats while signed out', (
    tester,
  ) async {
    KolkhozIdentityRuntime.instance.setTestState(
      identity: const KolkhozPlayerIdentity(
        id: 'guest-mira',
        displayName: 'Mira',
        guest: true,
        portable: false,
      ),
      statusMessage: 'Guest progress may be lost.',
    );
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
    expect(find.text('Mira'), findsOneWidget);
    expect(findAppText('1125'), findsNothing);
    expect(find.bySemanticsLabel('worker1'), findsNothing);
    expect(find.byKey(const Key('recovery-email-field')), findsOneWidget);
    expect(find.text('DEVICE-ONLY GUEST'), findsOneWidget);
  });

  testWidgets('profile panel loads recent games after signing in', (
    tester,
  ) async {
    final httpClient = FakeOnlineHttpClient();
    var signedIn = false;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return SizedBox(
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
                cloudSignedIn: signedIn,
                displayName: 'Mira',
                portraitAsset: 'worker1',
                profileStats: const KolkhozProfileStats(),
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
                menuRemoteConnection: testMenuRemoteConnection(httpClient),
                mainMenuController: testMainMenuController(httpClient),
                profileController: testProfileController(httpClient),
              ),
            );
          },
        ),
      ),
    );

    expect(
      httpClient.requests.where(
        (request) => request.route == 'GET /results/recent',
      ),
      isEmpty,
    );

    rebuild(() => signedIn = true);
    await tester.pumpAndSettle();

    expect(
      httpClient.requests.where(
        (request) => request.route == 'GET /results/recent',
      ),
      hasLength(1),
    );
    expect(find.byKey(const Key('recent-game-recent-game')), findsOneWidget);

    rebuild(() => signedIn = false);
    await tester.pump();

    expect(find.byKey(const Key('recent-game-recent-game')), findsNothing);
  });

  testWidgets('profile account is passwordless with guest recovery warning', (
    tester,
  ) async {
    KolkhozIdentityRuntime.instance.setTestState(
      identity: const KolkhozPlayerIdentity(
        id: 'guest-passwordless',
        displayName: 'Guest',
        guest: true,
        portable: false,
      ),
      statusMessage: 'Guest progress may be lost if this app is deleted.',
    );
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
          ),
        ),
      ),
    );

    expect(find.textContaining('PASSWORD'), findsNothing);
    expect(find.textContaining('RECOVERY EMAIL'), findsWidgets);
    expect(find.text('DEVICE-ONLY GUEST'), findsOneWidget);
    expect(find.textContaining('may be lost'), findsOneWidget);
    expect(find.byKey(const Key('link-another-device')), findsOneWidget);
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
    expect(findAssetImage('assets/ui/worker4.png'), findsWidgets);
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
    expect(findAppText('START OFFLINE GAME'), findsWidgets);
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

    expect(findAppText('ADD PLAYERS'), findsWidgets);
    expect(findAppText('START OFFLINE GAME'), findsNothing);

    await tester.tap(findAppText('ADD PLAYERS').first);
    await tester.pumpAndSettle();
    expect(findAppText('START OFFLINE GAME'), findsWidgets);
    expect(findAppText('VISIBILITY'), findsWidgets);
    expect(findAppText('PUBLIC'), findsWidgets);

    await tester.tap(findAppText('PUBLIC').first);
    await tester.pump();
    expect(findAppText('PUBLIC'), findsWidgets);
    expect(findAppText('PRIVATE'), findsNothing);

    await tester.tap(find.bySemanticsLabel('P2 Online'));
    await tester.pumpAndSettle();
    expect(findAppText('START ONLINE GAME'), findsWidgets);
    final p3Hotseat = find.bySemanticsLabel('P3 Hotseat');
    expect(p3Hotseat, findsOneWidget);
    expect(
      tester.getSemantics(p3Hotseat).flagsCollection.isEnabled.toBoolOrNull(),
      isFalse,
    );
    await tester.tap(findAppText('PUBLIC').first);
    await tester.pump();
    expect(findAppText('PRIVATE'), findsWidgets);

    await tester.tap(findAppText('JOIN GAME').first);
    await tester.pumpAndSettle();
    await tester.tap(findAppText('CREATE GAME').first);
    await tester.pumpAndSettle();
    expect(findAppText('START ONLINE GAME'), findsWidgets);

    await tester.ensureVisible(find.bySemanticsLabel('P3 Hard'));
    await tester.tap(find.bySemanticsLabel('P3 Hard'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.bySemanticsLabel('P4 Hard'));
    await tester.tap(find.bySemanticsLabel('P4 Hard'));
    await tester.pumpAndSettle();

    expect(changedControllers, isNotNull);
    expect(changedControllers![1], KolkhozPlayerController.human);
    expect(findAppText('START ONLINE GAME'), findsWidgets);
    expect(findAppText('RANKED'), findsNothing);
    expect(findAppText('CASUAL'), findsNothing);
    expect(findAppText('PRIVATE'), findsWidgets);

    await tester.ensureVisible(findAppText('START ONLINE GAME').first);
    await tester.tap(findAppText('START ONLINE GAME').first);
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
    expect(findAppText('ABCDE'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/ui/Icons/icon-foreman-misha.png',
      ),
      findsWidgets,
    );
    expect(findAppText('TYPE'), findsNothing);
    expect(findAppText('SEATS'), findsNothing);
    expect(findAppText('MOVES'), findsNothing);
    expect(find.bySemanticsLabel('INVITE CODE ABCDE'), findsOneWidget);
    expect(find.bySemanticsLabel('Waiting for players'), findsWidgets);
    expect(find.textContaining('Searching for Player'), findsOneWidget);
    expect(findAppText('Mira'), findsWidgets);
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
    await tester.pumpAndSettle();

    expect(
      findAppText('Demo mode: 5-year Kolkhoz with easy AI.'),
      findsNothing,
    );
    expect(find.text('DEMO MODE', findRichText: true), findsOneWidget);
    expect(
      find.text('5-year Kolkhoz with easy AI', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('52 CARD DECK'), findsOneWidget);
    expect(find.text('5 YEAR PLAN'), findsOneWidget);
    expect(KolkhozGameVariants.demoKolkhoz.wreckerCard, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('field-plan-preset-custom')),
      warnIfMissed: false,
    );
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
              menuRemoteConnection: testMenuRemoteConnection(httpClient),
              mainMenuController: testMainMenuController(httpClient),
              profileController: testProfileController(httpClient),
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
      final refreshButton = find.byWidgetPredicate(
        (widget) => widget is ChromeAssetButton && widget.label == 'Refresh',
      );
      final assignButton = find.byWidgetPredicate(
        (widget) =>
            widget is ChromeAssetButton && widget.label == 'Assign Game',
      );
      expect(tester.getSize(refreshButton).height, 44);
      expect(
        tester.getSize(refreshButton).height,
        tester.getSize(assignButton).height,
      );
      expect(findAppText('RANKED'), findsNothing);
      expect(findAppText('COMRADES'), findsNothing);
      expect(find.byTooltip('Ranked'), findsOneWidget);
      expect(find.byTooltip('Casual'), findsOneWidget);
      expect(find.byTooltip('Comrade'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byTooltip('Casual'),
          matching: findAssetImage('assets/ui/Icons/icon-foreman-misha.png'),
        ),
        findsOneWidget,
      );
      expect(findAppText('1 open'), findsNothing);
      expect(find.textContaining('Learning Table'), findsNothing);
      expect(
        httpClient.requests.map((request) => request.route),
        contains('GET /sessions'),
      );

      await tester.tap(assignButton);
      await tester.pump();

      expect(matchmakeCalled, isTrue);
      expect(matchmakeRankedOnly, isTrue);
      expect(matchmakeComradesOnly, isFalse);
    },
  );

  testWidgets('online lobby exposes the live weekly tournament join window', (
    tester,
  ) async {
    final httpClient = TournamentFakeOnlineHttpClient();

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
            menuRemoteConnection: testMenuRemoteConnection(httpClient),
            mainMenuController: testMainMenuController(httpClient),
            profileController: testProfileController(httpClient),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('weekly-tournament-card')),
      findsOneWidget,
    );
    expect(findAppText('WEEKLY KOLKHOZ TOURNAMENT'), findsOneWidget);
    expect(findChromeButton('JOIN TOURNAMENT'), findsOneWidget);

    await tester.tap(findChromeButton('JOIN TOURNAMENT'));
    await tester.pumpAndSettle();

    expect(httpClient.joined, isTrue);
    expect(findAppText('ENTRY CONFIRMED • 5 PLAYERS'), findsOneWidget);
  });

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
            menuRemoteConnection: testMenuRemoteConnection(httpClient),
            mainMenuController: testMainMenuController(httpClient),
            profileController: testProfileController(httpClient),
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
            menuRemoteConnection: testMenuRemoteConnection(httpClient),
            mainMenuController: testMainMenuController(httpClient),
            profileController: testProfileController(httpClient),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp(r'Mira')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'ABCDE - Mira')), findsNothing);

    await tester.tap(findChromeButton('Assign Game'));
    await tester.pump();

    expect(matchmakeCalls, 1);
    expect(joinedInviteCode, isNull);
    final disabledAssignButton = findChromeButton(
      'Sent north: online play is locked for this account.',
    );
    expect(disabledAssignButton, findsOneWidget);
    expect(
      tester.widget<ChromeAssetButton>(disabledAssignButton).enabled,
      false,
    );
    expect(
      findAppText('Sent north: online play is locked for this account.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'ABCDE - Mira')), findsNothing);

    await tester.tap(disabledAssignButton, warnIfMissed: false);
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
            menuRemoteConnection: testMenuRemoteConnection(httpClient),
            mainMenuController: testMainMenuController(httpClient),
            profileController: testProfileController(httpClient),
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
      findChromeButton('Sent north: online play is locked for this account.'),
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
    expect(find.bySemanticsLabel('KICK'), findsOneWidget);
    expect(find.byKey(const Key('online-waiting-cancel')), findsOneWidget);
    expect(find.bySemanticsLabel('Waiting for players'), findsWidgets);

    await tester.tap(find.byKey(const Key('online-waiting-cancel')));
    await tester.pump();

    expect(cancelCalls, 1);

    await tester.tap(find.bySemanticsLabel('KICK'));
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
}
