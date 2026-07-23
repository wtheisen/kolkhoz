import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kolkhoz_app/src/app/navigation/app_navigation_controller.dart';
import 'package:kolkhoz_app/src/app/remote_connection/remote_connection.dart';
import 'package:kolkhoz_app/src/app/remote_connection/push_remote_connection.dart';
import 'package:kolkhoz_app/src/app/remote_connection/remote_status.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/profile_controller.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_connection.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/main_menu_controller.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/settings/settings_store.dart';
import 'package:kolkhoz_app/src/app/views/shared/app_text.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/commerce.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/settings/game_sound.dart';
import 'package:kolkhoz_app/src/app/views/game/game_view.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_controller.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_remote_connection.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/remote_game_engine_factory.dart';
import 'package:kolkhoz_app/src/app/remote_connection/push_notifications.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/progression.dart';
import 'package:kolkhoz_app/src/app/profile/views/progression_notice.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/display/table_display.dart';
import 'package:kolkhoz_app/src/app/views/shared/tutorial_display.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_view.dart';

export 'package:kolkhoz_app/src/app/views/main_menu/main_menu_view.dart';
export 'package:kolkhoz_app/src/app/navigation/app_navigation_controller.dart'
    show KolkhozGameLaunchOrigin;

Future<bool> showGameControlConfirmation({
  required BuildContext context,
  required KolkhozLanguage language,
  DesignTokens tokens = defaultDesignTokens,
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final actionTextStyle = kolkhozFontStyle.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w800,
      );
      return AlertDialog(
        backgroundColor: tokens.colors.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius.md),
          side: BorderSide(color: tokens.colors.gold.withValues(alpha: 0.7)),
        ),
        titleTextStyle: kolkhozFontStyle.copyWith(
          color: tokens.colors.gold,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: kolkhozFontStyle.copyWith(
          color: tokens.colors.cream,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: tokens.colors.creamDim,
              textStyle: actionTextStyle,
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(language.strings.kolkhozappCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: tokens.colors.goldBright,
              textStyle: actionTextStyle,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<bool> showPushNotificationOffer({
  required BuildContext context,
  DesignTokens tokens = defaultDesignTokens,
}) async {
  final actionTextStyle = kolkhozFontStyle.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w800,
  );
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: tokens.colors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius.md),
        side: BorderSide(color: tokens.colors.gold.withValues(alpha: 0.7)),
      ),
      titleTextStyle: kolkhozFontStyle.copyWith(
        color: tokens.colors.gold,
        fontSize: 21,
        fontWeight: FontWeight.w900,
      ),
      contentTextStyle: kolkhozFontStyle.copyWith(
        color: tokens.colors.cream,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      title: const Text('Stay informed'),
      content: const Text(
        'Kolkhoz can notify you about comrade requests, invitations, and '
        'when a human move is waiting for you. Notifications never contain '
        'private game state.',
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: tokens.colors.creamDim,
            textStyle: actionTextStyle,
          ),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: tokens.colors.goldBright,
            textStyle: actionTextStyle,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Enable'),
        ),
      ],
    ),
  );
  return result ?? false;
}

bool shouldShowStandaloneLobby({
  required bool hasModel,
  required bool showingLobby,
  required bool isOnlineGame,
  required bool onlineStarted,
}) {
  return !hasModel || (showingLobby && (!isOnlineGame || !onlineStarted));
}

bool shouldEnterStartedOnlineGame({
  required bool showingLobby,
  required bool isOnlineGame,
  required bool onlineStarted,
}) => showingLobby && isOnlineGame && onlineStarted;

bool canAccessOnlinePlay({
  required bool fullGameUnlocked,
  required bool signedIn,
}) => fullGameUnlocked && signedIn;

String normalizeAccountEmail(String email) => email.trim();

const maxAccountEmailLength = 254;

String safeAccountErrorMessage(Object exception, KolkhozLanguage language) {
  if (exception is FormatException) {
    return exception.message;
  }
  final message = '$exception'.toLowerCase();
  if (message.contains('valid recovery email')) {
    return language.strings.kolkhozappAccountInvalidEmail;
  }
  if (message.contains('too many')) {
    return language.strings.kolkhozappAccountRateLimited;
  }
  if (message.contains('not configured') ||
      message.contains('could not be sent')) {
    return language.strings.kolkhozappAccountServiceUnavailable;
  }
  return language.strings.kolkhozappAccountRequestFailed;
}

class KolkhozApp extends StatefulWidget {
  const KolkhozApp({super.key});

  @override
  State<KolkhozApp> createState() => _KolkhozAppState();
}

class _KolkhozAppState extends State<KolkhozApp> with WidgetsBindingObserver {
  static const foremanHintDuration = Duration(seconds: 3);

  final navigatorKey = GlobalKey<NavigatorState>();
  final gameSounds = GameSoundController();
  late final AppNavigationController navigationController;
  late final GameController store;
  late final KolkhozCommerceController commerce;
  late final KolkhozAppSettingsStore settingsStore;
  late final RemoteConnection remoteConnection;
  late final MenuRemoteConnection menuRemoteConnection;
  late final MainMenuController mainMenuController;
  late final ProfileController profileController;
  late final PushRemoteConnection pushRemoteConnection;
  late final String onlineDeviceID;
  late final KolkhozPushNotifications pushNotifications;
  bool notificationPromptShown = false;
  bool guestLinkNoticeShown = false;
  RemoteActiveGame? activeRemoteSession;
  bool activeSessionSyncBusy = false;
  KolkhozAppSettings settings = const KolkhozAppSettings();
  String? activeInviteDialogSessionID;
  String? recordedGameStatsKey;
  String? handledIdentityUserID;
  TableViewModel? previousSoundModel;
  int previousSoundActionCount = 0;
  bool onlineSessionCreatedByLocalPlayer = false;
  String? foremanHint;
  Timer? foremanHintTimer;
  Timer? progressionNoticeTimer;
  String? progressionNotice;
  KolkhozGamePreset selectedPreset = KolkhozGamePreset.kolkhoz;
  KolkhozGameVariants customVariants = KolkhozGameVariants.kolkhoz;
  List<KolkhozPlayerController> playerControllers = List.of(
    KolkhozPlayerController.defaultControllers,
  );

  AppDestination get destination => navigationController.destination;
  KolkhozGameLaunchOrigin get gameLaunchOrigin =>
      navigationController.gameLaunchOrigin;
  KolkhozSettingsTab get selectedSettingsTab => KolkhozSettingsTab.values
      .byName(navigationController.settingsSection.name);
  bool get showingTutorial => navigationController.showingTutorial;
  bool get showingLobby => destination != AppDestination.game;
  bool get showingRules => destination == AppDestination.rules;
  bool get showingOnline => destination == AppDestination.online;
  bool get showingProfile => destination == AppDestination.profile;

  bool get demoMode => !commerce.fullGameUnlocked;
  bool get onlinePlayAllowed => canAccessOnlinePlay(
    fullGameUnlocked: commerce.fullGameUnlocked,
    signedIn: onlineSignedIn,
  );

  ProgressionState get effectiveProgression =>
      profileController.player?.portable == false
      ? const ProgressionState()
      : mergeProgressionStates(
          settings.progression,
          settings.onlineProgressionUserID == onlineUserID
              ? settings.onlineProgression
              : const ProgressionState(),
        );

  KolkhozGameVariants get activeVariants {
    if (demoMode) {
      return KolkhozGameVariants.demoKolkhoz;
    }
    return selectedPreset.variants ?? customVariants;
  }

  List<KolkhozPlayerController> get activePlayerControllers {
    return demoMode
        ? KolkhozPlayerController.demoControllers
        : playerControllers;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    navigationController = AppNavigationController()
      ..addListener(handleNavigationChanged);
    settingsStore = KolkhozAppSettingsStore.defaultStore();
    settings = settingsStore.load();
    onlineDeviceID =
        settings.installationID ??
        '${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}';
    if (settings.installationID == null) {
      settings = settings.copyWith(installationID: onlineDeviceID);
      settingsStore.save(settings);
    }
    gameSounds.enabled = settings.soundEnabled;
    final lastStartedSetup = settings.lastStartedSetup;
    if (lastStartedSetup != null) {
      selectedPreset = presetForVariants(lastStartedSetup.variants);
      customVariants = lastStartedSetup.variants;
      playerControllers = KolkhozPlayerController.normalized(
        lastStartedSetup.controllers,
      );
    }
    remoteConnection = RemoteConnection(
      baseURL: onlineServerURL,
      accessTokenProvider: identityAccessToken,
      deviceID: onlineDeviceID,
      activeSessionID: () => store.onlineSessionID,
    )..addListener(handleRemoteConnectionChanged);
    menuRemoteConnection = MenuRemoteConnection(remoteConnection);
    profileController = ProfileController(connection: remoteConnection)
      ..addListener(handlePlayerIdentityChanged);
    pushRemoteConnection = PushRemoteConnection(remoteConnection);
    final gameRemoteConnection = GameRemoteConnection(remoteConnection);
    store = GameController(
      remoteGameEngineFactory: RemoteGameEngineFactory(gameRemoteConnection),
    );
    store.addListener(handleStoreChanged);
    mainMenuController = MainMenuController(
      menuRemoteConnection,
      () => onlineSignedIn,
      () => store.onlineSessionID,
    )..addListener(handleMainMenuChanged);
    commerce = KolkhozCommerceController(
      fetchFullGameEntitlement: profileController.fetchFullGameEntitlement,
      claimFullGamePurchase: profileController.claimFullGamePurchase,
      onFullGameChanged: cacheFullGameEntitlement,
    );
    syncPendingGameLobby();
    commerce.addListener(handleCommerceChanged);
    commerce.initialize();
    pushNotifications = KolkhozPushNotifications(
      installationID: onlineDeviceID,
      registerInstallation:
          ({required installationID, required platform, required token}) =>
              pushRemoteConnection.registerInstallation(
                installationID: installationID,
                platform: platform,
                token: token,
              ),
      deleteInstallation: (installationID) =>
          pushRemoteConnection.deleteInstallation(installationID),
      isSignedIn: () => onlineSignedIn,
      onForegroundMessage: handleForegroundPush,
      onOpenMessage: handleOpenedPush,
    );
    unawaited(pushNotifications.initialize());
    if (lastStartedSetup == null) {
      playerControllers = List.of(store.controllers);
    }
    unawaited(
      profileController.start(
        installationID: onlineDeviceID,
        displayName: settings.displayName,
      ),
    );
    remoteConnection.startHeartbeat();
    mainMenuController.startInvitePolling();
  }

  @override
  void dispose() {
    foremanHintTimer?.cancel();
    progressionNoticeTimer?.cancel();
    mainMenuController.removeListener(handleMainMenuChanged);
    mainMenuController.dispose();
    navigationController.removeListener(handleNavigationChanged);
    navigationController.dispose();
    store.removeListener(handleStoreChanged);
    commerce.removeListener(handleCommerceChanged);
    commerce.dispose();
    unawaited(gameSounds.dispose());
    unawaited(pushNotifications.dispose());
    remoteConnection.removeListener(handleRemoteConnectionChanged);
    remoteConnection.dispose();
    profileController.removeListener(handlePlayerIdentityChanged);
    profileController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    store.dispose();
    super.dispose();
  }

  void handleNavigationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      remoteConnection.startHeartbeat();
      mainMenuController.startInvitePolling();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      remoteConnection.stopHeartbeat();
      mainMenuController.stopInvitePolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Kolkhoz',
      locale: Locale(settings.language.name),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        fontFamily: 'Handjet',
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Handjet'),
      ),
      builder: (context, child) => DefaultTextStyle.merge(
        style: kolkhozFontStyle,
        child: Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (showingLobby && demoMode && onlineSignedIn)
              Positioned(
                key: const ValueKey('unlock-full-game'),
                right: 16,
                bottom: 16,
                child: SafeArea(
                  child: SizedBox(
                    width: 220,
                    height: 46,
                    child: ChromeAssetButton.command(
                      label: commerce.price == null
                          ? 'UNLOCK FULL GAME'
                          : 'UNLOCK • ${commerce.price}',
                      prominent: true,
                      tokens: settings.appearance.tokens,
                      onPressed: commerce.busy ? null : showFullGameUnlock,
                      iconAsset: 'assets/ui/Icons/icon-lock.png',
                      iconSize: 22,
                    ),
                  ),
                ),
              ),
            if (activeRemoteSession?.requiresSync ?? false)
              Positioned.fill(
                child: ActiveSessionSyncOverlay(
                  tokens: settings.appearance.tokens,
                  busy: activeSessionSyncBusy,
                  onSync: syncActiveSession,
                ),
              ),
            if (store.isSpectating)
              Positioned(
                key: const ValueKey('spectator-banner'),
                top: 12,
                left: 76,
                child: SafeArea(
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: settings.appearance.tokens.colors.black
                            .withValues(alpha: 0.8),
                        border: Border.all(
                          color: settings.appearance.tokens.colors.gold,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'SPECTATING • READ ONLY',
                        style: kolkhozFontStyle.copyWith(
                          color: settings.appearance.tokens.colors.goldBright,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (store.onlineUpdate?.series case final series?)
              Positioned(
                key: const ValueKey('series-banner'),
                top: 12,
                right: 12,
                child: SafeArea(
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: settings.appearance.tokens.colors.black
                            .withValues(alpha: 0.8),
                        border: Border.all(
                          color: settings.appearance.tokens.colors.gold,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'BEST OF ${series.bestOf} • ROUND ${series.roundNumber} • '
                        '${[for (var i = 0; i < 4; i++) 'P${i + 1} ${series.winsFor(i)}'].join('  ')}',
                        style: kolkhozFontStyle.copyWith(
                          color: settings.appearance.tokens.colors.goldBright,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (store.onlineUpdate?.tournament case final tournament?)
              Positioned(
                key: const ValueKey('tournament-round-banner'),
                top: 12,
                left: 76,
                child: SafeArea(
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: settings.appearance.tokens.colors.redDark
                            .withValues(alpha: 0.88),
                        border: Border.all(
                          color: settings.appearance.tokens.colors.gold,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'TOURNAMENT • ROUND ${tournament.roundNumber}/${tournament.totalRounds} • TABLE ${tournament.tableNumber}',
                        style: kolkhozFontStyle.copyWith(
                          color: settings.appearance.tokens.colors.goldBright,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      home: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final language = settings.language;
          final appearance = settings.appearance;
          final cardBack = settings.cardBack;
          final tokens = appearance.tokens;
          late final Widget content;
          if (store.error != null && store.model == null) {
            content = StandaloneErrorView(error: store.error!, tokens: tokens);
          } else if (shouldShowStandaloneLobby(
            hasModel: store.model != null,
            showingLobby: showingLobby,
            isOnlineGame: store.isOnlineGame,
            onlineStarted: store.onlineUpdate?.started ?? false,
          )) {
            content = StandaloneLobby(
              tokens: tokens,
              language: language,
              appearance: appearance,
              cardBack: cardBack,
              error: store.error,
              selectedPreset: selectedPreset,
              customVariants: customVariants,
              playerControllers: playerControllers,
              gameLobby: store.lobby,
              demoMode: demoMode,
              animationSpeed: store.animationSpeed,
              confirmNewGame: settings.confirmNewGame,
              confirmMainMenu: settings.confirmMainMenu,
              showInvalidTapHints: settings.showInvalidTapHints,
              soundEnabled: settings.soundEnabled,
              showingRules: showingRules,
              showingOnline: showingOnline,
              showingProfile: showingProfile,
              initialSettingsTab: selectedSettingsTab,
              hostedInviteCode: store.onlineInviteCode,
              onlineSessionUpdate: store.onlineUpdate,
              showHostedInviteCode: onlineSessionCreatedByLocalPlayer,
              displayName: settings.displayName,
              portraitAsset: settings.portraitAsset,
              profileStats: settings.profileStats,
              progression: effectiveProgression,
              unlockedCardBacks: {
                for (final cardBack in KolkhozCardBack.values)
                  if (isCardBackUnlocked(effectiveProgression, cardBack) ||
                      cardBack == settings.cardBack)
                    cardBack,
              },
              favoriteSetup: settings.favoriteSetup,
              lastStartedSetup: settings.lastStartedSetup,
              comradesSummary: comradesSummary,
              cloudConfigured: true,
              cloudReady: true,
              cloudSignedIn: onlineSignedIn,
              cloudEmail: profileController.player?.recoveryEmail,
              cloudAuthBusy: profileController.busy,
              cloudAuthMessage: profileController.message,
              cloudAuthIsError: profileController.messageIsError,
              onHostOnline: hostOnlineGame,
              onHostOnlineSeries: hostOnlineSeries,
              onInviteOnlineComrades: inviteOnlineComrades,
              onJoinOnline: joinOnlineGame,
              onWatchOnline: (baseURL, sessionID) async {
                await store.watchOnlineGame(sessionID: sessionID);
                if (mounted) {
                  setState(() => onlineSessionCreatedByLocalPlayer = false);
                  navigationController.showGame(
                    launchOrigin: KolkhozGameLaunchOrigin.joined,
                  );
                }
              },
              onMatchmakeOnline: matchmakeOnlineGame,
              onKickOnlinePlayer: kickOnlinePlayer,
              onEnterOnlineGame: enterOnlineGame,
              onSyncActiveSession: syncActiveSession,
              onCancelOnlineGame: returnToLobby,
              onStart: () {
                syncPendingGameLobby();
                store.startGame();
                setState(() => onlineSessionCreatedByLocalPlayer = false);
                navigationController.showGame(
                  launchOrigin: KolkhozGameLaunchOrigin.created,
                );
              },
              onRememberStartedSetup: rememberStartedSetup,
              onPresetChanged: (preset) {
                if (demoMode) {
                  return;
                }
                setState(() {
                  selectedPreset = preset;
                  final variants = preset.variants;
                  if (variants != null) {
                    customVariants = variants;
                  }
                });
                navigationController.showOffline();
                syncPendingGameLobby();
              },
              onCustomVariantsChanged: (variants) {
                if (demoMode) {
                  return;
                }
                setState(() {
                  selectedPreset = KolkhozGamePreset.custom;
                  customVariants = variants;
                });
                navigationController.showOffline();
                syncPendingGameLobby();
              },
              onPlayerControllersChanged: (controllers) {
                if (demoMode) {
                  return;
                }
                setState(() {
                  playerControllers = KolkhozPlayerController.normalized(
                    controllers,
                  );
                });
                syncPendingGameLobby();
              },
              onAnimationSpeedChanged: store.setAnimationSpeed,
              onConfirmNewGameChanged: setConfirmNewGame,
              onConfirmMainMenuChanged: setConfirmMainMenu,
              onShowInvalidTapHintsChanged: setShowInvalidTapHints,
              onSoundEnabledChanged: setSoundEnabled,
              onRulesPressed: () {
                navigationController.showRules();
              },
              onOfflinePressed: () {
                navigationController.showOffline();
              },
              onOnlinePressed: () {
                if (onlinePlayAllowed) {
                  navigationController.showOnline();
                } else {
                  navigationController.showProfile();
                }
              },
              onProfilePressed: () {
                navigationController.showProfile();
              },
              onSettingsPressed: () {
                navigationController.showProfile(
                  section: AppSettingsSection.display,
                );
              },
              onDisplayNameChanged: profileController.player?.portable == true
                  ? setDisplayName
                  : null,
              onPortraitChanged: profileController.player?.portable == true
                  ? setPortraitAsset
                  : null,
              onSaveFavoriteSetup: saveFavoriteSetup,
              onUseFavoriteSetup: useFavoriteSetup,
              onCloudSignIn: null,
              onCloudSignUp: null,
              onCloudResetPassword: null,
              onCloudDeleteAccount: deleteAccount,
              onComradeRequestToUser: requestComradeByUserID,
              menuRemoteConnection: menuRemoteConnection,
              mainMenuController: mainMenuController,
              profileController: profileController,
              onStartDailyChallenge: () async {
                await store.startDailyChallenge();
                if (mounted) {
                  setState(() => onlineSessionCreatedByLocalPlayer = true);
                  navigationController.showGame(
                    launchOrigin: KolkhozGameLaunchOrigin.created,
                  );
                }
              },
              onTutorialPressed: () {
                showTutorial();
              },
              onLanguageToggle: toggleLanguage,
              onAppearanceToggle: toggleAppearance,
              onCardBackChanged: setCardBack,
            );
          } else {
            final model = store.model!;
            content = Stack(
              children: [
                KolkhozBoard(
                  model: model,
                  tokens: tokens,
                  language: language,
                  appearance: appearance,
                  heroOfSovietUnion: store.currentVariants.heroOfSovietUnion,
                  cardBack: cardBack,
                  onAction: applyBoardAction,
                  onPanelSelected: store.setActivePanel,
                  onLanguageToggle: toggleLanguage,
                  onAppearanceToggle: toggleAppearance,
                  onCardBackChanged: setCardBack,
                  onSwapHandCardTap: store.selectSwapHandCard,
                  onHandCardTap: store.selectHandCard,
                  onPlotCardTap: store.selectPlotCard,
                  onAssignmentCardTap: store.selectAssignmentCard,
                  onInvalidHandCardTap: showFollowSuitHint,
                  canUndo: store.canUndo,
                  onUndo: store.undoLastAction,
                  onHotSeatReady: store.revealLocalPlayer,
                  onNewGame: requestNewGameFromBoard,
                  onReturnToLobby: requestReturnToLobby,
                  onCopyGameResult: copyGameResult,
                  onSaveGameLog: saveGameLog,
                  gameLogActions: store.gameLogActions,
                  gameReactions: store.gameReactions,
                  hasUnreadLogMessages: store.hasUnreadReactions,
                  canSendReaction: store.canSendReaction,
                  onReaction: store.sendReaction,
                  activeReaction: store.activeReaction,
                  gameOverReturnsToLobby:
                      store.onlineUpdate?.tournament != null ||
                      !(store.isOnlineGame &&
                          store.onlineUpdate?.ranked == false &&
                          store.onlineUpdate?.series?.completed != true &&
                          store.model?.table.phase == phaseGameOver),
                  onTutorial: showTutorial,
                  animationSpeed: store.animationSpeed,
                  transition: store.currentTransition,
                  onTransitionComplete: store.completeTransition,
                  onAnimationSpeedChanged: store.setAnimationSpeed,
                  confirmNewGame: settings.confirmNewGame,
                  onConfirmNewGameChanged: setConfirmNewGame,
                  confirmMainMenu: settings.confirmMainMenu,
                  onConfirmMainMenuChanged: setConfirmMainMenu,
                  showInvalidTapHints: settings.showInvalidTapHints,
                  onShowInvalidTapHintsChanged: setShowInvalidTapHints,
                  comradeUserIDs: comradesSummary.userIDs,
                  incomingComradeRequestUserIDs: {
                    for (final request in comradesSummary.incomingRequests)
                      request.userID,
                  },
                  outgoingComradeRequestUserIDs: {
                    for (final request in comradesSummary.outgoingRequests)
                      request.userID,
                  },
                  currentProfileUserID: comradesSummary.userID,
                  onComradeRequestToUser: requestComradeByUserID,
                ),
                if (store.error != null)
                  Positioned(
                    left: 76,
                    right: 12,
                    bottom: 12,
                    child: SafeArea(
                      child: StandaloneErrorBanner(
                        error: store.error!,
                        tokens: tokens,
                      ),
                    ),
                  ),
              ],
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                key: const ValueKey('app-content'),
                child: KolkhozCardBackScope(cardBack: cardBack, child: content),
              ),
              if (foremanHint != null && !showingTutorial)
                Positioned(
                  key: const ValueKey('foreman-hint'),
                  right: 18,
                  bottom: 18,
                  child: IgnorePointer(
                    child: ForemanHintBubble(
                      message: foremanHint!,
                      tokens: tokens,
                    ),
                  ),
                ),
              if (progressionNotice != null && !showingTutorial)
                Positioned(
                  key: const ValueKey('progression-notice'),
                  top: 18,
                  right: 18,
                  child: SafeArea(
                    child: ProgressionNotice(
                      message: progressionNotice!,
                      tokens: tokens,
                    ),
                  ),
                ),
              if (showingTutorial)
                Positioned.fill(
                  key: const ValueKey('tutorial-overlay'),
                  child: TutorialWalkthroughOverlay(
                    tokens: tokens,
                    language: language,
                    model: showingLobby ? null : store.model,
                    onClose: navigationController.closeTutorial,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String? get onlineUserID => profileController.userID;

  bool get onlineSignedIn => onlineUserID != null;

  OnlineComradesResponse get comradesSummary => profileController.comrades;

  Future<String?> identityAccessToken() async => profileController.accessToken;

  void handlePlayerIdentityChanged() {
    if (!mounted) return;
    setState(() {});
    final userID = profileController.userID;
    if (handledIdentityUserID == userID) return;
    handledIdentityUserID = userID;
    syncCommerceUser();
    if (profileController.player != null) {
      unawaited(loadCloudProfile());
      unawaited(showGuestLinkNotice());
    }
    unawaited(loadComradesSummary());
    if (onlineSignedIn) unawaited(offerPushNotifications());
  }

  Future<void> showGuestLinkNotice() async {
    if (guestLinkNoticeShown || profileController.player?.portable != false) {
      return;
    }
    guestLinkNoticeShown = true;
    await WidgetsBinding.instance.endOfFrame;
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final link = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: settings.appearance.tokens.colors.panel,
        title: const Text('DEVICE-ONLY GUEST'),
        content: const Text(
          'This account is tied to this device. If you already have a Kolkhoz '
          'account, link it now to keep your profile and progress together.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CONTINUE AS GUEST'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LINK ACCOUNT'),
          ),
        ],
      ),
    );
    if (link == true && mounted) {
      navigationController.showProfile();
    }
  }

  void handleCommerceChanged() {
    if (mounted) setState(() {});
  }

  void syncCommerceUser() {
    final userID = onlineUserID;
    unawaited(
      commerce.attachUser(
        userID,
        cachedFullGame:
            userID != null && settings.fullGameEntitlementUserID == userID,
      ),
    );
  }

  void cacheFullGameEntitlement(String userID, bool unlocked) {
    if (unlocked) {
      settings = settings.copyWith(fullGameEntitlementUserID: userID);
    } else if (settings.fullGameEntitlementUserID == userID) {
      settings = settings.copyWith(clearFullGameEntitlement: true);
    }
    settingsStore.save(settings);
  }

  Future<void> showFullGameUnlock() async {
    if (!onlineSignedIn) {
      navigationController.showProfile();
      return;
    }
    await commerce.refresh();
    if (!mounted) return;
    await showDialog<void>(
      context: navigatorKey.currentContext!,
      builder: (context) => AnimatedBuilder(
        animation: commerce,
        builder: (context, _) => AlertDialog(
          backgroundColor: settings.appearance.tokens.colors.panel,
          title: Text(
            commerce.fullGameUnlocked
                ? 'FULL GAME UNLOCKED'
                : 'UNLOCK THE FULL GAME',
          ),
          content: Text(
            commerce.fullGameUnlocked
                ? 'This Kolkhoz account owns the full game on every supported platform.'
                : 'One purchase unlocks complete offline play, variants, progression, '
                      'and online multiplayer on every supported platform. This purchase '
                      'will be permanently linked to the signed-in Kolkhoz account.'
                      '${commerce.message == null ? '' : '\n\n${commerce.message}'}',
          ),
          actions: [
            if (!commerce.fullGameUnlocked)
              TextButton(
                onPressed: commerce.busy ? null : commerce.restore,
                child: const Text('RESTORE PURCHASE'),
              ),
            if (!commerce.fullGameUnlocked)
              TextButton(
                onPressed: commerce.busy ? null : commerce.purchase,
                child: Text(
                  commerce.busy
                      ? 'PLEASE WAIT…'
                      : commerce.price == null
                      ? 'PURCHASE'
                      : 'PURCHASE • ${commerce.price}',
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      ),
    );
  }

  void handleStoreChanged() {
    if (shouldEnterStartedOnlineGame(
      showingLobby: showingLobby,
      isOnlineGame: store.isOnlineGame,
      onlineStarted: store.onlineUpdate?.started ?? false,
    )) {
      navigationController.showGame();
    }
    final model = store.model;
    if (model != null) {
      final actions = store.gameLogActions;
      final cue = gameSoundCueForTransition(
        previous: previousSoundModel,
        next: model,
        previousActionCount: previousSoundActionCount,
        actions: actions,
      );
      final faceCardVoice = faceCardVoiceAssetForTransition(
        previous: previousSoundModel,
        next: model,
        previousActionCount: previousSoundActionCount,
        actions: actions,
      );
      final assignmentWorkAssets = assignmentWorkAssetsForTransition(
        previous: previousSoundModel,
        previousActionCount: previousSoundActionCount,
        actions: actions,
      );
      previousSoundModel = model;
      previousSoundActionCount = actions.length;
      unawaited(
        gameSounds.play(gameSoundCueWithVoiceOverride(cue, faceCardVoice)),
      );
      unawaited(gameSounds.playAsset(faceCardVoice));
      for (final asset in assignmentWorkAssets) {
        unawaited(gameSounds.playAsset(asset, volume: 0.65));
      }
    }
    final result = model?.table.gameResult;
    if (model == null || result == null) {
      recordedGameStatsKey = null;
      return;
    }
    final online = store.isOnlineGame;
    final playerID = online ? store.onlinePlayerID : 0;
    if (playerID == null) {
      return;
    }
    final key = [
      online ? 'online' : 'offline',
      store.onlineSessionID ?? store.currentSeed.toString(),
      playerID.toString(),
    ].join(':');
    if (recordedGameStatsKey == key) {
      return;
    }
    recordedGameStatsKey = key;
    if (online) {
      unawaited(loadCloudProfile());
      return;
    }
    recordCompletedGameStats(
      online: false,
      won: result.winnerSeatID == playerID,
      progressionSummary: ProgressionGameSummary(
        won: result.winnerSeatID == playerID,
        score: finalScoreForSeat(result.scores, playerID),
        fullFiveYearGame: store.currentVariants.maxYears >= 5,
        margin:
            finalScoreForSeat(result.scores, playerID) -
            result.scores
                .where((score) => score.seatID != playerID)
                .map(finalScoreValue)
                .fold<int>(0, math.max),
        medals: seatByID(model, playerID)?.medals ?? 0,
        exiledPlotCards: model.table.requisitionEvents
            .where((event) => event.seatID == playerID && event.card != null)
            .length,
        saboteurExiled: model.table.exiledByYear.values
            .expand((cards) => cards)
            .any((card) => card.suit == 'wrecker'),
      ),
    );
  }

  Future<void> requestNewGameFromBoard() async {
    clearForemanHint();
    final finished = store.finishedGameLobby;
    if (finished != null) {
      if (finished.canRematch) {
        await store.rematchOnlineGame();
        setState(() => onlineSessionCreatedByLocalPlayer = true);
        navigationController.showOffline(
          launchOrigin: KolkhozGameLaunchOrigin.created,
        );
        return;
      }
      returnToLobby();
      return;
    }
    if (settings.confirmNewGame) {
      final confirmed = await confirmGameControl(
        title: settings.language.strings.kolkhozappNewGame,
        message:
            settings.language.strings.kolkhozappThisWillReplaceTheCurrentGame,
        confirmLabel: settings.language.strings.kolkhozappNewGame2,
      );
      if (!confirmed) {
        return;
      }
    }
    store.startGame(
      variants: store.currentVariants,
      controllers: store.controllers,
    );
    onlineSessionCreatedByLocalPlayer = false;
  }

  Future<void> requestReturnToLobby() async {
    clearForemanHint();
    final gameOver = store.finishedGameLobby != null;
    if (!gameOver && settings.confirmMainMenu) {
      final confirmed = await confirmGameControl(
        title: settings.language.strings.kolkhozappMainMenu,
        message: settings
            .language
            .strings
            .kolkhozappLeaveTheCurrentGameAndReturnToSetup,
        confirmLabel: settings.language.strings.kolkhozappMainMenu2,
      );
      if (!confirmed) {
        return;
      }
    }
    returnToLobby();
  }

  void returnToLobby() {
    clearForemanHint();
    store.leaveOnlineGame();
    setState(() => onlineSessionCreatedByLocalPlayer = false);
    navigationController.returnFromGame();
  }

  void showTutorial() {
    clearForemanHint();
    store.clearActivePanel();
    if (showingLobby || store.model == null) {
      store.startGame(
        variants: activeVariants,
        controllers: activePlayerControllers,
      );
    }
    navigationController.showGame(tutorial: true);
  }

  void applyBoardAction(LegalAction action) {
    clearForemanHint();
    store.applyLegalAction(action);
  }

  Future<void> copyGameResult() async {
    final finished = store.finishedGameLobby;
    if (finished == null) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(
        text: gameResultShareText(
          model: finished.model,
          seed: finished.seed,
          variants: finished.lobby.variants,
          language: settings.language,
        ),
      ),
    );
    showForemanHintMessage(settings.language.strings.kolkhozappCopied);
  }

  Future<void> saveGameLog() async {
    if (store.finishedGameLobby == null) {
      return;
    }
    try {
      final file = await store.saveGameLog();
      showForemanHintMessage(
        settings.language == KolkhozLanguage.en
            ? 'Game log saved to ${file.path}'
            : 'Журнал игры сохранён: ${file.path}',
      );
    } catch (exception) {
      showForemanHintMessage('$exception');
    }
  }

  void showFollowSuitHint() {
    if (!settings.showInvalidTapHints) {
      return;
    }
    showForemanHintMessage(
      settings.language.strings.kolkhozappRememberYouMustFollowSuitIfAble,
    );
  }

  void showForemanHintMessage(String message) {
    foremanHintTimer?.cancel();
    setState(() {
      foremanHint = message;
    });
    foremanHintTimer = Timer(foremanHintDuration, () {
      if (!mounted) {
        return;
      }
      setState(() => foremanHint = null);
      foremanHintTimer = null;
    });
  }

  void clearForemanHint() {
    foremanHintTimer?.cancel();
    foremanHintTimer = null;
    if (foremanHint == null || !mounted) {
      return;
    }
    setState(() => foremanHint = null);
  }

  void handleRemoteConnectionChanged() {
    final active = remoteConnection.status.activeGame;
    if (!mounted ||
        (activeRemoteSession?.sessionID == active?.sessionID &&
            activeRemoteSession?.requiresSync == active?.requiresSync)) {
      return;
    }
    setState(() => activeRemoteSession = active);
  }

  Future<void> sendOnlinePresenceHeartbeat() =>
      remoteConnection.refreshHeartbeat();

  void handleMainMenuChanged() {
    final invite = mainMenuController.pendingInvite;
    if (invite != null && activeInviteDialogSessionID == null) {
      unawaited(presentSessionInvite(invite));
    }
  }

  Future<void> presentSessionInvite(OnlineSessionInvite invite) async {
    final dialogContext = navigatorKey.currentContext;
    if (dialogContext == null || activeInviteDialogSessionID != null) {
      return;
    }
    activeInviteDialogSessionID = invite.sessionID;
    final join = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        backgroundColor: settings.appearance.tokens.colors.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            settings.appearance.tokens.radius.md,
          ),
          side: BorderSide(
            color: settings.appearance.tokens.colors.gold.withValues(
              alpha: 0.7,
            ),
          ),
        ),
        titleTextStyle: kolkhozFontStyle.copyWith(
          color: settings.appearance.tokens.colors.gold,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: kolkhozFontStyle.copyWith(
          color: settings.appearance.tokens.colors.cream,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        title: Text(settings.language.strings.kolkhozappGameInvite),
        content: Text(
          settings.language.strings.kolkhozappValue1InvitedYouToAGame(
            value1: invite.hostDisplayName,
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: settings.appearance.tokens.colors.creamDim,
              textStyle: kolkhozFontStyle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(settings.language.strings.kolkhozappDecline),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: settings.appearance.tokens.colors.goldBright,
              textStyle: kolkhozFontStyle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(settings.language.strings.kolkhozappJoinGame),
          ),
        ],
      ),
    );
    activeInviteDialogSessionID = null;
    if (join == true) {
      mainMenuController.acceptPendingInvite(invite.sessionID);
      await joinOnlineGame(onlineServerURL, invite.sessionID, null);
      return;
    }
    mainMenuController.dismissPendingInvite(invite.sessionID);
  }

  void toggleLanguage() {
    setState(() {
      settings = settings.copyWith(language: settings.language.next);
      settingsStore.save(settings);
    });
  }

  void toggleAppearance() {
    setState(() {
      settings = settings.copyWith(appearance: settings.appearance.next);
      settingsStore.save(settings);
    });
  }

  void setCardBack(KolkhozCardBack value) {
    if (!isCardBackUnlocked(effectiveProgression, value) &&
        value != settings.cardBack) {
      return;
    }
    setState(() {
      settings = settings.copyWith(cardBack: value);
      settingsStore.save(settings);
    });
  }

  void setConfirmNewGame(bool value) {
    setState(() {
      settings = settings.copyWith(confirmNewGame: value);
      settingsStore.save(settings);
    });
  }

  void setConfirmMainMenu(bool value) {
    setState(() {
      settings = settings.copyWith(confirmMainMenu: value);
      settingsStore.save(settings);
    });
  }

  void setShowInvalidTapHints(bool value) {
    setState(() {
      settings = settings.copyWith(showInvalidTapHints: value);
      settingsStore.save(settings);
    });
  }

  void setSoundEnabled(bool value) {
    setState(() {
      settings = settings.copyWith(soundEnabled: value);
      gameSounds.enabled = value;
    });
    settingsStore.save(settings);
  }

  void setDisplayName(String value) {
    final next = settings.copyWith(displayName: value);
    setState(() => settings = next);
    settingsStore.save(next);
    scheduleCloudProfileSync();
  }

  void setPortraitAsset(String value) {
    if (!profilePortraitAssets.contains(value)) {
      return;
    }
    if (!isProfilePortraitUnlocked(effectiveProgression, value) &&
        value != settings.portraitAsset) {
      return;
    }
    final next = settings.copyWith(portraitAsset: value);
    setState(() => settings = next);
    settingsStore.save(next);
    scheduleCloudProfileSync();
  }

  void saveFavoriteSetup() {
    if (demoMode) {
      return;
    }
    final next = settings.copyWith(
      favoriteSetup: KolkhozFavoriteSetup(
        variants: activeVariants,
        controllers: activePlayerControllers,
      ),
    );
    setState(() => settings = next);
    settingsStore.save(next);
    showForemanHintMessage(settings.language.strings.kolkhozappFavoriteSaved);
  }

  void rememberStartedSetup(
    List<KolkhozPlayerController> controllers,
    List<String> lobbySeats,
    bool browserJoinable,
  ) {
    if (demoMode) {
      return;
    }
    final next = settings.copyWith(
      lastStartedSetup: KolkhozFavoriteSetup(
        variants: activeVariants,
        controllers: KolkhozPlayerController.normalized(controllers),
        lobbySeats: lobbySeats,
        browserJoinable: browserJoinable,
      ),
    );
    settings = next;
    settingsStore.save(next);
  }

  void useFavoriteSetup() {
    final favorite = settings.favoriteSetup;
    if (demoMode || favorite == null) {
      return;
    }
    final controllers = KolkhozPlayerController.normalized(
      favorite.controllers,
    );
    setState(() {
      selectedPreset = presetForVariants(favorite.variants);
      customVariants = favorite.variants;
      playerControllers = controllers;
    });
    navigationController.showOffline();
    syncPendingGameLobby();
  }

  void syncPendingGameLobby() {
    if (store.lifecycle != GameControllerLifecycle.lobby ||
        store.isOnlineGame) {
      return;
    }
    store.configureLobby(
      variants: activeVariants,
      controllers: activePlayerControllers,
    );
  }

  void scheduleCloudProfileSync() {
    profileController.scheduleCurrentProfileSave(
      displayName: normalizedDisplayName,
      portraitAsset: settings.portraitAsset,
      loadingMessage: settings.language.strings.kolkhozappSyncingProfile,
      successMessage: settings.language.strings.kolkhozappProfileSaved,
      errorMessage: syncErrorMessage(),
    );
  }

  Future<void> deleteAccount() async {
    await profileController.runAccountAction(
      action: () async {
        await pushNotifications.unregister();
        await profileController.deleteRemoteAccount();
        if (profileController.accessToken != null) {
          await profileController.clearIdentity();
        }
        await commerce.attachUser(null, cachedFullGame: false);
        settings = settings.copyWith(
          clearFullGameEntitlement: true,
          clearOnlineProgression: true,
        );
        settingsStore.save(settings);
        profileController.clearSocialState();
        mainMenuController.resetInvites();
        activeInviteDialogSessionID = null;
      },
      successMessage: settings.language.strings.kolkhozappAccountDeleted,
      errorMessage: accountErrorMessage,
    );
  }

  Future<void> offerPushNotifications() async {
    if (!mounted || notificationPromptShown || !onlineSignedIn) {
      return;
    }
    notificationPromptShown = true;
    final authorization = await pushNotifications.authorization();
    if (!mounted) {
      return;
    }
    if (authorization == KolkhozPushAuthorization.authorized) {
      unawaited(pushNotifications.requestPermissionAndRegister());
      return;
    }
    if (authorization != KolkhozPushAuthorization.notDetermined) {
      return;
    }
    final dialogContext = navigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) {
      return;
    }
    final enable = await showPushNotificationOffer(
      context: dialogContext,
      tokens: settings.appearance.tokens,
    );
    if (enable != true) {
      return;
    }
    final registered = await pushNotifications.requestPermissionAndRegister();
    if (!registered && mounted) {
      showForemanHintMessage(
        'Notifications are off. You can enable them in Settings.',
      );
    }
  }

  void handleForegroundPush(KolkhozPushPayload payload) {
    if (!mounted) {
      return;
    }
    final message = payload.body ?? payload.title ?? 'Kolkhoz has an update.';
    showForemanHintMessage(message);
    if (payload.type == 'game_invitation') {
      unawaited(mainMenuController.pollInvites());
    } else if (payload.type.startsWith('comrade_')) {
      unawaited(loadComradesSummary());
    } else if (payload.sessionID == store.onlineSessionID) {
      unawaited(store.refreshOnlineGame());
    }
  }

  Future<void> handleOpenedPush(KolkhozPushPayload payload) async {
    if (!mounted) {
      return;
    }
    if (payload.type.startsWith('comrade_')) {
      navigationController.showOnline();
      await loadComradesSummary();
      return;
    }
    if (payload.type == 'game_invitation') {
      navigationController.showOnline();
      await mainMenuController.pollInvites();
      return;
    }
    final sessionID = payload.sessionID;
    if (sessionID != null && sessionID.isNotEmpty) {
      try {
        await joinOnlineGame(onlineServerURL, sessionID, null);
      } catch (_) {
        navigationController.showOnline();
      }
    }
  }

  Future<void> loadCloudProfile() async {
    final identityPlayer = profileController.player;
    if (identityPlayer == null || profileController.busy) {
      return;
    }
    final profile = await profileController.loadCurrentProfile(
      successMessage: settings.language.strings.kolkhozappProfileLoaded,
      errorMessage: syncErrorMessage(),
    );
    if (profile == null || !mounted) return;
    final displayName = profile.displayName?.trim();
    final portraitAsset = profile.portraitAsset;
    final loadedProgression = identityPlayer.portable
        ? profile.progression
        : const ProgressionState();
    final next = settings.copyWith(
      displayName: displayName == null || displayName.isEmpty
          ? settings.displayName
          : displayName,
      portraitAsset: identityPlayer.portable
          ? portraitAsset ?? settings.portraitAsset
          : defaultProfilePortraitAsset,
      profileStats: profile.stats,
      onlineProgression: loadedProgression,
      onlineProgressionUserID: identityPlayer.id,
    );
    setState(() => settings = next);
    settingsStore.save(next);
    profileController.updateDisplayName(next.displayName);
  }

  Future<void> syncActiveSession() async {
    if (activeSessionSyncBusy) {
      return;
    }
    setState(() => activeSessionSyncBusy = true);
    try {
      await store.syncActiveOnlineGame();
      if (!mounted) {
        return;
      }
      setState(() {
        activeRemoteSession = null;
        activeSessionSyncBusy = false;
        onlineSessionCreatedByLocalPlayer = false;
      });
      if (store.onlineUpdate?.started ?? false) {
        navigationController.showGame(
          launchOrigin: KolkhozGameLaunchOrigin.joined,
        );
      } else {
        navigationController.showOnline(
          launchOrigin: KolkhozGameLaunchOrigin.joined,
        );
      }
      unawaited(sendOnlinePresenceHeartbeat());
    } catch (exception) {
      if (mounted) {
        setState(() => activeSessionSyncBusy = false);
        showForemanHintMessage('$exception');
      }
    }
  }

  Future<void> loadComradesSummary() async {
    await profileController.refreshComrades();
  }

  Future<void> requestComradeByUserID(String userID) async {
    if (demoMode || userID == comradesSummary.userID) {
      return;
    }
    await profileController.sendComradeRequestToUser(userID);
  }

  void recordCompletedGameStats({
    required bool online,
    required bool won,
    ProgressionGameSummary? progressionSummary,
  }) {
    final nextStats = settings.profileStats.recordResult(
      online: online,
      won: won,
    );
    final update =
        progressionSummary == null || profileController.player?.portable != true
        ? null
        : evaluateProgression(settings.progression, progressionSummary);
    final next = settings.copyWith(
      profileStats: nextStats,
      progression: update?.state,
    );
    setState(() => settings = next);
    settingsStore.save(next);
    if (update != null && update.newCompletions.isNotEmpty) {
      showProgressionNotice(update.newCompletions);
    }
  }

  void showProgressionNotice(List<ProgressionDefinition> completions) {
    progressionNoticeTimer?.cancel();
    final latest = completions.last;
    final reward = latest.reward == null ? '' : ' • ${latest.reward} unlocked';
    setState(() {
      progressionNotice = '${latest.title} complete$reward';
    });
    progressionNoticeTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() => progressionNotice = null);
      }
    });
  }

  String get normalizedDisplayName {
    final trimmed = settings.displayName.trim();
    return trimmed.isEmpty ? defaultProfileDisplayName : trimmed;
  }

  String accountErrorMessage(Object exception) {
    return safeAccountErrorMessage(exception, settings.language);
  }

  String syncErrorMessage() {
    return settings.language.strings.kolkhozappProfileSyncFailed;
  }

  Future<bool> confirmGameControl({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final dialogContext = navigatorKey.currentContext;
    if (dialogContext == null) {
      return false;
    }
    return showGameControlConfirmation(
      context: dialogContext,
      language: settings.language,
      tokens: settings.appearance.tokens,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    );
  }

  Future<String> hostOnlineGame(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
    bool ranked,
    bool browserJoinable,
  ) => hostOnlineSeries(
    baseURL,
    controllers,
    enterImmediately,
    ranked,
    browserJoinable,
    1,
  );

  Future<String> hostOnlineSeries(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
    bool ranked,
    bool browserJoinable,
    int bestOf,
  ) async {
    if (!onlinePlayAllowed) {
      throw HttpException(
        settings.language.strings.kolkhozappSignInBeforeJoiningOnlinePlay,
      );
    }
    store.configureLobby(variants: activeVariants, controllers: controllers);
    final sessionID = await store.startOnlineGame(
      ranked: ranked,
      browserJoinable: browserJoinable,
      bestOf: bestOf,
    );
    setState(() => onlineSessionCreatedByLocalPlayer = true);
    if (enterImmediately) {
      navigationController.showGame(
        launchOrigin: KolkhozGameLaunchOrigin.created,
      );
    } else {
      navigationController.showOffline(
        launchOrigin: KolkhozGameLaunchOrigin.created,
      );
    }
    unawaited(sendOnlinePresenceHeartbeat());
    return sessionID;
  }

  Future<void> inviteOnlineComrades(
    String sessionID,
    List<String> userIDs,
  ) async {
    if (userIDs.isEmpty) {
      return;
    }
    await menuRemoteConnection.inviteSessionComrades(
      sessionID: sessionID,
      userIDs: userIDs,
    );
  }

  Future<void> joinOnlineGame(
    Uri baseURL,
    String inviteCode,
    int? preferredPlayerID,
  ) async {
    if (!onlinePlayAllowed) {
      throw HttpException(
        settings.language.strings.kolkhozappSignInBeforeJoiningOnlinePlay,
      );
    }
    await store.joinOnlineGame(
      inviteCode: inviteCode,
      preferredPlayerID: preferredPlayerID,
    );
    setState(() => onlineSessionCreatedByLocalPlayer = false);
    navigationController.showOnline(
      launchOrigin: KolkhozGameLaunchOrigin.joined,
    );
    unawaited(sendOnlinePresenceHeartbeat());
  }

  Future<String> matchmakeOnlineGame(
    Uri baseURL,
    bool rankedOnly,
    bool comradesOnly,
  ) async {
    if (!onlinePlayAllowed) {
      throw HttpException(
        settings.language.strings.kolkhozappSignInBeforeJoiningOnlinePlay,
      );
    }
    final inviteCode = await store.matchmakeOnlineGame(
      rankedOnly: rankedOnly,
      comradesOnly: comradesOnly,
    );
    setState(() => onlineSessionCreatedByLocalPlayer = false);
    navigationController.showOnline(
      launchOrigin: KolkhozGameLaunchOrigin.joined,
    );
    unawaited(sendOnlinePresenceHeartbeat());
    return inviteCode;
  }

  Future<void> kickOnlinePlayer(int playerID) {
    return store.kickOnlinePlayer(playerID);
  }

  void enterOnlineGame() {
    navigationController.showGame();
  }
}

class ActiveSessionSyncOverlay extends StatelessWidget {
  const ActiveSessionSyncOverlay({
    required this.tokens,
    required this.busy,
    required this.onSync,
    super.key,
  });

  final DesignTokens tokens;
  final bool busy;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.colors.black.withValues(alpha: 0.78),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            decoration: BoxDecoration(
              color: tokens.colors.panel,
              border: Border.all(color: tokens.colors.gold, width: 2),
              borderRadius: BorderRadius.circular(tokens.radius.md),
              boxShadow: [
                BoxShadow(
                  color: tokens.colors.black.withValues(alpha: 0.7),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync, color: tokens.colors.goldBright, size: 34),
                const SizedBox(height: 12),
                Text(
                  'GAME ACTIVE ON ANOTHER DEVICE',
                  textAlign: TextAlign.center,
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.cream,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Continue the same lobby or game from this device.',
                  textAlign: TextAlign.center,
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.creamDim,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onSync,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(busy ? 'SYNCING…' : 'SYNC VIEW'),
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.colors.gold,
                      foregroundColor: tokens.colors.black,
                      textStyle: kolkhozFontStyle.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StandaloneErrorBanner extends StatelessWidget {
  const StandaloneErrorBanner({
    required this.error,
    required this.tokens,
    super.key,
  });

  final String error;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.colors.redBright),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          error,
          style: kolkhozFontStyle.copyWith(
            color: tokens.colors.cream,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class StandaloneErrorView extends StatelessWidget {
  const StandaloneErrorView({
    required this.error,
    required this.tokens,
    super.key,
  });

  final String error;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: StandaloneErrorBanner(error: error, tokens: tokens),
        ),
      ),
    );
  }
}
