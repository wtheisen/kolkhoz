import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
              displayName: settings.displayName,
              portraitAsset: settings.portraitAsset,
              profileStats: settings.profileStats,
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
    });
    unawaited(loadCloudProfile());
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
    this.displayName = defaultProfileDisplayName,
    this.portraitAsset = defaultProfilePortraitAsset,
    this.profileStats = defaultProfileStats,
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
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
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
              final wide = usableWidth >= 560 && usableWidth > usableHeight;
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
              final titleWidth = wide
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
                  showingRules: showingRules,
                  showingOnline: showingOnline,
                  showingProfile: showingProfile,
                  cloudConfigured: cloudConfigured,
                  cloudReady: cloudReady,
                  cloudSignedIn: cloudSignedIn,
                  cloudEmail: cloudEmail,
                  cloudAuthBusy: cloudAuthBusy,
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
                  animationSpeed: animationSpeed,
                  confirmNewGame: confirmNewGame,
                  confirmMainMenu: confirmMainMenu,
                  showInvalidTapHints: showInvalidTapHints,
                  showingRules: showingRules,
                  showingOnline: showingOnline,
                  showingProfile: showingProfile,
                  displayName: displayName,
                  portraitAsset: portraitAsset,
                  profileStats: profileStats,
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
                  onEnterOnlineGame: onEnterOnlineGame,
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
    required this.showingRules,
    required this.showingOnline,
    required this.showingProfile,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudEmail,
    required this.cloudAuthBusy,
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
  final bool showingRules;
  final bool showingOnline;
  final bool showingProfile;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
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
        final cardHeight = (constraints.maxWidth * 0.50).clamp(92.0, 176.0);
        return Column(
          spacing: 10,
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
                fit: BoxFit.cover,
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
              cloudConfigured: cloudConfigured,
              cloudReady: cloudReady,
              cloudSignedIn: cloudSignedIn,
              cloudEmail: cloudEmail,
              cloudAuthBusy: cloudAuthBusy,
              onOfflinePressed: onOfflinePressed,
              onOnlinePressed: onOnlinePressed,
              onProfilePressed: onProfilePressed,
              onRulesPressed: onRulesPressed,
              onLanguageToggle: onLanguageToggle,
              onAppearanceToggle: onAppearanceToggle,
            ),
            Image.asset(
              'ios_resources/ui-divider-crops.png',
              width: (constraints.maxWidth * 0.88).clamp(110.0, 170.0),
              height: 34,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
            const Spacer(),
            _LobbyFooter(tokens: tokens, language: language),
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
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudEmail,
    required this.cloudAuthBusy,
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
  final bool showingRules;
  final bool showingOnline;
  final bool showingProfile;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final VoidCallback onOfflinePressed;
  final VoidCallback onOnlinePressed;
  final VoidCallback? onProfilePressed;
  final VoidCallback onRulesPressed;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 9,
      children: [
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ChromeAssetButton.command(
            label: language.t(KolkhozText.lobbyCreateGame),
            prominent: !showingRules && !showingOnline && !showingProfile,
            tokens: tokens,
            onPressed: onOfflinePressed,
            iconAsset: 'ios_resources/Icons/icon-create-game.png',
            iconSize: 40,
            textSize: PixelTextSize.cardRank,
            expandLabel: false,
            padding: const EdgeInsets.symmetric(horizontal: 76),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ChromeAssetButton.command(
            label: language.t(KolkhozText.lobbyJoinGame),
            prominent: showingOnline,
            tokens: tokens,
            onPressed: onOnlinePressed,
            iconAsset: 'ios_resources/Icons/icon-join-game.png',
            iconSize: 40,
            textSize: PixelTextSize.cardRank,
            expandLabel: false,
            padding: const EdgeInsets.symmetric(horizontal: 76),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ChromeAssetButton.command(
            label: language.t(KolkhozText.lobbyHowToPlay),
            prominent: showingRules,
            tokens: tokens,
            onPressed: onRulesPressed,
            iconAsset: 'ios_resources/Icons/icon-foreman-misha.png',
            iconSize: 40,
            textSize: PixelTextSize.cardRank,
            expandLabel: false,
            padding: const EdgeInsets.symmetric(horizontal: 76),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const iconCount = 4;
            const iconSpacing = 8.0;
            final iconSize =
                ((constraints.maxWidth - iconSpacing * (iconCount - 1)) /
                        iconCount)
                    .clamp(44.0, 58.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: iconSpacing,
              children: [
                _LobbyIconButton(
                  tokens: tokens,
                  label: language.t(KolkhozText.lobbyAccountStatus),
                  tooltip: cloudStatusTooltip,
                  iconAsset: cloudStatusIconAsset,
                  prominent: cloudSignedIn,
                  size: iconSize,
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
                  iconAsset:
                      'ios_resources/Icons/${appearance.toggleIconAsset}',
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
                  onPressed: onProfilePressed,
                ),
              ],
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

class _LobbyIconButton extends StatelessWidget {
  const _LobbyIconButton({
    required this.tokens,
    required this.label,
    required this.iconAsset,
    this.tooltip,
    this.prominent = false,
    this.size = 58,
    this.onPressed,
  });

  final DesignTokens tokens;
  final String label;
  final String iconAsset;
  final String? tooltip;
  final bool prominent;
  final double size;
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
    this.animationSpeed = defaultGameAnimationSpeed,
    this.confirmNewGame = true,
    this.confirmMainMenu = true,
    this.showInvalidTapHints = true,
    required this.showingRules,
    required this.showingOnline,
    required this.showingProfile,
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
    required this.onTutorialPressed,
    required this.onStart,
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
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
    required this.onDisplayNameChanged,
    required this.onPortraitChanged,
    required this.onCloudSignIn,
    required this.onCloudSignUp,
    required this.onCloudResetPassword,
    required this.onCloudSignOut,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final bool demoMode;
  final KolkhozGameVariants variants;
  final KolkhozAppearance appearance;
  final GameAnimationSpeed animationSpeed;
  final bool confirmNewGame;
  final bool confirmMainMenu;
  final bool showInvalidTapHints;
  final bool showingRules;
  final bool showingOnline;
  final bool showingProfile;
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
  final VoidCallback onTutorialPressed;
  final VoidCallback onStart;
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
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
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onPortraitChanged;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final Future<void> Function()? onCloudSignOut;

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
            )
          : showingOnline
          ? _OnlinePanel(
              tokens: tokens,
              language: language,
              onJoinOnline: onJoinOnline,
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
              onStart: onStart,
              onHostOnline: onHostOnline,
              onEnterOnlineGame: onEnterOnlineGame,
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
  session,
  assist,
  display,
  rules;

  String title(KolkhozLanguage language) {
    return switch (this) {
      _SettingsTab.profile => language.t(KolkhozText.kolkhozappProfile),
      _SettingsTab.session => OptionsMenuTab.session.title(language),
      _SettingsTab.assist => OptionsMenuTab.assist.title(language),
      _SettingsTab.display => OptionsMenuTab.display.title(language),
      _SettingsTab.rules => OptionsMenuTab.rules.title(language),
    };
  }

  String get iconAsset {
    return switch (this) {
      _SettingsTab.profile => 'ios_resources/Icons/icon-profile.png',
      _SettingsTab.session => OptionsMenuTab.session.iconAsset,
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
      _SettingsTab.session => SingleChildScrollView(
        child: OptionsSessionControls(
          tokens: widget.tokens,
          language: widget.language,
          onNewGame: widget.onStart,
          onTutorial: widget.onTutorialPressed,
          confirmNewGame: widget.confirmNewGame,
          onConfirmNewGameChanged: widget.onConfirmNewGameChanged,
          confirmMainMenu: widget.confirmMainMenu,
          onConfirmMainMenuChanged: widget.onConfirmMainMenuChanged,
        ),
      ),
      _SettingsTab.assist => SingleChildScrollView(
        child: OptionsAssistControls(
          tokens: widget.tokens,
          language: widget.language,
          showInvalidTapHints: widget.showInvalidTapHints,
          onShowInvalidTapHintsChanged: widget.onShowInvalidTapHintsChanged,
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
        Row(
          spacing: 8,
          children: [
            const _AssetIcon('ios_resources/Icons/icon-gears.png', size: 30),
            Text(
              widget.language.t(KolkhozText.kolkhozappSettings),
              style: kolkhozFontStyle.copyWith(
                color: widget.tokens.colors.gold,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = optionsMenuTabSpacing;
            final columns = constraints.maxWidth >= 520 ? 5 : 3;
            final tabWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final tab in _SettingsTab.values)
                  SizedBox(
                    width: tabWidth,
                    child: OptionsMenuTabButton(
                      tokens: widget.tokens,
                      label: tab.title(widget.language),
                      iconAsset: tab.iconAsset,
                      selected: selectedTab == tab,
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

class _VariantPanel extends StatefulWidget {
  const _VariantPanel({
    required this.tokens,
    required this.language,
    required this.selectedPreset,
    required this.customVariants,
    required this.playerControllers,
    required this.demoMode,
    required this.variants,
    required this.onStart,
    required this.onHostOnline,
    required this.onEnterOnlineGame,
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
  final VoidCallback onStart;
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
  )
  onHostOnline;
  final VoidCallback onEnterOnlineGame;
  final ValueChanged<KolkhozGamePreset> onPresetChanged;
  final ValueChanged<KolkhozGameVariants> onCustomVariantsChanged;
  final ValueChanged<List<KolkhozPlayerController>> onPlayerControllersChanged;

  @override
  State<_VariantPanel> createState() => _VariantPanelState();
}

class _VariantPanelState extends State<_VariantPanel> {
  late List<_LobbySeatChoice> seatChoices;
  bool startingOnline = false;
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
      await widget.onHostOnline(_onlineServerURL, effectiveControllers, true);
      widget.onEnterOnlineGame();
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
          onPresetChanged: widget.demoMode ? null : widget.onPresetChanged,
        ),
        if (widget.demoMode)
          _VariantRowBackground(
            tokens: widget.tokens,
            active: false,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              spacing: 9,
              children: [
                const _AssetIcon('ios_resources/Icons/icon-demo.png', size: 34),
                Expanded(
                  child: Text(
                    widget.language.t(
                      KolkhozText.kolkhozappDemoMode2YearKolkhozWithEasyAi,
                    ),
                    style: kolkhozFontStyle.copyWith(
                      color: widget.tokens.colors.cardInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
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
                        onChanged: widget.onCustomVariantsChanged,
                      )
                    else
                      _PresetSummary(
                        tokens: widget.tokens,
                        language: widget.language,
                        variants: widget.variants,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 540;
            final seats = _SeatQuickControls(
              tokens: widget.tokens,
              language: widget.language,
              choices: effectiveSeatChoices,
              onChanged: widget.demoMode ? null : setSeatChoice,
            );
            final startButton = SizedBox(
              width: compact ? double.infinity : 220,
              height: 56,
              child: ChromeAssetButton.command(
                label: startingOnline
                    ? widget.language.t(KolkhozText.kolkhozappWorking)
                    : widget.demoMode
                    ? widget.language.t(KolkhozText.kolkhozappStartDemo)
                    : hasOnlineSeats
                    ? widget.language.t(KolkhozText.kolkhozappStartOnlineGame)
                    : widget.language.t(KolkhozText.kolkhozappStartOfflineGame),
                prominent: true,
                tokens: widget.tokens,
                onPressed: startingOnline ? null : startGame,
                iconAsset: widget.demoMode
                    ? 'ios_resources/Icons/icon-demo.png'
                    : 'ios_resources/Icons/icon-create-game.png',
                iconSize: 28,
                textSize: PixelTextSize.title,
                expandLabel: false,
              ),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Center(child: seats),
                  startButton,
                ],
              );
            }
            return Row(children: [seats, const Spacer(), startButton]);
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
    required this.onPresetChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGamePreset selectedPreset;
  final ValueChanged<KolkhozGamePreset>? onPresetChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = ((constraints.maxWidth - 620) / 900)
            .clamp(0.0, 1.0)
            .toDouble();
        final spacing = 6 + 6 * scale;
        final buttonWidth =
            (constraints.maxWidth -
                spacing * (KolkhozGamePreset.values.length - 1)) /
            KolkhozGamePreset.values.length;
        final buttonHeight = (buttonWidth * 0.21).clamp(58.0, 88.0);
        final iconSize = (buttonHeight * 0.58).clamp(38.0, 52.0);
        final textSize = scale > 0.38
            ? PixelTextSize.cardRank
            : PixelTextSize.title;

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
                  horizontalPadding: 16 + 10 * scale,
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
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<_LobbySeatChoice> choices;
  final void Function(int playerID, _LobbySeatChoice choice)? onChanged;

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
            onChanged: onChanged == null || playerID == 0
                ? null
                : (choice) => onChanged!(playerID, choice),
          ),
      ],
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
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final int playerID;
  final _LobbySeatChoice choice;
  final List<_LobbySeatChoice> options;
  final ValueChanged<_LobbySeatChoice>? onChanged;

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
              width: 66,
              height: 62,
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
                          size: 30,
                          opacity: active ? 1 : 0.82,
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 15,
                          child: ChromeScaledLabel(
                            occupantLabel,
                            color: active
                                ? tokens.colors.onAccent
                                : tokens.colors.cardInk,
                            size: PixelTextSize.caption2,
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

  @override
  Widget build(BuildContext context) {
    return ChromeAssetButton(
      label: label,
      backgroundAsset: selected
          ? chromeButtonPrimaryAsset
          : chromeButtonSecondaryAsset,
      tokens: tokens,
      textColor: selected ? tokens.colors.onAccent : tokens.colors.cardInk,
      textSize: textSize,
      onPressed: onPressed,
      iconAsset: iconAsset,
      iconSize: iconSize,
      height: height,
      padding: EdgeInsets.fromLTRB(
        iconAsset == null ? 10 : horizontalPadding ?? 14,
        3,
        horizontalPadding == null ? 10 : horizontalPadding!,
        0,
      ),
      boxShadow: selected
          ? [
              BoxShadow(
                color: tokens.colors.gold.withValues(alpha: 0.18),
                blurRadius: 5,
                offset: const Offset(0, 1),
              ),
            ]
          : null,
    );
  }
}

class _PresetSummary extends StatelessWidget {
  const _PresetSummary({
    required this.tokens,
    required this.language,
    required this.variants,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;

  @override
  Widget build(BuildContext context) {
    final rows = _VariantRowData.enabledRows(variants);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _variantInfoScale(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10 + 6 * scale,
          children: [
            _DeckSummary(
              tokens: tokens,
              language: language,
              deckType: variants.deckType,
              maxYears: variants.maxYears,
              scale: scale,
            ),
            for (final row in rows)
              _VariantReadOnlyRow(
                tokens: tokens,
                language: language,
                row: row,
                scale: scale,
              ),
          ],
        );
      },
    );
  }
}

class _CustomVariantOptions extends StatelessWidget {
  const _CustomVariantOptions({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final ValueChanged<KolkhozGameVariants> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _variantInfoScale(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10 + 6 * scale,
          children: [
            Row(
              spacing: 6 + 4 * scale,
              children: [
                Expanded(
                  child: _ImageTabButton(
                    tokens: tokens,
                    label: language.t(KolkhozText.variantDeck52Cards),
                    iconAsset: 'ios_resources/Icons/icon-variant-deck-52.png',
                    iconSize: 32 + 12 * scale,
                    selected: variants.deckType == 52,
                    height: 58 + 16 * scale,
                    textSize: scale > 0.38
                        ? PixelTextSize.cardRank
                        : PixelTextSize.title,
                    horizontalPadding: 14 + 8 * scale,
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
                    iconSize: 32 + 12 * scale,
                    selected: variants.deckType == 36,
                    height: 58 + 16 * scale,
                    textSize: scale > 0.38
                        ? PixelTextSize.cardRank
                        : PixelTextSize.title,
                    horizontalPadding: 14 + 8 * scale,
                    onPressed: () => onChanged(
                      variants.copyWith(deckType: 36, accumulateJobs: false),
                    ),
                  ),
                ),
              ],
            ),
            for (final row in _VariantRowData.configurableRows(variants))
              _VariantToggleRow(
                tokens: tokens,
                language: language,
                row: row,
                value: row.valueOf(variants),
                scale: scale,
                onChanged: (value) => onChanged(row.withValue(variants, value)),
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
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final int deckType;
  final int maxYears;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 8 + 10 * scale,
        vertical: 8 + 8 * scale,
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
              fontSize: 16 + 5 * scale,
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
              fontSize: 17 + 6 * scale,
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
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final _VariantRowData row;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return _VariantRowBackground(
      tokens: tokens,
      active: true,
      padding: EdgeInsets.symmetric(
        horizontal: 16 + 12 * scale,
        vertical: 13 + 12 * scale,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 12 + 8 * scale,
        children: [
          _VariantIcon(row.iconAsset, size: _variantIconSize(scale)),
          Expanded(
            child: _VariantText(
              tokens: tokens,
              language: language,
              row: row,
              active: true,
              scale: scale,
            ),
          ),
        ],
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
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final _VariantRowData row;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double scale;

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
              horizontal: 16 + 12 * scale,
              vertical: 13 + 12 * scale,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 12 + 8 * scale,
              children: [
                _VariantIcon(
                  row.iconAsset,
                  size: _variantIconSize(scale),
                  opacity: value ? 1 : 0.82,
                ),
                Expanded(
                  child: _VariantText(
                    tokens: tokens,
                    language: language,
                    row: row,
                    active: value,
                    scale: scale,
                  ),
                ),
                _VariantToggleMark(
                  tokens: tokens,
                  active: value,
                  size: 34 + 12 * scale,
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
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final _VariantRowData row;
  final bool active;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final titleColor = active ? tokens.colors.onAccent : tokens.colors.cardInk;
    final bodyColor = active
        ? tokens.colors.creamDim
        : tokens.colors.cardInk.withValues(alpha: 0.74);
    final titleSize = _variantTitleTextSize(scale);
    final bodySize = _variantBodyTextSize(scale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 7 + 3 * scale,
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

  @override
  Widget build(BuildContext context) {
    final previewName = widget.displayName.trim().isEmpty
        ? defaultProfileDisplayName
        : widget.displayName.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Row(
          spacing: 8,
          children: [
            const _AssetIcon('ios_resources/Icons/icon-profile.png', size: 30),
            Text(
              widget.language.t(KolkhozText.kolkhozappProfile2),
              style: kolkhozFontStyle.copyWith(
                color: widget.tokens.colors.gold,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        _GoldDivider(tokens: widget.tokens),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                _ProfilePreview(
                  tokens: widget.tokens,
                  name: previewName,
                  portraitAsset: widget.portraitAsset,
                ),
                _ProfileStatsGrid(
                  tokens: widget.tokens,
                  language: widget.language,
                  stats: widget.profileStats,
                ),
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
                _ProfileTextField(
                  tokens: widget.tokens,
                  controller: displayNameController,
                  label: widget.language.t(KolkhozText.kolkhozappDisplayName),
                ),
                Text(
                  widget.language.t(KolkhozText.kolkhozappPortrait),
                  style: kolkhozFontStyle.copyWith(
                    color: widget.tokens.colors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final asset in profilePortraitAssets)
                      _ProfilePortraitChoice(
                        tokens: widget.tokens,
                        asset: asset,
                        selected: widget.portraitAsset == asset,
                        onPressed: widget.onPortraitChanged == null
                            ? null
                            : () => widget.onPortraitChanged!(asset),
                      ),
                  ],
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

class _ProfilePreview extends StatelessWidget {
  const _ProfilePreview({
    required this.tokens,
    required this.name,
    required this.portraitAsset,
  });

  final DesignTokens tokens;
  final String name;
  final String portraitAsset;

  @override
  Widget build(BuildContext context) {
    return _VariantRowBackground(
      tokens: tokens,
      active: true,
      child: Row(
        spacing: 12,
        children: [
          _ProfilePortraitImage(
            tokens: tokens,
            asset: portraitAsset,
            size: 74,
            selected: true,
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.cream,
                fontSize: 24,
                height: 1.0,
                fontWeight: FontWeight.w700,
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
    required this.onJoinOnline,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
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

  @override
  void initState() {
    super.initState();
    inviteController = TextEditingController();
    if (_useOpenGameBrowserProxy) {
      openSessions = _proxiedOpenSessions;
    }
  }

  @override
  void dispose() {
    inviteController.dispose();
    super.dispose();
  }

  Future<void> refreshSessions() async {
    if (_useOpenGameBrowserProxy) {
      setState(() {
        openSessions = _proxiedOpenSessions;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    const _AssetIcon(
                      'ios_resources/Icons/icon-online.png',
                      size: 26,
                    ),
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
                          KolkhozText
                              .kolkhozappJoinAnOpenGameOrEnterAnInviteCode,
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
                _OpenSessionsList(
                  tokens: widget.tokens,
                  language: widget.language,
                  sessions: openSessions,
                  busy: busy,
                  onRefresh: refreshSessions,
                  onJoin: joinSession,
                ),
                if (status != null)
                  _OnlineStatusBanner(
                    tokens: widget.tokens,
                    message: status!,
                    isError: statusIsError,
                  ),
              ],
            ),
          ),
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
                        : widget.language.t(KolkhozText.kolkhozappAssignGame),
                    prominent: true,
                    tokens: widget.tokens,
                    iconAsset: 'ios_resources/Icons/icon-join-game.png',
                    expandLabel: false,
                    onPressed: busy ? null : join,
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
    playerProfiles: [OnlinePlayerProfile(playerID: 0, displayName: 'Misha')],
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
      OnlinePlayerProfile(playerID: 0, displayName: 'Anya'),
      OnlinePlayerProfile(playerID: 1, displayName: 'Boris'),
    ],
    turnPlayerID: 1,
    actionLogCount: 4,
    createdAt: 1783517100,
    expiresAt: 1783524300,
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
      OnlinePlayerProfile(playerID: 0, displayName: 'Comrade Vera'),
      OnlinePlayerProfile(playerID: 1, displayName: 'Lev'),
      OnlinePlayerProfile(playerID: 2, displayName: 'Nina'),
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
      ),
      OnlinePlayerProfile(playerID: 2, displayName: 'Yuri'),
    ],
    turnPlayerID: 0,
    actionLogCount: 7,
    createdAt: 1783515300,
    expiresAt: 1783522500,
  ),
];

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
    required this.busy,
    required this.onRefresh,
    required this.onJoin,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<OnlineSessionListing> sessions;
  final bool busy;
  final VoidCallback onRefresh;
  final ValueChanged<OnlineSessionListing> onJoin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 7,
      children: [
        Row(
          spacing: 8,
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
        ),
        if (sessions.isEmpty)
          _VariantRowBackground(
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
          )
        else
          for (final session in sessions)
            _OpenSessionRow(
              tokens: tokens,
              language: language,
              session: session,
              busy: busy,
              onJoin: () => onJoin(session),
            ),
      ],
    );
  }
}

class _OpenSessionRow extends StatelessWidget {
  const _OpenSessionRow({
    required this.tokens,
    required this.language,
    required this.session,
    required this.busy,
    required this.onJoin,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineSessionListing session;
  final bool busy;
  final VoidCallback onJoin;

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
    return _VariantRowBackground(
      tokens: tokens,
      active: true,
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                _VariantPixelLine(
                  height: _pixelTextSlotHeight(PixelTextSize.caption),
                  child: PixelText(
                    hostName == null || hostName.isEmpty
                        ? session.shortID
                        : '${session.shortID} - $hostName',
                    color: tokens.colors.cream,
                    size: PixelTextSize.caption,
                    variant: PixelTextVariant.heavy,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ),
                _VariantPixelLine(
                  height: _pixelTextSlotHeight(PixelTextSize.caption2),
                  child: PixelText(
                    language.t(KolkhozText.kolkhozappOpenOpenseats, {
                      'openSeats': openSeats,
                    }),
                    color: tokens.colors.creamDim,
                    size: PixelTextSize.caption2,
                    variant: PixelTextVariant.regular,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 82,
            height: 34,
            child: ChromeAssetButton.command(
              label: language.t(KolkhozText.kolkhozappJoin),
              prominent: true,
              tokens: tokens,
              iconAsset: 'ios_resources/Icons/icon-join-game.png',
              onPressed: busy || session.openSeats.isEmpty ? null : onJoin,
            ),
          ),
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

  static List<_VariantRowData> enabledRows(KolkhozGameVariants variants) => [
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
