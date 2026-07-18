import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'animation_speed.dart';
import 'app_settings.dart';
import 'app_text.dart';
import 'art_direction.dart';
import 'c_engine_bridge.dart';
import 'commerce.dart';
import 'design_tokens.dart';
import 'field_plan_assets.dart';
import 'field_plan_typography.dart';
import 'game_constants.dart';
import 'game_sound.dart';
import 'board_view.dart';
import 'live_game_store.dart';
import 'online_game_models.dart';
import 'online_game_client.dart';
import 'pixel_text.dart';
import 'push_notifications.dart';
import 'printed_underlay.dart';
import 'player_profile_panel.dart';
import 'progression/progression.dart';
import 'progression/progression_notice.dart';
import 'progression/progression_overview.dart';
import 'render_model.dart';
import 'rule_content.dart';
import 'supabase_config.dart';
import 'table_display.dart';
import 'tutorial_display.dart';

part 'online_lobby_panel.dart';
part 'lobby/lobby_screen.dart';
part 'lobby/game_setup_panel.dart';
part 'lobby/profile_settings_panel.dart';
part 'lobby/leaderboard_panel.dart';
part 'lobby/variant_controls.dart';

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
            child: Text(language.t(KolkhozText.kolkhozappCancel)),
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
  if (exception is AuthRetryableFetchException) {
    return language.t(KolkhozText.kolkhozappAccountServiceUnavailable);
  }
  if (exception is AuthException) {
    return switch (exception.code) {
      'email_address_invalid' || 'validation_failed' => language.t(
        KolkhozText.kolkhozappAccountInvalidEmail,
      ),
      'email_exists' || 'user_already_exists' => language.t(
        KolkhozText.kolkhozappAccountAlreadyExists,
      ),
      'over_request_rate_limit' || 'over_email_send_rate_limit' => language.t(
        KolkhozText.kolkhozappAccountRateLimited,
      ),
      'signup_disabled' || 'email_provider_disabled' || 'provider_disabled' =>
        language.t(KolkhozText.kolkhozappAccountCreationUnavailable),
      'weak_password' => language.t(KolkhozText.kolkhozappAccountWeakPassword),
      'invalid_credentials' => language.t(
        KolkhozText.kolkhozappAccountInvalidCredentials,
      ),
      'request_timeout' => language.t(
        KolkhozText.kolkhozappAccountServiceUnavailable,
      ),
      _ => language.t(KolkhozText.kolkhozappAccountRequestFailed),
    };
  }
  return language.t(KolkhozText.kolkhozappAccountRequestFailed);
}

class KolkhozApp extends StatefulWidget {
  const KolkhozApp({super.key});

  @override
  State<KolkhozApp> createState() => _KolkhozAppState();
}

enum KolkhozGameLaunchOrigin {
  created,
  joined;

  bool get returnsToJoinGame => this == KolkhozGameLaunchOrigin.joined;
}

enum _AppDestination { offline, rules, online, profile, game }

class _KolkhozAppState extends State<KolkhozApp> with WidgetsBindingObserver {
  static const foremanHintDuration = Duration(seconds: 3);
  static const onlinePresenceHeartbeatInterval = Duration(seconds: 15);
  static const onlineInvitePollInterval = Duration(seconds: 5);

  final navigatorKey = GlobalKey<NavigatorState>();
  final gameSounds = GameSoundController();
  late final LiveGameStore store;
  late final KolkhozCommerceController commerce;
  late final KolkhozAppSettingsStore settingsStore;
  StreamSubscription<AuthState>? supabaseAuthSubscription;
  Timer? cloudProfileSyncTimer;
  Timer? onlinePresenceTimer;
  Timer? onlineInviteTimer;
  late final String onlineDeviceID;
  late final KolkhozPushNotifications pushNotifications;
  bool notificationPromptShown = false;
  OnlineActiveSession? activeRemoteSession;
  bool activeSessionSyncBusy = false;
  KolkhozAppSettings settings = const KolkhozAppSettings();
  bool cloudAuthBusy = false;
  String? cloudAuthMessage;
  bool cloudAuthIsError = false;
  bool cloudProfileBusy = false;
  bool comradesSummaryBusy = false;
  bool sessionInviteBusy = false;
  OnlineComradesResponse comradesSummary = const OnlineComradesResponse();
  final Set<String> dismissedInviteSessionIDs = {};
  String? activeInviteDialogSessionID;
  String? recordedGameStatsKey;
  TableViewModel? previousSoundModel;
  int previousSoundActionCount = 0;
  _AppDestination destination = _AppDestination.offline;
  KolkhozSettingsTab selectedSettingsTab = KolkhozSettingsTab.profile;
  bool onlineSessionCreatedByLocalPlayer = false;
  KolkhozGameLaunchOrigin gameLaunchOrigin = KolkhozGameLaunchOrigin.created;
  bool showingTutorial = false;
  String? foremanHint;
  Timer? foremanHintTimer;
  Timer? progressionNoticeTimer;
  String? progressionNotice;
  KolkhozGamePreset selectedPreset = KolkhozGamePreset.kolkhoz;
  KolkhozGameVariants customVariants = KolkhozGameVariants.kolkhoz;
  List<KolkhozPlayerController> playerControllers = List.of(
    KolkhozPlayerController.defaultControllers,
  );

  bool get showingLobby => destination != _AppDestination.game;
  bool get showingRules => destination == _AppDestination.rules;
  bool get showingOnline => destination == _AppDestination.online;
  bool get showingProfile => destination == _AppDestination.profile;

  bool get demoMode => !commerce.fullGameUnlocked;
  bool get onlinePlayAllowed => canAccessOnlinePlay(
    fullGameUnlocked: commerce.fullGameUnlocked,
    signedIn: supabaseCurrentUser != null,
  );

  ProgressionState get effectiveProgression => mergeProgressionStates(
    settings.progression,
    settings.onlineProgressionUserID == supabaseCurrentUser?.id
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
    store = LiveGameStore(
      onlineAccessTokenProvider: supabaseAccessToken,
      onlineDeviceID: onlineDeviceID,
    );
    store.addListener(handleStoreChanged);
    commerce = KolkhozCommerceController(
      clientFactory: onlineClient,
      onFullGameChanged: cacheFullGameEntitlement,
    );
    commerce.addListener(handleCommerceChanged);
    commerce.initialize();
    pushNotifications = KolkhozPushNotifications(
      installationID: onlineDeviceID,
      registerInstallation:
          ({required installationID, required platform, required token}) =>
              onlineClient().registerInstallation(
                installationID: installationID,
                platform: platform,
                token: token,
              ),
      deleteInstallation: (installationID) =>
          onlineClient().deleteInstallation(installationID),
      isSignedIn: () => supabaseCurrentUser != null,
      onForegroundMessage: handleForegroundPush,
      onOpenMessage: handleOpenedPush,
    );
    unawaited(pushNotifications.initialize());
    if (lastStartedSetup == null) {
      playerControllers = List.of(store.controllers);
    }
    KolkhozSupabaseRuntime.instance.addListener(handleSupabaseRuntimeChanged);
    KolkhozSupabaseRuntime.instance.start();
    attachSupabaseAuthSubscription();
    startOnlinePresenceHeartbeat();
    startOnlineInvitePolling();
  }

  @override
  void dispose() {
    foremanHintTimer?.cancel();
    progressionNoticeTimer?.cancel();
    cloudProfileSyncTimer?.cancel();
    onlinePresenceTimer?.cancel();
    onlineInviteTimer?.cancel();
    supabaseAuthSubscription?.cancel();
    store.removeListener(handleStoreChanged);
    commerce.removeListener(handleCommerceChanged);
    commerce.dispose();
    unawaited(gameSounds.dispose());
    unawaited(pushNotifications.dispose());
    KolkhozSupabaseRuntime.instance.removeListener(
      handleSupabaseRuntimeChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
    store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startOnlinePresenceHeartbeat();
      startOnlineInvitePolling();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      onlinePresenceTimer?.cancel();
      onlinePresenceTimer = null;
      onlineInviteTimer?.cancel();
      onlineInviteTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Kolkhoz',
      theme: ThemeData(
        fontFamily: 'Handjet',
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Handjet'),
      ),
      builder: (context, child) => DefaultTextStyle.merge(
        style: kolkhozFontStyle,
        child: Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (showingLobby && demoMode && supabaseCurrentUser != null)
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
              cloudConfigured: KolkhozSupabaseRuntime.instance.isConfigured,
              cloudReady: KolkhozSupabaseRuntime.instance.isReady,
              cloudSignedIn: supabaseCurrentUser != null,
              cloudEmail: supabaseCurrentUser?.email,
              cloudAuthBusy: cloudAuthBusy || cloudProfileBusy,
              cloudAuthMessage: cloudAuthMessage,
              cloudAuthIsError: cloudAuthIsError,
              onHostOnline: hostOnlineGame,
              onHostOnlineSeries: hostOnlineSeries,
              onInviteOnlineComrades: inviteOnlineComrades,
              onJoinOnline: joinOnlineGame,
              onWatchOnline: (baseURL, sessionID) async {
                await store.watchOnlineGame(
                  baseURL: baseURL,
                  sessionID: sessionID,
                );
                if (mounted) {
                  setState(() {
                    gameLaunchOrigin = KolkhozGameLaunchOrigin.joined;
                    onlineSessionCreatedByLocalPlayer = false;
                    destination = _AppDestination.game;
                  });
                }
              },
              onMatchmakeOnline: matchmakeOnlineGame,
              onKickOnlinePlayer: kickOnlinePlayer,
              onEnterOnlineGame: enterOnlineGame,
              onCancelOnlineGame: returnToLobby,
              onStart: () {
                final controllers = activePlayerControllers;
                store.newGame(
                  variants: activeVariants,
                  controllers: controllers,
                );
                setState(() {
                  gameLaunchOrigin = KolkhozGameLaunchOrigin.created;
                  onlineSessionCreatedByLocalPlayer = false;
                  destination = _AppDestination.game;
                });
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
                  destination = _AppDestination.offline;
                });
              },
              onCustomVariantsChanged: (variants) {
                if (demoMode) {
                  return;
                }
                setState(() {
                  selectedPreset = KolkhozGamePreset.custom;
                  customVariants = variants;
                  destination = _AppDestination.offline;
                });
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
              },
              onAnimationSpeedChanged: store.setAnimationSpeed,
              onConfirmNewGameChanged: setConfirmNewGame,
              onConfirmMainMenuChanged: setConfirmMainMenu,
              onShowInvalidTapHintsChanged: setShowInvalidTapHints,
              onSoundEnabledChanged: setSoundEnabled,
              onRulesPressed: () {
                setState(() {
                  destination = _AppDestination.rules;
                });
              },
              onOfflinePressed: () {
                setState(() {
                  destination = _AppDestination.offline;
                });
              },
              onOnlinePressed: () {
                setState(() {
                  destination = !onlinePlayAllowed
                      ? _AppDestination.profile
                      : _AppDestination.online;
                  if (!onlinePlayAllowed) {
                    selectedSettingsTab = KolkhozSettingsTab.profile;
                  }
                });
              },
              onProfilePressed: () {
                setState(() {
                  destination = _AppDestination.profile;
                  selectedSettingsTab = KolkhozSettingsTab.profile;
                });
              },
              onSettingsPressed: () {
                setState(() {
                  destination = _AppDestination.profile;
                  selectedSettingsTab = KolkhozSettingsTab.display;
                });
              },
              onDisplayNameChanged: setDisplayName,
              onPortraitChanged: setPortraitAsset,
              onSaveFavoriteSetup: saveFavoriteSetup,
              onUseFavoriteSetup: useFavoriteSetup,
              onCloudSignIn: signInWithSupabase,
              onCloudSignUp: signUpWithSupabase,
              onCloudResetPassword: resetSupabasePassword,
              onCloudSignOut: signOutOfSupabase,
              onCloudDeleteAccount: deleteSupabaseAccount,
              onComradesChanged: updateComradesSummary,
              onComradeRequestToUser: requestComradeByUserID,
              onlineClientFactory: onlineClient,
              onStartDailyChallenge: () async {
                await store.startDailyChallenge(baseURL: _onlineServerURL);
                if (mounted) {
                  setState(() {
                    gameLaunchOrigin = KolkhozGameLaunchOrigin.created;
                    onlineSessionCreatedByLocalPlayer = true;
                    destination = _AppDestination.game;
                  });
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
                  onTrickHandCardTap: store.selectTrickHandCard,
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
                      !(store.isOnlineGame &&
                          store.onlineUpdate?.ranked == false &&
                          store.onlineUpdate?.series?.completed != true &&
                          store.model?.table.phase == phaseGameOver),
                  onTutorial: showTutorial,
                  animationSpeed: store.animationSpeed,
                  presentationRevision: store.presentationRevision,
                  assignmentPresentationCardIDs:
                      store.onlineAssignmentPresentationCardIDs,
                  onPresentationComplete: store.acknowledgeRevisionPresented,
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
                    onClose: () => setState(() => showingTutorial = false),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  User? get supabaseCurrentUser {
    return KolkhozSupabaseRuntime.instance.client?.auth.currentUser;
  }

  Future<String?> supabaseAccessToken() async {
    return KolkhozSupabaseRuntime
        .instance
        .client
        ?.auth
        .currentSession
        ?.accessToken;
  }

  void handleSupabaseRuntimeChanged() {
    attachSupabaseAuthSubscription();
    if (!mounted) {
      return;
    }
    setState(() {});
    syncCommerceUser();
    unawaited(loadCloudProfile());
    unawaited(loadComradesSummary());
  }

  void attachSupabaseAuthSubscription() {
    final client = KolkhozSupabaseRuntime.instance.client;
    if (client == null || supabaseAuthSubscription != null) {
      return;
    }
    supabaseAuthSubscription = client.auth.onAuthStateChange.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      syncCommerceUser();
      unawaited(loadCloudProfile());
      unawaited(loadComradesSummary());
      if (supabaseCurrentUser != null) {
        unawaited(offerPushNotifications());
      }
    });
    unawaited(loadCloudProfile());
    unawaited(loadComradesSummary());
    syncCommerceUser();
  }

  void handleCommerceChanged() {
    if (mounted) setState(() {});
  }

  void syncCommerceUser() {
    final userID = supabaseCurrentUser?.id;
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
    if (supabaseCurrentUser == null) {
      setState(() {
        destination = _AppDestination.profile;
        selectedSettingsTab = KolkhozSettingsTab.profile;
      });
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
    if (store.model?.table.phase == phaseGameOver) {
      if (store.isOnlineGame && store.onlineUpdate?.ranked == false) {
        await store.rematchOnlineGame();
        setState(() {
          gameLaunchOrigin = KolkhozGameLaunchOrigin.created;
          onlineSessionCreatedByLocalPlayer = true;
          destination = _AppDestination.offline;
        });
        return;
      }
      returnToLobby();
      return;
    }
    if (settings.confirmNewGame) {
      final confirmed = await confirmGameControl(
        title: settings.language.t(KolkhozText.kolkhozappNewGame),
        message: settings.language.t(
          KolkhozText.kolkhozappThisWillReplaceTheCurrentGame,
        ),
        confirmLabel: settings.language.t(KolkhozText.kolkhozappNewGame2),
      );
      if (!confirmed) {
        return;
      }
    }
    store.newGame(
      variants: store.currentVariants,
      controllers: store.controllers,
    );
    onlineSessionCreatedByLocalPlayer = false;
  }

  Future<void> requestReturnToLobby() async {
    clearForemanHint();
    final gameOver = store.model?.table.phase == phaseGameOver;
    if (!gameOver && settings.confirmMainMenu) {
      final confirmed = await confirmGameControl(
        title: settings.language.t(KolkhozText.kolkhozappMainMenu),
        message: settings.language.t(
          KolkhozText.kolkhozappLeaveTheCurrentGameAndReturnToSetup,
        ),
        confirmLabel: settings.language.t(KolkhozText.kolkhozappMainMenu2),
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
    setState(() {
      onlineSessionCreatedByLocalPlayer = false;
      destination = gameLaunchOrigin.returnsToJoinGame
          ? _AppDestination.online
          : _AppDestination.offline;
    });
  }

  void showTutorial() {
    clearForemanHint();
    store.clearActivePanel();
    if (showingLobby || store.model == null) {
      store.newGame(
        variants: activeVariants,
        controllers: activePlayerControllers,
      );
    }
    setState(() {
      destination = _AppDestination.game;
      showingTutorial = true;
    });
  }

  void applyBoardAction(LegalAction action) {
    clearForemanHint();
    store.applyLegalAction(action);
  }

  Future<void> copyGameResult() async {
    final model = store.model;
    if (model == null || model.table.phase != phaseGameOver) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(
        text: gameResultShareText(
          model: model,
          seed: store.currentSeed,
          variants: store.currentVariants,
          language: settings.language,
        ),
      ),
    );
    showForemanHintMessage(settings.language.t(KolkhozText.kolkhozappCopied));
  }

  Future<void> saveGameLog() async {
    final model = store.model;
    if (model == null || model.table.phase != phaseGameOver) {
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
      settings.language.t(
        KolkhozText.kolkhozappRememberYouMustFollowSuitIfAble,
      ),
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

  void startOnlinePresenceHeartbeat() {
    if (onlinePresenceTimer != null) {
      return;
    }
    unawaited(sendOnlinePresenceHeartbeat());
    onlinePresenceTimer = Timer.periodic(
      onlinePresenceHeartbeatInterval,
      (_) => unawaited(sendOnlinePresenceHeartbeat()),
    );
  }

  Future<void> sendOnlinePresenceHeartbeat() async {
    try {
      final heartbeat = await onlineClient().sendPresenceHeartbeat(
        sessionID: store.onlineSessionID,
      );
      final active = heartbeat.activeSession;
      if (mounted &&
          (activeRemoteSession?.sessionID != active?.sessionID ||
              activeRemoteSession?.requiresSync != active?.requiresSync)) {
        setState(() => activeRemoteSession = active);
      }
    } catch (_) {
      // Presence is best effort; gameplay and account flows handle real errors.
    }
  }

  void startOnlineInvitePolling() {
    if (onlineInviteTimer != null) {
      return;
    }
    unawaited(pollSessionInvites());
    onlineInviteTimer = Timer.periodic(
      onlineInvitePollInterval,
      (_) => unawaited(pollSessionInvites()),
    );
  }

  Future<void> pollSessionInvites() async {
    if (sessionInviteBusy ||
        supabaseCurrentUser == null ||
        store.onlineSessionID != null ||
        activeInviteDialogSessionID != null) {
      return;
    }
    sessionInviteBusy = true;
    try {
      final invites = await onlineClient().fetchSessionInvites();
      for (final invite in invites) {
        if (dismissedInviteSessionIDs.contains(invite.sessionID)) {
          continue;
        }
        await presentSessionInvite(invite);
        break;
      }
    } catch (_) {
      // Invite polling is best effort; explicit online joins surface real errors.
    } finally {
      sessionInviteBusy = false;
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
        title: Text(settings.language.t(KolkhozText.kolkhozappGameInvite)),
        content: Text(
          settings.language.t(KolkhozText.kolkhozappValue1InvitedYouToAGame, {
            'value1': invite.hostDisplayName,
          }),
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
            child: Text(settings.language.t(KolkhozText.kolkhozappDecline)),
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
            child: Text(settings.language.t(KolkhozText.kolkhozappJoinGame)),
          ),
        ],
      ),
    );
    activeInviteDialogSessionID = null;
    if (join == true) {
      await joinOnlineGame(_onlineServerURL, invite.sessionID, null);
      return;
    }
    dismissedInviteSessionIDs.add(invite.sessionID);
    unawaited(declineSessionInvite(invite.sessionID));
  }

  Future<void> declineSessionInvite(String sessionID) async {
    try {
      await onlineClient().declineSessionInvite(sessionID);
    } catch (_) {
      // Dismissed locally even if the best-effort server decline fails.
    }
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
    showForemanHintMessage(
      settings.language.t(KolkhozText.kolkhozappFavoriteSaved),
    );
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
      destination = _AppDestination.offline;
    });
  }

  void scheduleCloudProfileSync() {
    cloudProfileSyncTimer?.cancel();
    cloudProfileSyncTimer = Timer(const Duration(milliseconds: 700), () {
      cloudProfileSyncTimer = null;
      unawaited(syncCloudProfile());
    });
  }

  Future<void> signInWithSupabase(String email, String password) async {
    await runCloudAuthAction(() async {
      final client = KolkhozSupabaseRuntime.instance.client!;
      await client.auth.signInWithPassword(
        email: normalizeAccountEmail(email),
        password: password,
      );
      await loadCloudProfile();
      unawaited(offerPushNotifications());
      cloudAuthMessage = settings.language.t(
        KolkhozText.kolkhozappSignedInProfileLoaded,
      );
      cloudAuthIsError = false;
    });
  }

  Future<void> signUpWithSupabase(String email, String password) async {
    await runCloudAuthAction(() async {
      final client = KolkhozSupabaseRuntime.instance.client!;
      final displayName = normalizedDisplayName;
      final response = await client.auth.signUp(
        email: normalizeAccountEmail(email),
        password: password,
        emailRedirectTo: KolkhozSupabaseConfig.authRedirectUrl,
        data: {'display_name': displayName},
      );
      if (response.session == null) {
        cloudAuthMessage = settings.language.t(
          KolkhozText.kolkhozappAccountCreatedCheckYourEmailToConfirmItThe,
        );
      } else {
        await syncCloudProfile();
        cloudAuthMessage = settings.language.t(
          KolkhozText.kolkhozappAccountCreated,
        );
      }
      cloudAuthIsError = false;
    });
  }

  Future<void> signOutOfSupabase() async {
    await runCloudAuthAction(() async {
      final client = KolkhozSupabaseRuntime.instance.client!;
      await pushNotifications.unregister();
      await client.auth.signOut();
      await commerce.attachUser(null, cachedFullGame: false);
      comradesSummary = const OnlineComradesResponse();
      dismissedInviteSessionIDs.clear();
      activeInviteDialogSessionID = null;
      cloudAuthMessage = settings.language.t(KolkhozText.kolkhozappSignedOut);
      cloudAuthIsError = false;
    });
  }

  Future<void> deleteSupabaseAccount() async {
    await runCloudAuthAction(() async {
      final client = KolkhozSupabaseRuntime.instance.client!;
      await pushNotifications.unregister();
      await onlineClient().deleteAccount();
      await client.auth.signOut();
      await commerce.attachUser(null, cachedFullGame: false);
      settings = settings.copyWith(
        clearFullGameEntitlement: true,
        clearOnlineProgression: true,
      );
      settingsStore.save(settings);
      comradesSummary = const OnlineComradesResponse();
      dismissedInviteSessionIDs.clear();
      activeInviteDialogSessionID = null;
      cloudAuthMessage = settings.language.t(
        KolkhozText.kolkhozappAccountDeleted,
      );
      cloudAuthIsError = false;
    });
  }

  Future<void> offerPushNotifications() async {
    if (!mounted || notificationPromptShown || supabaseCurrentUser == null) {
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
      unawaited(pollSessionInvites());
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
      setState(() => destination = _AppDestination.online);
      await loadComradesSummary();
      return;
    }
    if (payload.type == 'game_invitation') {
      setState(() => destination = _AppDestination.online);
      await pollSessionInvites();
      return;
    }
    final sessionID = payload.sessionID;
    if (sessionID != null && sessionID.isNotEmpty) {
      try {
        await joinOnlineGame(_onlineServerURL, sessionID, null);
      } catch (_) {
        setState(() => destination = _AppDestination.online);
      }
    }
  }

  Future<void> resetSupabasePassword(String email) async {
    await runCloudAuthAction(() async {
      final trimmed = normalizeAccountEmail(email);
      if (trimmed.isEmpty) {
        throw const FormatException('Enter an email first.');
      }
      final client = KolkhozSupabaseRuntime.instance.client!;
      await client.auth.resetPasswordForEmail(
        trimmed,
        redirectTo: KolkhozSupabaseConfig.authRedirectUrl,
      );
      cloudAuthMessage = settings.language.t(
        KolkhozText.kolkhozappPasswordResetEmailSent,
      );
      cloudAuthIsError = false;
    });
  }

  Future<void> runCloudAuthAction(Future<void> Function() action) async {
    if (KolkhozSupabaseRuntime.instance.client == null || cloudAuthBusy) {
      return;
    }
    setState(() {
      cloudAuthBusy = true;
      cloudAuthMessage = null;
      cloudAuthIsError = false;
    });
    try {
      await action();
    } catch (exception) {
      cloudAuthMessage = accountErrorMessage(exception);
      cloudAuthIsError = true;
    } finally {
      if (mounted) {
        setState(() => cloudAuthBusy = false);
      }
    }
  }

  Future<void> syncCloudProfile() async {
    final client = KolkhozSupabaseRuntime.instance.client;
    final user = client?.auth.currentUser;
    if (user == null) {
      return;
    }
    if (mounted) {
      setState(() {
        cloudProfileBusy = true;
        cloudAuthMessage = settings.language.t(
          KolkhozText.kolkhozappSyncingProfile,
        );
        cloudAuthIsError = false;
      });
    }
    try {
      await client!.from('profiles').upsert({
        'user_id': user.id,
        'display_name': normalizedDisplayName,
        'avatar_url': settings.portraitAsset,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) {
        setState(() {
          cloudAuthMessage = settings.language.t(
            KolkhozText.kolkhozappProfileSaved,
          );
          cloudAuthIsError = false;
        });
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          cloudAuthMessage = syncErrorMessage(exception);
          cloudAuthIsError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => cloudProfileBusy = false);
      }
    }
  }

  Future<void> loadCloudProfile() async {
    final client = KolkhozSupabaseRuntime.instance.client;
    final user = client?.auth.currentUser;
    if (user == null || cloudProfileBusy) {
      return;
    }
    if (mounted) {
      setState(() => cloudProfileBusy = true);
    }
    try {
      final profile = await client!
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('user_id', user.id)
          .maybeSingle();
      final stats = await client
          .from('profile_stats')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      final progression = await client
          .from('profile_progression')
          .select('progress, completed, unlocks')
          .eq('user_id', user.id)
          .maybeSingle();
      if (profile == null) {
        await syncCloudProfile();
        return;
      }
      final displayName = profile['display_name'] as String?;
      final avatarURL = profile['avatar_url'] as String?;
      final previousCompleted = effectiveProgression.completed;
      final loadedOnlineProgression = ProgressionState.fromJson(progression);
      final loadedProgression = mergeProgressionStates(
        settings.progression,
        loadedOnlineProgression,
      );
      final next = settings.copyWith(
        displayName: displayName == null || displayName.trim().isEmpty
            ? settings.displayName
            : displayName,
        portraitAsset:
            profilePortraitAssets.contains(avatarURL) &&
                isProfilePortraitUnlocked(loadedProgression, avatarURL!)
            ? avatarURL
            : settings.portraitAsset,
        profileStats: profileStatsFromSupabaseJson(stats),
        onlineProgression: loadedOnlineProgression,
        onlineProgressionUserID: user.id,
      );
      settings = next;
      settingsStore.save(next);
      if (store.isOnlineGame && store.model?.table.gameResult != null) {
        final nextCompleted = effectiveProgression.completed;
        final newlyCompleted = progressionDefinitions
            .where(
              (definition) =>
                  nextCompleted.contains(definition.id) &&
                  !previousCompleted.contains(definition.id),
            )
            .toList();
        if (newlyCompleted.isNotEmpty) {
          showProgressionNotice(newlyCompleted);
        }
      }
      if (mounted) {
        setState(() {
          cloudAuthMessage = settings.language.t(
            KolkhozText.kolkhozappProfileLoaded,
          );
          cloudAuthIsError = false;
        });
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          cloudAuthMessage = syncErrorMessage(exception);
          cloudAuthIsError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => cloudProfileBusy = false);
      }
    }
  }

  KolkhozOnlineClient onlineClient() {
    return KolkhozOnlineClient(
      _onlineServerURL,
      accessTokenProvider: _currentSupabaseAccessToken,
      deviceID: onlineDeviceID,
    );
  }

  Future<void> syncActiveSession() async {
    if (activeSessionSyncBusy) {
      return;
    }
    setState(() => activeSessionSyncBusy = true);
    try {
      await store.syncActiveOnlineGame(baseURL: _onlineServerURL);
      if (!mounted) {
        return;
      }
      setState(() {
        activeRemoteSession = null;
        activeSessionSyncBusy = false;
        gameLaunchOrigin = KolkhozGameLaunchOrigin.joined;
        onlineSessionCreatedByLocalPlayer = false;
        destination = store.onlineUpdate?.started ?? false
            ? _AppDestination.game
            : _AppDestination.online;
      });
      unawaited(sendOnlinePresenceHeartbeat());
    } catch (exception) {
      if (mounted) {
        setState(() => activeSessionSyncBusy = false);
        showForemanHintMessage('$exception');
      }
    }
  }

  Future<void> loadComradesSummary() async {
    if (comradesSummaryBusy) {
      return;
    }
    if (supabaseCurrentUser == null) {
      if (mounted && comradesSummary.userID != null) {
        setState(() => comradesSummary = const OnlineComradesResponse());
      }
      return;
    }
    comradesSummaryBusy = true;
    try {
      final response = await onlineClient().fetchComrades();
      updateComradesSummary(response);
    } catch (_) {
      if (mounted && comradesSummary.userID != null) {
        setState(() => comradesSummary = const OnlineComradesResponse());
      }
    } finally {
      comradesSummaryBusy = false;
    }
  }

  void updateComradesSummary(OnlineComradesResponse response) {
    if (!mounted) {
      return;
    }
    setState(() => comradesSummary = response);
  }

  Future<void> requestComradeByUserID(String userID) async {
    if (demoMode || userID == comradesSummary.userID) {
      return;
    }
    final client = onlineClient();
    await client.sendComradeRequestToUser(userID);
    updateComradesSummary(await client.fetchComrades());
  }

  Future<void> recordOfflineResultInCloud(bool won) async {
    final client = KolkhozSupabaseRuntime.instance.client;
    final user = client?.auth.currentUser;
    if (user == null) {
      return;
    }
    try {
      await client!.rpc('record_offline_result', params: {'won': won});
      await loadCloudProfile();
    } catch (exception) {
      if (mounted) {
        setState(() {
          cloudAuthMessage = syncErrorMessage(exception);
          cloudAuthIsError = true;
        });
      }
    }
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
    final update = progressionSummary == null
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
    if (!online) {
      unawaited(recordOfflineResultInCloud(won));
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

  String syncErrorMessage(Object exception) {
    return settings.language.t(KolkhozText.kolkhozappProfileSyncFailed);
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
        settings.language.t(
          KolkhozText.kolkhozappSignInBeforeJoiningOnlinePlay,
        ),
      );
    }
    final sessionID = await store.hostOnlineGame(
      baseURL: baseURL,
      variants: activeVariants,
      controllers: controllers,
      ranked: ranked,
      browserJoinable: browserJoinable,
      bestOf: bestOf,
    );
    setState(() {
      gameLaunchOrigin = KolkhozGameLaunchOrigin.created;
      destination = enterImmediately
          ? _AppDestination.game
          : _AppDestination.offline;
      onlineSessionCreatedByLocalPlayer = true;
    });
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
    await onlineClient().inviteSessionComrades(
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
        settings.language.t(
          KolkhozText.kolkhozappSignInBeforeJoiningOnlinePlay,
        ),
      );
    }
    await store.joinOnlineGame(
      baseURL: baseURL,
      inviteCode: inviteCode,
      preferredPlayerID: preferredPlayerID,
    );
    setState(() {
      gameLaunchOrigin = KolkhozGameLaunchOrigin.joined;
      destination = _AppDestination.online;
      onlineSessionCreatedByLocalPlayer = false;
    });
    unawaited(sendOnlinePresenceHeartbeat());
  }

  Future<String> matchmakeOnlineGame(
    Uri baseURL,
    bool rankedOnly,
    bool comradesOnly,
  ) async {
    if (!onlinePlayAllowed) {
      throw HttpException(
        settings.language.t(
          KolkhozText.kolkhozappSignInBeforeJoiningOnlinePlay,
        ),
      );
    }
    final inviteCode = await store.matchmakeOnlineGame(
      baseURL: baseURL,
      rankedOnly: rankedOnly,
      comradesOnly: comradesOnly,
    );
    setState(() {
      gameLaunchOrigin = KolkhozGameLaunchOrigin.joined;
      destination = _AppDestination.online;
      onlineSessionCreatedByLocalPlayer = false;
    });
    unawaited(sendOnlinePresenceHeartbeat());
    return inviteCode;
  }

  Future<void> kickOnlinePlayer(int playerID) {
    return store.kickOnlinePlayer(playerID);
  }

  void enterOnlineGame() {
    setState(() {
      destination = _AppDestination.game;
    });
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
