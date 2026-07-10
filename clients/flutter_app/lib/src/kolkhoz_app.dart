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
import 'c_engine_bridge.dart';
import 'design_tokens.dart';
import 'game_constants.dart';
import 'board_view.dart';
import 'live_game_store.dart';
import 'online_game_models.dart';
import 'pixel_text.dart';
import 'player_profile_panel.dart';
import 'render_model.dart';
import 'rule_content.dart';
import 'supabase_config.dart';
import 'table_display.dart';
import 'tutorial_display.dart';

part 'online_lobby_panel.dart';

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

class KolkhozApp extends StatefulWidget {
  const KolkhozApp({super.key});

  @override
  State<KolkhozApp> createState() => _KolkhozAppState();
}

class _KolkhozAppState extends State<KolkhozApp> with WidgetsBindingObserver {
  static const foremanHintDuration = Duration(seconds: 3);
  static const onlinePresenceHeartbeatInterval = Duration(seconds: 15);
  static const onlineInvitePollInterval = Duration(seconds: 5);

  final navigatorKey = GlobalKey<NavigatorState>();
  late final LiveGameStore store;
  late final KolkhozAppSettingsStore settingsStore;
  StreamSubscription<AuthState>? supabaseAuthSubscription;
  Timer? cloudProfileSyncTimer;
  Timer? onlinePresenceTimer;
  Timer? onlineInviteTimer;
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
  bool showingLobby = true;
  bool showingRules = false;
  bool showingOnline = false;
  bool showingProfile = false;
  KolkhozSettingsTab selectedSettingsTab = KolkhozSettingsTab.profile;
  bool onlineSessionCreatedByLocalPlayer = false;
  bool showingTutorial = false;
  String? foremanHint;
  Timer? foremanHintTimer;
  KolkhozGamePreset selectedPreset = KolkhozGamePreset.kolkhoz;
  KolkhozGameVariants customVariants = KolkhozGameVariants.kolkhoz;
  List<KolkhozPlayerController> playerControllers = List.of(
    KolkhozPlayerController.defaultControllers,
  );

  bool get demoMode => supabaseCurrentUser == null;

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
    final lastStartedSetup = settings.lastStartedSetup;
    if (lastStartedSetup != null) {
      selectedPreset = presetForVariants(lastStartedSetup.variants);
      customVariants = lastStartedSetup.variants;
      playerControllers = KolkhozPlayerController.normalized(
        lastStartedSetup.controllers,
      );
    }
    store = LiveGameStore(onlineAccessTokenProvider: supabaseAccessToken);
    store.addListener(handleStoreChanged);
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
    cloudProfileSyncTimer?.cancel();
    onlinePresenceTimer?.cancel();
    onlineInviteTimer?.cancel();
    supabaseAuthSubscription?.cancel();
    store.removeListener(handleStoreChanged);
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
        child: child ?? const SizedBox.shrink(),
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
          } else if (store.model == null ||
              (showingLobby &&
                  (!store.isOnlineGame ||
                      !(store.onlineUpdate?.started ?? false)))) {
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
              onInviteOnlineComrades: inviteOnlineComrades,
              onJoinOnline: joinOnlineGame,
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
                  onlineSessionCreatedByLocalPlayer = false;
                  showingLobby = false;
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
                  showingRules = false;
                  showingOnline = false;
                  showingProfile = false;
                });
              },
              onCustomVariantsChanged: (variants) {
                if (demoMode) {
                  return;
                }
                setState(() {
                  selectedPreset = KolkhozGamePreset.custom;
                  customVariants = variants;
                  showingRules = false;
                  showingOnline = false;
                  showingProfile = false;
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
              onRulesPressed: () {
                setState(() {
                  showingRules = true;
                  showingOnline = false;
                  showingProfile = false;
                });
              },
              onOfflinePressed: () {
                setState(() {
                  showingRules = false;
                  showingOnline = false;
                  showingProfile = false;
                });
              },
              onOnlinePressed: () {
                setState(() {
                  showingRules = false;
                  showingOnline = !demoMode;
                  showingProfile = demoMode;
                });
              },
              onProfilePressed: () {
                setState(() {
                  showingRules = false;
                  showingOnline = false;
                  showingProfile = true;
                  selectedSettingsTab = KolkhozSettingsTab.profile;
                });
              },
              onSettingsPressed: () {
                setState(() {
                  showingRules = false;
                  showingOnline = false;
                  showingProfile = true;
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
              onComradesChanged: updateComradesSummary,
              onComradeRequestToUser: requestComradeByUserID,
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
                  gameOverReturnsToLobby: store.isOnlineGame,
                  onTutorial: showTutorial,
                  animationSpeed: store.animationSpeed,
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
      unawaited(loadCloudProfile());
      unawaited(loadComradesSummary());
    });
    unawaited(loadCloudProfile());
    unawaited(loadComradesSummary());
  }

  void handleStoreChanged() {
    final model = store.model;
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
    );
  }

  Future<void> requestNewGameFromBoard() async {
    clearForemanHint();
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
      showingLobby = true;
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
      showingRules = false;
      showingOnline = false;
      showingProfile = false;
      showingLobby = false;
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
      await onlineClient().sendPresenceHeartbeat();
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
      showingRules = false;
      showingOnline = false;
      showingProfile = false;
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
        email: email.trim(),
        password: password,
      );
      await loadCloudProfile();
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
        email: email.trim(),
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
      await client.auth.signOut();
      comradesSummary = const OnlineComradesResponse();
      dismissedInviteSessionIDs.clear();
      activeInviteDialogSessionID = null;
      cloudAuthMessage = settings.language.t(KolkhozText.kolkhozappSignedOut);
      cloudAuthIsError = false;
    });
  }

  Future<void> resetSupabasePassword(String email) async {
    await runCloudAuthAction(() async {
      final trimmed = email.trim();
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
      if (profile == null) {
        await syncCloudProfile();
        return;
      }
      final displayName = profile['display_name'] as String?;
      final avatarURL = profile['avatar_url'] as String?;
      final next = settings.copyWith(
        displayName: displayName == null || displayName.trim().isEmpty
            ? settings.displayName
            : displayName,
        portraitAsset: profilePortraitAssets.contains(avatarURL)
            ? avatarURL!
            : settings.portraitAsset,
        profileStats: profileStatsFromSupabaseJson(stats),
      );
      settings = next;
      settingsStore.save(next);
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
    );
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

  void recordCompletedGameStats({required bool online, required bool won}) {
    final nextStats = settings.profileStats.recordResult(
      online: online,
      won: won,
    );
    final next = settings.copyWith(profileStats: nextStats);
    setState(() => settings = next);
    settingsStore.save(next);
    if (!online) {
      unawaited(recordOfflineResultInCloud(won));
    }
  }

  String get normalizedDisplayName {
    final trimmed = settings.displayName.trim();
    return trimmed.isEmpty ? defaultProfileDisplayName : trimmed;
  }

  String accountErrorMessage(Object exception) {
    if (exception is FormatException) {
      return exception.message;
    }
    return settings.language.t(KolkhozText.kolkhozappAccountRequestFailed);
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
  ) async {
    if (demoMode) {
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
    );
    setState(() {
      showingRules = false;
      showingOnline = false;
      showingProfile = false;
      showingLobby = !enterImmediately;
      onlineSessionCreatedByLocalPlayer = true;
    });
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
    if (demoMode) {
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
      showingRules = false;
      showingOnline = true;
      showingProfile = false;
      showingLobby = true;
      onlineSessionCreatedByLocalPlayer = false;
    });
  }

  Future<String> matchmakeOnlineGame(
    Uri baseURL,
    bool rankedOnly,
    bool comradesOnly,
  ) async {
    if (demoMode) {
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
      showingRules = false;
      showingOnline = true;
      showingProfile = false;
      showingLobby = true;
      onlineSessionCreatedByLocalPlayer = false;
    });
    return inviteCode;
  }

  Future<void> kickOnlinePlayer(int playerID) {
    return store.kickOnlinePlayer(playerID);
  }

  void enterOnlineGame() {
    setState(() {
      showingRules = false;
      showingOnline = true;
      showingProfile = false;
      showingLobby = false;
    });
  }
}

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
      KolkhozGamePreset.kolkhoz =>
        'ios_resources/Icons/icon-preset-kolkhoz.png',
      KolkhozGamePreset.littleKolkhoz =>
        'ios_resources/Icons/icon-preset-little-kolkhoz.png',
      KolkhozGamePreset.campStyle =>
        'ios_resources/Icons/icon-preset-camp-style.png',
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
              Container(
                height: cardHeight,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: tokens.colors.gold.withValues(alpha: 0.72),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.colors.black.withValues(alpha: 0.28),
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Image.asset(
                  'ios_resources/title-card-kolkhoz.png',
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
                  'ios_resources/ui-divider-crops.png',
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
            iconAsset: 'ios_resources/Icons/icon-create-game.png',
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
                ? 'ios_resources/Icons/icon-join-game.png'
                : 'ios_resources/Icons/icon-lock.png',
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
            iconAsset: 'ios_resources/Icons/icon-foreman-misha.png',
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
                iconAsset: 'ios_resources/Icons/${language.toggleIconAsset}',
                size: iconSize,
                onPressed: onLanguageToggle,
              ),
              _LobbyIconButton(
                tokens: tokens,
                label: language.t(KolkhozText.lobbyTheme),
                tooltip: appearance.toggleTitle(language),
                iconAsset: 'ios_resources/Icons/${appearance.toggleIconAsset}',
                size: iconSize,
                onPressed: onAppearanceToggle,
              ),
              _LobbyIconButton(
                tokens: tokens,
                label: language.t(KolkhozText.lobbySettings),
                tooltip: language.t(KolkhozText.lobbySettings),
                iconAsset: 'ios_resources/Icons/icon-gears.png',
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
      return 'ios_resources/Icons/icon-status-connecting.png';
    }
    if (!cloudConfigured) {
      return 'ios_resources/Icons/icon-warning.png';
    }
    if (cloudSignedIn) {
      return 'ios_resources/Icons/icon-status-connected.png';
    }
    return 'ios_resources/Icons/icon-profile.png';
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
              displayName: displayName,
              portraitAsset: portraitAsset,
              profileStats: profileStats,
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
  comrades,
  assist,
  display,
  rules;

  String title(KolkhozLanguage language) {
    return switch (this) {
      KolkhozSettingsTab.profile => language.t(KolkhozText.kolkhozappProfile),
      KolkhozSettingsTab.comrades => language.t(KolkhozText.kolkhozappComrades),
      KolkhozSettingsTab.assist => OptionsMenuTab.assist.title(language),
      KolkhozSettingsTab.display => OptionsMenuTab.display.title(language),
      KolkhozSettingsTab.rules => OptionsMenuTab.rules.title(language),
    };
  }

  String get iconAsset {
    return switch (this) {
      KolkhozSettingsTab.profile => 'ios_resources/Icons/icon-profile.png',
      KolkhozSettingsTab.comrades =>
        'ios_resources/Icons/icon-friends-list.png',
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
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
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
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final KolkhozCardBack cardBack;
  final GameAnimationSpeed animationSpeed;
  final bool confirmNewGame;
  final bool confirmMainMenu;
  final bool showInvalidTapHints;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
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
          onAnimationSpeedChanged: widget.onAnimationSpeedChanged,
          onLanguageToggle: widget.onLanguageToggle,
          onAppearanceToggle: widget.onAppearanceToggle,
          onCardBackChanged: widget.onCardBackChanged,
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
            final tabWidth =
                (constraints.maxWidth -
                    spacing * (KolkhozSettingsTab.values.length - 1)) /
                KolkhozSettingsTab.values.length;
            final tabHeight = (tabWidth * 0.30).clamp(38.0, 52.0);
            return Row(
              spacing: spacing,
              children: [
                for (final tab in KolkhozSettingsTab.values)
                  Expanded(
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

class _VariantPanel extends StatefulWidget {
  const _VariantPanel({
    required this.tokens,
    required this.language,
    required this.selectedPreset,
    required this.customVariants,
    required this.playerControllers,
    required this.demoMode,
    required this.variants,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.favoriteSetup,
    required this.lastStartedSetup,
    required this.comradesSummary,
    required this.compactRail,
    required this.onStart,
    required this.onHostOnline,
    required this.onInviteOnlineComrades,
    required this.onRememberStartedSetup,
    required this.hostedInviteCode,
    required this.onlineSessionUpdate,
    required this.showHostedInviteCode,
    required this.onKickOnlinePlayer,
    required this.onEnterOnlineGame,
    required this.onCancelOnlineGame,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
    required this.onSaveFavoriteSetup,
    required this.onUseFavoriteSetup,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final bool demoMode;
  final KolkhozGameVariants variants;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final KolkhozFavoriteSetup? favoriteSetup;
  final KolkhozFavoriteSetup? lastStartedSetup;
  final OnlineComradesResponse comradesSummary;
  final bool compactRail;
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
  final void Function(
    List<KolkhozPlayerController> controllers,
    List<String> lobbySeats,
    bool browserJoinable,
  )?
  onRememberStartedSetup;
  final String? hostedInviteCode;
  final OnlineSessionUpdate? onlineSessionUpdate;
  final bool showHostedInviteCode;
  final Future<void> Function(int playerID)? onKickOnlinePlayer;
  final VoidCallback onEnterOnlineGame;
  final VoidCallback? onCancelOnlineGame;
  final ValueChanged<KolkhozGamePreset> onPresetChanged;
  final ValueChanged<KolkhozGameVariants> onCustomVariantsChanged;
  final ValueChanged<List<KolkhozPlayerController>> onPlayerControllersChanged;
  final VoidCallback? onSaveFavoriteSetup;
  final VoidCallback? onUseFavoriteSetup;

  @override
  State<_VariantPanel> createState() => _VariantPanelState();
}

class _VariantPanelState extends State<_VariantPanel> {
  late List<_LobbySeatChoice> seatChoices;
  final Map<int, String> selectedComradeUserIDsBySeat = {};
  bool showingSeatLobby = false;
  bool startingOnline = false;
  bool browserJoinable = true;
  String? onlineStatus;
  bool onlineStatusIsError = false;
  bool onlineStatusDisablesAction = false;

  @override
  void initState() {
    super.initState();
    seatChoices = _initialSeatChoices();
    browserJoinable = widget.lastStartedSetup?.browserJoinable ?? true;
    showingSeatLobby = widget.lastStartedSetup != null && !widget.demoMode;
  }

  @override
  void didUpdateWidget(covariant _VariantPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.demoMode && !oldWidget.demoMode) {
      showingSeatLobby = false;
    }
    if (widget.lastStartedSetup != oldWidget.lastStartedSetup &&
        widget.lastStartedSetup != null &&
        !showingSeatLobby &&
        !widget.demoMode) {
      seatChoices = _initialSeatChoices();
      browserJoinable = widget.lastStartedSetup!.browserJoinable;
      showingSeatLobby = true;
    }
  }

  List<_LobbySeatChoice> _initialSeatChoices() {
    final lastStartedSetup = widget.lastStartedSetup;
    if (lastStartedSetup == null || widget.demoMode) {
      return _LobbySeatChoice.emptySetupChoices();
    }
    return _LobbySeatChoice.fromStoredValues(
      lastStartedSetup.lobbySeats,
      fallbackControllers: lastStartedSetup.controllers,
    );
  }

  List<_LobbySeatChoice> get effectiveSeatChoices {
    if (widget.demoMode) {
      return _LobbySeatChoice.fromControllers(
        KolkhozPlayerController.demoControllers,
      );
    }
    return seatChoices;
  }

  List<KolkhozPlayerController> get effectiveControllers {
    return _LobbySeatChoice.toControllers(effectiveSeatChoices);
  }

  bool get hasOnlineSeats =>
      effectiveSeatChoices.contains(_LobbySeatChoice.online) ||
      effectiveSeatChoices.contains(_LobbySeatChoice.comrade);

  bool get hasUnassignedSeats =>
      effectiveSeatChoices.contains(_LobbySeatChoice.empty);

  bool get hasUnassignedComradeSeats {
    for (var playerID = 1; playerID < kolkhozPlayerCount; playerID += 1) {
      final userID = selectedComradeUserIDsBySeat[playerID];
      if (effectiveSeatChoices[playerID] == _LobbySeatChoice.comrade &&
          !_hasComradeUserID(userID)) {
        return true;
      }
    }
    return false;
  }

  List<String> get invitedComradeUserIDs {
    final userIDs = <String>{};
    for (var playerID = 1; playerID < kolkhozPlayerCount; playerID += 1) {
      if (effectiveSeatChoices[playerID] == _LobbySeatChoice.comrade) {
        final userID = selectedComradeUserIDsBySeat[playerID];
        if (_hasComradeUserID(userID)) {
          userIDs.add(userID!);
        }
      }
    }
    return userIDs.toList(growable: false);
  }

  bool _hasComradeUserID(String? userID) {
    if (userID == null || userID.isEmpty) {
      return false;
    }
    return widget.comradesSummary.comrades.any(
      (comrade) => comrade.userID == userID,
    );
  }

  void setSeatChoice(int playerID, _LobbySeatChoice choice) {
    final next = List<_LobbySeatChoice>.of(effectiveSeatChoices);
    next[playerID] = choice;
    final exclusive = _LobbySeatChoice.withExclusiveHumanMode(
      next,
      changedPlayerID: playerID,
    );
    setState(() {
      seatChoices = exclusive;
      if (choice == _LobbySeatChoice.comrade) {
        final comrades = widget.comradesSummary.comrades;
        if (selectedComradeUserIDsBySeat[playerID] == null &&
            comrades.isNotEmpty) {
          selectedComradeUserIDsBySeat[playerID] = comrades.first.userID;
        }
        browserJoinable = false;
      } else {
        selectedComradeUserIDsBySeat.remove(playerID);
      }
      for (var index = 1; index < kolkhozPlayerCount; index += 1) {
        if (exclusive[index] != _LobbySeatChoice.comrade) {
          selectedComradeUserIDsBySeat.remove(index);
        }
      }
      onlineStatus = null;
      onlineStatusIsError = false;
      onlineStatusDisablesAction = false;
    });
    widget.onPlayerControllersChanged(
      _LobbySeatChoice.toControllers(exclusive),
    );
  }

  void setSeatComrade(int playerID, String userID) {
    setState(() {
      selectedComradeUserIDsBySeat[playerID] = userID;
      onlineStatus = null;
      onlineStatusIsError = false;
      onlineStatusDisablesAction = false;
    });
  }

  Future<void> startGame() async {
    if (!hasOnlineSeats) {
      rememberEffectiveSetup();
      widget.onPlayerControllersChanged(effectiveControllers);
      widget.onStart();
      return;
    }
    if (startingOnline) {
      return;
    }
    setState(() {
      startingOnline = true;
      onlineStatus = null;
      onlineStatusIsError = false;
      onlineStatusDisablesAction = false;
    });
    try {
      final sessionID = await widget.onHostOnline(
        _onlineServerURL,
        effectiveControllers,
        false,
        false,
        browserJoinable,
      );
      await widget.onInviteOnlineComrades?.call(
        sessionID,
        invitedComradeUserIDs,
      );
      rememberEffectiveSetup();
    } catch (exception) {
      if (!mounted) {
        return;
      }
      setState(() {
        onlineStatus = onlineFailureStatusMessage(exception, widget.language);
        onlineStatusIsError = true;
        onlineStatusDisablesAction = false;
      });
    } finally {
      if (mounted) {
        setState(() => startingOnline = false);
      }
    }
  }

  void rememberEffectiveSetup() {
    widget.onRememberStartedSetup?.call(
      effectiveControllers,
      _LobbySeatChoice.storedValues(effectiveSeatChoices),
      browserJoinable,
    );
  }

  void useFavoriteSetup() {
    final favorite = widget.favoriteSetup;
    if (favorite == null || widget.demoMode) {
      return;
    }
    setState(() {
      seatChoices = _LobbySeatChoice.fromControllers(favorite.controllers);
      onlineStatus = null;
      onlineStatusIsError = false;
      onlineStatusDisablesAction = false;
    });
    widget.onUseFavoriteSetup?.call();
  }

  Future<void> copyHostedInviteCode(String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!mounted) {
      return;
    }
    setState(() {
      onlineStatus = widget.language.t(KolkhozText.kolkhozappCopied);
      onlineStatusIsError = false;
      onlineStatusDisablesAction = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showingSeatLobby && !widget.demoMode) {
      return _buildLobbyStep();
    }
    return _buildSetupStep();
  }

  Widget _buildSetupStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        _PresetSelector(
          tokens: widget.tokens,
          language: widget.language,
          selectedPreset: widget.selectedPreset,
          compact: widget.compactRail,
          onPresetChanged: widget.demoMode ? null : widget.onPresetChanged,
        ),
        _GoldDivider(tokens: widget.tokens),
        Expanded(child: _VariantOptionsScroll(panel: widget)),
        if (widget.demoMode)
          _primaryCommandButton(
            label: widget.language.t(KolkhozText.kolkhozappStartDemo),
            iconAsset: 'ios_resources/Icons/icon-demo.png',
            onPressed: startGame,
          )
        else
          _setupCommandRow(),
      ],
    );
  }

  Widget _buildLobbyStep() {
    final hostedOnlineUpdate = widget.showHostedInviteCode
        ? widget.onlineSessionUpdate
        : null;
    if (hostedOnlineUpdate != null) {
      return _buildHostedOnlineLobbyStep(hostedOnlineUpdate);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _PresetSummaryStrip(
          tokens: widget.tokens,
          language: widget.language,
          variants: widget.variants,
          compact: widget.compactRail,
        ),
        if (onlineStatus != null &&
            (!onlineStatusIsError || !onlineStatusDisablesAction))
          _OnlineStatusBanner(
            tokens: widget.tokens,
            message: onlineStatus!,
            isError: onlineStatusIsError,
          ),
        _GoldDivider(tokens: widget.tokens),
        Expanded(
          child: KolkhozScrollbar(
            tokens: widget.tokens,
            childBuilder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    _SeatLobbyEditor(
                      tokens: widget.tokens,
                      language: widget.language,
                      choices: effectiveSeatChoices,
                      displayName: widget.displayName,
                      portraitAsset: widget.portraitAsset,
                      profileStats: widget.profileStats,
                      comrades: widget.comradesSummary.comrades,
                      selectedComradeUserIDsBySeat:
                          selectedComradeUserIDsBySeat,
                      onComradeChanged: widget.demoMode ? null : setSeatComrade,
                      onChanged: widget.demoMode ? null : setSeatChoice,
                      compact: widget.compactRail,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _lobbyCommandRow(),
      ],
    );
  }

  Widget _lobbyCommandRow() {
    final height = widget.compactRail ? 50.0 : 56.0;
    return Row(
      spacing: 8,
      children: [
        SizedBox(
          width: widget.compactRail ? 154 : 190,
          child: _backToSetupButton(height: height),
        ),
        _BrowserJoinableToggle(
          tokens: widget.tokens,
          language: widget.language,
          browserJoinable: browserJoinable,
          enabled: hasOnlineSeats,
          onChanged: (value) => setState(() => browserJoinable = value),
        ),
        Expanded(
          child: _primaryCommandButton(
            label: _startButtonLabel(),
            iconAsset: _startButtonIconAsset(),
            onPressed:
                startingOnline ||
                    _startButtonShowsBan() ||
                    hasUnassignedSeats ||
                    hasUnassignedComradeSeats
                ? null
                : startGame,
            enabled:
                !_startButtonShowsBan() &&
                !hasUnassignedSeats &&
                !hasUnassignedComradeSeats,
          ),
        ),
      ],
    );
  }

  Widget _backToSetupButton({
    required double height,
    Key? key,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: height,
      child: ChromeAssetButton.command(
        key: key,
        label: widget.language.t(KolkhozText.kolkhozappBackToSetup),
        prominent: false,
        tokens: widget.tokens,
        iconAsset: 'ios_resources/Icons/icon-toolbar-undo.png',
        iconSize: widget.compactRail ? 18 : 22,
        textSize: widget.compactRail
            ? PixelTextSize.caption
            : PixelTextSize.headline,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        expandLabel: false,
        onPressed: onPressed ?? () => setState(() => showingSeatLobby = false),
      ),
    );
  }

  Widget _buildHostedOnlineLobbyStep(OnlineSessionUpdate update) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _PresetSummaryStrip(
          tokens: widget.tokens,
          language: widget.language,
          variants: widget.variants,
          compact: widget.compactRail,
        ),
        if (onlineStatus != null)
          _OnlineStatusBanner(
            tokens: widget.tokens,
            message: onlineStatus!,
            isError: onlineStatusIsError,
          ),
        _GoldDivider(tokens: widget.tokens),
        Expanded(
          child: _OnlineWaitingRoomPanel(
            tokens: widget.tokens,
            language: widget.language,
            update: update,
            inviteCode: widget.hostedInviteCode,
            onCopyInviteCode: widget.hostedInviteCode == null
                ? null
                : () =>
                      unawaited(copyHostedInviteCode(widget.hostedInviteCode!)),
            showHeaderCancel: false,
            showInviteCard: false,
            showJoinButton: false,
            canKickPlayers: !update.started,
            onKickPlayer: widget.onKickOnlinePlayer,
            onEnterOnlineGame: widget.onEnterOnlineGame,
            onCancelOnlineGame: widget.onCancelOnlineGame,
          ),
        ),
        _hostedLobbyCommandRow(update),
      ],
    );
  }

  Widget _hostedLobbyCommandRow(OnlineSessionUpdate update) {
    final height = widget.compactRail ? 50.0 : 56.0;
    final countdownSeconds = update.lobbyCountdownSeconds;
    final waitingLabel = countdownSeconds == null
        ? widget.language.t(KolkhozText.kolkhozappWaitingForPlayers)
        : widget.language.t(KolkhozText.kolkhozappGameStartsInValue1s, {
            'value1': countdownSeconds,
          });
    return Row(
      spacing: 8,
      children: [
        SizedBox(
          width: widget.compactRail ? 154 : 190,
          child: _backToSetupButton(
            height: height,
            key: const Key('hosted-online-back-to-setup'),
            onPressed:
                widget.onCancelOnlineGame ??
                () => setState(() => showingSeatLobby = false),
          ),
        ),
        if (widget.hostedInviteCode != null)
          SizedBox(
            width: widget.compactRail ? 134 : 164,
            child: _HostedInviteCodeFooterButton(
              tokens: widget.tokens,
              language: widget.language,
              inviteCode: widget.hostedInviteCode!,
              height: height,
              onCopy: () =>
                  unawaited(copyHostedInviteCode(widget.hostedInviteCode!)),
            ),
          ),
        Expanded(
          child: _WaitingRoomEnterButton(
            tokens: widget.tokens,
            language: widget.language,
            tableReady: update.started,
            waitingLabel: waitingLabel,
            height: height,
            onPressed: widget.onEnterOnlineGame,
          ),
        ),
      ],
    );
  }

  Widget _primaryCommandButton({
    required String label,
    required String iconAsset,
    required VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return SizedBox(
      height: widget.compactRail ? 50.0 : 56.0,
      child: ChromeAssetButton.command(
        width: double.infinity,
        padding: widget.compactRail
            ? const EdgeInsets.symmetric(horizontal: 8)
            : null,
        label: label,
        prominent: true,
        tokens: widget.tokens,
        onPressed: onPressed,
        enabled: enabled,
        disabledOpacity: 0.72,
        iconAsset: iconAsset,
        iconSize: widget.compactRail ? 22 : 28,
        textSize: widget.compactRail
            ? PixelTextSize.headline
            : PixelTextSize.title,
        expandLabel: false,
      ),
    );
  }

  Widget _setupCommandRow() {
    final height = widget.compactRail ? 50.0 : 56.0;
    final secondaryTextSize = widget.compactRail
        ? PixelTextSize.caption
        : PixelTextSize.headline;
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: SizedBox(
            height: height,
            child: ChromeAssetButton.command(
              label: widget.language.t(KolkhozText.kolkhozappSaveFavorite),
              prominent: false,
              tokens: widget.tokens,
              onPressed: widget.onSaveFavoriteSetup,
              textSize: secondaryTextSize,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              expandLabel: false,
              surfaceKey: const Key('save-favorite-setup-button'),
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: height,
            child: ChromeAssetButton.command(
              label: widget.language.t(KolkhozText.kolkhozappUseFavorite),
              prominent: false,
              tokens: widget.tokens,
              onPressed: widget.favoriteSetup != null ? useFavoriteSetup : null,
              enabled: widget.favoriteSetup != null,
              textSize: secondaryTextSize,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              expandLabel: false,
              surfaceKey: const Key('use-favorite-setup-button'),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: height,
            child: ChromeAssetButton.command(
              width: double.infinity,
              label: widget.language.t(KolkhozText.kolkhozappContinueToLobby),
              prominent: true,
              tokens: widget.tokens,
              onPressed: () => setState(() => showingSeatLobby = true),
              iconAsset: 'ios_resources/Icons/icon-add-friend.png',
              iconSize: widget.compactRail ? 22 : 28,
              textSize: widget.compactRail
                  ? PixelTextSize.headline
                  : PixelTextSize.title,
              padding: widget.compactRail
                  ? const EdgeInsets.symmetric(horizontal: 8)
                  : null,
              expandLabel: false,
            ),
          ),
        ),
      ],
    );
  }

  bool _startButtonShowsBan() {
    return onlineStatus != null && onlineStatusDisablesAction;
  }

  String _startButtonLabel() {
    if (_startButtonShowsBan()) {
      return onlineStatus!;
    }
    if (startingOnline) {
      return widget.language.t(KolkhozText.kolkhozappWorking);
    }
    if (hasOnlineSeats) {
      return widget.language.t(KolkhozText.kolkhozappStartOnlineGame);
    }
    return widget.language.t(KolkhozText.kolkhozappStartOfflineGame);
  }

  String _startButtonIconAsset() {
    if (_startButtonShowsBan()) {
      return 'ios_resources/Icons/icon-warning.png';
    }
    return 'ios_resources/Icons/icon-create-game.png';
  }
}

class _VariantOptionsScroll extends StatelessWidget {
  const _VariantOptionsScroll({required this.panel});

  final _VariantPanel panel;

  @override
  Widget build(BuildContext context) {
    return KolkhozScrollbar(
      tokens: panel.tokens,
      childBuilder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: const EdgeInsets.only(right: 10, bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              if (panel.selectedPreset == KolkhozGamePreset.custom &&
                  !panel.demoMode)
                _CustomVariantOptions(
                  tokens: panel.tokens,
                  language: panel.language,
                  variants: panel.customVariants,
                  compact: panel.compactRail,
                  onChanged: panel.onCustomVariantsChanged,
                )
              else
                _PresetSummary(
                  tokens: panel.tokens,
                  language: panel.language,
                  variants: panel.variants,
                  demoMode: panel.demoMode,
                  compact: panel.compactRail,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetSummaryStrip extends StatelessWidget {
  const _PresetSummaryStrip({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.compact,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final majorPreset = presetForVariants(variants);
    final icons = [
      if (majorPreset.iconAsset != null)
        _VariantHeaderIconData(
          label: presetTitle(majorPreset, language),
          iconAsset: majorPreset.iconAsset!,
          showLabel: true,
        ),
      for (final row in _VariantRowData.summaryRows(variants))
        _VariantHeaderIconData(
          label: row.localizedTitle(language, variants),
          iconAsset: row.iconAssetFor(variants),
        ),
    ];
    return Align(
      alignment: Alignment.center,
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: compact ? 5 : 7,
        runSpacing: compact ? 5 : 7,
        children: [
          for (final icon in icons)
            _VariantHeaderIconChip(
              label: icon.label,
              iconAsset: icon.iconAsset,
              showLabel: icon.showLabel,
              tokens: tokens,
              compact: compact,
            ),
        ],
      ),
    );
  }
}

class _VariantHeaderIconData {
  const _VariantHeaderIconData({
    required this.label,
    required this.iconAsset,
    this.showLabel = false,
  });

  final String label;
  final String iconAsset;
  final bool showLabel;
}

class _VariantHeaderIconChip extends StatelessWidget {
  const _VariantHeaderIconChip({
    required this.label,
    required this.iconAsset,
    required this.showLabel,
    required this.tokens,
    required this.compact,
  });

  final String label;
  final String iconAsset;
  final bool showLabel;
  final DesignTokens tokens;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = showLabel
        ? (compact ? 128.0 : 154.0)
        : (compact ? 42.0 : 48.0);
    final height = compact ? 38.0 : 44.0;
    final iconSize = showLabel
        ? (compact ? 25.0 : 29.0)
        : (compact ? 28.0 : 33.0);
    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned.fill(
                  child: ChromeButtonBackground(
                    asset: chromeButtonPrimaryAsset,
                  ),
                ),
                if (showLabel)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: compact ? 5 : 7,
                      children: [
                        _VariantIcon(iconAsset, size: iconSize),
                        Expanded(
                          child: ChromeScaledLabel(
                            label,
                            color: tokens.colors.onAccent,
                            size: compact
                                ? PixelTextSize.caption2
                                : PixelTextSize.caption,
                            uppercase: false,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _VariantIcon(iconAsset, size: iconSize),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetSelector extends StatelessWidget {
  const _PresetSelector({
    required this.tokens,
    required this.language,
    required this.selectedPreset,
    required this.compact,
    required this.onPresetChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGamePreset selectedPreset;
  final bool compact;
  final ValueChanged<KolkhozGamePreset>? onPresetChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = ((constraints.maxWidth - 620) / 900)
            .clamp(0.0, 1.0)
            .toDouble();
        final spacing = compact ? 6.0 : 6 + 6 * scale;
        final buttonWidth =
            (constraints.maxWidth -
                spacing * (KolkhozGamePreset.values.length - 1)) /
            KolkhozGamePreset.values.length;
        final buttonHeight = compact
            ? 52.0
            : (buttonWidth * 0.21).clamp(58.0, 88.0);
        final iconSize = compact
            ? (buttonHeight * 0.72).clamp(34.0, 40.0)
            : (buttonHeight * 0.58).clamp(38.0, 52.0);
        final textSize = compact
            ? _buttonContentTextSize(buttonHeight)
            : scale > 0.38
            ? PixelTextSize.cardRank
            : PixelTextSize.title;
        final horizontalPadding = compact ? 7.0 : 16 + 10 * scale;

        return Row(
          spacing: spacing,
          children: [
            for (final preset in KolkhozGamePreset.values)
              Expanded(
                child: _ImageTabButton(
                  tokens: tokens,
                  label: presetTitle(preset, language),
                  selected: selectedPreset == preset,
                  iconAsset: preset.iconAsset,
                  iconSize: iconSize,
                  height: buttonHeight,
                  textSize: textSize,
                  horizontalPadding: horizontalPadding,
                  contentSpacing: compact ? 6 : 8,
                  onPressed: onPresetChanged == null
                      ? null
                      : () => onPresetChanged!(preset),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SeatLobbyEditor extends StatelessWidget {
  const _SeatLobbyEditor({
    required this.tokens,
    required this.language,
    required this.choices,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.comrades,
    required this.selectedComradeUserIDsBySeat,
    required this.onComradeChanged,
    required this.onChanged,
    required this.compact,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<_LobbySeatChoice> choices;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final List<OnlineComradeProfile> comrades;
  final Map<int, String> selectedComradeUserIDsBySeat;
  final void Function(int playerID, String userID)? onComradeChanged;
  final void Function(int playerID, _LobbySeatChoice choice)? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final normalized = _LobbySeatChoice.normalized(choices);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 660 && !compact
            ? 4
            : constraints.maxWidth >= 430
            ? 2
            : 1;
        const spacing = 8.0;
        final columnWidth =
            (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var playerID = 0; playerID < kolkhozPlayerCount; playerID += 1)
              SizedBox(
                width: columnWidth,
                child: _SeatLobbyColumn(
                  tokens: tokens,
                  language: language,
                  playerID: playerID,
                  choice: normalized[playerID],
                  displayName: displayName,
                  portraitAsset: portraitAsset,
                  profileStats: profileStats,
                  comrades: comrades,
                  selectedComradeUserID: selectedComradeUserIDsBySeat[playerID],
                  choices: normalized,
                  options: _LobbySeatChoice.optionsForPlayer(playerID),
                  onComradeChanged: onComradeChanged == null || playerID == 0
                      ? null
                      : (userID) => onComradeChanged!(playerID, userID),
                  onChanged: onChanged == null || playerID == 0
                      ? null
                      : (choice) => onChanged!(playerID, choice),
                  compact: compact,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SeatLobbyColumn extends StatelessWidget {
  const _SeatLobbyColumn({
    required this.tokens,
    required this.language,
    required this.playerID,
    required this.choice,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.comrades,
    required this.selectedComradeUserID,
    required this.choices,
    required this.options,
    required this.onComradeChanged,
    required this.onChanged,
    required this.compact,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final int playerID;
  final _LobbySeatChoice choice;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final List<OnlineComradeProfile> comrades;
  final String? selectedComradeUserID;
  final List<_LobbySeatChoice> choices;
  final List<_LobbySeatChoice> options;
  final ValueChanged<String>? onComradeChanged;
  final ValueChanged<_LobbySeatChoice>? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final playerLabel = language.t(KolkhozText.kolkhozappPValue1, {
      'value1': playerID + 1,
    });
    final localProfile = playerID == 0 && choice == _LobbySeatChoice.local;
    final selectedComrade = choice == _LobbySeatChoice.comrade
        ? _selectedComrade()
        : null;
    final occupantLabel = localProfile
        ? displayName
        : selectedComrade != null
        ? selectedComrade.displayLabel
        : choice.shortTitle(language);
    final subtitle = localProfile
        ? _profileRatingSummary(language, profileStats)
        : selectedComrade != null
        ? _comradePresenceSummary(language, selectedComrade)
        : choice == _LobbySeatChoice.empty
        ? language.t(KolkhozText.kolkhozappOpen)
        : choice.shortTitle(language);
    final semanticLabel = '$playerLabel $occupantLabel';
    final card = PlayerProfilePanel(
      tokens: tokens,
      displayName: occupantLabel,
      portraitAsset: localProfile
          ? portraitAsset
          : selectedComrade?.portraitAsset ??
                _seatPortraitAsset(playerID, choice),
      seatLabel: playerLabel,
      subtitle: subtitle,
      subtitleIconAsset: localProfile ? null : choice.iconAsset,
      portraitSize: compact ? 42 : 48,
      minHeight: compact ? 78 : 92,
      active: playerID == 0,
      muted: choice == _LobbySeatChoice.empty,
    );
    if (onChanged != null) {
      final visibleOptions = options
          .where((option) => option != _LobbySeatChoice.empty)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: compact ? 6 : 8,
        children: [
          ExcludeSemantics(child: card),
          for (final option in visibleOptions)
            _SeatChoiceOptionButton(
              tokens: tokens,
              language: language,
              playerLabel: playerLabel,
              option: option,
              selected: option == choice,
              enabled: _LobbySeatChoice.isOptionEnabledForPlayer(
                playerID,
                choices,
                option,
              ),
              compact: compact,
              onPressed: () => onChanged!(option),
            ),
          if (choice == _LobbySeatChoice.comrade)
            _SeatComradePicker(
              tokens: tokens,
              language: language,
              comrades: comrades,
              selectedUserID: selectedComradeUserID,
              compact: compact,
              onChanged: onComradeChanged,
            ),
        ],
      );
    }
    return Semantics(
      button: true,
      enabled: onChanged != null,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Tooltip(
          message: semanticLabel,
          child: PopupMenuButton<_LobbySeatChoice>(
            tooltip: semanticLabel,
            enabled: onChanged != null,
            offset: const Offset(0, -172),
            color: tokens.colors.panel,
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            onSelected: onChanged,
            itemBuilder: (context) => [
              for (final option in options)
                PopupMenuItem(
                  value: option,
                  enabled: _LobbySeatChoice.isOptionEnabledForPlayer(
                    playerID,
                    choices,
                    option,
                  ),
                  child: Row(
                    spacing: 8,
                    children: [
                      _AssetIcon(
                        option.iconAsset,
                        size: 24,
                        opacity: option == choice ? 1 : 0.72,
                      ),
                      Text(
                        option.shortTitle(language).toUpperCase(),
                        style: kolkhozFontStyle.copyWith(
                          color: option == choice
                              ? tokens.colors.goldBright
                              : _LobbySeatChoice.isOptionEnabledForPlayer(
                                  playerID,
                                  choices,
                                  option,
                                )
                              ? tokens.colors.creamDim
                              : tokens.colors.creamDim.withValues(alpha: 0.48),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: card,
          ),
        ),
      ),
    );
  }

  OnlineComradeProfile? _selectedComrade() {
    for (final comrade in comrades) {
      if (comrade.userID == selectedComradeUserID) {
        return comrade;
      }
    }
    return null;
  }

  String _seatPortraitAsset(int playerID, _LobbySeatChoice choice) {
    if (choice == _LobbySeatChoice.empty) {
      return 'worker${playerID + 1}';
    }
    final iconAsset = choice.iconAsset;
    const prefix = 'ios_resources/';
    const suffix = '.png';
    if (iconAsset.startsWith(prefix) && iconAsset.endsWith(suffix)) {
      return iconAsset.substring(
        prefix.length,
        iconAsset.length - suffix.length,
      );
    }
    return 'worker${playerID + 1}';
  }
}

class _SeatComradePicker extends StatelessWidget {
  const _SeatComradePicker({
    required this.tokens,
    required this.language,
    required this.comrades,
    required this.selectedUserID,
    required this.compact,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<OnlineComradeProfile> comrades;
  final String? selectedUserID;
  final bool compact;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedComrade();
    final label =
        selected?.displayLabel ?? language.t(KolkhozText.kolkhozappNoComrades);
    final enabled = onChanged != null && comrades.isNotEmpty;
    return Tooltip(
      message: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.56,
        child: PopupMenuButton<String>(
          enabled: enabled,
          tooltip: label,
          color: tokens.colors.panel,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          onSelected: onChanged,
          itemBuilder: (context) => [
            for (final comrade in comrades)
              PopupMenuItem(
                value: comrade.userID,
                child: Row(
                  spacing: 8,
                  children: [
                    PlayerProfilePortraitImage(
                      tokens: tokens,
                      asset:
                          comrade.portraitAsset ?? defaultProfilePortraitAsset,
                      size: 28,
                      selected: comrade.userID == selectedUserID,
                    ),
                    Expanded(
                      child: Text(
                        comrade.displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kolkhozFontStyle.copyWith(
                          color: comrade.userID == selectedUserID
                              ? tokens.colors.goldBright
                              : tokens.colors.creamDim,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: SizedBox(
            height: compact ? 34 : 38,
            child: _VariantRowBackground(
              tokens: tokens,
              active: selected != null,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 6 : 7,
              ),
              child: Row(
                spacing: 8,
                children: [
                  _AssetIcon(
                    'ios_resources/Icons/icon-comrade.png',
                    size: compact ? 20 : 24,
                    opacity: selected != null ? 1 : 0.7,
                  ),
                  Expanded(
                    child: ChromeScaledLabel(
                      label,
                      color: selected != null
                          ? tokens.colors.activeSurfaceText
                          : tokens.colors.cardInk.withValues(alpha: 0.72),
                      size: compact
                          ? PixelTextSize.caption2
                          : PixelTextSize.caption,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  OnlineComradeProfile? _selectedComrade() {
    for (final comrade in comrades) {
      if (comrade.userID == selectedUserID) {
        return comrade;
      }
    }
    return null;
  }
}

class _SeatChoiceOptionButton extends StatelessWidget {
  const _SeatChoiceOptionButton({
    required this.tokens,
    required this.language,
    required this.playerLabel,
    required this.option,
    required this.selected,
    required this.enabled,
    required this.compact,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String playerLabel;
  final _LobbySeatChoice option;
  final bool selected;
  final bool enabled;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = option.shortTitle(language);
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$playerLabel $label',
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Opacity(
            opacity: enabled ? 1 : 0.54,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? onPressed : null,
              child: SizedBox(
                height: compact ? 34 : 38,
                child: _VariantRowBackground(
                  tokens: tokens,
                  active: selected,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 10,
                    vertical: compact ? 6 : 7,
                  ),
                  child: Row(
                    spacing: 8,
                    children: [
                      _AssetIcon(
                        option.iconAsset,
                        size: compact ? 20 : 24,
                        opacity: selected ? 1 : 0.82,
                      ),
                      Expanded(
                        child: ChromeScaledLabel(
                          label,
                          color: selected
                              ? tokens.colors.activeSurfaceText
                              : tokens.colors.cardInk,
                          size: compact
                              ? PixelTextSize.caption2
                              : PixelTextSize.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrowserJoinableToggle extends StatelessWidget {
  const _BrowserJoinableToggle({
    required this.tokens,
    required this.language,
    required this.browserJoinable,
    required this.enabled,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool browserJoinable;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = browserJoinable
        ? language.t(KolkhozText.kolkhozappBrowser)
        : language.t(KolkhozText.kolkhozappLocked);
    return _OnlineGameOptionToggle(
      tokens: tokens,
      title: language.t(KolkhozText.kolkhozappAccess),
      label: label,
      selected: browserJoinable,
      enabled: enabled,
      iconAsset: browserJoinable
          ? 'ios_resources/Icons/icon-online.png'
          : 'ios_resources/Icons/icon-lock.png',
      onTap: () => onChanged(!browserJoinable),
    );
  }
}

class _OnlineGameOptionToggle extends StatelessWidget {
  const _OnlineGameOptionToggle({
    required this.tokens,
    required this.title,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.iconAsset,
    required this.onTap,
  });

  final DesignTokens tokens;
  final String title;
  final String label;
  final bool selected;
  final bool enabled;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? tokens.colors.activeSurfaceText
        : tokens.colors.cardInk;
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: selected,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Opacity(
            opacity: enabled ? 1 : 0.58,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? onTap : null,
              child: SizedBox(
                width: 138,
                height: 62,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ChromeButtonBackground(
                        asset: selected
                            ? chromeButtonPrimaryAsset
                            : chromeButtonSecondaryAsset,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
                      child: Row(
                        spacing: 8,
                        children: [
                          _AssetIcon(
                            iconAsset,
                            size: 30,
                            opacity: selected ? 1 : 0.82,
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              spacing: 2,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 13,
                                  child: ChromeScaledLabel(
                                    title,
                                    color: foreground.withValues(alpha: 0.68),
                                    size: PixelTextSize.caption2,
                                  ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  height: 18,
                                  child: ChromeScaledLabel(
                                    label,
                                    color: foreground,
                                    size: PixelTextSize.caption,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _LobbySeatChoice {
  empty,
  local,
  online,
  comrade,
  easyAI,
  mediumAI,
  hardAI;

  static List<_LobbySeatChoice> emptySetupChoices() {
    return const [
      _LobbySeatChoice.local,
      _LobbySeatChoice.empty,
      _LobbySeatChoice.empty,
      _LobbySeatChoice.empty,
    ];
  }

  static List<_LobbySeatChoice> fromControllers(
    List<KolkhozPlayerController> controllers,
  ) {
    final normalized = KolkhozPlayerController.normalized(controllers);
    return [for (final controller in normalized) fromController(controller)];
  }

  static List<_LobbySeatChoice> fromStoredValues(
    List<String> values, {
    required List<KolkhozPlayerController> fallbackControllers,
  }) {
    if (values.isEmpty) {
      return fromControllers(fallbackControllers);
    }
    try {
      return withExclusiveHumanMode(
        normalized([
          for (final value in values)
            _LobbySeatChoice.values.firstWhere(
              (choice) => choice.name == value,
            ),
        ]),
      );
    } catch (_) {
      return fromControllers(fallbackControllers);
    }
  }

  static _LobbySeatChoice fromController(KolkhozPlayerController controller) {
    return switch (controller) {
      KolkhozPlayerController.human => _LobbySeatChoice.local,
      KolkhozPlayerController.heuristicAI => _LobbySeatChoice.easyAI,
      KolkhozPlayerController.mediumAI => _LobbySeatChoice.mediumAI,
      KolkhozPlayerController.neuralAI => _LobbySeatChoice.hardAI,
    };
  }

  static List<_LobbySeatChoice> normalized(List<_LobbySeatChoice> choices) {
    final normalized = List<_LobbySeatChoice>.generate(
      kolkhozPlayerCount,
      (index) => index < choices.length
          ? choices[index]
          : fromController(KolkhozPlayerController.defaultControllers[index]),
    );
    if (normalized.first == _LobbySeatChoice.empty ||
        normalized.first == _LobbySeatChoice.online ||
        normalized.first == _LobbySeatChoice.comrade) {
      normalized[0] = _LobbySeatChoice.local;
    }
    if (!normalized.any((choice) => choice == _LobbySeatChoice.local)) {
      normalized[0] = _LobbySeatChoice.local;
    }
    return normalized;
  }

  static List<_LobbySeatChoice> optionsForPlayer(int playerID) {
    if (playerID == 0) {
      return const [local];
    }
    return const [
      _LobbySeatChoice.local,
      _LobbySeatChoice.online,
      _LobbySeatChoice.comrade,
      _LobbySeatChoice.easyAI,
      _LobbySeatChoice.mediumAI,
      _LobbySeatChoice.hardAI,
      _LobbySeatChoice.empty,
    ];
  }

  static bool isOptionEnabledForPlayer(
    int playerID,
    List<_LobbySeatChoice> choices,
    _LobbySeatChoice option,
  ) {
    if (playerID == 0) {
      return option == _LobbySeatChoice.local;
    }
    if (option != _LobbySeatChoice.local &&
        option != _LobbySeatChoice.online &&
        option != _LobbySeatChoice.comrade) {
      return true;
    }
    final normalized = _LobbySeatChoice.normalized(choices);
    final otherSeats = [
      for (var index = 1; index < kolkhozPlayerCount; index += 1)
        if (index != playerID) normalized[index],
    ];
    if (option == _LobbySeatChoice.local) {
      return !otherSeats.contains(_LobbySeatChoice.online);
    }
    return !otherSeats.contains(_LobbySeatChoice.local);
  }

  static List<_LobbySeatChoice> withExclusiveHumanMode(
    List<_LobbySeatChoice> choices, {
    int? changedPlayerID,
  }) {
    final normalized = _LobbySeatChoice.normalized(choices);
    var chosenHumanMode = _LobbySeatChoice.local;
    if (changedPlayerID != null &&
        changedPlayerID > 0 &&
        changedPlayerID < kolkhozPlayerCount &&
        normalized[changedPlayerID].isHumanSeat) {
      chosenHumanMode = normalized[changedPlayerID];
    } else {
      for (var index = 1; index < kolkhozPlayerCount; index += 1) {
        if (normalized[index].isHumanSeat) {
          chosenHumanMode = normalized[index];
        }
      }
    }
    for (var index = 1; index < kolkhozPlayerCount; index += 1) {
      final choice = normalized[index];
      final incompatible =
          (choice == _LobbySeatChoice.online &&
              chosenHumanMode == _LobbySeatChoice.local) ||
          (choice == _LobbySeatChoice.comrade &&
              chosenHumanMode == _LobbySeatChoice.local) ||
          (choice == _LobbySeatChoice.local &&
              (chosenHumanMode == _LobbySeatChoice.online ||
                  chosenHumanMode == _LobbySeatChoice.comrade)) ||
          (choice == _LobbySeatChoice.online &&
              chosenHumanMode == _LobbySeatChoice.comrade) ||
          (choice == _LobbySeatChoice.comrade &&
              chosenHumanMode == _LobbySeatChoice.online);
      if (incompatible) {
        normalized[index] = _LobbySeatChoice.empty;
      }
    }
    return normalized;
  }

  static List<KolkhozPlayerController> toControllers(
    List<_LobbySeatChoice> choices,
  ) {
    return KolkhozPlayerController.normalized([
      for (final choice in normalized(choices)) choice.controller,
    ]);
  }

  static List<String> storedValues(List<_LobbySeatChoice> choices) {
    return [
      for (final choice in normalized(choices))
        choice == _LobbySeatChoice.comrade
            ? _LobbySeatChoice.online.name
            : choice.name,
    ];
  }

  bool get isHumanSeat {
    return this == _LobbySeatChoice.local ||
        this == _LobbySeatChoice.online ||
        this == _LobbySeatChoice.comrade;
  }

  KolkhozPlayerController get controller {
    return switch (this) {
      _LobbySeatChoice.empty => KolkhozPlayerController.neuralAI,
      _LobbySeatChoice.local ||
      _LobbySeatChoice.online ||
      _LobbySeatChoice.comrade => KolkhozPlayerController.human,
      _LobbySeatChoice.easyAI => KolkhozPlayerController.heuristicAI,
      _LobbySeatChoice.mediumAI => KolkhozPlayerController.mediumAI,
      _LobbySeatChoice.hardAI => KolkhozPlayerController.neuralAI,
    };
  }

  String shortTitle(KolkhozLanguage language) {
    return switch (this) {
      _LobbySeatChoice.empty => language.t(KolkhozText.kolkhozappOpen),
      _LobbySeatChoice.local => language.t(KolkhozText.kolkhozappHotseat),
      _LobbySeatChoice.online => language.t(KolkhozText.kolkhozappOnline),
      _LobbySeatChoice.comrade => language.t(KolkhozText.kolkhozappComrade),
      _LobbySeatChoice.easyAI => KolkhozPlayerController.heuristicAI.shortTitle(
        language,
      ),
      _LobbySeatChoice.mediumAI => KolkhozPlayerController.mediumAI.shortTitle(
        language,
      ),
      _LobbySeatChoice.hardAI => KolkhozPlayerController.neuralAI.shortTitle(
        language,
      ),
    };
  }

  String get iconAsset {
    return switch (this) {
      _LobbySeatChoice.empty => 'ios_resources/Icons/icon-human-seat.png',
      _LobbySeatChoice.local =>
        'ios_resources/Icons/icon-controller-hotseat-player.png',
      _LobbySeatChoice.online =>
        'ios_resources/Icons/icon-controller-online-player.png',
      _LobbySeatChoice.comrade => 'ios_resources/Icons/icon-comrade.png',
      _LobbySeatChoice.easyAI =>
        'ios_resources/Icons/icon-controller-easy-ai.png',
      _LobbySeatChoice.mediumAI =>
        'ios_resources/Icons/icon-controller-medium-ai.png',
      _LobbySeatChoice.hardAI =>
        'ios_resources/Icons/icon-controller-hard-ai.png',
    };
  }
}

class _ImageTabButton extends StatelessWidget {
  const _ImageTabButton({
    required this.tokens,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.iconAsset,
    this.iconSize = 18,
    this.height = 48,
    this.textSize = PixelTextSize.caption,
    this.horizontalPadding,
    this.contentSpacing = 8,
  });

  final DesignTokens tokens;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final String? iconAsset;
  final double iconSize;
  final double height;
  final PixelTextSize textSize;
  final double? horizontalPadding;
  final double contentSpacing;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final active = selected && enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: ChromeAssetButton(
          label: enabled ? label : '',
          backgroundAsset: active
              ? chromeButtonPrimaryAsset
              : chromeButtonSecondaryAsset,
          tokens: tokens,
          textColor: active
              ? tokens.colors.onAccent
              : tokens.colors.cardInk.withValues(alpha: enabled ? 1 : 0.58),
          textSize: textSize,
          onPressed: onPressed,
          iconAsset: enabled ? iconAsset : 'ios_resources/Icons/icon-lock.png',
          iconSize: iconSize,
          height: height,
          padding: EdgeInsets.fromLTRB(
            enabled && iconAsset == null ? 10 : horizontalPadding ?? 14,
            3,
            horizontalPadding == null ? 10 : horizontalPadding!,
            0,
          ),
          spacing: enabled ? contentSpacing : 0,
          uppercase: enabled,
          enabled: enabled,
          disabledOpacity: 0.56,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: tokens.colors.gold.withValues(alpha: 0.18),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _PresetSummary extends StatefulWidget {
  const _PresetSummary({
    required this.tokens,
    required this.language,
    required this.variants,
    this.demoMode = false,
    this.compact = false,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final bool demoMode;
  final bool compact;

  @override
  State<_PresetSummary> createState() => _PresetSummaryState();
}

class _PresetSummaryState extends State<_PresetSummary> {
  int selectedRowIndex = 0;

  @override
  void didUpdateWidget(covariant _PresetSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rows = _VariantRowData.summaryRows(
      widget.variants,
      demoMode: widget.demoMode,
    );
    if (selectedRowIndex >= rows.length) {
      selectedRowIndex = math.max(0, rows.length - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _VariantRowData.summaryRows(
      widget.variants,
      demoMode: widget.demoMode,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _variantInfoScale(constraints.maxWidth);
        final selectedRow = rows.isEmpty ? null : rows[selectedRowIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: widget.compact ? 6 : 8 + 2 * scale,
          children: [
            if (widget.compact && rows.isNotEmpty) ...[
              _VariantIconStrip(
                tokens: widget.tokens,
                language: widget.language,
                variants: widget.variants,
                rows: rows,
                selectedIndex: selectedRowIndex,
                onSelected: (index) => setState(() {
                  selectedRowIndex = index;
                }),
              ),
              if (selectedRow != null)
                _VariantReadOnlyRow(
                  tokens: widget.tokens,
                  language: widget.language,
                  variants: widget.variants,
                  row: selectedRow,
                  scale: 0,
                  compact: true,
                ),
            ] else
              for (final row in rows)
                _VariantReadOnlyRow(
                  tokens: widget.tokens,
                  language: widget.language,
                  variants: widget.variants,
                  row: row,
                  scale: scale,
                ),
          ],
        );
      },
    );
  }
}

class _CustomVariantOptions extends StatefulWidget {
  const _CustomVariantOptions({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.compact,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final bool compact;
  final ValueChanged<KolkhozGameVariants> onChanged;

  @override
  State<_CustomVariantOptions> createState() => _CustomVariantOptionsState();
}

class _CustomVariantOptionsState extends State<_CustomVariantOptions> {
  int selectedRowIndex = 0;

  @override
  void didUpdateWidget(covariant _CustomVariantOptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rows = _VariantRowData.configurableRows(widget.variants);
    if (selectedRowIndex >= rows.length) {
      selectedRowIndex = math.max(0, rows.length - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _variantInfoScale(constraints.maxWidth);
        final rows = _VariantRowData.configurableRows(widget.variants);
        final selectedRow = rows.isEmpty ? null : rows[selectedRowIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: widget.compact ? 6 : 8 + 2 * scale,
          children: [
            if (widget.compact && rows.isNotEmpty) ...[
              _VariantIconStrip(
                tokens: widget.tokens,
                language: widget.language,
                variants: widget.variants,
                rows: rows,
                selectedIndex: selectedRowIndex,
                onSelected: (index) => setState(() {
                  selectedRowIndex = index;
                }),
              ),
              if (selectedRow != null) _customRow(selectedRow, scale: 0),
            ] else
              for (final row in rows) _customRow(row, scale: scale),
          ],
        );
      },
    );
  }

  Widget _customRow(_VariantRowData row, {required double scale}) {
    if (row == _VariantRowData.deckType) {
      return _DeckVariantToggleRow(
        tokens: widget.tokens,
        language: widget.language,
        variants: widget.variants,
        scale: scale,
        compact: widget.compact,
        onChanged: widget.onChanged,
      );
    }
    if (row == _VariantRowData.maxYears) {
      return _YearVariantToggleRow(
        tokens: widget.tokens,
        language: widget.language,
        variants: widget.variants,
        scale: scale,
        compact: widget.compact,
        onChanged: widget.onChanged,
      );
    }
    return _VariantToggleRow(
      tokens: widget.tokens,
      language: widget.language,
      variants: widget.variants,
      row: row,
      value: row.valueOf(widget.variants),
      scale: scale,
      compact: widget.compact,
      onChanged: (value) =>
          widget.onChanged(row.withValue(widget.variants, value)),
    );
  }
}

class _DeckVariantToggleRow extends StatelessWidget {
  const _DeckVariantToggleRow({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.scale,
    required this.compact,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final double scale;
  final bool compact;
  final ValueChanged<KolkhozGameVariants> onChanged;

  @override
  Widget build(BuildContext context) {
    final deckButtonHeight = compact ? 52.0 : 58 + 16 * scale;
    final deckIconSize = compact
        ? (deckButtonHeight * 0.72).clamp(34.0, 40.0)
        : 32 + 12 * scale;
    final deckTextSize = compact
        ? _buttonContentTextSize(deckButtonHeight)
        : scale > 0.38
        ? PixelTextSize.cardRank
        : PixelTextSize.title;
    final deckPadding = compact ? 7.0 : 14 + 8 * scale;
    final deckSpacing = compact ? 6.0 : 8.0;
    return Row(
      spacing: compact ? 6 : 6 + 4 * scale,
      children: [
        Expanded(
          child: _ImageTabButton(
            tokens: tokens,
            label: language.t(KolkhozText.variantDeck52Cards),
            iconAsset: 'ios_resources/Icons/icon-variant-deck-52.png',
            iconSize: deckIconSize,
            selected: variants.deckType == 52,
            height: deckButtonHeight,
            textSize: deckTextSize,
            horizontalPadding: deckPadding,
            contentSpacing: deckSpacing,
            onPressed: () => onChanged(
              variants.copyWith(deckType: 52, ordenNachalniku: false),
            ),
          ),
        ),
        Expanded(
          child: _ImageTabButton(
            tokens: tokens,
            label: language.t(KolkhozText.variantDeck36Cards),
            iconAsset: 'ios_resources/Icons/icon-variant-deck-36.png',
            iconSize: deckIconSize,
            selected: variants.deckType == 36,
            height: deckButtonHeight,
            textSize: deckTextSize,
            horizontalPadding: deckPadding,
            contentSpacing: deckSpacing,
            onPressed: () => onChanged(
              variants.copyWith(deckType: 36, accumulateJobs: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _YearVariantToggleRow extends StatelessWidget {
  const _YearVariantToggleRow({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.scale,
    required this.compact,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final double scale;
  final bool compact;
  final ValueChanged<KolkhozGameVariants> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? 7 : 8 + 2 * scale,
      runSpacing: compact ? 7 : 8 + 2 * scale,
      children: [
        for (var years = 1; years <= 5; years += 1)
          _VariantIconChip(
            tokens: tokens,
            label: language.t(KolkhozText.variantValue1YearPlan, {
              'value1': years,
            }),
            iconAsset: 'ios_resources/Icons/icon-year-$years.png',
            selected: variants.maxYears == years,
            onPressed: () => onChanged(variants.copyWith(maxYears: years)),
          ),
      ],
    );
  }
}

double _variantInfoScale(double width) {
  return ((width - 520) / 900).clamp(0.0, 1.0).toDouble();
}

class _VariantReadOnlyRow extends StatelessWidget {
  const _VariantReadOnlyRow({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.row,
    required this.scale,
    this.compact = false,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final _VariantRowData row;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _VariantRowBackground(
      tokens: tokens,
      active: true,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16 + 12 * scale,
        vertical: compact ? 9 : 13 + 12 * scale,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: compact ? 10 : 12 + 8 * scale,
        children: [
          _VariantIcon(
            row.iconAssetFor(variants),
            size: compact ? 40 : _variantIconSize(scale),
          ),
          Expanded(
            child: _VariantText(
              tokens: tokens,
              language: language,
              variants: variants,
              row: row,
              active: true,
              scale: scale,
              compact: compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantIconStrip extends StatelessWidget {
  const _VariantIconStrip({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.rows,
    required this.selectedIndex,
    required this.onSelected,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final List<_VariantRowData> rows;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (var index = 0; index < rows.length; index += 1)
          _VariantIconChip(
            tokens: tokens,
            label: rows[index].localizedTitle(language, variants),
            iconAsset: rows[index].iconAssetFor(variants),
            selected: index == selectedIndex,
            onPressed: () => onSelected(index),
          ),
      ],
    );
  }
}

class _VariantIconChip extends StatelessWidget {
  const _VariantIconChip({
    required this.tokens,
    required this.label,
    required this.iconAsset,
    required this.selected,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final String label;
  final String iconAsset;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: SizedBox(
              width: 52,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ChromeButtonBackground(
                      asset: selected
                          ? chromeButtonPrimaryAsset
                          : chromeButtonSecondaryAsset,
                    ),
                  ),
                  _VariantIcon(
                    iconAsset,
                    size: selected ? 34 : 31,
                    opacity: selected ? 1 : 0.82,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VariantToggleRow extends StatelessWidget {
  const _VariantToggleRow({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.row,
    required this.value,
    required this.onChanged,
    required this.scale,
    this.compact = false,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final _VariantRowData row;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = row.localizedTitle(language, variants);
    return Semantics(
      button: true,
      toggled: value,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: _VariantRowBackground(
            tokens: tokens,
            active: value,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16 + 12 * scale,
              vertical: compact ? 9 : 13 + 12 * scale,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: compact ? 10 : 12 + 8 * scale,
              children: [
                _VariantIcon(
                  row.iconAssetFor(variants),
                  size: compact ? 40 : _variantIconSize(scale),
                  opacity: value ? 1 : 0.82,
                ),
                Expanded(
                  child: _VariantText(
                    tokens: tokens,
                    language: language,
                    variants: variants,
                    row: row,
                    active: value,
                    scale: scale,
                    compact: compact,
                  ),
                ),
                _VariantToggleMark(
                  tokens: tokens,
                  active: value,
                  size: compact ? 30 : 34 + 12 * scale,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VariantRowBackground extends StatelessWidget {
  const _VariantRowBackground({
    required this.tokens,
    required this.active,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final DesignTokens tokens;
  final bool active;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ChromeButtonBackground(
              asset: active
                  ? chromeButtonPrimaryAsset
                  : chromeButtonSecondaryAsset,
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _VariantToggleMark extends StatelessWidget {
  const _VariantToggleMark({
    required this.tokens,
    required this.active,
    this.size = 30,
  });

  final DesignTokens tokens;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? tokens.colors.gold.withValues(alpha: 0.82)
            : tokens.colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active
              ? tokens.colors.goldBright
              : tokens.colors.steel.withValues(alpha: 0.45),
        ),
      ),
      child: active
          ? _AssetIcon('ios_resources/Icons/icon-check.png', size: size * 0.63)
          : null,
    );
  }
}

class _VariantText extends StatelessWidget {
  const _VariantText({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.row,
    required this.active,
    required this.scale,
    this.compact = false,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final _VariantRowData row;
  final bool active;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleColor = active
        ? tokens.colors.activeSurfaceText
        : tokens.colors.cardInk;
    final bodyColor = active
        ? tokens.colors.activeSurfaceText
        : tokens.colors.cardInk.withValues(alpha: 0.74);
    final titleSize = compact
        ? PixelTextSize.headline
        : _variantTitleTextSize(scale);
    final bodySize = compact
        ? PixelTextSize.caption
        : _variantBodyTextSize(scale);
    final description = row.localizedDescription(language, variants);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: description.isEmpty
          ? 0
          : compact
          ? 4
          : 7 + 3 * scale,
      children: [
        _VariantPixelLine(
          height: _pixelTextSlotHeight(titleSize),
          child: PixelText(
            row.localizedTitle(language, variants).toUpperCase(),
            color: titleColor,
            size: titleSize,
            variant: PixelTextVariant.heavy,
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ),
        if (description.isNotEmpty)
          _VariantPixelLine(
            height: _pixelTextSlotHeight(bodySize),
            child: PixelText(
              description,
              color: bodyColor,
              size: bodySize,
              variant: PixelTextVariant.regular,
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
      ],
    );
  }
}

class _VariantPixelLine extends StatelessWidget {
  const _VariantPixelLine({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }
}

PixelTextSize _variantTitleTextSize(double scale) {
  return scale > 0.44 ? PixelTextSize.cardRank : PixelTextSize.title;
}

PixelTextSize _variantBodyTextSize(double scale) {
  return scale > 0.44 ? PixelTextSize.title : PixelTextSize.headline;
}

double _pixelTextSlotHeight(PixelTextSize size) {
  return switch (size) {
    PixelTextSize.cardRank => 34,
    PixelTextSize.title => 29,
    PixelTextSize.headline => 25,
    PixelTextSize.caption => 20,
    PixelTextSize.caption2 => 18,
    PixelTextSize.small => 16,
    PixelTextSize.xSmall => 14,
  };
}

double _variantIconSize(double scale) {
  return 55 + 22 * scale;
}

class _RulesPanel extends StatelessWidget {
  const _RulesPanel({
    required this.tokens,
    required this.language,
    required this.onTutorialPressed,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback onTutorialPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth;
              final twoColumn = contentWidth >= 560;
              final ruleWidth = twoColumn
                  ? (contentWidth - 12) / 2
                  : contentWidth;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [
                    Row(
                      spacing: 8,
                      children: [
                        const _AssetIcon(
                          'ios_resources/Icons/icon-rules-scroll.png',
                          size: 30,
                        ),
                        Text(
                          language.t(KolkhozText.kolkhozappHowToPlay),
                          style: kolkhozFontStyle.copyWith(
                            color: tokens.colors.gold,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Center(
                      child: Image.asset(
                        'ios_resources/Embellishments/art-rules-divider.png',
                        height: 48,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final rule in lobbyRuleSummaries)
                          SizedBox(
                            width: ruleWidth,
                            child: _RuleBlock(
                              tokens: tokens,
                              title: rule.title(language),
                              body: rule.body(language),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 220,
            height: 44,
            child: ChromeAssetButton.command(
              label: language.t(KolkhozText.kolkhozappTutorial),
              prominent: true,
              tokens: tokens,
              onPressed: onTutorialPressed,
              iconAsset: 'ios_resources/Icons/icon-foreman-misha.png',
              iconSize: 22,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePanel extends StatefulWidget {
  const _ProfilePanel({
    required this.tokens,
    required this.language,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudEmail,
    required this.cloudAuthBusy,
    required this.cloudAuthMessage,
    required this.cloudAuthIsError,
    required this.onDisplayNameChanged,
    required this.onPortraitChanged,
    required this.onCloudSignIn,
    required this.onCloudSignUp,
    required this.onCloudResetPassword,
    required this.onCloudSignOut,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final String? cloudAuthMessage;
  final bool cloudAuthIsError;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onPortraitChanged;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final Future<void> Function()? onCloudSignOut;

  @override
  State<_ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<_ProfilePanel> {
  late final TextEditingController displayNameController;
  late String lastSubmittedName;

  @override
  void initState() {
    super.initState();
    lastSubmittedName = widget.displayName;
    displayNameController = TextEditingController(text: widget.displayName);
    displayNameController.addListener(notifyDisplayNameChanged);
  }

  @override
  void didUpdateWidget(covariant _ProfilePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.displayName != lastSubmittedName &&
        widget.displayName != displayNameController.text) {
      displayNameController.text = widget.displayName;
      lastSubmittedName = widget.displayName;
    }
  }

  @override
  void dispose() {
    displayNameController.removeListener(notifyDisplayNameChanged);
    displayNameController.dispose();
    super.dispose();
  }

  void notifyDisplayNameChanged() {
    final next = displayNameController.text;
    if (next == lastSubmittedName) {
      return;
    }
    lastSubmittedName = next;
    widget.onDisplayNameChanged?.call(next);
  }

  Future<void> showPortraitPicker() async {
    if (widget.onPortraitChanged == null) {
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.tokens.colors.panel,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.tokens.colors.gold.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.tokens.colors.black.withValues(alpha: 0.42),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final asset in profilePortraitAssets)
                _ProfilePortraitChoice(
                  tokens: widget.tokens,
                  asset: asset,
                  selected: widget.portraitAsset == asset,
                  onPressed: () => Navigator.of(context).pop(asset),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != widget.portraitAsset) {
      widget.onPortraitChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                if (widget.cloudSignedIn) ...[
                  _ProfilePreview(
                    tokens: widget.tokens,
                    controller: displayNameController,
                    portraitAsset: widget.portraitAsset,
                    onPortraitPressed: widget.onPortraitChanged == null
                        ? null
                        : showPortraitPicker,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      Text(
                        widget.language.t(KolkhozText.kolkhozappStats),
                        style: kolkhozFontStyle.copyWith(
                          color: widget.tokens.colors.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columnCount = constraints.maxWidth >= 520
                              ? 3
                              : 1;
                          return PlayerProfileStatsGrid(
                            tokens: widget.tokens,
                            groups: kolkhozProfileStatGroups(
                              stats: widget.profileStats,
                              language: widget.language,
                            ),
                            columnsForWidth: (_) => columnCount,
                          );
                        },
                      ),
                    ],
                  ),
                ],
                _CloudAuthPanel(
                  tokens: widget.tokens,
                  language: widget.language,
                  configured: widget.cloudConfigured,
                  ready: widget.cloudReady,
                  signedIn: widget.cloudSignedIn,
                  email: widget.cloudEmail,
                  busy: widget.cloudAuthBusy,
                  message: widget.cloudAuthMessage,
                  messageIsError: widget.cloudAuthIsError,
                  onSignIn: widget.onCloudSignIn,
                  onSignUp: widget.onCloudSignUp,
                  onResetPassword: widget.onCloudResetPassword,
                  onSignOut: widget.onCloudSignOut,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CloudAuthPanel extends StatefulWidget {
  const _CloudAuthPanel({
    required this.tokens,
    required this.language,
    required this.configured,
    required this.ready,
    required this.signedIn,
    required this.email,
    required this.busy,
    required this.message,
    required this.messageIsError,
    required this.onSignIn,
    required this.onSignUp,
    required this.onResetPassword,
    required this.onSignOut,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool configured;
  final bool ready;
  final bool signedIn;
  final String? email;
  final bool busy;
  final String? message;
  final bool messageIsError;
  final Future<void> Function(String email, String password)? onSignIn;
  final Future<void> Function(String email, String password)? onSignUp;
  final Future<void> Function(String email)? onResetPassword;
  final Future<void> Function()? onSignOut;

  @override
  State<_CloudAuthPanel> createState() => _CloudAuthPanelState();
}

class _CloudAuthPanelState extends State<_CloudAuthPanel> {
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  late final TextEditingController confirmPasswordController;
  String? localMessage;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void clearLocalMessage() {
    if (localMessage == null) {
      return;
    }
    setState(() => localMessage = null);
  }

  void submitSignUp() {
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;
    if (password != confirmPassword) {
      setState(() {
        localMessage = widget.language.t(
          KolkhozText.kolkhozappPasswordsDoNotMatch,
        );
      });
      return;
    }
    clearLocalMessage();
    widget.onSignUp?.call(emailController.text, password);
  }

  @override
  Widget build(BuildContext context) {
    final status = !widget.configured
        ? widget.language.t(
            KolkhozText.kolkhozappCloudProfilesAreNotConfiguredForThisBuild,
          )
        : !widget.ready
        ? widget.language.t(KolkhozText.kolkhozappCloudProfilesAreStarting)
        : widget.signedIn
        ? widget.language.t(KolkhozText.kolkhozappSignedInAsValue1, {
            'value1': widget.email ?? 'player',
            'value2': widget.email ?? 'игрок',
          })
        : widget.language.t(
            KolkhozText.kolkhozappSignInToSyncProfileAndOnlineSeats,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          widget.language.t(KolkhozText.kolkhozappAccount),
          style: kolkhozFontStyle.copyWith(
            color: widget.tokens.colors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (widget.configured && widget.ready && widget.signedIn)
          _SignedInAccountRow(
            tokens: widget.tokens,
            status: status,
            signOutLabel: widget.busy
                ? widget.language.t(KolkhozText.kolkhozappWorking)
                : widget.language.t(KolkhozText.kolkhozappSignOut),
            onSignOut: widget.busy || widget.onSignOut == null
                ? null
                : widget.onSignOut,
          )
        else
          _VariantRowBackground(
            tokens: widget.tokens,
            active: false,
            child: Text(
              status,
              style: kolkhozFontStyle.copyWith(
                color: widget.tokens.colors.creamDim,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (widget.message != null &&
            (!widget.signedIn || widget.messageIsError))
          _OnlineStatusBanner(
            tokens: widget.tokens,
            message: widget.message!,
            isError: widget.messageIsError,
          ),
        if (widget.configured &&
            widget.ready &&
            !widget.signedIn &&
            localMessage != null)
          _OnlineStatusBanner(
            tokens: widget.tokens,
            message: localMessage!,
            isError: true,
          ),
        if (widget.configured && widget.ready && !widget.signedIn) ...[
          _ProfileTextField(
            tokens: widget.tokens,
            controller: emailController,
            label: widget.language.t(KolkhozText.kolkhozappEmail),
            maxLength: 72,
            onChanged: (_) => clearLocalMessage(),
          ),
          _ProfileTextField(
            tokens: widget.tokens,
            controller: passwordController,
            label: widget.language.t(KolkhozText.kolkhozappPassword),
            obscureText: true,
            maxLength: 72,
            onChanged: (_) => clearLocalMessage(),
          ),
          _ProfileTextField(
            tokens: widget.tokens,
            controller: confirmPasswordController,
            label: widget.language.t(KolkhozText.kolkhozappConfirmPassword),
            obscureText: true,
            maxLength: 72,
            onChanged: (_) => clearLocalMessage(),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              SizedBox(
                width: 142,
                height: 38,
                child: ChromeAssetButton.command(
                  label: widget.busy
                      ? widget.language.t(KolkhozText.kolkhozappWorking)
                      : widget.language.t(KolkhozText.kolkhozappSignIn),
                  prominent: false,
                  tokens: widget.tokens,
                  onPressed: widget.busy || widget.onSignIn == null
                      ? null
                      : () {
                          clearLocalMessage();
                          widget.onSignIn!(
                            emailController.text,
                            passwordController.text,
                          );
                        },
                ),
              ),
              SizedBox(
                width: 142,
                height: 38,
                child: ChromeAssetButton.command(
                  label: widget.language.t(KolkhozText.kolkhozappReset),
                  prominent: false,
                  tokens: widget.tokens,
                  onPressed: widget.busy || widget.onResetPassword == null
                      ? null
                      : () {
                          clearLocalMessage();
                          widget.onResetPassword!(emailController.text);
                        },
                ),
              ),
              SizedBox(
                width: 142,
                height: 38,
                child: ChromeAssetButton.command(
                  label: widget.language.t(KolkhozText.kolkhozappCreate),
                  prominent: true,
                  tokens: widget.tokens,
                  onPressed: widget.busy || widget.onSignUp == null
                      ? null
                      : submitSignUp,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SignedInAccountRow extends StatelessWidget {
  const _SignedInAccountRow({
    required this.tokens,
    required this.status,
    required this.signOutLabel,
    required this.onSignOut,
  });

  final DesignTokens tokens;
  final String status;
  final String signOutLabel;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: _VariantRowBackground(
            tokens: tokens,
            active: true,
            child: Row(
              spacing: 8,
              children: [
                const _AssetIcon(
                  'ios_resources/Icons/icon-status-connected.png',
                  size: 24,
                ),
                Expanded(
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kolkhozFontStyle.copyWith(
                      color: tokens.colors.activeSurfaceText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 142,
          height: 42,
          child: ChromeAssetButton.command(
            label: signOutLabel,
            prominent: false,
            tokens: tokens,
            onPressed: onSignOut,
          ),
        ),
      ],
    );
  }
}

class _ComradesSettingsPanel extends StatefulWidget {
  const _ComradesSettingsPanel({
    required this.tokens,
    required this.language,
    required this.comradesSummary,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudEmail,
    required this.cloudAuthBusy,
    required this.cloudAuthMessage,
    required this.cloudAuthIsError,
    required this.onCloudSignIn,
    required this.onCloudSignUp,
    required this.onCloudResetPassword,
    required this.onComradesChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineComradesResponse comradesSummary;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final String? cloudAuthMessage;
  final bool cloudAuthIsError;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final ValueChanged<OnlineComradesResponse>? onComradesChanged;

  @override
  State<_ComradesSettingsPanel> createState() => _ComradesSettingsPanelState();
}

class _ComradesSettingsPanelState extends State<_ComradesSettingsPanel> {
  @override
  Widget build(BuildContext context) {
    if (widget.cloudSignedIn) {
      return _ComradesPanel(
        tokens: widget.tokens,
        language: widget.language,
        initialComrades: widget.comradesSummary,
        onComradesChanged: widget.onComradesChanged,
      );
    }

    return SingleChildScrollView(
      child: _CloudAuthPanel(
        tokens: widget.tokens,
        language: widget.language,
        configured: widget.cloudConfigured,
        ready: widget.cloudReady,
        signedIn: widget.cloudSignedIn,
        email: widget.cloudEmail,
        busy: widget.cloudAuthBusy,
        message: widget.cloudAuthMessage,
        messageIsError: widget.cloudAuthIsError,
        onSignIn: widget.onCloudSignIn,
        onSignUp: widget.onCloudSignUp,
        onResetPassword: widget.onCloudResetPassword,
        onSignOut: null,
      ),
    );
  }
}

class _ComradesPanel extends StatefulWidget {
  const _ComradesPanel({
    required this.tokens,
    required this.language,
    required this.initialComrades,
    required this.onComradesChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineComradesResponse initialComrades;
  final ValueChanged<OnlineComradesResponse>? onComradesChanged;

  @override
  State<_ComradesPanel> createState() => _ComradesPanelState();
}

class _ComradesPanelState extends State<_ComradesPanel> {
  late final TextEditingController codeController;
  bool busy = false;
  String? message;
  bool messageIsError = false;
  OnlineComradesResponse comrades = const OnlineComradesResponse();

  @override
  void initState() {
    super.initState();
    codeController = TextEditingController();
    comrades = widget.initialComrades;
    unawaited(loadComrades());
  }

  @override
  void didUpdateWidget(covariant _ComradesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialComrades != oldWidget.initialComrades && !busy) {
      comrades = widget.initialComrades;
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  KolkhozOnlineClient _client() {
    return KolkhozOnlineClient(
      _onlineServerURL,
      accessTokenProvider: _currentSupabaseAccessToken,
    );
  }

  Future<void> loadComrades() async {
    await runComradeAction(() async {
      comrades = await _client().fetchComrades();
      widget.onComradesChanged?.call(comrades);
    }, showWorking: false);
  }

  Future<void> addComrade() async {
    final code = codeController.text.trim();
    if (code.isEmpty) {
      return;
    }
    await runComradeAction(() async {
      await _client().sendComradeRequest(code);
      codeController.clear();
      comrades = await _client().fetchComrades();
      widget.onComradesChanged?.call(comrades);
      message = widget.language.t(KolkhozText.kolkhozappComradeRequestSent);
      messageIsError = false;
    });
  }

  Future<void> respondToComradeRequest(String userID, bool accept) async {
    await runComradeAction(() async {
      await _client().respondToComradeRequest(userID: userID, accept: accept);
      comrades = await _client().fetchComrades();
      widget.onComradesChanged?.call(comrades);
      message = widget.language.t(
        accept
            ? KolkhozText.kolkhozappComradeRequestAccepted
            : KolkhozText.kolkhozappComradeRequestDeclined,
      );
      messageIsError = false;
    });
  }

  Future<void> removeComrade(String userID) async {
    await runComradeAction(() async {
      await _client().removeComrade(userID);
      comrades = await _client().fetchComrades();
      widget.onComradesChanged?.call(comrades);
      message = widget.language.t(KolkhozText.kolkhozappComradeRemoved);
      messageIsError = false;
    });
  }

  Future<void> copyComradeCode() async {
    final code = comrades.comradeCode;
    if (code == null || code.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }
    setState(() {
      message = widget.language.t(KolkhozText.kolkhozappCopied);
      messageIsError = false;
    });
  }

  Future<void> runComradeAction(
    Future<void> Function() action, {
    bool showWorking = true,
  }) async {
    if (busy) {
      return;
    }
    if (mounted) {
      setState(() {
        busy = showWorking;
        if (showWorking) {
          message = null;
          messageIsError = false;
        }
      });
    }
    try {
      await action();
    } catch (exception) {
      if (mounted) {
        setState(() {
          message = _comradeSyncErrorMessage(exception);
          messageIsError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  String _comradeSyncErrorMessage(Object exception) {
    if (exception is OnlineRequestException || exception is SocketException) {
      return onlineFailureStatusMessage(exception, widget.language);
    }
    return widget.language.t(KolkhozText.kolkhozappProfileSyncFailed);
  }

  @override
  Widget build(BuildContext context) {
    final code = comrades.comradeCode ?? '-----';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                _ComradeSectionTitle(
                  tokens: widget.tokens,
                  label: widget.language.t(KolkhozText.kolkhozappComrades),
                  iconAsset: 'ios_resources/Icons/icon-friends-list.png',
                ),
                if (comrades.comrades.isEmpty)
                  _ComradeEmptyRow(
                    tokens: widget.tokens,
                    label: widget.language.t(KolkhozText.kolkhozappNoComrades),
                  )
                else
                  for (final comrade in comrades.comrades)
                    _ComradeRow(
                      tokens: widget.tokens,
                      language: widget.language,
                      comrade: comrade,
                      busy: busy,
                      onRemove: () => removeComrade(comrade.userID),
                    ),
                const SizedBox(height: 2),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final requestColumns = <Widget>[
                      _ComradeRequestColumn(
                        tokens: widget.tokens,
                        language: widget.language,
                        label: widget.language.t(
                          KolkhozText.kolkhozappIncomingRequests,
                        ),
                        iconAsset: 'ios_resources/Icons/icon-add-friend.png',
                        requests: comrades.incomingRequests,
                        busy: busy,
                        incoming: true,
                        onAccept: (request) =>
                            respondToComradeRequest(request.userID, true),
                        onDecline: (request) =>
                            respondToComradeRequest(request.userID, false),
                      ),
                      _ComradeRequestColumn(
                        tokens: widget.tokens,
                        language: widget.language,
                        label: widget.language.t(
                          KolkhozText.kolkhozappOutgoingRequests,
                        ),
                        iconAsset: 'ios_resources/Icons/icon-friends-list.png',
                        requests: comrades.outgoingRequests,
                        busy: busy,
                        incoming: false,
                        onAccept: null,
                        onDecline: null,
                      ),
                    ];
                    if (constraints.maxWidth < 620) {
                      return Column(spacing: 8, children: requestColumns);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 10,
                      children: [
                        for (final column in requestColumns)
                          Expanded(child: column),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        if (message != null)
          _OnlineStatusBanner(
            tokens: widget.tokens,
            message: message!,
            isError: messageIsError,
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            const footerControlHeight = 38.0;
            final codeBox = _ComradeCodeDisplayBox(
              tokens: widget.tokens,
              code: code,
              height: footerControlHeight,
            );
            final copyButton = SizedBox(
              width: 126,
              height: footerControlHeight,
              child: ChromeAssetButton.command(
                label: widget.language.t(KolkhozText.kolkhozappCopyCode),
                prominent: false,
                tokens: widget.tokens,
                iconAsset: 'ios_resources/Icons/icon-comrade.png',
                expandLabel: false,
                onPressed: comrades.comradeCode == null
                    ? null
                    : copyComradeCode,
              ),
            );
            final inputBox = _ComradeCodeTextField(
              tokens: widget.tokens,
              controller: codeController,
              hint: widget.language.t(KolkhozText.kolkhozappComradeCode),
              height: footerControlHeight,
            );
            final addButton = SizedBox(
              width: 142,
              height: footerControlHeight,
              child: ChromeAssetButton.command(
                label: busy
                    ? widget.language.t(KolkhozText.kolkhozappWorking)
                    : widget.language.t(KolkhozText.kolkhozappAddComrade),
                prominent: true,
                tokens: widget.tokens,
                iconAsset: 'ios_resources/Icons/icon-add-friend.png',
                onPressed: busy ? null : addComrade,
              ),
            );
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(child: codeBox),
                      copyButton,
                    ],
                  ),
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(child: inputBox),
                      addButton,
                    ],
                  ),
                ],
              );
            }
            return Row(
              spacing: 8,
              children: [
                Expanded(flex: 2, child: codeBox),
                copyButton,
                Expanded(flex: 3, child: inputBox),
                addButton,
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ComradeRequestColumn extends StatelessWidget {
  const _ComradeRequestColumn({
    required this.tokens,
    required this.language,
    required this.label,
    required this.iconAsset,
    required this.requests,
    required this.busy,
    required this.incoming,
    required this.onAccept,
    required this.onDecline,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String label;
  final String iconAsset;
  final List<OnlineComradeProfile> requests;
  final bool busy;
  final bool incoming;
  final ValueChanged<OnlineComradeProfile>? onAccept;
  final ValueChanged<OnlineComradeProfile>? onDecline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        _ComradeSectionTitle(
          tokens: tokens,
          label: label,
          iconAsset: iconAsset,
        ),
        if (requests.isEmpty)
          _ComradeEmptyRow(
            tokens: tokens,
            label: language.t(KolkhozText.kolkhozappNoComradeRequests),
          )
        else
          for (final request in requests)
            _ComradeRequestRow(
              tokens: tokens,
              language: language,
              request: request,
              busy: busy,
              incoming: incoming,
              onAccept: onAccept == null ? null : () => onAccept!(request),
              onDecline: onDecline == null ? null : () => onDecline!(request),
            ),
      ],
    );
  }
}

class _ComradeSectionTitle extends StatelessWidget {
  const _ComradeSectionTitle({
    required this.tokens,
    required this.label,
    required this.iconAsset,
  });

  final DesignTokens tokens;
  final String label;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        spacing: 6,
        children: [
          Image.asset(
            iconAsset,
            width: 18,
            height: 18,
            filterQuality: FilterQuality.none,
          ),
          Expanded(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComradeEmptyRow extends StatelessWidget {
  const _ComradeEmptyRow({required this.tokens, required this.label});

  final DesignTokens tokens;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _VariantRowBackground(
      tokens: tokens,
      active: false,
      child: Text(
        label,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.creamDim,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ComradeRequestRow extends StatelessWidget {
  const _ComradeRequestRow({
    required this.tokens,
    required this.language,
    required this.request,
    required this.busy,
    required this.incoming,
    required this.onAccept,
    required this.onDecline,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineComradeProfile request;
  final bool busy;
  final bool incoming;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    return _VariantRowBackground(
      tokens: tokens,
      active: incoming,
      child: Row(
        spacing: 8,
        children: [
          PlayerProfilePortraitImage(
            tokens: tokens,
            asset: request.portraitAsset ?? defaultProfilePortraitAsset,
            size: 42,
            selected: incoming,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  request.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: incoming
                        ? tokens.colors.onAccent
                        : tokens.colors.cardInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  _profileRatingSummary(language, request.stats),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color:
                        (incoming
                                ? tokens.colors.onAccent
                                : tokens.colors.cardInk)
                            .withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (incoming) ...[
            _ComradeIconButton(
              tokens: tokens,
              iconAsset: 'ios_resources/Icons/icon-check.png',
              label: language.t(KolkhozText.kolkhozappAccept),
              onPressed: busy ? null : onAccept,
            ),
            _ComradeIconButton(
              tokens: tokens,
              iconAsset: 'ios_resources/Icons/icon-warning.png',
              label: language.t(KolkhozText.kolkhozappDecline),
              onPressed: busy ? null : onDecline,
            ),
          ] else
            Image.asset(
              'ios_resources/Icons/icon-status-connecting.png',
              width: 30,
              height: 30,
              filterQuality: FilterQuality.none,
            ),
        ],
      ),
    );
  }
}

class _ComradeIconButton extends StatelessWidget {
  const _ComradeIconButton({
    required this.tokens,
    required this.iconAsset,
    required this.label,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final String iconAsset;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 36,
        height: 32,
        child: ChromeAssetButton.command(
          label: '',
          prominent: false,
          tokens: tokens,
          iconAsset: iconAsset,
          iconSize: 22,
          expandLabel: false,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _ComradeRow extends StatelessWidget {
  const _ComradeRow({
    required this.tokens,
    required this.language,
    required this.comrade,
    required this.busy,
    required this.onRemove,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineComradeProfile comrade;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final status = _comradePresenceSummary(language, comrade);
    final statusColor = (comrade.isOnline || comrade.inGame || comrade.inLobby)
        ? tokens.colors.green
        : tokens.colors.cardInk.withValues(alpha: 0.62);
    return _VariantRowBackground(
      tokens: tokens,
      active: false,
      child: Row(
        spacing: 8,
        children: [
          PlayerProfilePortraitImage(
            tokens: tokens,
            asset: comrade.portraitAsset ?? defaultProfilePortraitAsset,
            size: 42,
            selected: false,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  comrade.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.cardInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  '$status / ${_profileRatingSummary(language, comrade.stats)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            height: 32,
            child: ChromeAssetButton.command(
              label: language.t(KolkhozText.kolkhozappRemove),
              prominent: false,
              tokens: tokens,
              iconAsset: 'ios_resources/Icons/icon-warning.png',
              onPressed: busy ? null : onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

String _comradePresenceSummary(
  KolkhozLanguage language,
  OnlineComradeProfile comrade,
) {
  if (comrade.inGame) {
    return language.t(KolkhozText.kolkhozappInGame);
  }
  if (comrade.inLobby) {
    return language.t(KolkhozText.kolkhozappInLobby);
  }
  if (comrade.isOnline) {
    return language.t(KolkhozText.kolkhozappOnline);
  }
  return language.t(KolkhozText.kolkhozappOfflineStatus);
}

String _profileRatingSummary(
  KolkhozLanguage language,
  KolkhozProfileStats stats,
) {
  return '${language.t(KolkhozText.kolkhozappRanked)} ${stats.rating}  '
      '${language.t(KolkhozText.kolkhozappCasual)} ${stats.casualRating}';
}

class _ComradeCodeDisplayBox extends StatelessWidget {
  const _ComradeCodeDisplayBox({
    required this.tokens,
    required this.code,
    required this.height,
  });

  final DesignTokens tokens;
  final String code;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _comradeFooterBoxDecoration(tokens),
      child: SelectableText(
        code,
        maxLines: 1,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cardInk,
          fontSize: 23,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _ComradeCodeTextField extends StatelessWidget {
  const _ComradeCodeTextField({
    required this.tokens,
    required this.controller,
    required this.hint,
    required this.height,
  });

  final DesignTokens tokens;
  final TextEditingController controller;
  final String hint;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: _comradeFooterBoxDecoration(tokens),
      child: TextField(
        controller: controller,
        maxLength: 12,
        minLines: 1,
        maxLines: 1,
        textAlignVertical: TextAlignVertical.center,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cardInk,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
        cursorColor: tokens.colors.redDark,
        decoration: InputDecoration(
          hintText: hint.toUpperCase(),
          counterText: '',
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          hintStyle: kolkhozFontStyle.copyWith(
            color: tokens.colors.cardInk.withValues(alpha: 0.44),
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

BoxDecoration _comradeFooterBoxDecoration(DesignTokens tokens) {
  return BoxDecoration(
    color: tokens.colors.cardFill.withValues(alpha: 0.74),
    borderRadius: BorderRadius.circular(5),
    border: Border.all(
      color: tokens.colors.gold.withValues(alpha: 0.56),
      width: 1,
    ),
  );
}

class _ProfilePreview extends StatelessWidget {
  const _ProfilePreview({
    required this.tokens,
    required this.controller,
    required this.portraitAsset,
    required this.onPortraitPressed,
  });

  final DesignTokens tokens;
  final TextEditingController controller;
  final String portraitAsset;
  final VoidCallback? onPortraitPressed;

  @override
  Widget build(BuildContext context) {
    return PlayerProfilePanel(
      tokens: tokens,
      displayName: controller.text.trim().isEmpty
          ? defaultProfileDisplayName
          : controller.text.trim(),
      portraitAsset: portraitAsset,
      active: true,
      portraitSelected: true,
      portraitSize: 74,
      minHeight: 94,
      padding: const EdgeInsets.all(10),
      onPortraitPressed: onPortraitPressed,
      portraitSemanticsLabel: portraitAsset,
      title: TextField(
        controller: controller,
        maxLength: 24,
        minLines: 1,
        maxLines: 1,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cream,
          fontSize: 28,
          height: 1.0,
          fontWeight: FontWeight.w700,
        ),
        cursorColor: tokens.colors.goldBright,
        decoration: InputDecoration(
          counterText: '',
          hintText: defaultProfileDisplayName,
          hintStyle: kolkhozFontStyle.copyWith(
            color: tokens.colors.creamDim.withValues(alpha: 0.74),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.tokens,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.maxLength = 24,
    this.onChanged,
  });

  final DesignTokens tokens;
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final int maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.34)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        maxLength: maxLength,
        onChanged: onChanged,
        minLines: 1,
        maxLines: 1,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cream,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          labelStyle: kolkhozFontStyle.copyWith(
            color: tokens.colors.creamDim.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}

class _ProfilePortraitChoice extends StatelessWidget {
  const _ProfilePortraitChoice({
    required this.tokens,
    required this.asset,
    required this.selected,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final String asset;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Semantics(
        button: true,
        selected: selected,
        label: asset,
        child: PlayerProfilePortraitImage(
          tokens: tokens,
          asset: asset,
          size: 58,
          selected: selected,
        ),
      ),
    );
  }
}

class _RuleBlock extends StatelessWidget {
  const _RuleBlock({
    required this.tokens,
    required this.title,
    required this.body,
  });

  final DesignTokens tokens;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 98),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(
            title.toUpperCase(),
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.gold,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            body,
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.creamDim,
              fontSize: 15,
              height: 1.12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldDivider extends StatelessWidget {
  const _GoldDivider({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: tokens.colors.gold.withValues(alpha: 0.35),
    );
  }
}

class _AssetIcon extends StatelessWidget {
  const _AssetIcon(this.asset, {this.size = 18, this.opacity = 1});

  final String asset;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        filterQuality: FilterQuality.none,
      ),
    );
  }
}

class _VariantIcon extends StatelessWidget {
  const _VariantIcon(this.asset, {required this.size, this.opacity = 1});

  final String asset;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final source = _variantIconSourceRect(asset);
    if (source == null) {
      return _AssetIcon(asset, size: size, opacity: opacity);
    }
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<ui.Image>(
          future: _LobbyImageCache.load(context, asset),
          builder: (context, snapshot) {
            final image = snapshot.data;
            if (image == null) {
              return _AssetIcon(asset, size: size);
            }
            return CustomPaint(
              painter: _CroppedAssetIconPainter(image: image, source: source),
            );
          },
        ),
      ),
    );
  }
}

class _LobbyImageCache {
  static final Map<String, Future<ui.Image>> _images = {};

  static Future<ui.Image> load(BuildContext context, String asset) {
    return _images.putIfAbsent(asset, () async {
      final bytes = await DefaultAssetBundle.of(context).load(asset);
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    });
  }
}

class _CroppedAssetIconPainter extends CustomPainter {
  const _CroppedAssetIconPainter({required this.image, required this.source});

  final ui.Image image;
  final Rect source;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || source.isEmpty) {
      return;
    }
    final scale = math.min(
      size.width / source.width,
      size.height / source.height,
    );
    final width = source.width * scale;
    final height = source.height * scale;
    final destination = Rect.fromLTWH(
      (size.width - width) / 2,
      (size.height - height) / 2,
      width,
      height,
    );
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    canvas.drawImageRect(image, source, destination, paint);
  }

  @override
  bool shouldRepaint(covariant _CroppedAssetIconPainter oldDelegate) {
    return image != oldDelegate.image || source != oldDelegate.source;
  }
}

Rect? _variantIconSourceRect(String asset) {
  return switch (asset) {
    'ios_resources/Icons/icon-variant-accumulation.png' => const Rect.fromLTRB(
      70,
      28,
      330,
      301,
    ),
    'ios_resources/Icons/icon-variant-hero.png' => const Rect.fromLTRB(
      127,
      31,
      345,
      289,
    ),
    'ios_resources/Icons/icon-variant-medals.png' => const Rect.fromLTRB(
      72,
      67,
      259,
      341,
    ),
    'ios_resources/Icons/icon-variant-mice.png' => const Rect.fromLTRB(
      95,
      98,
      387,
      329,
    ),
    'ios_resources/Icons/icon-variant-nomenclature.png' => const Rect.fromLTRB(
      124,
      131,
      352,
      377,
    ),
    'ios_resources/Icons/icon-variant-northern-style.png' =>
      const Rect.fromLTRB(42, 121, 299, 389),
    'ios_resources/Icons/icon-variant-order-to-boss.png' => const Rect.fromLTRB(
      55,
      101,
      323,
      318,
    ),
    'ios_resources/Icons/icon-variant-saboteur.png' => const Rect.fromLTRB(
      44,
      33,
      273,
      297,
    ),
    'ios_resources/Icons/icon-variant-swap.png' => const Rect.fromLTRB(
      63,
      134,
      338,
      386,
    ),
    _ => null,
  };
}

class _VariantRowData {
  _VariantRowData({
    this.titleKey,
    this.descriptionKey,
    this.iconAsset,
    this.titleFor,
    this.descriptionFor,
    this.iconAssetForVariants,
    required this.valueOf,
    required this.withValue,
    this.visibleInCustom = _alwaysVisible,
  });

  final KolkhozText? titleKey;
  final KolkhozText? descriptionKey;
  final String? iconAsset;
  final String Function(KolkhozGameVariants variants, KolkhozLanguage language)?
  titleFor;
  final String Function(KolkhozGameVariants variants, KolkhozLanguage language)?
  descriptionFor;
  final String Function(KolkhozGameVariants variants)? iconAssetForVariants;
  final bool Function(KolkhozGameVariants variants) valueOf;
  final KolkhozGameVariants Function(KolkhozGameVariants variants, bool value)
  withValue;
  final bool Function(KolkhozGameVariants variants) visibleInCustom;

  static final deckType = _VariantRowData(
    titleFor: (variants, language) => language.t(
      KolkhozText.variantValue1CardDeck,
      {'value1': variants.deckType},
    ),
    descriptionFor: (variants, language) => '',
    iconAssetForVariants: (variants) =>
        'ios_resources/Icons/icon-variant-deck-${variants.deckType}.png',
    valueOf: (variants) => true,
    withValue: (variants, value) => variants,
  );
  static final maxYears = _VariantRowData(
    titleFor: (variants, language) => language.t(
      KolkhozText.variantValue1YearPlan,
      {'value1': variants.maxYears},
    ),
    descriptionFor: (variants, language) => '',
    iconAssetForVariants: (variants) {
      final yearIcon = variants.maxYears.clamp(1, 5).toInt();
      return 'ios_resources/Icons/icon-year-$yearIcon.png';
    },
    valueOf: (variants) => true,
    withValue: (variants, value) => variants,
  );
  static final nomenclature = _VariantRowData(
    titleKey: KolkhozText.variantNomenklaturaTitle,
    descriptionKey: KolkhozText.variantNomenklaturaDescription,
    iconAsset: 'ios_resources/Icons/icon-variant-nomenclature.png',
    valueOf: (variants) => variants.nomenclature,
    withValue: (variants, value) => variants.copyWith(nomenclature: value),
  );
  static final allowSwap = _VariantRowData(
    titleKey: KolkhozText.variantSwapTitle,
    descriptionKey: KolkhozText.variantSwapDescription,
    iconAsset: 'ios_resources/Icons/icon-variant-swap.png',
    valueOf: (variants) => variants.allowSwap,
    withValue: (variants, value) => variants.copyWith(allowSwap: value),
  );
  static final northernStyle = _VariantRowData(
    titleKey: KolkhozText.variantNorthernStyleTitle,
    descriptionKey: KolkhozText.variantNorthernStyleDescription,
    iconAsset: 'ios_resources/Icons/icon-variant-northern-style.png',
    valueOf: (variants) => variants.northernStyle,
    withValue: (variants, value) => variants.copyWith(northernStyle: value),
  );
  static final miceVariant = _VariantRowData(
    titleKey: KolkhozText.variantMiceTitle,
    descriptionKey: KolkhozText.variantMiceDescription,
    iconAsset: 'ios_resources/Icons/icon-variant-mice.png',
    valueOf: (variants) => variants.miceVariant,
    withValue: (variants, value) => variants.copyWith(miceVariant: value),
  );
  static final ordenNachalniku = _VariantRowData(
    titleKey: KolkhozText.variantOrdenNachalnikuTitle,
    descriptionKey: KolkhozText.variantOrdenNachalnikuDescription,
    iconAsset: 'ios_resources/Icons/icon-variant-order-to-boss.png',
    valueOf: (variants) => variants.ordenNachalniku,
    withValue: (variants, value) => variants.copyWith(ordenNachalniku: value),
    visibleInCustom: (variants) => variants.deckType == 36,
  );
  static final medalsCount = _VariantRowData(
    titleKey: KolkhozText.variantMedalsTitle,
    descriptionKey: KolkhozText.variantMedalsDescription,
    iconAsset: 'ios_resources/Icons/icon-variant-medals.png',
    valueOf: (variants) => variants.medalsCount,
    withValue: (variants, value) => variants.copyWith(medalsCount: value),
  );
  static final heroOfSovietUnion = _VariantRowData(
    titleKey: KolkhozText.variantHeroTitle,
    descriptionKey: KolkhozText.variantHeroDescription,
    iconAsset: 'ios_resources/Icons/icon-variant-hero.png',
    valueOf: (variants) => variants.heroOfSovietUnion,
    withValue: (variants, value) => variants.copyWith(heroOfSovietUnion: value),
  );
  static final accumulateJobs = _VariantRowData(
    titleKey: KolkhozText.variantAccumulationTitle,
    descriptionKey: KolkhozText.variantAccumulationDescription,
    iconAsset: 'ios_resources/Icons/icon-variant-accumulation.png',
    valueOf: (variants) => variants.accumulateJobs,
    withValue: (variants, value) => variants.copyWith(accumulateJobs: value),
    visibleInCustom: (variants) => variants.deckType != 36,
  );
  static final wrecker = _VariantRowData(
    titleKey: KolkhozText.variantWreckerTitle,
    descriptionKey: KolkhozText.variantWreckerDescription,
    iconAsset: 'ios_resources/Icons/icon-variant-saboteur.png',
    valueOf: (variants) => variants.wreckerCard,
    withValue: (variants, value) => variants.copyWith(wreckerCard: value),
  );
  static final demoMode = _VariantRowData(
    titleKey: KolkhozText.variantDemoModeTitle,
    descriptionKey: KolkhozText.variantDemoModeDescription,
    iconAsset: 'ios_resources/Icons/icon-year-2.png',
    valueOf: (variants) => false,
    withValue: (variants, value) => variants,
    visibleInCustom: (variants) => false,
  );

  static final all = [
    nomenclature,
    allowSwap,
    northernStyle,
    miceVariant,
    ordenNachalniku,
    medalsCount,
    heroOfSovietUnion,
    accumulateJobs,
    wrecker,
  ];

  static List<_VariantRowData> enabledRows(
    KolkhozGameVariants variants, {
    bool demoMode = false,
  }) => [
    if (demoMode) _VariantRowData.demoMode,
    for (final row in all)
      if (row.valueOf(variants)) row,
  ];

  static List<_VariantRowData> summaryRows(
    KolkhozGameVariants variants, {
    bool demoMode = false,
  }) => [deckType, maxYears, ...enabledRows(variants, demoMode: demoMode)];

  static List<_VariantRowData> configurableRows(KolkhozGameVariants variants) =>
      [
        deckType,
        maxYears,
        for (final row in all)
          if (row.visibleInCustom(variants)) row,
      ];

  String localizedTitle(
    KolkhozLanguage language,
    KolkhozGameVariants variants,
  ) {
    final builder = titleFor;
    if (builder != null) {
      return builder(variants, language);
    }
    return language.t(titleKey!);
  }

  String localizedDescription(
    KolkhozLanguage language,
    KolkhozGameVariants variants,
  ) {
    final builder = descriptionFor;
    if (builder != null) {
      return builder(variants, language);
    }
    return language.t(descriptionKey!);
  }

  String iconAssetFor(KolkhozGameVariants variants) {
    final builder = iconAssetForVariants;
    if (builder != null) {
      return builder(variants);
    }
    return iconAsset!;
  }
}

bool _alwaysVisible(KolkhozGameVariants variants) => true;

extension _ControllerLobbyLabels on KolkhozPlayerController {
  String shortTitle(KolkhozLanguage language) {
    return switch (this) {
      KolkhozPlayerController.human => language.t(KolkhozText.kolkhozappHuman),
      KolkhozPlayerController.heuristicAI => language.t(
        KolkhozText.kolkhozappEasy,
      ),
      KolkhozPlayerController.mediumAI => language.t(
        KolkhozText.kolkhozappMedium,
      ),
      KolkhozPlayerController.neuralAI => language.t(
        KolkhozText.kolkhozappHard,
      ),
    };
  }
}

String presetTitle(KolkhozGamePreset preset, KolkhozLanguage language) {
  return switch (preset) {
    KolkhozGamePreset.kolkhoz => language.t(KolkhozText.presetKolkhoz),
    KolkhozGamePreset.littleKolkhoz => language.t(
      KolkhozText.presetLittleKolkhoz,
    ),
    KolkhozGamePreset.campStyle => language.t(KolkhozText.presetCampStyle),
    KolkhozGamePreset.custom => language.t(KolkhozText.presetCustom),
  };
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
