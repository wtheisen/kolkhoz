part of '../kolkhoz_app.dart';

KolkhozGamePreset presetForVariants(KolkhozGameVariants variants) {
  if (sameVariants(variants, KolkhozGameVariants.kolkhoz)) {
    return KolkhozGamePreset.kolkhoz;
  }
  if (sameVariants(variants, KolkhozGameVariants.littleKolkhoz)) {
    return KolkhozGamePreset.littleKolkhoz;
  }
  if (sameVariants(variants, KolkhozGameVariants.campStyle)) {
    return KolkhozGamePreset.campStyle;
  }
  return KolkhozGamePreset.custom;
}

bool sameVariants(KolkhozGameVariants left, KolkhozGameVariants right) {
  return left.deckType == right.deckType &&
      left.maxYears == right.maxYears &&
      left.nomenclature == right.nomenclature &&
      left.allowSwap == right.allowSwap &&
      left.northernStyle == right.northernStyle &&
      left.miceVariant == right.miceVariant &&
      left.ordenNachalniku == right.ordenNachalniku &&
      left.medalsCount == right.medalsCount &&
      left.accumulateJobs == right.accumulateJobs &&
      left.heroOfSovietUnion == right.heroOfSovietUnion &&
      left.wreckerCard == right.wreckerCard;
}

String gameResultShareText({
  required TableViewModel model,
  required int seed,
  required KolkhozGameVariants variants,
  required KolkhozLanguage language,
}) {
  final scores = model.table.gameResult?.scores ?? model.table.scoreboard;
  final winnerID =
      model.table.gameResult?.winnerSeatID ?? inferredWinnerID(scores);
  final winnerScore = finalScoreForSeat(scores, winnerID);
  final winnerName = model.table.seats
      .firstWhere(
        (seat) => seat.id == winnerID,
        orElse: () => model.table.seats.first,
      )
      .name;
  final setup = [
    presetTitle(presetForVariants(variants), language),
    '${variants.deckType} cards',
    '${variants.maxYears} years',
  ].join(' / ');
  final scoreLine = model.table.seats
      .map((seat) => '${seat.name} ${finalScoreForSeat(scores, seat.id)}')
      .join(', ');
  return [
    'Kolkhoz result',
    'Winner: $winnerName - $winnerScore',
    'Scores: $scoreLine',
    'Setup: $setup',
    'Seed: $seed',
  ].join('\n');
}

enum KolkhozGamePreset {
  kolkhoz,
  littleKolkhoz,
  campStyle,
  custom;

  String get title {
    return switch (this) {
      KolkhozGamePreset.kolkhoz => 'Kolkhoz',
      KolkhozGamePreset.littleKolkhoz => 'Little Kolkhoz',
      KolkhozGamePreset.campStyle => 'Camp Style',
      KolkhozGamePreset.custom => 'Custom',
    };
  }

  KolkhozGameVariants? get variants {
    return switch (this) {
      KolkhozGamePreset.kolkhoz => KolkhozGameVariants.kolkhoz,
      KolkhozGamePreset.littleKolkhoz => KolkhozGameVariants.littleKolkhoz,
      KolkhozGamePreset.campStyle => KolkhozGameVariants.campStyle,
      KolkhozGamePreset.custom => null,
    };
  }

  String? get iconAsset {
    return switch (this) {
      KolkhozGamePreset.kolkhoz => 'assets/ui/Icons/icon-preset-kolkhoz.png',
      KolkhozGamePreset.littleKolkhoz =>
        'assets/ui/Icons/icon-preset-little-kolkhoz.png',
      KolkhozGamePreset.campStyle =>
        'assets/ui/Icons/icon-preset-camp-style.png',
      KolkhozGamePreset.custom => null,
    };
  }
}

class StandaloneLobby extends StatelessWidget {
  const StandaloneLobby({
    required this.tokens,
    required this.language,
    required this.appearance,
    this.cardBack = KolkhozCardBack.classic,
    required this.onStart,
    required this.selectedPreset,
    required this.customVariants,
    required this.playerControllers,
    this.demoMode = false,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.confirmNewGame = true,
    this.confirmMainMenu = true,
    this.showInvalidTapHints = true,
    this.soundEnabled = true,
    required this.showingRules,
    required this.showingOnline,
    required this.onHostOnline,
    this.onInviteOnlineComrades,
    required this.onJoinOnline,
    this.onRememberStartedSetup,
    this.onMatchmakeOnline,
    this.onKickOnlinePlayer,
    required this.onEnterOnlineGame,
    this.onCancelOnlineGame,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
    this.onAnimationSpeedChanged,
    this.onConfirmNewGameChanged,
    this.onConfirmMainMenuChanged,
    this.onShowInvalidTapHintsChanged,
    this.onSoundEnabledChanged,
    required this.onRulesPressed,
    required this.onOfflinePressed,
    required this.onOnlinePressed,
    required this.onTutorialPressed,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
    this.onCardBackChanged,
    this.showingProfile = false,
    this.initialSettingsTab = KolkhozSettingsTab.profile,
    this.hostedInviteCode,
    this.onlineSessionUpdate,
    this.showHostedInviteCode = false,
    this.displayName = defaultProfileDisplayName,
    this.portraitAsset = defaultProfilePortraitAsset,
    this.profileStats = defaultProfileStats,
    this.progression = const ProgressionState(),
    this.unlockedCardBacks = const {
      KolkhozCardBack.classic,
      KolkhozCardBack.harvest,
      KolkhozCardBack.granary,
      KolkhozCardBack.winter,
    },
    this.favoriteSetup,
    this.lastStartedSetup,
    this.comradesSummary = const OnlineComradesResponse(),
    this.cloudConfigured = false,
    this.cloudReady = false,
    this.cloudSignedIn = false,
    this.cloudEmail,
    this.cloudAuthBusy = false,
    this.cloudAuthMessage,
    this.cloudAuthIsError = false,
    this.onProfilePressed,
    this.onSettingsPressed,
    this.onDisplayNameChanged,
    this.onPortraitChanged,
    this.onSaveFavoriteSetup,
    this.onUseFavoriteSetup,
    this.onCloudSignIn,
    this.onCloudSignUp,
    this.onCloudResetPassword,
    this.onCloudSignOut,
    this.onComradesChanged,
    this.onComradeRequestToUser,
    this.onlineClientFactory,
    this.error,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final KolkhozCardBack cardBack;
  final VoidCallback onStart;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final bool demoMode;
  final GameAnimationSpeed animationSpeed;
  final bool confirmNewGame;
  final bool confirmMainMenu;
  final bool showInvalidTapHints;
  final bool soundEnabled;
  final bool showingRules;
  final bool showingOnline;
  final bool showingProfile;
  final KolkhozSettingsTab initialSettingsTab;
  final String? hostedInviteCode;
  final OnlineSessionUpdate? onlineSessionUpdate;
  final bool showHostedInviteCode;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final ProgressionState progression;
  final Set<KolkhozCardBack> unlockedCardBacks;
  final KolkhozFavoriteSetup? favoriteSetup;
  final KolkhozFavoriteSetup? lastStartedSetup;
  final OnlineComradesResponse comradesSummary;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final String? cloudAuthMessage;
  final bool cloudAuthIsError;
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
    bool ranked,
    bool browserJoinable,
  )
  onHostOnline;
  final Future<void> Function(String sessionID, List<String> userIDs)?
  onInviteOnlineComrades;
  final Future<void> Function(
    Uri baseURL,
    String inviteCode,
    int? preferredPlayerID,
  )
  onJoinOnline;
  final void Function(
    List<KolkhozPlayerController> controllers,
    List<String> lobbySeats,
    bool browserJoinable,
  )?
  onRememberStartedSetup;
  final Future<String> Function(
    Uri baseURL,
    bool rankedOnly,
    bool comradesOnly,
  )?
  onMatchmakeOnline;
  final Future<void> Function(int playerID)? onKickOnlinePlayer;
  final VoidCallback onEnterOnlineGame;
  final VoidCallback? onCancelOnlineGame;
  final ValueChanged<KolkhozGamePreset> onPresetChanged;
  final ValueChanged<KolkhozGameVariants> onCustomVariantsChanged;
  final ValueChanged<List<KolkhozPlayerController>> onPlayerControllersChanged;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final ValueChanged<bool>? onSoundEnabledChanged;
  final VoidCallback onRulesPressed;
  final VoidCallback onOfflinePressed;
  final VoidCallback onOnlinePressed;
  final VoidCallback onTutorialPressed;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;
  final ValueChanged<KolkhozCardBack>? onCardBackChanged;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onSettingsPressed;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onPortraitChanged;
  final VoidCallback? onSaveFavoriteSetup;
  final VoidCallback? onUseFavoriteSetup;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final Future<void> Function()? onCloudSignOut;
  final ValueChanged<OnlineComradesResponse>? onComradesChanged;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final KolkhozOnlineClient Function()? onlineClientFactory;
  final String? error;

  KolkhozGameVariants get activeVariants {
    if (demoMode) {
      return KolkhozGameVariants.demoKolkhoz;
    }
    return selectedPreset.variants ?? customVariants;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              tokens.colors.background,
              tokens.colors.iron,
              tokens.colors.black,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final usableWidth = constraints.maxWidth;
              final usableHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 640.0;
              final shortLandscape =
                  usableWidth > usableHeight && usableHeight < 430;
              final wide = usableWidth >= 560 && usableWidth > usableHeight;
              final compactRail = wide && shortLandscape;
              const outerPadding = 10.0;
              final contentWidth = (usableWidth - outerPadding * 2).clamp(
                260.0,
                double.infinity,
              );
              final contentHeight = (usableHeight - outerPadding * 2).clamp(
                300.0,
                double.infinity,
              );
              final spacing = (usableHeight * 0.018).clamp(8.0, 12.0);
              final titleWidth = compactRail
                  ? (contentWidth * 0.24).clamp(148.0, 168.0)
                  : wide
                  ? (contentWidth * 0.34).clamp(210.0, 292.0)
                  : contentWidth;
              final panelWidth = wide
                  ? (contentWidth - titleWidth - spacing).clamp(
                      300.0,
                      double.infinity,
                    )
                  : contentWidth;
              final titleHeight = wide
                  ? contentHeight
                  : (usableHeight * 0.40).clamp(300.0, 326.0);
              final panelHeight = wide
                  ? contentHeight
                  : (usableHeight - titleHeight - spacing - 20).clamp(
                      320.0,
                      double.infinity,
                    );

              final titleColumn = SizedBox(
                width: titleWidth,
                height: titleHeight,
                child: _LobbyTitleColumn(
                  tokens: tokens,
                  language: language,
                  appearance: appearance,
                  compact: compactRail,
                  showingRules: showingRules,
                  showingOnline: showingOnline,
                  showingProfile: showingProfile,
                  demoMode: demoMode,
                  cloudConfigured: cloudConfigured,
                  cloudReady: cloudReady,
                  cloudSignedIn: cloudSignedIn,
                  cloudEmail: cloudEmail,
                  cloudAuthBusy: cloudAuthBusy,
                  comradeRequestCount: comradesSummary.incomingRequests.length,
                  onOfflinePressed: onOfflinePressed,
                  onOnlinePressed: onOnlinePressed,
                  onProfilePressed: onProfilePressed,
                  onSettingsPressed: onSettingsPressed,
                  onRulesPressed: onRulesPressed,
                  onLanguageToggle: onLanguageToggle,
                  onAppearanceToggle: onAppearanceToggle,
                ),
              );
              final panel = SizedBox(
                width: panelWidth,
                height: panelHeight,
                child: _LobbyPanel(
                  tokens: tokens,
                  language: language,
                  selectedPreset: selectedPreset,
                  customVariants: customVariants,
                  playerControllers: playerControllers,
                  demoMode: demoMode,
                  variants: activeVariants,
                  appearance: appearance,
                  cardBack: cardBack,
                  compactRail: compactRail,
                  animationSpeed: animationSpeed,
                  confirmNewGame: confirmNewGame,
                  confirmMainMenu: confirmMainMenu,
                  showInvalidTapHints: showInvalidTapHints,
                  soundEnabled: soundEnabled,
                  showingRules: showingRules,
                  showingOnline: showingOnline,
                  showingProfile: showingProfile,
                  initialSettingsTab: initialSettingsTab,
                  hostedInviteCode: hostedInviteCode,
                  onlineSessionUpdate: onlineSessionUpdate,
                  showHostedInviteCode: showHostedInviteCode,
                  displayName: displayName,
                  portraitAsset: portraitAsset,
                  profileStats: profileStats,
                  progression: progression,
                  unlockedCardBacks: unlockedCardBacks,
                  favoriteSetup: favoriteSetup,
                  lastStartedSetup: lastStartedSetup,
                  comradesSummary: comradesSummary,
                  cloudConfigured: cloudConfigured,
                  cloudReady: cloudReady,
                  cloudSignedIn: cloudSignedIn,
                  cloudEmail: cloudEmail,
                  cloudAuthBusy: cloudAuthBusy,
                  cloudAuthMessage: cloudAuthMessage,
                  cloudAuthIsError: cloudAuthIsError,
                  onTutorialPressed: onTutorialPressed,
                  onStart: onStart,
                  onHostOnline: onHostOnline,
                  onInviteOnlineComrades: onInviteOnlineComrades,
                  onJoinOnline: onJoinOnline,
                  onRememberStartedSetup: onRememberStartedSetup,
                  onMatchmakeOnline: onMatchmakeOnline,
                  onKickOnlinePlayer: onKickOnlinePlayer,
                  onEnterOnlineGame: onEnterOnlineGame,
                  onCancelOnlineGame: onCancelOnlineGame,
                  onPresetChanged: onPresetChanged,
                  onCustomVariantsChanged: onCustomVariantsChanged,
                  onPlayerControllersChanged: onPlayerControllersChanged,
                  onAnimationSpeedChanged: onAnimationSpeedChanged,
                  onConfirmNewGameChanged: onConfirmNewGameChanged,
                  onConfirmMainMenuChanged: onConfirmMainMenuChanged,
                  onShowInvalidTapHintsChanged: onShowInvalidTapHintsChanged,
                  onSoundEnabledChanged: onSoundEnabledChanged,
                  onLanguageToggle: onLanguageToggle,
                  onAppearanceToggle: onAppearanceToggle,
                  onCardBackChanged: onCardBackChanged,
                  onDisplayNameChanged: onDisplayNameChanged,
                  onPortraitChanged: onPortraitChanged,
                  onSaveFavoriteSetup: onSaveFavoriteSetup,
                  onUseFavoriteSetup: onUseFavoriteSetup,
                  onCloudSignIn: onCloudSignIn,
                  onCloudSignUp: onCloudSignUp,
                  onCloudResetPassword: onCloudResetPassword,
                  onCloudSignOut: onCloudSignOut,
                  onComradesChanged: onComradesChanged,
                  onComradeRequestToUser: onComradeRequestToUser,
                  onlineClientFactory: onlineClientFactory,
                ),
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(outerPadding),
                child: Align(
                  alignment: wide ? Alignment.topLeft : Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleColumn,
                            SizedBox(width: spacing),
                            panel,
                          ],
                        )
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            titleColumn,
                            SizedBox(height: spacing),
                            panel,
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LobbyTitleColumn extends StatelessWidget {
  const _LobbyTitleColumn({
    required this.tokens,
    required this.language,
    required this.appearance,
    required this.compact,
    required this.showingRules,
    required this.showingOnline,
    required this.showingProfile,
    required this.demoMode,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudEmail,
    required this.cloudAuthBusy,
    required this.comradeRequestCount,
    required this.onOfflinePressed,
    required this.onOnlinePressed,
    required this.onProfilePressed,
    required this.onSettingsPressed,
    required this.onRulesPressed,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final bool compact;
  final bool showingRules;
  final bool showingOnline;
  final bool showingProfile;
  final bool demoMode;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final int comradeRequestCount;
  final VoidCallback onOfflinePressed;
  final VoidCallback onOnlinePressed;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onSettingsPressed;
  final VoidCallback onRulesPressed;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortCompact = compact && constraints.maxHeight < 370;
        final cardHeight = compact
            ? (constraints.maxWidth * 0.54).clamp(
                shortCompact ? 52.0 : 58.0,
                shortCompact ? 60.0 : 72.0,
              )
            : (constraints.maxWidth * 0.50).clamp(92.0, 176.0);
        final mainContent = SizedBox(
          width: constraints.maxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: compact ? (shortCompact ? 4 : 7) : 10,
            children: [
              SizedBox(
                height: cardHeight,
                child: Image.asset(
                  'assets/ui/title-card-kolkhoz.png',
                  width: double.infinity,
                  fit: compact ? BoxFit.contain : BoxFit.cover,
                  filterQuality: FilterQuality.none,
                ),
              ),
              _LobbyButtonStack(
                tokens: tokens,
                language: language,
                appearance: appearance,
                showingRules: showingRules,
                showingOnline: showingOnline,
                showingProfile: showingProfile,
                demoMode: demoMode,
                cloudConfigured: cloudConfigured,
                cloudReady: cloudReady,
                cloudSignedIn: cloudSignedIn,
                cloudEmail: cloudEmail,
                cloudAuthBusy: cloudAuthBusy,
                comradeRequestCount: comradeRequestCount,
                onOfflinePressed: onOfflinePressed,
                onOnlinePressed: onOnlinePressed,
                onProfilePressed: onProfilePressed,
                onSettingsPressed: onSettingsPressed,
                onRulesPressed: onRulesPressed,
                onLanguageToggle: onLanguageToggle,
                onAppearanceToggle: onAppearanceToggle,
                compact: compact,
              ),
              if (!compact)
                Image.asset(
                  'assets/ui/ui-divider-crops.png',
                  width: (constraints.maxWidth * 0.88).clamp(110.0, 170.0),
                  height: 34,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
            ],
          ),
        );
        return Column(
          spacing: compact ? (shortCompact ? 4 : 7) : 10,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: mainContent,
              ),
            ),
            if (!compact) _LobbyFooter(tokens: tokens, language: language),
          ],
        );
      },
    );
  }
}

class _LobbyButtonStack extends StatelessWidget {
  const _LobbyButtonStack({
    required this.tokens,
    required this.language,
    required this.appearance,
    required this.showingRules,
    required this.showingOnline,
    required this.showingProfile,
    required this.demoMode,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudEmail,
    required this.cloudAuthBusy,
    required this.comradeRequestCount,
    required this.onOfflinePressed,
    required this.onOnlinePressed,
    required this.onProfilePressed,
    required this.onSettingsPressed,
    required this.onRulesPressed,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
    required this.compact,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final bool showingRules;
  final bool showingOnline;
  final bool showingProfile;
  final bool demoMode;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final int comradeRequestCount;
  final VoidCallback onOfflinePressed;
  final VoidCallback onOnlinePressed;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onSettingsPressed;
  final VoidCallback onRulesPressed;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final joinEnabled = !demoMode;
    final mainButtonHeight = compact ? 46.0 : 58.0;
    final mainIconSize = _buttonContentIconSize(mainButtonHeight);
    final mainTextSize = _buttonContentTextSize(mainButtonHeight);
    final mainPadding = EdgeInsets.symmetric(
      horizontal: compact ? (mainButtonHeight * 0.17).clamp(6.0, 10.0) : 76,
    );
    final mainSpacing = (mainButtonHeight * 0.13).clamp(4.0, 8.0);
    return Column(
      spacing: compact ? 6 : 9,
      children: [
        SizedBox(
          width: double.infinity,
          height: mainButtonHeight,
          child: ChromeAssetButton.command(
            label: language.t(
              demoMode
                  ? KolkhozText.lobbyPlayDemo
                  : KolkhozText.lobbyCreateGame,
            ),
            prominent: !showingRules && !showingOnline && !showingProfile,
            tokens: tokens,
            onPressed: onOfflinePressed,
            iconAsset: 'assets/ui/Icons/icon-create-game.png',
            iconSize: mainIconSize,
            textSize: mainTextSize,
            expandLabel: false,
            padding: mainPadding,
            spacing: mainSpacing,
            uppercase: true,
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: mainButtonHeight,
          child: ChromeAssetButton.command(
            label: language.t(KolkhozText.lobbyJoinGame),
            prominent: joinEnabled && showingOnline,
            tokens: tokens,
            onPressed: onOnlinePressed,
            iconAsset: joinEnabled
                ? 'assets/ui/Icons/icon-join-game.png'
                : 'assets/ui/Icons/icon-lock.png',
            iconSize: mainIconSize,
            textSize: mainTextSize,
            expandLabel: false,
            enabled: joinEnabled,
            disabledOpacity: 0.48,
            padding: mainPadding,
            spacing: mainSpacing,
            uppercase: true,
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: mainButtonHeight,
          child: ChromeAssetButton.command(
            label: language.t(KolkhozText.lobbyHowToPlay),
            prominent: showingRules,
            tokens: tokens,
            onPressed: onRulesPressed,
            iconAsset: 'assets/ui/Icons/icon-foreman-misha.png',
            iconSize: mainIconSize,
            textSize: mainTextSize,
            expandLabel: false,
            padding: mainPadding,
            spacing: mainSpacing,
            uppercase: true,
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const iconCount = 4;
            const iconSpacing = 8.0;
            final useGrid =
                compact &&
                constraints.maxWidth <
                    (44.0 * iconCount + iconSpacing * (iconCount - 1));
            final iconSize = useGrid
                ? ((constraints.maxWidth - iconSpacing) / 2).clamp(48.0, 58.0)
                : ((constraints.maxWidth - iconSpacing * (iconCount - 1)) /
                          iconCount)
                      .clamp(44.0, 58.0);
            final buttons = [
              _LobbyIconButton(
                tokens: tokens,
                label: language.t(KolkhozText.lobbyAccountStatus),
                tooltip: cloudStatusTooltip,
                iconAsset: cloudStatusIconAsset,
                prominent: cloudSignedIn,
                size: iconSize,
                badgeCount: comradeRequestCount,
                onPressed: onProfilePressed,
              ),
              _LobbyIconButton(
                tokens: tokens,
                label: language.t(KolkhozText.lobbyLanguage),
                tooltip: language.toggleTitle,
                iconAsset: 'assets/ui/Icons/${language.toggleIconAsset}',
                size: iconSize,
                onPressed: onLanguageToggle,
              ),
              _LobbyIconButton(
                tokens: tokens,
                label: language.t(KolkhozText.lobbyTheme),
                tooltip: appearance.toggleTitle(language),
                iconAsset: 'assets/ui/Icons/${appearance.toggleIconAsset}',
                size: iconSize,
                onPressed: onAppearanceToggle,
              ),
              _LobbyIconButton(
                tokens: tokens,
                label: language.t(KolkhozText.lobbySettings),
                tooltip: language.t(KolkhozText.lobbySettings),
                iconAsset: 'assets/ui/Icons/icon-gears.png',
                prominent: showingProfile,
                size: iconSize,
                badgeCount: comradeRequestCount,
                onPressed: onSettingsPressed ?? onProfilePressed,
              ),
            ];
            if (useGrid) {
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: iconSpacing,
                runSpacing: 6,
                children: buttons,
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: iconSpacing,
              children: buttons,
            );
          },
        ),
      ],
    );
  }

  String get cloudStatusIconAsset {
    if (cloudAuthBusy || (cloudConfigured && !cloudReady)) {
      return 'assets/ui/Icons/icon-status-connecting.png';
    }
    if (!cloudConfigured) {
      return 'assets/ui/Icons/icon-warning.png';
    }
    if (cloudSignedIn) {
      return 'assets/ui/Icons/icon-status-connected.png';
    }
    return 'assets/ui/Icons/icon-profile.png';
  }

  String get cloudStatusTooltip {
    if (!cloudConfigured) {
      return language.t(KolkhozText.kolkhozappCloudAccountUnavailable);
    }
    if (cloudAuthBusy || !cloudReady) {
      return language.t(KolkhozText.kolkhozappConnectingAccount);
    }
    if (cloudSignedIn) {
      final email = cloudEmail?.trim();
      if (email != null && email.isNotEmpty) {
        return language.t(KolkhozText.kolkhozappSignedInEmail, {
          'email': email,
        });
      }
      return language.t(KolkhozText.kolkhozappSignedIn);
    }
    return language.t(KolkhozText.kolkhozappSignedOut2);
  }
}

double _buttonContentIconSize(double buttonHeight) {
  return (buttonHeight * 0.68).clamp(24.0, 40.0);
}

PixelTextSize _buttonContentTextSize(double buttonHeight) {
  final targetFontSize = buttonHeight * 0.40;
  if (targetFontSize <= 9) {
    return PixelTextSize.xSmall;
  }
  if (targetFontSize <= 10.5) {
    return PixelTextSize.small;
  }
  if (targetFontSize <= 12) {
    return PixelTextSize.caption2;
  }
  if (targetFontSize <= 15) {
    return PixelTextSize.caption;
  }
  if (targetFontSize <= 18.5) {
    return PixelTextSize.headline;
  }
  if (targetFontSize <= 22) {
    return PixelTextSize.title;
  }
  return PixelTextSize.cardRank;
}

class _LobbyIconButton extends StatelessWidget {
  const _LobbyIconButton({
    required this.tokens,
    required this.label,
    required this.iconAsset,
    this.tooltip,
    this.prominent = false,
    this.size = 58,
    this.badgeCount = 0,
    this.onPressed,
  });

  final DesignTokens tokens;
  final String label;
  final String iconAsset;
  final String? tooltip;
  final bool prominent;
  final double size;
  final int badgeCount;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: ChromeButtonBackground(
                asset: prominent
                    ? chromeButtonPrimaryAsset
                    : chromeButtonSecondaryAsset,
              ),
            ),
            Image.asset(
              iconAsset,
              width: (size * 0.52).clamp(23.0, 30.0),
              height: (size * 0.52).clamp(23.0, 30.0),
              filterQuality: FilterQuality.none,
            ),
            if (badgeCount > 0)
              Positioned(
                right: (size * 0.06).clamp(2.0, 5.0),
                top: (size * 0.04).clamp(1.0, 4.0),
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: (size * 0.30).clamp(16.0, 19.0),
                  ),
                  height: (size * 0.30).clamp(16.0, 19.0),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: tokens.colors.redBright,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: tokens.colors.gold, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: kolkhozFontStyle.copyWith(
                        color: tokens.colors.activeSurfaceText,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Tooltip(
      message: tooltip ?? label,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: label,
        child: button,
      ),
    );
  }
}

class _LobbyFooter extends StatelessWidget {
  const _LobbyFooter({required this.tokens, required this.language});

  final DesignTokens tokens;
  final KolkhozLanguage language;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 2,
      children: [
        Text(
          language.t(KolkhozText.kolkhozappGameBy),
          style: kolkhozFontStyle.copyWith(
            color: tokens.colors.gold,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          language.t(KolkhozText.kolkhozappWilliamTheisen),
          style: kolkhozFontStyle.copyWith(
            color: tokens.colors.gold,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LobbyPanel extends StatelessWidget {
  const _LobbyPanel({
    required this.tokens,
    required this.language,
    required this.selectedPreset,
    required this.customVariants,
    required this.playerControllers,
    required this.demoMode,
    required this.variants,
    required this.appearance,
    required this.cardBack,
    required this.compactRail,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.confirmNewGame = true,
    this.confirmMainMenu = true,
    this.showInvalidTapHints = true,
    this.soundEnabled = true,
    required this.showingRules,
    required this.showingOnline,
    required this.showingProfile,
    required this.initialSettingsTab,
    required this.hostedInviteCode,
    required this.onlineSessionUpdate,
    required this.showHostedInviteCode,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.progression,
    required this.unlockedCardBacks,
    required this.favoriteSetup,
    required this.lastStartedSetup,
    required this.comradesSummary,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudEmail,
    required this.cloudAuthBusy,
    required this.cloudAuthMessage,
    required this.cloudAuthIsError,
    required this.onTutorialPressed,
    required this.onStart,
    required this.onHostOnline,
    required this.onInviteOnlineComrades,
    required this.onJoinOnline,
    required this.onRememberStartedSetup,
    required this.onMatchmakeOnline,
    required this.onKickOnlinePlayer,
    required this.onEnterOnlineGame,
    required this.onCancelOnlineGame,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
    this.onAnimationSpeedChanged,
    this.onConfirmNewGameChanged,
    this.onConfirmMainMenuChanged,
    this.onShowInvalidTapHintsChanged,
    this.onSoundEnabledChanged,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
    required this.onCardBackChanged,
    required this.onDisplayNameChanged,
    required this.onPortraitChanged,
    required this.onSaveFavoriteSetup,
    required this.onUseFavoriteSetup,
    required this.onCloudSignIn,
    required this.onCloudSignUp,
    required this.onCloudResetPassword,
    required this.onCloudSignOut,
    required this.onComradesChanged,
    required this.onComradeRequestToUser,
    required this.onlineClientFactory,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final bool demoMode;
  final KolkhozGameVariants variants;
  final KolkhozAppearance appearance;
  final KolkhozCardBack cardBack;
  final bool compactRail;
  final GameAnimationSpeed animationSpeed;
  final bool confirmNewGame;
  final bool confirmMainMenu;
  final bool showInvalidTapHints;
  final bool soundEnabled;
  final bool showingRules;
  final bool showingOnline;
  final bool showingProfile;
  final KolkhozSettingsTab initialSettingsTab;
  final String? hostedInviteCode;
  final OnlineSessionUpdate? onlineSessionUpdate;
  final bool showHostedInviteCode;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final ProgressionState progression;
  final Set<KolkhozCardBack> unlockedCardBacks;
  final KolkhozFavoriteSetup? favoriteSetup;
  final KolkhozFavoriteSetup? lastStartedSetup;
  final OnlineComradesResponse comradesSummary;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final String? cloudAuthMessage;
  final bool cloudAuthIsError;
  final VoidCallback onTutorialPressed;
  final VoidCallback onStart;
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
    bool ranked,
    bool browserJoinable,
  )
  onHostOnline;
  final Future<void> Function(String sessionID, List<String> userIDs)?
  onInviteOnlineComrades;
  final Future<void> Function(
    Uri baseURL,
    String inviteCode,
    int? preferredPlayerID,
  )
  onJoinOnline;
  final void Function(
    List<KolkhozPlayerController> controllers,
    List<String> lobbySeats,
    bool browserJoinable,
  )?
  onRememberStartedSetup;
  final Future<String> Function(
    Uri baseURL,
    bool rankedOnly,
    bool comradesOnly,
  )?
  onMatchmakeOnline;
  final Future<void> Function(int playerID)? onKickOnlinePlayer;
  final VoidCallback onEnterOnlineGame;
  final VoidCallback? onCancelOnlineGame;
  final ValueChanged<KolkhozGamePreset> onPresetChanged;
  final ValueChanged<KolkhozGameVariants> onCustomVariantsChanged;
  final ValueChanged<List<KolkhozPlayerController>> onPlayerControllersChanged;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final ValueChanged<bool>? onSoundEnabledChanged;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;
  final ValueChanged<KolkhozCardBack>? onCardBackChanged;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onPortraitChanged;
  final VoidCallback? onSaveFavoriteSetup;
  final VoidCallback? onUseFavoriteSetup;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final Future<void> Function()? onCloudSignOut;
  final ValueChanged<OnlineComradesResponse>? onComradesChanged;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final KolkhozOnlineClient Function()? onlineClientFactory;

  @override
  Widget build(BuildContext context) {
    final creatingGame = !showingProfile && !showingOnline && !showingRules;
    final variantPanel = _VariantPanel(
      tokens: tokens,
      language: language,
      selectedPreset: selectedPreset,
      customVariants: customVariants,
      playerControllers: playerControllers,
      demoMode: demoMode,
      variants: variants,
      displayName: displayName,
      portraitAsset: portraitAsset,
      profileStats: profileStats,
      favoriteSetup: favoriteSetup,
      lastStartedSetup: lastStartedSetup,
      comradesSummary: comradesSummary,
      compactRail: compactRail,
      onStart: onStart,
      onHostOnline: onHostOnline,
      onInviteOnlineComrades: onInviteOnlineComrades,
      onComradeRequestToUser: onComradeRequestToUser,
      onRememberStartedSetup: onRememberStartedSetup,
      hostedInviteCode: hostedInviteCode,
      onlineSessionUpdate: onlineSessionUpdate,
      showHostedInviteCode: showHostedInviteCode,
      onKickOnlinePlayer: onKickOnlinePlayer,
      onEnterOnlineGame: onEnterOnlineGame,
      onCancelOnlineGame: onCancelOnlineGame,
      onPresetChanged: onPresetChanged,
      onCustomVariantsChanged: onCustomVariantsChanged,
      onPlayerControllersChanged: onPlayerControllersChanged,
      onSaveFavoriteSetup: onSaveFavoriteSetup,
      onUseFavoriteSetup: onUseFavoriteSetup,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.colors.panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(tokens.radius.panelOuter),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: tokens.colors.black.withValues(alpha: 0.36),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(offstage: !creatingGame, child: variantPanel),
          if (showingProfile)
            _SettingsPanel(
              tokens: tokens,
              language: language,
              appearance: appearance,
              cardBack: cardBack,
              animationSpeed: animationSpeed,
              confirmNewGame: confirmNewGame,
              confirmMainMenu: confirmMainMenu,
              showInvalidTapHints: showInvalidTapHints,
              soundEnabled: soundEnabled,
              displayName: displayName,
              portraitAsset: portraitAsset,
              profileStats: profileStats,
              progression: progression,
              unlockedCardBacks: unlockedCardBacks,
              comradesSummary: comradesSummary,
              cloudConfigured: cloudConfigured,
              cloudReady: cloudReady,
              cloudSignedIn: cloudSignedIn,
              cloudEmail: cloudEmail,
              cloudAuthBusy: cloudAuthBusy,
              cloudAuthMessage: cloudAuthMessage,
              cloudAuthIsError: cloudAuthIsError,
              initialTab: initialSettingsTab,
              onStart: onStart,
              onTutorialPressed: onTutorialPressed,
              onAnimationSpeedChanged: onAnimationSpeedChanged,
              onConfirmNewGameChanged: onConfirmNewGameChanged,
              onConfirmMainMenuChanged: onConfirmMainMenuChanged,
              onShowInvalidTapHintsChanged: onShowInvalidTapHintsChanged,
              onSoundEnabledChanged: onSoundEnabledChanged,
              onLanguageToggle: onLanguageToggle,
              onAppearanceToggle: onAppearanceToggle,
              onCardBackChanged: onCardBackChanged,
              onDisplayNameChanged: onDisplayNameChanged,
              onPortraitChanged: onPortraitChanged,
              onCloudSignIn: onCloudSignIn,
              onCloudSignUp: onCloudSignUp,
              onCloudResetPassword: onCloudResetPassword,
              onCloudSignOut: onCloudSignOut,
              onComradesChanged: onComradesChanged,
              onlineClientFactory: onlineClientFactory,
            )
          else if (showingOnline)
            _OnlinePanel(
              tokens: tokens,
              language: language,
              hostedInviteCode: hostedInviteCode,
              onlineSessionUpdate: onlineSessionUpdate,
              showHostedInviteCode: showHostedInviteCode,
              onJoinOnline: onJoinOnline,
              onMatchmakeOnline: onMatchmakeOnline,
              onKickOnlinePlayer: onKickOnlinePlayer,
              onEnterOnlineGame: onEnterOnlineGame,
              onCancelOnlineGame: onCancelOnlineGame,
              comradesSummary: comradesSummary,
              onComradesChanged: onComradesChanged,
              onComradeRequestToUser: onComradeRequestToUser,
              onlineClientFactory: onlineClientFactory,
            )
          else if (showingRules)
            _RulesPanel(
              tokens: tokens,
              language: language,
              onTutorialPressed: onTutorialPressed,
            ),
        ],
      ),
    );
  }
}

enum KolkhozSettingsTab {
  profile,
  leaderboard,
  progress,
  comrades,
  assist,
  display,
  rules;

  String title(KolkhozLanguage language) {
    return switch (this) {
      KolkhozSettingsTab.profile => language.t(KolkhozText.kolkhozappProfile),
      KolkhozSettingsTab.leaderboard => 'LEADERBOARD',
      KolkhozSettingsTab.progress => language.t(KolkhozText.kolkhozappProgress),
      KolkhozSettingsTab.comrades => language.t(KolkhozText.kolkhozappComrades),
      KolkhozSettingsTab.assist => OptionsMenuTab.assist.title(language),
      KolkhozSettingsTab.display => OptionsMenuTab.display.title(language),
      KolkhozSettingsTab.rules => OptionsMenuTab.rules.title(language),
    };
  }

  String get iconAsset {
    return switch (this) {
      KolkhozSettingsTab.profile => 'assets/ui/Icons/icon-profile.png',
      KolkhozSettingsTab.leaderboard => 'assets/ui/Icons/icon-medal-star.png',
      KolkhozSettingsTab.progress => 'assets/ui/Icons/icon-medal-star.png',
      KolkhozSettingsTab.comrades => 'assets/ui/Icons/icon-friends-list.png',
      KolkhozSettingsTab.assist => OptionsMenuTab.assist.iconAsset,
      KolkhozSettingsTab.display => OptionsMenuTab.display.iconAsset,
      KolkhozSettingsTab.rules => OptionsMenuTab.rules.iconAsset,
    };
  }
}

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({
    required this.tokens,
    required this.language,
    required this.appearance,
    required this.cardBack,
    required this.animationSpeed,
    required this.confirmNewGame,
    required this.confirmMainMenu,
    required this.showInvalidTapHints,
    required this.soundEnabled,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.progression,
    required this.unlockedCardBacks,
    required this.comradesSummary,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudEmail,
    required this.cloudAuthBusy,
    required this.cloudAuthMessage,
    required this.cloudAuthIsError,
    required this.initialTab,
    required this.onStart,
    required this.onTutorialPressed,
    required this.onAnimationSpeedChanged,
    required this.onConfirmNewGameChanged,
    required this.onConfirmMainMenuChanged,
    required this.onShowInvalidTapHintsChanged,
    required this.onSoundEnabledChanged,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
    required this.onCardBackChanged,
    required this.onDisplayNameChanged,
    required this.onPortraitChanged,
    required this.onCloudSignIn,
    required this.onCloudSignUp,
    required this.onCloudResetPassword,
    required this.onCloudSignOut,
    required this.onComradesChanged,
    required this.onlineClientFactory,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final KolkhozCardBack cardBack;
  final GameAnimationSpeed animationSpeed;
  final bool confirmNewGame;
  final bool confirmMainMenu;
  final bool showInvalidTapHints;
  final bool soundEnabled;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final ProgressionState progression;
  final Set<KolkhozCardBack> unlockedCardBacks;
  final OnlineComradesResponse comradesSummary;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final String? cloudAuthMessage;
  final bool cloudAuthIsError;
  final KolkhozSettingsTab initialTab;
  final VoidCallback onStart;
  final VoidCallback onTutorialPressed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final ValueChanged<bool>? onSoundEnabledChanged;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;
  final ValueChanged<KolkhozCardBack>? onCardBackChanged;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onPortraitChanged;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final Future<void> Function()? onCloudSignOut;
  final ValueChanged<OnlineComradesResponse>? onComradesChanged;
  final KolkhozOnlineClient Function()? onlineClientFactory;

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  late KolkhozSettingsTab selectedTab = widget.initialTab;

  @override
  void didUpdateWidget(covariant _SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      selectedTab = widget.initialTab;
    }
  }

  Widget _tabBody() {
    return switch (selectedTab) {
      KolkhozSettingsTab.profile => _ProfilePanel(
        tokens: widget.tokens,
        language: widget.language,
        displayName: widget.displayName,
        portraitAsset: widget.portraitAsset,
        profileStats: widget.profileStats,
        progression: widget.progression,
        cloudConfigured: widget.cloudConfigured,
        cloudReady: widget.cloudReady,
        cloudSignedIn: widget.cloudSignedIn,
        cloudEmail: widget.cloudEmail,
        cloudAuthBusy: widget.cloudAuthBusy,
        cloudAuthMessage: widget.cloudAuthMessage,
        cloudAuthIsError: widget.cloudAuthIsError,
        onDisplayNameChanged: widget.onDisplayNameChanged,
        onPortraitChanged: widget.onPortraitChanged,
        onCloudSignIn: widget.onCloudSignIn,
        onCloudSignUp: widget.onCloudSignUp,
        onCloudResetPassword: widget.onCloudResetPassword,
        onCloudSignOut: widget.onCloudSignOut,
      ),
      KolkhozSettingsTab.leaderboard => _LeaderboardPanel(
        tokens: widget.tokens,
        language: widget.language,
        clientFactory: widget.onlineClientFactory,
        signedIn: widget.cloudSignedIn,
      ),
      KolkhozSettingsTab.progress => ProgressionOverview(
        state: widget.progression,
        tokens: widget.tokens,
      ),
      KolkhozSettingsTab.comrades => _ComradesSettingsPanel(
        tokens: widget.tokens,
        language: widget.language,
        comradesSummary: widget.comradesSummary,
        cloudConfigured: widget.cloudConfigured,
        cloudReady: widget.cloudReady,
        cloudSignedIn: widget.cloudSignedIn,
        cloudEmail: widget.cloudEmail,
        cloudAuthBusy: widget.cloudAuthBusy,
        cloudAuthMessage: widget.cloudAuthMessage,
        cloudAuthIsError: widget.cloudAuthIsError,
        onCloudSignIn: widget.onCloudSignIn,
        onCloudSignUp: widget.onCloudSignUp,
        onCloudResetPassword: widget.onCloudResetPassword,
        onComradesChanged: widget.onComradesChanged,
      ),
      KolkhozSettingsTab.assist => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            OptionsSessionControls(
              tokens: widget.tokens,
              language: widget.language,
              onNewGame: widget.onStart,
              onTutorial: widget.onTutorialPressed,
              confirmNewGame: widget.confirmNewGame,
              onConfirmNewGameChanged: widget.onConfirmNewGameChanged,
              confirmMainMenu: widget.confirmMainMenu,
              onConfirmMainMenuChanged: widget.onConfirmMainMenuChanged,
            ),
            _GoldDivider(tokens: widget.tokens),
            OptionsAssistControls(
              tokens: widget.tokens,
              language: widget.language,
              showInvalidTapHints: widget.showInvalidTapHints,
              onShowInvalidTapHintsChanged: widget.onShowInvalidTapHintsChanged,
            ),
          ],
        ),
      ),
      KolkhozSettingsTab.display => SingleChildScrollView(
        child: OptionsDisplayControls(
          tokens: widget.tokens,
          language: widget.language,
          appearance: widget.appearance,
          cardBack: widget.cardBack,
          animationSpeed: widget.animationSpeed,
          soundEnabled: widget.soundEnabled,
          onSoundEnabledChanged: widget.onSoundEnabledChanged,
          onAnimationSpeedChanged: widget.onAnimationSpeedChanged,
          onLanguageToggle: widget.onLanguageToggle,
          onAppearanceToggle: widget.onAppearanceToggle,
          onCardBackChanged: widget.onCardBackChanged,
          unlockedCardBacks: widget.unlockedCardBacks,
        ),
      ),
      KolkhozSettingsTab.rules => SingleChildScrollView(
        child: OptionsMenuRules(
          tokens: widget.tokens,
          language: widget.language,
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = optionsMenuTabSpacing;
            final tabWidth = math.max(
              92.0,
              (constraints.maxWidth - spacing * 4) / 5,
            );
            final tabHeight = (tabWidth * 0.30).clamp(38.0, 52.0);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: spacing,
                children: [
                  for (final tab in KolkhozSettingsTab.values)
                    SizedBox(
                      width: tabWidth,
                      child: _SettingsTabButton(
                        tokens: widget.tokens,
                        label: tab.title(widget.language),
                        iconAsset: tab.iconAsset,
                        selected: selectedTab == tab,
                        height: tabHeight,
                        onPressed: () => setState(() => selectedTab = tab),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        _GoldDivider(tokens: widget.tokens),
        Expanded(child: _tabBody()),
      ],
    );
  }
}

class _SettingsTabButton extends StatelessWidget {
  const _SettingsTabButton({
    required this.tokens,
    required this.label,
    required this.iconAsset,
    required this.selected,
    required this.height,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final String label;
  final String iconAsset;
  final bool selected;
  final double height;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final iconSize = (height * 0.72).clamp(24.0, 38.0);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: ChromeAssetButton(
            label: label,
            tokens: tokens,
            backgroundAsset: selected
                ? chromeButtonPrimaryAsset
                : chromeButtonSecondaryAsset,
            textColor: selected
                ? tokens.colors.onAccent
                : tokens.colors.cardInk,
            textSize: _settingsTabTextSize(height),
            onPressed: onPressed,
            iconAsset: iconAsset,
            iconSize: iconSize,
            height: height,
            padding: EdgeInsets.symmetric(
              horizontal: (height * 0.08).clamp(3.0, 6.0),
            ),
            spacing: (height * 0.08).clamp(3.0, 5.0),
            expandLabel: false,
          ),
        ),
      ),
    );
  }
}

PixelTextSize _settingsTabTextSize(double height) {
  final targetFontSize = height * 0.58;
  if (targetFontSize <= 10.5) {
    return PixelTextSize.small;
  }
  if (targetFontSize <= 12) {
    return PixelTextSize.caption2;
  }
  if (targetFontSize <= 15) {
    return PixelTextSize.caption;
  }
  if (targetFontSize <= 18.5) {
    return PixelTextSize.headline;
  }
  return PixelTextSize.title;
}
