import 'dart:async';
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
import 'render_model.dart';
import 'rule_content.dart';
import 'supabase_config.dart';
import 'tutorial_display.dart';

Future<bool> showGameControlConfirmation({
  required BuildContext context,
  required KolkhozLanguage language,
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(language.t(KolkhozText.kolkhozappCancel)),
          ),
          TextButton(
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

class _KolkhozAppState extends State<KolkhozApp> {
  static const foremanHintDuration = Duration(seconds: 3);

  final navigatorKey = GlobalKey<NavigatorState>();
  late final LiveGameStore store;
  late final KolkhozAppSettingsStore settingsStore;
  StreamSubscription<AuthState>? supabaseAuthSubscription;
  Timer? cloudProfileSyncTimer;
  KolkhozAppSettings settings = const KolkhozAppSettings();
  bool cloudAuthBusy = false;
  String? cloudAuthMessage;
  bool cloudAuthIsError = false;
  bool cloudProfileBusy = false;
  bool comradesSummaryBusy = false;
  OnlineComradesResponse comradesSummary = const OnlineComradesResponse();
  String? recordedGameStatsKey;
  bool showingLobby = true;
  bool showingRules = false;
  bool showingOnline = false;
  bool showingProfile = false;
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
    settingsStore = KolkhozAppSettingsStore.defaultStore();
    settings = settingsStore.load();
    store = LiveGameStore(onlineAccessTokenProvider: supabaseAccessToken);
    store.addListener(handleStoreChanged);
    playerControllers = List.of(store.controllers);
    KolkhozSupabaseRuntime.instance.addListener(handleSupabaseRuntimeChanged);
    KolkhozSupabaseRuntime.instance.start();
    attachSupabaseAuthSubscription();
  }

  @override
  void dispose() {
    foremanHintTimer?.cancel();
    cloudProfileSyncTimer?.cancel();
    supabaseAuthSubscription?.cancel();
    store.removeListener(handleStoreChanged);
    KolkhozSupabaseRuntime.instance.removeListener(
      handleSupabaseRuntimeChanged,
    );
    store.dispose();
    super.dispose();
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
          final tokens = appearance.tokens;
          late final Widget content;
          if (store.error != null && store.model == null) {
            content = StandaloneErrorView(error: store.error!, tokens: tokens);
          } else if (store.model == null || showingLobby) {
            content = StandaloneLobby(
              tokens: tokens,
              language: language,
              appearance: appearance,
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
              hostedInviteCode: store.onlineInviteCode,
              displayName: settings.displayName,
              portraitAsset: settings.portraitAsset,
              profileStats: settings.profileStats,
              comradesSummary: comradesSummary,
              cloudConfigured: KolkhozSupabaseRuntime.instance.isConfigured,
              cloudReady: KolkhozSupabaseRuntime.instance.isReady,
              cloudSignedIn: supabaseCurrentUser != null,
              cloudEmail: supabaseCurrentUser?.email,
              cloudAuthBusy: cloudAuthBusy || cloudProfileBusy,
              cloudAuthMessage: cloudAuthMessage,
              cloudAuthIsError: cloudAuthIsError,
              onHostOnline: hostOnlineGame,
              onJoinOnline: joinOnlineGame,
              onEnterOnlineGame: enterOnlineGame,
              onStart: () {
                store.newGame(
                  variants: activeVariants,
                  controllers: activePlayerControllers,
                );
                setState(() => showingLobby = false);
              },
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
                });
              },
              onDisplayNameChanged: setDisplayName,
              onPortraitChanged: setPortraitAsset,
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
                  onAction: applyBoardAction,
                  onPanelSelected: store.setActivePanel,
                  onLanguageToggle: toggleLanguage,
                  onAppearanceToggle: toggleAppearance,
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
                child: content,
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
    if (showingLobby &&
        showingOnline &&
        store.isOnlineGame &&
        !store.onlineWaitingForPlayers) {
      setState(() => showingLobby = false);
    }
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

  void showFollowSuitHint() {
    if (!settings.showInvalidTapHints) {
      return;
    }
    foremanHintTimer?.cancel();
    setState(() {
      foremanHint = settings.language.t(
        KolkhozText.kolkhozappRememberYouMustFollowSuitIfAble,
      );
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
    );
    setState(() {
      showingRules = false;
      showingOnline = true;
      showingProfile = false;
      showingLobby = !enterImmediately;
    });
    return sessionID;
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
      showingLobby = false;
    });
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
    required this.onJoinOnline,
    required this.onEnterOnlineGame,
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
    this.showingProfile = false,
    this.hostedInviteCode,
    this.displayName = defaultProfileDisplayName,
    this.portraitAsset = defaultProfilePortraitAsset,
    this.profileStats = defaultProfileStats,
    this.comradesSummary = const OnlineComradesResponse(),
    this.cloudConfigured = false,
    this.cloudReady = false,
    this.cloudSignedIn = false,
    this.cloudEmail,
    this.cloudAuthBusy = false,
    this.cloudAuthMessage,
    this.cloudAuthIsError = false,
    this.onProfilePressed,
    this.onDisplayNameChanged,
    this.onPortraitChanged,
    this.onCloudSignIn,
    this.onCloudSignUp,
    this.onCloudResetPassword,
    this.onCloudSignOut,
    this.onComradesChanged,
    this.onComradeRequestToUser,
    this.error,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
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
  final String? hostedInviteCode;
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
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
    bool ranked,
  )
  onHostOnline;
  final Future<void> Function(
    Uri baseURL,
    String inviteCode,
    int? preferredPlayerID,
  )
  onJoinOnline;
  final VoidCallback onEnterOnlineGame;
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
  final VoidCallback? onProfilePressed;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onPortraitChanged;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final Future<void> Function()? onCloudSignOut;
  final ValueChanged<OnlineComradesResponse>? onComradesChanged;
  final Future<void> Function(String userID)? onComradeRequestToUser;
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
                  compactRail: compactRail,
                  animationSpeed: animationSpeed,
                  confirmNewGame: confirmNewGame,
                  confirmMainMenu: confirmMainMenu,
                  showInvalidTapHints: showInvalidTapHints,
                  showingRules: showingRules,
                  showingOnline: showingOnline,
                  showingProfile: showingProfile,
                  hostedInviteCode: hostedInviteCode,
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
                  onTutorialPressed: onTutorialPressed,
                  onStart: onStart,
                  onHostOnline: onHostOnline,
                  onJoinOnline: onJoinOnline,
                  onPresetChanged: onPresetChanged,
                  onCustomVariantsChanged: onCustomVariantsChanged,
                  onPlayerControllersChanged: onPlayerControllersChanged,
                  onAnimationSpeedChanged: onAnimationSpeedChanged,
                  onConfirmNewGameChanged: onConfirmNewGameChanged,
                  onConfirmMainMenuChanged: onConfirmMainMenuChanged,
                  onShowInvalidTapHintsChanged: onShowInvalidTapHintsChanged,
                  onLanguageToggle: onLanguageToggle,
                  onAppearanceToggle: onAppearanceToggle,
                  onDisplayNameChanged: onDisplayNameChanged,
                  onPortraitChanged: onPortraitChanged,
                  onCloudSignIn: onCloudSignIn,
                  onCloudSignUp: onCloudSignUp,
                  onCloudResetPassword: onCloudResetPassword,
                  onCloudSignOut: onCloudSignOut,
                  onComradesChanged: onComradesChanged,
                  onComradeRequestToUser: onComradeRequestToUser,
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
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: wide ? contentWidth : panelWidth,
                          child: StandaloneErrorBanner(
                            error: error!,
                            tokens: tokens,
                          ),
                        ),
                      ],
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
  final VoidCallback onRulesPressed;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = compact
            ? (constraints.maxWidth * 0.54).clamp(58.0, 72.0)
            : (constraints.maxWidth * 0.50).clamp(92.0, 176.0);
        return Column(
          spacing: compact ? 7 : 10,
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
            const Spacer(),
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
                onPressed: onProfilePressed,
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
                        color: tokens.colors.cream,
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
    required this.compactRail,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.confirmNewGame = true,
    this.confirmMainMenu = true,
    this.showInvalidTapHints = true,
    required this.showingRules,
    required this.showingOnline,
    required this.showingProfile,
    required this.hostedInviteCode,
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
    required this.onTutorialPressed,
    required this.onStart,
    required this.onHostOnline,
    required this.onJoinOnline,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
    this.onAnimationSpeedChanged,
    this.onConfirmNewGameChanged,
    this.onConfirmMainMenuChanged,
    this.onShowInvalidTapHintsChanged,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
    required this.onDisplayNameChanged,
    required this.onPortraitChanged,
    required this.onCloudSignIn,
    required this.onCloudSignUp,
    required this.onCloudResetPassword,
    required this.onCloudSignOut,
    required this.onComradesChanged,
    required this.onComradeRequestToUser,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final bool demoMode;
  final KolkhozGameVariants variants;
  final KolkhozAppearance appearance;
  final bool compactRail;
  final GameAnimationSpeed animationSpeed;
  final bool confirmNewGame;
  final bool confirmMainMenu;
  final bool showInvalidTapHints;
  final bool showingRules;
  final bool showingOnline;
  final bool showingProfile;
  final String? hostedInviteCode;
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
  final VoidCallback onTutorialPressed;
  final VoidCallback onStart;
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
    bool ranked,
  )
  onHostOnline;
  final Future<void> Function(
    Uri baseURL,
    String inviteCode,
    int? preferredPlayerID,
  )
  onJoinOnline;
  final ValueChanged<KolkhozGamePreset> onPresetChanged;
  final ValueChanged<KolkhozGameVariants> onCustomVariantsChanged;
  final ValueChanged<List<KolkhozPlayerController>> onPlayerControllersChanged;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onPortraitChanged;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final Future<void> Function()? onCloudSignOut;
  final ValueChanged<OnlineComradesResponse>? onComradesChanged;
  final Future<void> Function(String userID)? onComradeRequestToUser;

  @override
  Widget build(BuildContext context) {
    return _PanelSurface(
      tokens: tokens,
      child: showingProfile
          ? _SettingsPanel(
              tokens: tokens,
              language: language,
              appearance: appearance,
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
              onStart: onStart,
              onTutorialPressed: onTutorialPressed,
              onAnimationSpeedChanged: onAnimationSpeedChanged,
              onConfirmNewGameChanged: onConfirmNewGameChanged,
              onConfirmMainMenuChanged: onConfirmMainMenuChanged,
              onShowInvalidTapHintsChanged: onShowInvalidTapHintsChanged,
              onLanguageToggle: onLanguageToggle,
              onAppearanceToggle: onAppearanceToggle,
              onDisplayNameChanged: onDisplayNameChanged,
              onPortraitChanged: onPortraitChanged,
              onCloudSignIn: onCloudSignIn,
              onCloudSignUp: onCloudSignUp,
              onCloudResetPassword: onCloudResetPassword,
              onCloudSignOut: onCloudSignOut,
              onComradesChanged: onComradesChanged,
            )
          : showingOnline
          ? _OnlinePanel(
              tokens: tokens,
              language: language,
              hostedInviteCode: hostedInviteCode,
              onJoinOnline: onJoinOnline,
              comradesSummary: comradesSummary,
              onComradesChanged: onComradesChanged,
              onComradeRequestToUser: onComradeRequestToUser,
            )
          : showingRules
          ? _RulesPanel(
              tokens: tokens,
              language: language,
              onTutorialPressed: onTutorialPressed,
            )
          : _VariantPanel(
              tokens: tokens,
              language: language,
              selectedPreset: selectedPreset,
              customVariants: customVariants,
              playerControllers: playerControllers,
              demoMode: demoMode,
              variants: variants,
              compactRail: compactRail,
              onStart: onStart,
              onHostOnline: onHostOnline,
              onPresetChanged: onPresetChanged,
              onCustomVariantsChanged: onCustomVariantsChanged,
              onPlayerControllersChanged: onPlayerControllersChanged,
            ),
    );
  }
}

class _PanelSurface extends StatelessWidget {
  const _PanelSurface({required this.tokens, required this.child});

  final DesignTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
      child: child,
    );
  }
}

enum _SettingsTab {
  profile,
  comrades,
  assist,
  display,
  rules;

  String title(KolkhozLanguage language) {
    return switch (this) {
      _SettingsTab.profile => language.t(KolkhozText.kolkhozappProfile),
      _SettingsTab.comrades => language.t(KolkhozText.kolkhozappComrades),
      _SettingsTab.assist => OptionsMenuTab.assist.title(language),
      _SettingsTab.display => OptionsMenuTab.display.title(language),
      _SettingsTab.rules => OptionsMenuTab.rules.title(language),
    };
  }

  String get iconAsset {
    return switch (this) {
      _SettingsTab.profile => 'ios_resources/Icons/icon-profile.png',
      _SettingsTab.comrades => 'ios_resources/Icons/icon-friends-list.png',
      _SettingsTab.assist => OptionsMenuTab.assist.iconAsset,
      _SettingsTab.display => OptionsMenuTab.display.iconAsset,
      _SettingsTab.rules => OptionsMenuTab.rules.iconAsset,
    };
  }
}

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({
    required this.tokens,
    required this.language,
    required this.appearance,
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
    required this.onStart,
    required this.onTutorialPressed,
    required this.onAnimationSpeedChanged,
    required this.onConfirmNewGameChanged,
    required this.onConfirmMainMenuChanged,
    required this.onShowInvalidTapHintsChanged,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
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
  final VoidCallback onStart;
  final VoidCallback onTutorialPressed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;
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
  _SettingsTab selectedTab = _SettingsTab.profile;

  Widget _tabBody() {
    return switch (selectedTab) {
      _SettingsTab.profile => _ProfilePanel(
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
      _SettingsTab.comrades => _ComradesSettingsPanel(
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
      _SettingsTab.assist => SingleChildScrollView(
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
      _SettingsTab.display => SingleChildScrollView(
        child: OptionsDisplayControls(
          tokens: widget.tokens,
          language: widget.language,
          appearance: widget.appearance,
          animationSpeed: widget.animationSpeed,
          onAnimationSpeedChanged: widget.onAnimationSpeedChanged,
          onLanguageToggle: widget.onLanguageToggle,
          onAppearanceToggle: widget.onAppearanceToggle,
        ),
      ),
      _SettingsTab.rules => SingleChildScrollView(
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
                    spacing * (_SettingsTab.values.length - 1)) /
                _SettingsTab.values.length;
            final tabHeight = (tabWidth * 0.30).clamp(38.0, 52.0);
            return Row(
              spacing: spacing,
              children: [
                for (final tab in _SettingsTab.values)
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
    required this.compactRail,
    required this.onStart,
    required this.onHostOnline,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final bool demoMode;
  final KolkhozGameVariants variants;
  final bool compactRail;
  final VoidCallback onStart;
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
    bool ranked,
  )
  onHostOnline;
  final ValueChanged<KolkhozGamePreset> onPresetChanged;
  final ValueChanged<KolkhozGameVariants> onCustomVariantsChanged;
  final ValueChanged<List<KolkhozPlayerController>> onPlayerControllersChanged;

  @override
  State<_VariantPanel> createState() => _VariantPanelState();
}

class _VariantPanelState extends State<_VariantPanel> {
  late List<_LobbySeatChoice> seatChoices;
  bool startingOnline = false;
  bool rankedGame = true;
  String? onlineStatus;
  bool onlineStatusIsError = false;

  @override
  void initState() {
    super.initState();
    seatChoices = _LobbySeatChoice.fromControllers(widget.playerControllers);
  }

  @override
  void didUpdateWidget(covariant _VariantPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!seatChoices.contains(_LobbySeatChoice.online)) {
      seatChoices = _LobbySeatChoice.fromControllers(widget.playerControllers);
    }
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
      effectiveSeatChoices.contains(_LobbySeatChoice.online);

  void setSeatChoice(int playerID, _LobbySeatChoice choice) {
    final next = List<_LobbySeatChoice>.of(effectiveSeatChoices);
    next[playerID] = choice;
    final exclusive = _LobbySeatChoice.withExclusiveHumanMode(
      next,
      changedPlayerID: playerID,
    );
    setState(() {
      seatChoices = exclusive;
      onlineStatus = null;
      onlineStatusIsError = false;
    });
    widget.onPlayerControllersChanged(
      _LobbySeatChoice.toControllers(exclusive),
    );
  }

  Future<void> startGame() async {
    if (!hasOnlineSeats) {
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
    });
    try {
      await widget.onHostOnline(
        _onlineServerURL,
        effectiveControllers,
        false,
        rankedGame,
      );
    } catch (exception) {
      if (!mounted) {
        return;
      }
      setState(() {
        onlineStatus = exception is SocketException
            ? widget.language.t(
                KolkhozText
                    .kolkhozappCouldNotReachTheOnlineServerTryAgainInAMom,
              )
            : widget.language.t(
                KolkhozText.kolkhozappOnlineRequestFailedTryAgain,
              );
        onlineStatusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => startingOnline = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        if (onlineStatus != null)
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    if (widget.selectedPreset == KolkhozGamePreset.custom &&
                        !widget.demoMode)
                      _CustomVariantOptions(
                        tokens: widget.tokens,
                        language: widget.language,
                        variants: widget.customVariants,
                        compact: widget.compactRail,
                        onChanged: widget.onCustomVariantsChanged,
                      )
                    else
                      _PresetSummary(
                        tokens: widget.tokens,
                        language: widget.language,
                        variants: widget.variants,
                        demoMode: widget.demoMode,
                        compact: widget.compactRail,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final showsRankedToggle = hasOnlineSeats && !widget.demoMode;
            final inlineCompactControls =
                widget.compactRail &&
                constraints.maxWidth >= (showsRankedToggle ? 570.0 : 410.0);
            final compactWidth = showsRankedToggle
                ? 620.0
                : widget.compactRail
                ? 500.0
                : 540.0;
            final compact =
                !inlineCompactControls && constraints.maxWidth < compactWidth;
            final controlHeight = widget.compactRail ? 50.0 : 56.0;
            final seats = _SeatQuickControls(
              tokens: widget.tokens,
              language: widget.language,
              choices: effectiveSeatChoices,
              onChanged: widget.demoMode ? null : setSeatChoice,
              compact: widget.compactRail,
            );
            final rankedToggle = showsRankedToggle
                ? _RankedGameToggle(
                    tokens: widget.tokens,
                    language: widget.language,
                    ranked: rankedGame,
                    onChanged: (value) => setState(() => rankedGame = value),
                  )
                : null;
            Widget startButton({double? width}) {
              return SizedBox(
                width: width,
                height: controlHeight,
                child: ChromeAssetButton.command(
                  width: double.infinity,
                  padding: widget.compactRail
                      ? const EdgeInsets.symmetric(horizontal: 8)
                      : null,
                  label: startingOnline
                      ? widget.language.t(KolkhozText.kolkhozappWorking)
                      : widget.demoMode
                      ? widget.language.t(KolkhozText.kolkhozappStartDemo)
                      : hasOnlineSeats
                      ? widget.language.t(KolkhozText.kolkhozappStartOnlineGame)
                      : widget.language.t(
                          KolkhozText.kolkhozappStartOfflineGame,
                        ),
                  prominent: true,
                  tokens: widget.tokens,
                  onPressed: startingOnline ? null : startGame,
                  iconAsset: widget.demoMode
                      ? 'ios_resources/Icons/icon-demo.png'
                      : 'ios_resources/Icons/icon-create-game.png',
                  iconSize: widget.compactRail ? 22 : 28,
                  textSize: widget.compactRail
                      ? PixelTextSize.headline
                      : PixelTextSize.title,
                  expandLabel: false,
                ),
              );
            }

            if (inlineCompactControls) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  seats,
                  if (rankedToggle != null) ...[
                    const SizedBox(width: 8),
                    rankedToggle,
                  ],
                  const SizedBox(width: 8),
                  Expanded(child: startButton()),
                ],
              );
            }
            final stackedStartButton = startButton(
              width: compact ? double.infinity : 220,
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Center(child: seats),
                  if (rankedToggle != null) Center(child: rankedToggle),
                  stackedStartButton,
                ],
              );
            }
            return Row(
              children: [
                seats,
                if (rankedToggle != null) ...[
                  const SizedBox(width: 10),
                  rankedToggle,
                ],
                const Spacer(),
                stackedStartButton,
              ],
            );
          },
        ),
      ],
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

class _SeatQuickControls extends StatelessWidget {
  const _SeatQuickControls({
    required this.tokens,
    required this.language,
    required this.choices,
    required this.onChanged,
    this.compact = false,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<_LobbySeatChoice> choices;
  final void Function(int playerID, _LobbySeatChoice choice)? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final normalized = _LobbySeatChoice.normalized(choices);
    return Row(
      spacing: 8,
      children: [
        for (var playerID = 0; playerID < kolkhozPlayerCount; playerID += 1)
          _SeatQuickButton(
            tokens: tokens,
            language: language,
            playerID: playerID,
            choice: normalized[playerID],
            options: _LobbySeatChoice.optionsForPlayer(playerID, normalized),
            compact: compact,
            onChanged: onChanged == null || playerID == 0
                ? null
                : (choice) => onChanged!(playerID, choice),
          ),
      ],
    );
  }
}

class _RankedGameToggle extends StatelessWidget {
  const _RankedGameToggle({
    required this.tokens,
    required this.language,
    required this.ranked,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool ranked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = ranked
        ? language.t(KolkhozText.kolkhozappRanked)
        : language.t(KolkhozText.kolkhozappCasual);
    return Semantics(
      button: true,
      toggled: ranked,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!ranked),
            child: SizedBox(
              width: 138,
              height: 62,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ChromeButtonBackground(
                      asset: ranked
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
                          ranked
                              ? 'ios_resources/Icons/icon-medal-star.png'
                              : 'ios_resources/Icons/icon-human-seat.png',
                          size: 30,
                          opacity: ranked ? 1 : 0.82,
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
                                  language.t(KolkhozText.kolkhozappGameType),
                                  color: ranked
                                      ? tokens.colors.onAccent.withValues(
                                          alpha: 0.7,
                                        )
                                      : tokens.colors.cardInk.withValues(
                                          alpha: 0.66,
                                        ),
                                  size: PixelTextSize.caption2,
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
                                height: 18,
                                child: ChromeScaledLabel(
                                  label,
                                  color: ranked
                                      ? tokens.colors.onAccent
                                      : tokens.colors.cardInk,
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
    );
  }
}

class _SeatQuickButton extends StatelessWidget {
  const _SeatQuickButton({
    required this.tokens,
    required this.language,
    required this.playerID,
    required this.choice,
    required this.options,
    required this.onChanged,
    this.compact = false,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final int playerID;
  final _LobbySeatChoice choice;
  final List<_LobbySeatChoice> options;
  final ValueChanged<_LobbySeatChoice>? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = choice.isHumanSeat;
    final label = language.t(KolkhozText.kolkhozappPValue1, {
      'value1': playerID + 1,
    });
    final occupantLabel = playerID == 0 && choice == _LobbySeatChoice.local
        ? language.t(KolkhozText.tabledisplayYou)
        : choice.shortTitle(language);
    return Semantics(
      button: true,
      label: '$label $occupantLabel',
      child: ExcludeSemantics(
        child: Tooltip(
          message: '$label $occupantLabel',
          child: PopupMenuButton<_LobbySeatChoice>(
            tooltip: '$label $occupantLabel',
            enabled: onChanged != null,
            offset: const Offset(0, -158),
            color: tokens.colors.panel,
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            onSelected: onChanged,
            itemBuilder: (context) => [
              for (final option in options)
                PopupMenuItem(
                  value: option,
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
                              : tokens.colors.creamDim,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: SizedBox(
              width: compact ? 52 : 66,
              height: compact ? 50 : 62,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ChromeButtonBackground(
                      asset: active
                          ? chromeButtonPrimaryAsset
                          : chromeButtonSecondaryAsset,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(7, 6, 7, 7),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 2,
                      children: [
                        _AssetIcon(
                          choice.iconAsset,
                          size: compact ? 24 : 30,
                          opacity: active ? 1 : 0.82,
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: compact ? 12 : 15,
                          child: ChromeScaledLabel(
                            occupantLabel,
                            color: active
                                ? tokens.colors.onAccent
                                : tokens.colors.cardInk,
                            size: compact
                                ? PixelTextSize.xSmall
                                : PixelTextSize.caption2,
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
    );
  }
}

enum _LobbySeatChoice {
  local,
  online,
  easyAI,
  mediumAI,
  hardAI;

  static List<_LobbySeatChoice> fromControllers(
    List<KolkhozPlayerController> controllers,
  ) {
    final normalized = KolkhozPlayerController.normalized(controllers);
    return [for (final controller in normalized) fromController(controller)];
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
    if (normalized.first == _LobbySeatChoice.online) {
      normalized[0] = _LobbySeatChoice.local;
    }
    if (!normalized.any((choice) => choice == _LobbySeatChoice.local)) {
      normalized[0] = _LobbySeatChoice.local;
    }
    return normalized;
  }

  static List<_LobbySeatChoice> optionsForPlayer(
    int playerID,
    List<_LobbySeatChoice> choices,
  ) {
    if (playerID == 0) {
      return const [local];
    }
    final normalized = _LobbySeatChoice.normalized(choices);
    final otherSeats = [
      for (var index = 1; index < kolkhozPlayerCount; index += 1)
        if (index != playerID) normalized[index],
    ];
    final hotseatActive = otherSeats.contains(_LobbySeatChoice.local);
    final onlineActive = otherSeats.contains(_LobbySeatChoice.online);
    final humanOptions = onlineActive
        ? const [_LobbySeatChoice.online]
        : hotseatActive
        ? const [_LobbySeatChoice.local]
        : const [_LobbySeatChoice.local, _LobbySeatChoice.online];
    return humanOptions.followedBy(const [
      _LobbySeatChoice.easyAI,
      _LobbySeatChoice.mediumAI,
      _LobbySeatChoice.hardAI,
    ]).toList();
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
          (choice == _LobbySeatChoice.local &&
              chosenHumanMode == _LobbySeatChoice.online);
      if (incompatible) {
        normalized[index] = _LobbySeatChoice.hardAI;
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

  bool get isHumanSeat {
    return this == _LobbySeatChoice.local || this == _LobbySeatChoice.online;
  }

  KolkhozPlayerController get controller {
    return switch (this) {
      _LobbySeatChoice.local ||
      _LobbySeatChoice.online => KolkhozPlayerController.human,
      _LobbySeatChoice.easyAI => KolkhozPlayerController.heuristicAI,
      _LobbySeatChoice.mediumAI => KolkhozPlayerController.mediumAI,
      _LobbySeatChoice.hardAI => KolkhozPlayerController.neuralAI,
    };
  }

  String shortTitle(KolkhozLanguage language) {
    return switch (this) {
      _LobbySeatChoice.local => language.t(KolkhozText.kolkhozappHotseat),
      _LobbySeatChoice.online => language.t(KolkhozText.kolkhozappOnline),
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
      _LobbySeatChoice.local =>
        'ios_resources/Icons/icon-controller-hotseat-player.png',
      _LobbySeatChoice.online =>
        'ios_resources/Icons/icon-controller-online-player.png',
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
    final rows = _VariantRowData.enabledRows(
      widget.variants,
      demoMode: widget.demoMode,
    );
    if (selectedRowIndex >= rows.length) {
      selectedRowIndex = math.max(0, rows.length - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _VariantRowData.enabledRows(
      widget.variants,
      demoMode: widget.demoMode,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _variantInfoScale(constraints.maxWidth);
        final selectedRow = rows.isEmpty ? null : rows[selectedRowIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: widget.compact ? 8 : 10 + 6 * scale,
          children: [
            _DeckSummary(
              tokens: widget.tokens,
              language: widget.language,
              deckType: widget.variants.deckType,
              maxYears: widget.variants.maxYears,
              scale: widget.compact ? 0 : scale,
              compact: widget.compact,
            ),
            if (widget.compact && rows.isNotEmpty) ...[
              _VariantIconStrip(
                tokens: widget.tokens,
                language: widget.language,
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
                  row: selectedRow,
                  scale: 0,
                  compact: true,
                ),
            ] else
              for (final row in rows)
                _VariantReadOnlyRow(
                  tokens: widget.tokens,
                  language: widget.language,
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
        final deckButtonHeight = widget.compact ? 52.0 : 58 + 16 * scale;
        final deckIconSize = widget.compact
            ? (deckButtonHeight * 0.72).clamp(34.0, 40.0)
            : 32 + 12 * scale;
        final deckTextSize = widget.compact
            ? _buttonContentTextSize(deckButtonHeight)
            : scale > 0.38
            ? PixelTextSize.cardRank
            : PixelTextSize.title;
        final deckPadding = widget.compact ? 7.0 : 14 + 8 * scale;
        final deckSpacing = widget.compact ? 6.0 : 8.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: widget.compact ? 8 : 10 + 6 * scale,
          children: [
            Row(
              spacing: widget.compact ? 6 : 6 + 4 * scale,
              children: [
                Expanded(
                  child: _ImageTabButton(
                    tokens: widget.tokens,
                    label: widget.language.t(KolkhozText.variantDeck52Cards),
                    iconAsset: 'ios_resources/Icons/icon-variant-deck-52.png',
                    iconSize: deckIconSize,
                    selected: widget.variants.deckType == 52,
                    height: deckButtonHeight,
                    textSize: deckTextSize,
                    horizontalPadding: deckPadding,
                    contentSpacing: deckSpacing,
                    onPressed: () => widget.onChanged(
                      widget.variants.copyWith(
                        deckType: 52,
                        ordenNachalniku: false,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _ImageTabButton(
                    tokens: widget.tokens,
                    label: widget.language.t(KolkhozText.variantDeck36Cards),
                    iconAsset: 'ios_resources/Icons/icon-variant-deck-36.png',
                    iconSize: deckIconSize,
                    selected: widget.variants.deckType == 36,
                    height: deckButtonHeight,
                    textSize: deckTextSize,
                    horizontalPadding: deckPadding,
                    contentSpacing: deckSpacing,
                    onPressed: () => widget.onChanged(
                      widget.variants.copyWith(
                        deckType: 36,
                        accumulateJobs: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.compact && rows.isNotEmpty) ...[
              _VariantIconStrip(
                tokens: widget.tokens,
                language: widget.language,
                rows: rows,
                selectedIndex: selectedRowIndex,
                onSelected: (index) => setState(() {
                  selectedRowIndex = index;
                }),
              ),
              if (selectedRow != null)
                _VariantToggleRow(
                  tokens: widget.tokens,
                  language: widget.language,
                  row: selectedRow,
                  value: selectedRow.valueOf(widget.variants),
                  scale: 0,
                  compact: true,
                  onChanged: (value) => widget.onChanged(
                    selectedRow.withValue(widget.variants, value),
                  ),
                ),
            ] else
              for (final row in rows)
                _VariantToggleRow(
                  tokens: widget.tokens,
                  language: widget.language,
                  row: row,
                  value: row.valueOf(widget.variants),
                  scale: scale,
                  onChanged: (value) =>
                      widget.onChanged(row.withValue(widget.variants, value)),
                ),
          ],
        );
      },
    );
  }
}

double _variantInfoScale(double width) {
  return ((width - 520) / 900).clamp(0.0, 1.0).toDouble();
}

class _DeckSummary extends StatelessWidget {
  const _DeckSummary({
    required this.tokens,
    required this.language,
    required this.deckType,
    required this.maxYears,
    required this.scale,
    this.compact = false,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final int deckType;
  final int maxYears;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 8 + 10 * scale,
        vertical: compact ? 7 : 8 + 8 * scale,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        spacing: 8,
        children: [
          Text(
            language.t(KolkhozText.variantDeckLabel),
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.creamDim,
              fontSize: compact ? 15 : 16 + 5 * scale,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            language.t(KolkhozText.kolkhozappDecktypeCardsMaxyearsYears, {
              'deckType': deckType,
              'maxYears': maxYears,
            }),
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.gold,
              fontSize: compact ? 16 : 17 + 6 * scale,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantReadOnlyRow extends StatelessWidget {
  const _VariantReadOnlyRow({
    required this.tokens,
    required this.language,
    required this.row,
    required this.scale,
    this.compact = false,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
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
            row.iconAsset,
            size: compact ? 40 : _variantIconSize(scale),
          ),
          Expanded(
            child: _VariantText(
              tokens: tokens,
              language: language,
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
    required this.rows,
    required this.selectedIndex,
    required this.onSelected,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
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
            label: rows[index].localizedTitle(language),
            iconAsset: rows[index].iconAsset,
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
    required this.row,
    required this.value,
    required this.onChanged,
    required this.scale,
    this.compact = false,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final _VariantRowData row;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = row.localizedTitle(language);
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
                  row.iconAsset,
                  size: compact ? 40 : _variantIconSize(scale),
                  opacity: value ? 1 : 0.82,
                ),
                Expanded(
                  child: _VariantText(
                    tokens: tokens,
                    language: language,
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
    required this.row,
    required this.active,
    required this.scale,
    this.compact = false,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final _VariantRowData row;
  final bool active;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleColor = active ? tokens.colors.onAccent : tokens.colors.cardInk;
    final bodyColor = active
        ? tokens.colors.creamDim
        : tokens.colors.cardInk.withValues(alpha: 0.74);
    final titleSize = compact
        ? PixelTextSize.headline
        : _variantTitleTextSize(scale);
    final bodySize = compact
        ? PixelTextSize.caption
        : _variantBodyTextSize(scale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: compact ? 4 : 7 + 3 * scale,
      children: [
        _VariantPixelLine(
          height: _pixelTextSlotHeight(titleSize),
          child: PixelText(
            row.localizedTitle(language).toUpperCase(),
            color: titleColor,
            size: titleSize,
            variant: PixelTextVariant.heavy,
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ),
        _VariantPixelLine(
          height: _pixelTextSlotHeight(bodySize),
          child: PixelText(
            row.localizedDescription(language),
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
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  late final TextEditingController confirmPasswordController;
  late String lastSubmittedName;

  @override
  void initState() {
    super.initState();
    lastSubmittedName = widget.displayName;
    displayNameController = TextEditingController(text: widget.displayName);
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
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
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
                  _ProfileStatsGrid(
                    tokens: widget.tokens,
                    language: widget.language,
                    stats: widget.profileStats,
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
                  emailController: emailController,
                  passwordController: passwordController,
                  confirmPasswordController: confirmPasswordController,
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
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
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
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final Future<void> Function(String email, String password)? onSignIn;
  final Future<void> Function(String email, String password)? onSignUp;
  final Future<void> Function(String email)? onResetPassword;
  final Future<void> Function()? onSignOut;

  @override
  State<_CloudAuthPanel> createState() => _CloudAuthPanelState();
}

class _CloudAuthPanelState extends State<_CloudAuthPanel> {
  String? localMessage;

  void clearLocalMessage() {
    if (localMessage == null) {
      return;
    }
    setState(() => localMessage = null);
  }

  void submitSignUp() {
    final password = widget.passwordController.text;
    final confirmPassword = widget.confirmPasswordController.text;
    if (password != confirmPassword) {
      setState(() {
        localMessage = widget.language.t(
          KolkhozText.kolkhozappPasswordsDoNotMatch,
        );
      });
      return;
    }
    clearLocalMessage();
    widget.onSignUp?.call(widget.emailController.text, password);
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
        _VariantRowBackground(
          tokens: widget.tokens,
          active: widget.signedIn,
          child: Text(
            status,
            style: kolkhozFontStyle.copyWith(
              color: widget.signedIn
                  ? widget.tokens.colors.cream
                  : widget.tokens.colors.creamDim,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (widget.message != null)
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
            controller: widget.emailController,
            label: widget.language.t(KolkhozText.kolkhozappEmail),
            maxLength: 72,
            onChanged: (_) => clearLocalMessage(),
          ),
          _ProfileTextField(
            tokens: widget.tokens,
            controller: widget.passwordController,
            label: widget.language.t(KolkhozText.kolkhozappPassword),
            obscureText: true,
            maxLength: 72,
            onChanged: (_) => clearLocalMessage(),
          ),
          _ProfileTextField(
            tokens: widget.tokens,
            controller: widget.confirmPasswordController,
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
                            widget.emailController.text,
                            widget.passwordController.text,
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
                          widget.onResetPassword!(widget.emailController.text);
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
        if (widget.configured && widget.ready && widget.signedIn)
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 142,
              height: 38,
              child: ChromeAssetButton.command(
                label: widget.busy
                    ? widget.language.t(KolkhozText.kolkhozappWorking)
                    : widget.language.t(KolkhozText.kolkhozappSignOut),
                prominent: false,
                tokens: widget.tokens,
                onPressed: widget.busy || widget.onSignOut == null
                    ? null
                    : widget.onSignOut,
              ),
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
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  late final TextEditingController confirmPasswordController;

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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          if (widget.cloudSignedIn)
            _ComradesPanel(
              tokens: widget.tokens,
              language: widget.language,
              initialComrades: widget.comradesSummary,
              onComradesChanged: widget.onComradesChanged,
            )
          else
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
              emailController: emailController,
              passwordController: passwordController,
              confirmPasswordController: confirmPasswordController,
              onSignIn: widget.onCloudSignIn,
              onSignUp: widget.onCloudSignUp,
              onResetPassword: widget.onCloudResetPassword,
              onSignOut: null,
            ),
        ],
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
          message = widget.language.t(KolkhozText.kolkhozappProfileSyncFailed);
          messageIsError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = comrades.comradeCode ?? '-----';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          widget.language.t(KolkhozText.kolkhozappComrades),
          style: kolkhozFontStyle.copyWith(
            color: widget.tokens.colors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        _VariantRowBackground(
          tokens: widget.tokens,
          active: false,
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      widget.language.t(KolkhozText.kolkhozappYourComradeCode),
                      style: kolkhozFontStyle.copyWith(
                        color: widget.tokens.colors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    SelectableText(
                      code,
                      style: kolkhozFontStyle.copyWith(
                        color: widget.tokens.colors.cardInk,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 126,
                height: 34,
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
              ),
            ],
          ),
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: _ProfileTextField(
                tokens: widget.tokens,
                controller: codeController,
                label: widget.language.t(KolkhozText.kolkhozappComradeCode),
                maxLength: 12,
              ),
            ),
            SizedBox(
              width: 142,
              height: 38,
              child: ChromeAssetButton.command(
                label: busy
                    ? widget.language.t(KolkhozText.kolkhozappWorking)
                    : widget.language.t(KolkhozText.kolkhozappAddComrade),
                prominent: true,
                tokens: widget.tokens,
                iconAsset: 'ios_resources/Icons/icon-add-friend.png',
                onPressed: busy ? null : addComrade,
              ),
            ),
          ],
        ),
        if (message != null)
          _OnlineStatusBanner(
            tokens: widget.tokens,
            message: message!,
            isError: messageIsError,
          ),
        _ComradeSectionTitle(
          tokens: widget.tokens,
          label: widget.language.t(KolkhozText.kolkhozappIncomingRequests),
          iconAsset: 'ios_resources/Icons/icon-add-friend.png',
        ),
        if (comrades.incomingRequests.isEmpty)
          _ComradeEmptyRow(
            tokens: widget.tokens,
            label: widget.language.t(KolkhozText.kolkhozappNoComradeRequests),
          )
        else
          for (final request in comrades.incomingRequests)
            _ComradeRequestRow(
              tokens: widget.tokens,
              language: widget.language,
              request: request,
              busy: busy,
              incoming: true,
              onAccept: () => respondToComradeRequest(request.userID, true),
              onDecline: () => respondToComradeRequest(request.userID, false),
            ),
        _ComradeSectionTitle(
          tokens: widget.tokens,
          label: widget.language.t(KolkhozText.kolkhozappOutgoingRequests),
          iconAsset: 'ios_resources/Icons/icon-friends-list.png',
        ),
        if (comrades.outgoingRequests.isEmpty)
          _ComradeEmptyRow(
            tokens: widget.tokens,
            label: widget.language.t(KolkhozText.kolkhozappNoComradeRequests),
          )
        else
          for (final request in comrades.outgoingRequests)
            _ComradeRequestRow(
              tokens: widget.tokens,
              language: widget.language,
              request: request,
              busy: busy,
              incoming: false,
              onAccept: null,
              onDecline: null,
            ),
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
          _ProfilePortraitImage(
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
                  '${language.t(KolkhozText.kolkhozappRating)} ${request.stats.rating}',
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
    return _VariantRowBackground(
      tokens: tokens,
      active: false,
      child: Row(
        spacing: 8,
        children: [
          _ProfilePortraitImage(
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
                  '${language.t(KolkhozText.kolkhozappRating)} ${comrade.stats.rating}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.cardInk.withValues(alpha: 0.72),
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
    return _VariantRowBackground(
      tokens: tokens,
      active: true,
      child: Row(
        spacing: 12,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPortraitPressed,
            child: Semantics(
              button: true,
              enabled: onPortraitPressed != null,
              label: portraitAsset,
              child: _ProfilePortraitImage(
                tokens: tokens,
                asset: portraitAsset,
                size: 74,
                selected: true,
              ),
            ),
          ),
          Expanded(
            child: TextField(
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
          ),
        ],
      ),
    );
  }
}

class _ProfileStatsGrid extends StatelessWidget {
  const _ProfileStatsGrid({
    required this.tokens,
    required this.language,
    required this.stats,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final totalGames = stats.totalWins + stats.totalLosses;
    final winRate = totalGames == 0
        ? '0%'
        : '${((stats.totalWins / totalGames) * 100).round()}%';
    final tiles = [
      _ProfileStatTileData(
        label: language.t(KolkhozText.kolkhozappOffline),
        value: stats.offlinePlays.toString(),
        detail: language.t(KolkhozText.kolkhozappGames),
      ),
      _ProfileStatTileData(
        label: language.t(KolkhozText.kolkhozappOffWins),
        value: stats.offlineWins.toString(),
        detail: language.t(KolkhozText.kolkhozappWins),
      ),
      _ProfileStatTileData(
        label: language.t(KolkhozText.kolkhozappOnline2),
        value: stats.onlinePlays.toString(),
        detail: language.t(KolkhozText.kolkhozappGames),
      ),
      _ProfileStatTileData(
        label: language.t(KolkhozText.kolkhozappOnWins),
        value: stats.onlineWins.toString(),
        detail: language.t(KolkhozText.kolkhozappWins),
      ),
      _ProfileStatTileData(
        label: language.t(KolkhozText.kolkhozappRating),
        value: stats.rating.toString(),
        detail: language.t(KolkhozText.kolkhozappCurrent),
      ),
      _ProfileStatTileData(
        label: language.t(KolkhozText.kolkhozappWins2),
        value: stats.totalWins.toString(),
        detail: language.t(KolkhozText.kolkhozappTotal),
      ),
      _ProfileStatTileData(
        label: language.t(KolkhozText.kolkhozappLosses),
        value: stats.totalLosses.toString(),
        detail: winRate,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          language.t(KolkhozText.kolkhozappStats),
          style: kolkhozFontStyle.copyWith(
            color: tokens.colors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700
                ? 5
                : constraints.maxWidth >= 480
                ? 3
                : 2;
            const spacing = 8.0;
            final tileWidth =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final tile in tiles)
                  SizedBox(
                    width: tileWidth,
                    height: 82,
                    child: _ProfileStatTile(tokens: tokens, data: tile),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProfileStatTileData {
  const _ProfileStatTileData({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;
}

class _ProfileStatTile extends StatelessWidget {
  const _ProfileStatTile({required this.tokens, required this.data});

  final DesignTokens tokens;
  final _ProfileStatTileData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.creamDim.withValues(alpha: 0.76),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.cream,
              fontSize: 26,
              height: 0.95,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            data.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.gold,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        child: _ProfilePortraitImage(
          tokens: tokens,
          asset: asset,
          size: 58,
          selected: selected,
        ),
      ),
    );
  }
}

class _ProfilePortraitImage extends StatelessWidget {
  const _ProfilePortraitImage({
    required this.tokens,
    required this.asset,
    required this.size,
    required this.selected,
  });

  final DesignTokens tokens;
  final String asset;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: selected
            ? tokens.colors.gold.withValues(alpha: 0.26)
            : tokens.colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected
              ? tokens.colors.gold
              : tokens.colors.steel.withValues(alpha: 0.42),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          'ios_resources/$asset.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) =>
              ColoredBox(color: tokens.colors.black.withValues(alpha: 0.42)),
        ),
      ),
    );
  }
}

class _OnlinePanel extends StatefulWidget {
  const _OnlinePanel({
    required this.tokens,
    required this.language,
    required this.hostedInviteCode,
    required this.onJoinOnline,
    required this.comradesSummary,
    required this.onComradesChanged,
    required this.onComradeRequestToUser,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String? hostedInviteCode;
  final OnlineComradesResponse comradesSummary;
  final ValueChanged<OnlineComradesResponse>? onComradesChanged;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final Future<void> Function(
    Uri baseURL,
    String inviteCode,
    int? preferredPlayerID,
  )
  onJoinOnline;

  @override
  State<_OnlinePanel> createState() => _OnlinePanelState();
}

class _OnlinePanelState extends State<_OnlinePanel> {
  late final TextEditingController inviteController;
  bool busy = false;
  String? status;
  bool statusIsError = false;
  List<OnlineSessionListing> openSessions = const [];
  Set<String> comradeUserIDs = const {};
  Set<String> incomingComradeRequestUserIDs = const {};
  Set<String> outgoingComradeRequestUserIDs = const {};
  String? currentUserID;
  String? selectedSessionID;
  bool rankedOnly = false;
  bool comradesOnly = false;

  Future<void> copyInviteCode(String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!mounted) {
      return;
    }
    setState(() {
      status = widget.language.t(KolkhozText.kolkhozappCopied);
      statusIsError = false;
    });
  }

  @override
  void initState() {
    super.initState();
    inviteController = TextEditingController();
    if (_useOpenGameBrowserProxy) {
      openSessions = _proxiedOpenSessions;
    }
    unawaited(loadComrades());
  }

  @override
  void dispose() {
    inviteController.dispose();
    super.dispose();
  }

  Future<void> refreshSessions() async {
    unawaited(loadComrades());
    if (_useOpenGameBrowserProxy) {
      setState(() {
        openSessions = _proxiedOpenSessions;
        selectedSessionID = _sessionStillOpen(selectedSessionID, openSessions)
            ? selectedSessionID
            : null;
        status = widget.language.t(KolkhozText.kolkhozappValue1Open, {
          'value1': openSessions.length,
        });
        statusIsError = false;
      });
      return;
    }
    await runOnlineAction(() async {
      final sessions = await KolkhozOnlineClient(
        _onlineServerURL,
      ).fetchSessions();
      openSessions = sessions;
      selectedSessionID = _sessionStillOpen(selectedSessionID, openSessions)
          ? selectedSessionID
          : null;
      status = sessions.isEmpty
          ? widget.language.t(KolkhozText.kolkhozappNoOpenGames)
          : widget.language.t(KolkhozText.kolkhozappValue1Open, {
              'value1': sessions.length,
            });
      statusIsError = false;
    });
  }

  Future<void> joinSession(OnlineSessionListing session) async {
    if (_useOpenGameBrowserProxy) {
      setState(() {
        selectedSessionID = session.sessionID;
        status = widget.language.t(KolkhozText.kolkhozappJoinedValue1, {
          'value1': session.shortID,
        });
        statusIsError = false;
      });
      return;
    }
    await runOnlineAction(() async {
      final seat = session.openSeats.isEmpty ? null : session.openSeats.first;
      await widget.onJoinOnline(_onlineServerURL, session.sessionID, seat);
      status = widget.language.t(KolkhozText.kolkhozappJoinedValue1, {
        'value1': session.shortID,
      });
      statusIsError = false;
    });
  }

  OnlineSessionListing? get selectedSession {
    final id = selectedSessionID;
    if (id == null) {
      return null;
    }
    for (final session in filteredSessions) {
      if (session.sessionID == id) {
        return session;
      }
    }
    return null;
  }

  Future<void> loadComrades() async {
    try {
      final response = await _onlineClient().fetchComrades();
      if (!mounted) {
        return;
      }
      setState(() {
        currentUserID = response.userID;
        comradeUserIDs = response.userIDs;
        incomingComradeRequestUserIDs = {
          for (final request in response.incomingRequests) request.userID,
        };
        outgoingComradeRequestUserIDs = {
          for (final request in response.outgoingRequests) request.userID,
        };
        _clearSelectionIfFilteredOut();
      });
      widget.onComradesChanged?.call(response);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        currentUserID = widget.comradesSummary.userID;
        comradeUserIDs = widget.comradesSummary.userIDs;
        incomingComradeRequestUserIDs = {
          for (final request in widget.comradesSummary.incomingRequests)
            request.userID,
        };
        outgoingComradeRequestUserIDs = {
          for (final request in widget.comradesSummary.outgoingRequests)
            request.userID,
        };
      });
    }
  }

  KolkhozOnlineClient _onlineClient() {
    return KolkhozOnlineClient(
      _onlineServerURL,
      accessTokenProvider: _currentSupabaseAccessToken,
    );
  }

  void selectSession(OnlineSessionListing session) {
    setState(() {
      selectedSessionID = selectedSessionID == session.sessionID
          ? null
          : session.sessionID;
    });
  }

  Future<void> sendComradeRequestToUser(String userID) async {
    if (widget.onComradeRequestToUser == null) {
      return;
    }
    await runOnlineAction(() async {
      await widget.onComradeRequestToUser!(userID);
      await loadComrades();
      status = widget.language.t(KolkhozText.kolkhozappComradeRequestSent);
      statusIsError = false;
    });
  }

  List<OnlineSessionListing> get filteredSessions {
    return [
      for (final session in openSessions)
        if (_matchesRankedFilter(session) && _matchesComradesFilter(session))
          session,
    ];
  }

  bool _matchesRankedFilter(OnlineSessionListing session) {
    return !rankedOnly || session.ranked;
  }

  bool _matchesComradesFilter(OnlineSessionListing session) {
    if (!comradesOnly) {
      return true;
    }
    return _sessionMatchesComradeFilter(session);
  }

  bool _sessionMatchesComradeFilter(OnlineSessionListing session) {
    return session.playerProfiles.any((profile) {
      final userID = profile.userID;
      return userID != null && comradeUserIDs.contains(userID);
    });
  }

  void toggleRankedFilter(bool value) {
    setState(() {
      rankedOnly = value;
      _clearSelectionIfFilteredOut();
    });
  }

  void toggleComradesFilter(bool value) {
    setState(() {
      comradesOnly = value;
      _clearSelectionIfFilteredOut();
    });
  }

  void _clearSelectionIfFilteredOut() {
    final selected = selectedSessionID;
    if (selected == null) {
      return;
    }
    if (!filteredSessions.any((session) => session.sessionID == selected)) {
      selectedSessionID = null;
    }
  }

  bool _sessionStillOpen(
    String? sessionID,
    List<OnlineSessionListing> sessions,
  ) {
    if (sessionID == null) {
      return false;
    }
    return sessions.any((session) => session.sessionID == sessionID);
  }

  Future<void> join() async {
    await runOnlineAction(() async {
      await widget.onJoinOnline(
        _onlineServerURL,
        inviteController.text.trim(),
        null,
      );
      status = widget.language.t(KolkhozText.kolkhozappJoinedValue1, {
        'value1': inviteController.text.trim(),
      });
      statusIsError = false;
    });
  }

  Future<void> runOnlineAction(Future<void> Function() action) async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      status = null;
      statusIsError = false;
    });
    try {
      await action();
    } catch (exception) {
      if (mounted) {
        setState(() {
          status = onlineStatusMessage(exception);
          statusIsError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  String onlineStatusMessage(Object exception) {
    if (exception is SocketException) {
      return widget.language.t(
        KolkhozText.kolkhozappCouldNotReachTheOnlineServerTryAgainInAMom,
      );
    }
    if (exception is HttpException) {
      if (exception.message.contains('sent north')) {
        return widget.language.t(
          KolkhozText.kolkhozappSentNorthOnlinePlayIsLockedForThisAccount,
        );
      }
      if (exception.message.contains('auth token')) {
        return widget.language.t(
          KolkhozText.kolkhozappSignInBeforeJoiningOnlinePlay,
        );
      }
      return widget.language.t(
        KolkhozText.kolkhozappTheOnlineServerRejectedTheRequest,
      );
    }
    return widget.language.t(KolkhozText.kolkhozappOnlineRequestFailedTryAgain);
  }

  @override
  Widget build(BuildContext context) {
    final visibleSessions = filteredSessions;
    final selected = selectedSession;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Row(
          spacing: 8,
          children: [
            const _AssetIcon('ios_resources/Icons/icon-online.png', size: 26),
            Text(
              widget.language.t(KolkhozText.kolkhozappJoinGame),
              style: kolkhozFontStyle.copyWith(
                color: widget.tokens.colors.gold,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            Expanded(
              child: Text(
                widget.language.t(
                  KolkhozText.kolkhozappJoinAnOpenGameOrEnterAnInviteCode,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kolkhozFontStyle.copyWith(
                  color: widget.tokens.colors.creamDim,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (widget.hostedInviteCode != null)
          _HostedInviteCodeCard(
            tokens: widget.tokens,
            language: widget.language,
            inviteCode: widget.hostedInviteCode!,
            onCopy: () => copyInviteCode(widget.hostedInviteCode!),
          ),
        _OpenSessionsToolbar(
          tokens: widget.tokens,
          language: widget.language,
          busy: busy,
          rankedOnly: rankedOnly,
          comradesOnly: comradesOnly,
          onRefresh: refreshSessions,
          onRankedChanged: toggleRankedFilter,
          onComradesChanged: toggleComradesFilter,
        ),
        Expanded(
          child: _OpenSessionsList(
            tokens: widget.tokens,
            language: widget.language,
            sessions: visibleSessions,
            selectedSessionID: selectedSessionID,
            currentUserID: currentUserID ?? widget.comradesSummary.userID,
            comradeUserIDs: comradeUserIDs.isEmpty
                ? widget.comradesSummary.userIDs
                : comradeUserIDs,
            incomingComradeRequestUserIDs: incomingComradeRequestUserIDs.isEmpty
                ? {
                    for (final request
                        in widget.comradesSummary.incomingRequests)
                      request.userID,
                  }
                : incomingComradeRequestUserIDs,
            outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs.isEmpty
                ? {
                    for (final request
                        in widget.comradesSummary.outgoingRequests)
                      request.userID,
                  }
                : outgoingComradeRequestUserIDs,
            onSelected: selectSession,
            onComradeRequestToUser: sendComradeRequestToUser,
          ),
        ),
        if (status != null)
          _OnlineStatusBanner(
            tokens: widget.tokens,
            message: status!,
            isError: statusIsError,
          ),
        SizedBox(
          height: 44,
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                child: _OnlineTextField(
                  tokens: widget.tokens,
                  controller: inviteController,
                  label: widget.language.t(KolkhozText.kolkhozappInviteCode),
                ),
              ),
              SizedBox(
                width: 220,
                child: Opacity(
                  opacity: busy ? 0.55 : 1,
                  child: ChromeAssetButton.command(
                    label: busy
                        ? widget.language.t(KolkhozText.kolkhozappWorking)
                        : selected == null
                        ? widget.language.t(KolkhozText.kolkhozappAssignGame)
                        : widget.language.t(KolkhozText.kolkhozappJoinGame),
                    prominent: true,
                    tokens: widget.tokens,
                    iconAsset: 'ios_resources/Icons/icon-join-game.png',
                    expandLabel: false,
                    onPressed: busy
                        ? null
                        : selected == null
                        ? join
                        : () => joinSession(selected),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final Uri _onlineServerURL = Uri.parse(
  'https://online.kolkhoz.williamtheisen.com',
);

Future<String?> _currentSupabaseAccessToken() async {
  return KolkhozSupabaseRuntime
      .instance
      .client
      ?.auth
      .currentSession
      ?.accessToken;
}

const bool _useOpenGameBrowserProxy = true;

const List<OnlineSessionListing> _proxiedOpenSessions = [
  OnlineSessionListing(
    sessionID: 'layout-kolkhoz-01',
    openSeats: [1, 2, 3],
    occupiedSeats: [0],
    controllers: [
      KolkhozPlayerController.human,
      KolkhozPlayerController.human,
      KolkhozPlayerController.human,
      KolkhozPlayerController.human,
    ],
    playerProfiles: [
      OnlinePlayerProfile(
        playerID: 0,
        displayName: 'Misha',
        stats: KolkhozProfileStats(rating: 1038),
      ),
    ],
    actionLogCount: 0,
    createdAt: 1783518000,
    expiresAt: 1783525200,
  ),
  OnlineSessionListing(
    sessionID: 'layout-brigade-02',
    openSeats: [2, 3],
    occupiedSeats: [0, 1],
    controllers: [
      KolkhozPlayerController.human,
      KolkhozPlayerController.human,
      KolkhozPlayerController.human,
      KolkhozPlayerController.human,
    ],
    playerProfiles: [
      OnlinePlayerProfile(
        playerID: 0,
        displayName: 'Anya',
        stats: KolkhozProfileStats(rating: 1112),
      ),
      OnlinePlayerProfile(
        playerID: 1,
        displayName: 'Boris',
        stats: KolkhozProfileStats(rating: 986),
      ),
    ],
    turnPlayerID: 1,
    actionLogCount: 4,
    createdAt: 1783517100,
    expiresAt: 1783524300,
    ranked: false,
  ),
  OnlineSessionListing(
    sessionID: 'layout-camp-style-03',
    openSeats: [3],
    occupiedSeats: [0, 1, 2],
    controllers: [
      KolkhozPlayerController.human,
      KolkhozPlayerController.human,
      KolkhozPlayerController.human,
      KolkhozPlayerController.human,
    ],
    playerProfiles: [
      OnlinePlayerProfile(
        playerID: 0,
        displayName: 'Comrade Vera',
        stats: KolkhozProfileStats(rating: 1194),
      ),
      OnlinePlayerProfile(
        playerID: 1,
        displayName: 'Lev',
        stats: KolkhozProfileStats(rating: 1047),
      ),
      OnlinePlayerProfile(
        playerID: 2,
        displayName: 'Nina',
        stats: KolkhozProfileStats(rating: 1086),
      ),
    ],
    turnPlayerID: 2,
    actionLogCount: 11,
    createdAt: 1783516200,
    expiresAt: 1783523400,
  ),
  OnlineSessionListing(
    sessionID: 'layout-long-host-name-04',
    openSeats: [1, 3],
    occupiedSeats: [0, 2],
    controllers: [
      KolkhozPlayerController.human,
      KolkhozPlayerController.human,
      KolkhozPlayerController.human,
      KolkhozPlayerController.human,
    ],
    playerProfiles: [
      OnlinePlayerProfile(
        playerID: 0,
        displayName: "People's Commissar of Potatoes",
        stats: KolkhozProfileStats(rating: 1231),
      ),
      OnlinePlayerProfile(
        playerID: 2,
        displayName: 'Yuri',
        stats: KolkhozProfileStats(rating: 1016),
      ),
    ],
    turnPlayerID: 0,
    actionLogCount: 7,
    createdAt: 1783515300,
    expiresAt: 1783522500,
  ),
];

class _HostedInviteCodeCard extends StatelessWidget {
  const _HostedInviteCodeCard({
    required this.tokens,
    required this.language,
    required this.inviteCode,
    required this.onCopy,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String inviteCode;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ChromeButtonBackground(asset: chromeButtonPrimaryAsset),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final codeBlock = _InviteCodeText(
                tokens: tokens,
                inviteCode: inviteCode,
              );
              final copyButton = SizedBox(
                width: compact ? double.infinity : 158,
                height: 44,
                child: ChromeAssetButton.command(
                  label: language.t(KolkhozText.kolkhozappCopyCode),
                  prominent: false,
                  tokens: tokens,
                  onPressed: onCopy,
                  iconAsset: 'ios_resources/Icons/icon-check.png',
                  iconSize: 20,
                  textSize: PixelTextSize.caption,
                  expandLabel: false,
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Row(
                    spacing: 9,
                    children: [
                      const _AssetIcon(
                        'ios_resources/Icons/icon-online.png',
                        size: 26,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(
                              language.t(KolkhozText.kolkhozappYourInviteCode),
                              style: kolkhozFontStyle.copyWith(
                                color: tokens.colors.onAccent,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                            Text(
                              language.t(
                                KolkhozText.kolkhozappWaitingForPlayers,
                              ),
                              style: kolkhozFontStyle.copyWith(
                                color: tokens.colors.onAccent.withValues(
                                  alpha: 0.72,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (compact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [codeBlock, copyButton],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 10,
                      children: [
                        Expanded(child: codeBlock),
                        copyButton,
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InviteCodeText extends StatelessWidget {
  const _InviteCodeText({required this.tokens, required this.inviteCode});

  final DesignTokens tokens;
  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.28),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.72)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SelectableText(
        inviteCode,
        maxLines: 2,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cream,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          height: 1,
        ),
      ),
    );
  }
}

class _OnlineStatusBanner extends StatelessWidget {
  const _OnlineStatusBanner({
    required this.tokens,
    required this.message,
    required this.isError,
  });

  final DesignTokens tokens;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? tokens.colors.redBright : tokens.colors.creamDim;
    final borderColor = isError
        ? tokens.colors.redBright.withValues(alpha: 0.62)
        : tokens.colors.steel.withValues(alpha: 0.44);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        spacing: 8,
        children: [
          _AssetIcon(
            isError
                ? 'ios_resources/Icons/icon-warning.png'
                : 'ios_resources/Icons/icon-status-connected.png',
            size: 18,
          ),
          Expanded(
            child: Text(
              message,
              style: kolkhozFontStyle.copyWith(
                color: color,
                fontSize: 13,
                height: 1.12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenSessionsList extends StatelessWidget {
  const _OpenSessionsList({
    required this.tokens,
    required this.language,
    required this.sessions,
    required this.selectedSessionID,
    required this.currentUserID,
    required this.comradeUserIDs,
    required this.incomingComradeRequestUserIDs,
    required this.outgoingComradeRequestUserIDs,
    required this.onSelected,
    required this.onComradeRequestToUser,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<OnlineSessionListing> sessions;
  final String? selectedSessionID;
  final String? currentUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final ValueChanged<OnlineSessionListing> onSelected;
  final Future<void> Function(String userID)? onComradeRequestToUser;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: _VariantRowBackground(
          tokens: tokens,
          active: false,
          child: Text(
            language.t(KolkhozText.kolkhozappNoOpenGames),
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.creamDim,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return ClipRect(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 7,
          children: [
            for (final session in sessions)
              _OpenSessionRow(
                tokens: tokens,
                language: language,
                session: session,
                expanded: selectedSessionID == session.sessionID,
                onToggle: () => onSelected(session),
                currentUserID: currentUserID,
                comradeUserIDs: comradeUserIDs,
                incomingComradeRequestUserIDs: incomingComradeRequestUserIDs,
                outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs,
                onComradeRequestToUser: onComradeRequestToUser,
              ),
          ],
        ),
      ),
    );
  }
}

class _OpenSessionsToolbar extends StatelessWidget {
  const _OpenSessionsToolbar({
    required this.tokens,
    required this.language,
    required this.busy,
    required this.rankedOnly,
    required this.comradesOnly,
    required this.onRefresh,
    required this.onRankedChanged,
    required this.onComradesChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool busy;
  final bool rankedOnly;
  final bool comradesOnly;
  final VoidCallback onRefresh;
  final ValueChanged<bool> onRankedChanged;
  final ValueChanged<bool> onComradesChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            language.t(KolkhozText.kolkhozappOpenGames),
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.gold,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Row(
          spacing: 6,
          children: [
            _OpenSessionsFilterButton(
              tokens: tokens,
              label: language.t(KolkhozText.kolkhozappRanked),
              iconAsset: 'ios_resources/Icons/icon-medal-star.png',
              selected: rankedOnly,
              onChanged: onRankedChanged,
            ),
            _OpenSessionsFilterButton(
              tokens: tokens,
              label: language.t(KolkhozText.kolkhozappComrades),
              iconAsset: 'ios_resources/Icons/icon-profile.png',
              selected: comradesOnly,
              onChanged: onComradesChanged,
            ),
          ],
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 112,
          height: 34,
          child: ChromeAssetButton.command(
            label: language.t(KolkhozText.kolkhozappRefresh),
            prominent: false,
            tokens: tokens,
            iconAsset: 'ios_resources/Icons/icon-status-connecting.png',
            onPressed: busy ? null : onRefresh,
          ),
        ),
      ],
    );
  }
}

class _OpenSessionsFilterButton extends StatelessWidget {
  const _OpenSessionsFilterButton({
    required this.tokens,
    required this.label,
    required this.iconAsset,
    required this.selected,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final String label;
  final String iconAsset;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 34,
      child: ChromeAssetButton.command(
        label: label,
        prominent: selected,
        tokens: tokens,
        iconAsset: iconAsset,
        onPressed: () => onChanged(!selected),
      ),
    );
  }
}

class _OpenSessionRow extends StatelessWidget {
  const _OpenSessionRow({
    required this.tokens,
    required this.language,
    required this.session,
    required this.expanded,
    required this.onToggle,
    required this.currentUserID,
    required this.comradeUserIDs,
    required this.incomingComradeRequestUserIDs,
    required this.outgoingComradeRequestUserIDs,
    required this.onComradeRequestToUser,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineSessionListing session;
  final bool expanded;
  final VoidCallback onToggle;
  final String? currentUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;

  @override
  Widget build(BuildContext context) {
    final openSeats = session.openSeats
        .map(
          (seat) =>
              language.t(KolkhozText.kolkhozappPValue1, {'value1': seat + 1}),
        )
        .join(' ');
    final hostProfile = session.playerProfiles
        .where((profile) => profile.playerID == 0)
        .firstOrNull;
    final hostName = hostProfile?.displayName?.trim();
    final title = hostName == null || hostName.isEmpty
        ? session.shortID
        : '${session.shortID} - $hostName';
    final titleColor = expanded ? tokens.colors.cream : tokens.colors.cardInk;
    final bodyColor = expanded
        ? tokens.colors.creamDim
        : tokens.colors.cardInk.withValues(alpha: 0.74);
    return Column(
      spacing: 0,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          label: title,
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: _VariantRowBackground(
                tokens: tokens,
                active: expanded,
                child: Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          _VariantPixelLine(
                            height: _pixelTextSlotHeight(PixelTextSize.caption),
                            child: PixelText(
                              title,
                              color: titleColor,
                              size: PixelTextSize.caption,
                              variant: PixelTextVariant.heavy,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                          _VariantPixelLine(
                            height: _pixelTextSlotHeight(
                              PixelTextSize.caption2,
                            ),
                            child: PixelText(
                              language.t(KolkhozText.kolkhozappOpenOpenseats, {
                                'openSeats': openSeats,
                              }),
                              color: bodyColor,
                              size: PixelTextSize.caption2,
                              variant: PixelTextVariant.regular,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _AssetIcon(
                      expanded
                          ? 'ios_resources/Icons/icon-tutorial-cue-done.png'
                          : 'ios_resources/Icons/icon-tutorial-cue-inspect.png',
                      size: 30,
                      opacity: expanded ? 1 : 0.82,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expanded)
          _OpenSessionDetails(
            tokens: tokens,
            language: language,
            session: session,
            hostName: hostName == null || hostName.isEmpty
                ? session.shortID
                : hostName,
            currentUserID: currentUserID,
            comradeUserIDs: comradeUserIDs,
            incomingComradeRequestUserIDs: incomingComradeRequestUserIDs,
            outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs,
            onComradeRequestToUser: onComradeRequestToUser,
          ),
      ],
    );
  }
}

class _OpenSessionDetails extends StatelessWidget {
  const _OpenSessionDetails({
    required this.tokens,
    required this.language,
    required this.session,
    required this.hostName,
    required this.currentUserID,
    required this.comradeUserIDs,
    required this.incomingComradeRequestUserIDs,
    required this.outgoingComradeRequestUserIDs,
    required this.onComradeRequestToUser,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineSessionListing session;
  final String hostName;
  final String? currentUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;

  @override
  Widget build(BuildContext context) {
    final openSeats = _seatList(session.openSeats);
    final occupiedSeats = _seatList(session.occupiedSeats);
    final profilesBySeat = <int, OnlinePlayerProfile>{
      for (final profile in session.playerProfiles) profile.playerID: profile,
    };
    final ratings = [
      for (final seat in session.occupiedSeats)
        profilesBySeat[seat]?.stats.rating ?? defaultProfileStats.rating,
    ];
    final averageRating = ratings.isEmpty
        ? language.t(KolkhozText.kolkhozappWaiting)
        : (ratings.reduce((left, right) => left + right) / ratings.length)
              .round()
              .toString();
    final turn = session.turnPlayerID == null
        ? language.t(KolkhozText.kolkhozappWaiting)
        : language.t(KolkhozText.kolkhozappPValue1, {
            'value1': session.turnPlayerID! + 1,
          });
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.34),
        border: Border(
          left: BorderSide(color: tokens.colors.gold.withValues(alpha: 0.52)),
          right: BorderSide(color: tokens.colors.gold.withValues(alpha: 0.52)),
          bottom: BorderSide(color: tokens.colors.gold.withValues(alpha: 0.52)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.t(KolkhozText.kolkhozappHost),
                value: hostName,
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.t(KolkhozText.kolkhozappSeats),
                value: '$occupiedSeats / $openSeats',
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.t(KolkhozText.kolkhozappTurn),
                value: turn,
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.t(KolkhozText.kolkhozappMoves),
                value: '${session.actionLogCount}',
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.t(KolkhozText.kolkhozappAverageRating),
                value: averageRating,
              ),
              _OpenSessionDetailChip(
                tokens: tokens,
                label: language.t(KolkhozText.kolkhozappGameType),
                value: session.ranked
                    ? language.t(KolkhozText.kolkhozappRanked)
                    : language.t(KolkhozText.kolkhozappCasual),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 660
                  ? (constraints.maxWidth - 24) / 4
                  : constraints.maxWidth >= 420
                  ? (constraints.maxWidth - 8) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < 4; index++)
                    SizedBox(
                      width: cardWidth,
                      child: _OpenSessionPlayerCard(
                        tokens: tokens,
                        language: language,
                        playerID: index,
                        profile: profilesBySeat[index],
                        open: session.openSeats.contains(index),
                        currentTurn: session.turnPlayerID == index,
                        currentUserID: currentUserID,
                        comradeUserIDs: comradeUserIDs,
                        incomingComradeRequestUserIDs:
                            incomingComradeRequestUserIDs,
                        outgoingComradeRequestUserIDs:
                            outgoingComradeRequestUserIDs,
                        onComradeRequestToUser: onComradeRequestToUser,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _seatList(List<int> seats) {
    if (seats.isEmpty) {
      return language.t(KolkhozText.kolkhozappWaiting);
    }
    return seats
        .map(
          (seat) =>
              language.t(KolkhozText.kolkhozappPValue1, {'value1': seat + 1}),
        )
        .join(' ');
  }
}

class _OpenSessionPlayerCard extends StatelessWidget {
  const _OpenSessionPlayerCard({
    required this.tokens,
    required this.language,
    required this.playerID,
    required this.profile,
    required this.open,
    required this.currentTurn,
    required this.currentUserID,
    required this.comradeUserIDs,
    required this.incomingComradeRequestUserIDs,
    required this.outgoingComradeRequestUserIDs,
    required this.onComradeRequestToUser,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final int playerID;
  final OnlinePlayerProfile? profile;
  final bool open;
  final bool currentTurn;
  final String? currentUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;

  @override
  Widget build(BuildContext context) {
    final player = language.t(KolkhozText.kolkhozappPValue1, {
      'value1': playerID + 1,
    });
    final name = profile?.displayName?.trim();
    final occupied = !open;
    final displayName = name == null || name.isEmpty
        ? occupied
              ? language.t(KolkhozText.kolkhozappHuman)
              : language.t(KolkhozText.kolkhozappOpen)
        : name;
    final portraitAsset = profile?.portraitAsset ?? 'worker${playerID + 1}';
    final rating = profile?.stats.rating ?? defaultProfileStats.rating;
    final profileUserID = profile?.userID;
    final showComradeAction =
        occupied &&
        profileUserID != null &&
        profileUserID != currentUserID &&
        onComradeRequestToUser != null;
    final isComrade =
        profileUserID != null && comradeUserIDs.contains(profileUserID);
    final hasIncomingRequest =
        profileUserID != null &&
        incomingComradeRequestUserIDs.contains(profileUserID);
    final hasOutgoingRequest =
        profileUserID != null &&
        outgoingComradeRequestUserIDs.contains(profileUserID);
    final actionLabel = isComrade
        ? language.t(KolkhozText.kolkhozappComrade)
        : hasOutgoingRequest
        ? language.t(KolkhozText.kolkhozappPending)
        : hasIncomingRequest
        ? language.t(KolkhozText.kolkhozappAccept)
        : language.t(KolkhozText.kolkhozappAddComrade);
    final actionIcon = isComrade
        ? 'ios_resources/Icons/icon-comrade.png'
        : hasOutgoingRequest
        ? 'ios_resources/Icons/icon-status-connecting.png'
        : 'ios_resources/Icons/icon-add-friend.png';
    final actionEnabled =
        showComradeAction && !isComrade && !hasOutgoingRequest;
    final borderColor = currentTurn
        ? tokens.colors.goldBright
        : occupied
        ? tokens.colors.gold.withValues(alpha: 0.58)
        : tokens.colors.steel.withValues(alpha: 0.36);
    final background = occupied
        ? tokens.colors.black.withValues(alpha: 0.36)
        : tokens.colors.black.withValues(alpha: 0.18);
    final foreground = occupied
        ? tokens.colors.cream
        : tokens.colors.creamDim.withValues(alpha: 0.62);

    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor, width: currentTurn ? 1.5 : 1),
        boxShadow: currentTurn
            ? [
                BoxShadow(
                  color: tokens.colors.gold.withValues(alpha: 0.16),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        spacing: 8,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: occupied ? 1 : 0.46,
                child: _ProfilePortraitImage(
                  tokens: tokens,
                  asset: portraitAsset,
                  size: 46,
                  selected: currentTurn,
                ),
              ),
              Positioned(
                left: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: currentTurn
                        ? tokens.colors.gold
                        : tokens.colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: tokens.colors.gold.withValues(alpha: 0.82),
                    ),
                  ),
                  child: Text(
                    player,
                    style: kolkhozFontStyle.copyWith(
                      color: currentTurn
                          ? tokens.colors.onAccent
                          : tokens.colors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 4,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Row(
                  spacing: 5,
                  children: [
                    _AssetIcon(
                      occupied
                          ? 'ios_resources/Icons/icon-medal-star.png'
                          : 'ios_resources/Icons/icon-human-seat.png',
                      size: 15,
                      opacity: occupied ? 1 : 0.58,
                    ),
                    Expanded(
                      child: Text(
                        occupied
                            ? '${language.t(KolkhozText.kolkhozappRating)} $rating'
                            : language.t(KolkhozText.kolkhozappOpen),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kolkhozFontStyle.copyWith(
                          color: occupied
                              ? tokens.colors.gold
                              : tokens.colors.creamDim.withValues(alpha: 0.58),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                if (showComradeAction)
                  SizedBox(
                    height: 24,
                    width: double.infinity,
                    child: ChromeAssetButton.command(
                      label: actionLabel,
                      prominent: hasIncomingRequest,
                      tokens: tokens,
                      iconAsset: actionIcon,
                      iconSize: 14,
                      textSize: PixelTextSize.xSmall,
                      expandLabel: false,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      spacing: 4,
                      onPressed: actionEnabled
                          ? () => unawaited(
                              onComradeRequestToUser!(profileUserID),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenSessionDetailChip extends StatelessWidget {
  const _OpenSessionDetailChip({
    required this.tokens,
    required this.label,
    required this.value,
  });

  final DesignTokens tokens;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cream,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(color: tokens.colors.gold),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _OnlineTextField extends StatelessWidget {
  const _OnlineTextField({
    required this.tokens,
    required this.controller,
    required this.label,
  });

  final DesignTokens tokens;
  final TextEditingController controller;
  final String label;

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
        minLines: 1,
        maxLines: 1,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cream,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: kolkhozFontStyle.copyWith(
            color: tokens.colors.creamDim.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
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
    required this.titleKey,
    required this.descriptionKey,
    required this.iconAsset,
    required this.valueOf,
    required this.withValue,
    this.visibleInCustom = _alwaysVisible,
  });

  final KolkhozText titleKey;
  final KolkhozText descriptionKey;
  final String iconAsset;
  final bool Function(KolkhozGameVariants variants) valueOf;
  final KolkhozGameVariants Function(KolkhozGameVariants variants, bool value)
  withValue;
  final bool Function(KolkhozGameVariants variants) visibleInCustom;

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

  static List<_VariantRowData> configurableRows(KolkhozGameVariants variants) =>
      [
        for (final row in all)
          if (row.visibleInCustom(variants)) row,
      ];

  String localizedTitle(KolkhozLanguage language) => language.t(titleKey);

  String localizedDescription(KolkhozLanguage language) =>
      language.t(descriptionKey);
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
