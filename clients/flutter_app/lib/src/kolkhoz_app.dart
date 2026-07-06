import 'dart:async';

import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'c_engine_bridge.dart';
import 'design_tokens.dart';
import 'game_constants.dart';
import 'board_view.dart';
import 'live_game_store.dart';
import 'pixel_text.dart';
import 'render_model.dart';
import 'rule_content.dart';
import 'tutorial_display.dart';

class KolkhozApp extends StatefulWidget {
  const KolkhozApp({super.key});

  @override
  State<KolkhozApp> createState() => _KolkhozAppState();
}

class _KolkhozAppState extends State<KolkhozApp> {
  static const foremanHintDuration = Duration(seconds: 3);

  late final LiveGameStore store;
  late final KolkhozAppSettingsStore settingsStore;
  KolkhozAppSettings settings = const KolkhozAppSettings();
  bool showingLobby = true;
  bool showingRules = false;
  bool showingOnline = false;
  bool showingTutorial = false;
  String? foremanHint;
  Timer? foremanHintTimer;
  KolkhozGamePreset selectedPreset = KolkhozGamePreset.kolkhoz;
  KolkhozGameVariants customVariants = KolkhozGameVariants.kolkhoz;
  List<KolkhozPlayerController> playerControllers = List.of(
    KolkhozPlayerController.defaultControllers,
  );

  KolkhozGameVariants get activeVariants {
    return selectedPreset.variants ?? customVariants;
  }

  @override
  void initState() {
    super.initState();
    settingsStore = KolkhozAppSettingsStore.defaultStore();
    settings = settingsStore.load();
    store = LiveGameStore();
    playerControllers = List.of(store.controllers);
  }

  @override
  void dispose() {
    foremanHintTimer?.cancel();
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
              showingRules: showingRules,
              showingOnline: showingOnline,
              onHostOnline: hostOnlineGame,
              onJoinOnline: joinOnlineGame,
              onStart: () {
                store.newGame(
                  variants: activeVariants,
                  controllers: playerControllers,
                );
                setState(() => showingLobby = false);
              },
              onPresetChanged: (preset) {
                setState(() {
                  selectedPreset = preset;
                  final variants = preset.variants;
                  if (variants != null) {
                    customVariants = variants;
                  }
                  showingRules = false;
                  showingOnline = false;
                });
              },
              onCustomVariantsChanged: (variants) {
                setState(() {
                  selectedPreset = KolkhozGamePreset.custom;
                  customVariants = variants;
                  showingRules = false;
                  showingOnline = false;
                });
              },
              onPlayerControllersChanged: (controllers) {
                setState(() {
                  playerControllers = KolkhozPlayerController.normalized(
                    controllers,
                  );
                });
              },
              onRulesPressed: () {
                setState(() {
                  showingRules = true;
                  showingOnline = false;
                });
              },
              onOfflinePressed: () {
                setState(() {
                  showingRules = false;
                  showingOnline = false;
                });
              },
              onOnlinePressed: () {
                setState(() {
                  showingRules = false;
                  showingOnline = true;
                });
              },
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
                  onPlotCardTap: store.selectPlotCard,
                  onAssignmentCardTap: store.selectAssignmentCard,
                  onInvalidHandCardTap: showFollowSuitHint,
                  onHotSeatReady: store.revealLocalPlayer,
                  onNewGame: () {
                    clearForemanHint();
                    store.newGame(
                      variants: store.currentVariants,
                      controllers: store.controllers,
                    );
                  },
                  onReturnToLobby: returnToLobby,
                  onTutorial: showTutorial,
                  animationSpeed: store.animationSpeed,
                  onAnimationSpeedChanged: store.setAnimationSpeed,
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
              Positioned.fill(child: content),
              if (foremanHint != null)
                Positioned(
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
                  child: TutorialWalkthroughOverlay(
                    tokens: tokens,
                    language: language,
                    onClose: () => setState(() => showingTutorial = false),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void returnToLobby() {
    clearForemanHint();
    store.leaveOnlineGame();
    setState(() {
      showingRules = false;
      showingOnline = false;
      showingLobby = true;
    });
  }

  void showTutorial() {
    clearForemanHint();
    store.clearActivePanel();
    if (showingLobby || store.model == null) {
      store.newGame(variants: activeVariants, controllers: playerControllers);
    }
    setState(() {
      showingRules = false;
      showingOnline = false;
      showingLobby = false;
      showingTutorial = true;
    });
  }

  void applyBoardAction(LegalAction action) {
    clearForemanHint();
    store.applyLegalAction(action);
  }

  void showFollowSuitHint() {
    foremanHintTimer?.cancel();
    setState(() {
      foremanHint = settings.language.text(
        en: 'Remember, you must follow suit if able.',
        ru: 'Помните: если можете, нужно ходить в масть.',
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

  Future<String> hostOnlineGame(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
  ) async {
    final sessionID = await store.hostOnlineGame(
      baseURL: baseURL,
      variants: activeVariants,
      controllers: controllers,
    );
    setState(() {
      showingRules = false;
      showingOnline = false;
      showingLobby = false;
    });
    return sessionID;
  }

  Future<void> joinOnlineGame(
    Uri baseURL,
    String inviteCode,
    int? preferredPlayerID,
  ) async {
    await store.joinOnlineGame(
      baseURL: baseURL,
      inviteCode: inviteCode,
      preferredPlayerID: preferredPlayerID,
    );
    setState(() {
      showingRules = false;
      showingOnline = false;
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
    required this.showingRules,
    required this.showingOnline,
    required this.onHostOnline,
    required this.onJoinOnline,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
    required this.onRulesPressed,
    required this.onOfflinePressed,
    required this.onOnlinePressed,
    required this.onTutorialPressed,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
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
  final bool showingRules;
  final bool showingOnline;
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
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
  final VoidCallback onRulesPressed;
  final VoidCallback onOfflinePressed;
  final VoidCallback onOnlinePressed;
  final VoidCallback onTutorialPressed;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;
  final String? error;

  KolkhozGameVariants get activeVariants {
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
                  onOfflinePressed: onOfflinePressed,
                  onOnlinePressed: onOnlinePressed,
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
                  variants: activeVariants,
                  showingRules: showingRules,
                  showingOnline: showingOnline,
                  onTutorialPressed: onTutorialPressed,
                  onStart: onStart,
                  onHostOnline: onHostOnline,
                  onJoinOnline: onJoinOnline,
                  onPresetChanged: onPresetChanged,
                  onCustomVariantsChanged: onCustomVariantsChanged,
                  onPlayerControllersChanged: onPlayerControllersChanged,
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
    required this.onOfflinePressed,
    required this.onOnlinePressed,
    required this.onRulesPressed,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final bool showingRules;
  final bool showingOnline;
  final VoidCallback onOfflinePressed;
  final VoidCallback onOnlinePressed;
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
              showingRules: showingRules,
              showingOnline: showingOnline,
              onOfflinePressed: onOfflinePressed,
              onOnlinePressed: onOnlinePressed,
              onRulesPressed: onRulesPressed,
            ),
            Image.asset(
              'ios_resources/ui-divider-crops.png',
              width: (constraints.maxWidth * 0.88).clamp(110.0, 170.0),
              height: 34,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
            const Spacer(),
            _LobbyFooter(
              tokens: tokens,
              language: language,
              appearance: appearance,
              onLanguageToggle: onLanguageToggle,
              onAppearanceToggle: onAppearanceToggle,
            ),
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
    required this.showingRules,
    required this.showingOnline,
    required this.onOfflinePressed,
    required this.onOnlinePressed,
    required this.onRulesPressed,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool showingRules;
  final bool showingOnline;
  final VoidCallback onOfflinePressed;
  final VoidCallback onOnlinePressed;
  final VoidCallback onRulesPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 9,
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ChromeAssetButton.command(
            label: language.text(en: 'Offline Play', ru: 'Игра локально'),
            prominent: !showingRules && !showingOnline,
            tokens: tokens,
            onPressed: onOfflinePressed,
            iconAsset: 'ios_resources/Icons/icon-human-seat.png',
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ChromeAssetButton.command(
            label: language.text(en: 'Online Play', ru: 'Онлайн игра'),
            prominent: showingOnline,
            tokens: tokens,
            onPressed: onOnlinePressed,
            iconAsset: 'ios_resources/Icons/icon-play-tap.png',
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ChromeAssetButton.command(
            label: language.text(en: 'How to Play', ru: 'Как играть'),
            prominent: showingRules,
            tokens: tokens,
            onPressed: onRulesPressed,
            iconAsset: 'ios_resources/Icons/icon-tutorial.png',
          ),
        ),
      ],
    );
  }
}

class _LobbyFooter extends StatelessWidget {
  const _LobbyFooter({
    required this.tokens,
    required this.language,
    required this.appearance,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 6,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 7,
          children: [
            _SmallChromeButton(
              tokens: tokens,
              label: language.footerLabel,
              iconAsset: 'ios_resources/Icons/${language.toggleIconAsset}',
              tooltip: language.toggleTitle,
              onPressed: onLanguageToggle,
            ),
            _SmallChromeButton(
              tokens: tokens,
              label: appearance.label(language),
              iconAsset: 'ios_resources/Icons/icon-appearance.png',
              tooltip: appearance.toggleTitle(language),
              onPressed: onAppearanceToggle,
            ),
          ],
        ),
        Column(
          spacing: 2,
          children: [
            Text(
              language.text(en: 'GAME BY', ru: 'АВТОР ИГРЫ'),
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              language.text(en: 'WILLIAM THEISEN', ru: 'УИЛЬЯМ ТАЙСОН'),
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SmallChromeButton extends StatelessWidget {
  const _SmallChromeButton({
    required this.tokens,
    required this.label,
    required this.iconAsset,
    this.tooltip,
    this.onPressed,
  });

  final DesignTokens tokens;
  final String label;
  final String iconAsset;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        width: 68,
        height: 38,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                'ios_resources/ui-nav-button-inactive.png',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 6,
                children: [
                  Image.asset(
                    iconAsset,
                    width: 16,
                    height: 16,
                    filterQuality: FilterQuality.none,
                  ),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kolkhozFontStyle.copyWith(
                        color: tokens.colors.creamDim,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Tooltip(
      message: tooltip ?? label,
      child: Semantics(button: true, enabled: onPressed != null, child: button),
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
    required this.variants,
    required this.showingRules,
    required this.showingOnline,
    required this.onTutorialPressed,
    required this.onStart,
    required this.onHostOnline,
    required this.onJoinOnline,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final KolkhozGameVariants variants;
  final bool showingRules;
  final bool showingOnline;
  final VoidCallback onTutorialPressed;
  final VoidCallback onStart;
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
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

  @override
  Widget build(BuildContext context) {
    return _PanelSurface(
      tokens: tokens,
      child: showingOnline
          ? _OnlinePanel(
              tokens: tokens,
              language: language,
              onHostOnline: onHostOnline,
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
              variants: variants,
              onStart: onStart,
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

class _VariantPanel extends StatelessWidget {
  const _VariantPanel({
    required this.tokens,
    required this.language,
    required this.selectedPreset,
    required this.customVariants,
    required this.playerControllers,
    required this.variants,
    required this.onStart,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final KolkhozGameVariants variants;
  final VoidCallback onStart;
  final ValueChanged<KolkhozGamePreset> onPresetChanged;
  final ValueChanged<KolkhozGameVariants> onCustomVariantsChanged;
  final ValueChanged<List<KolkhozPlayerController>> onPlayerControllersChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        _PresetSelector(
          tokens: tokens,
          language: language,
          selectedPreset: selectedPreset,
          onPresetChanged: onPresetChanged,
        ),
        _GoldDivider(tokens: tokens),
        Expanded(
          child: KolkhozScrollbar(
            tokens: tokens,
            childBuilder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    if (selectedPreset == KolkhozGamePreset.custom)
                      _CustomVariantOptions(
                        tokens: tokens,
                        language: language,
                        variants: customVariants,
                        onChanged: onCustomVariantsChanged,
                      )
                    else
                      _PresetSummary(
                        tokens: tokens,
                        language: language,
                        variants: variants,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Row(
          children: [
            _SeatQuickControls(
              tokens: tokens,
              language: language,
              controllers: playerControllers,
              onChanged: onPlayerControllersChanged,
            ),
            const Spacer(),
            SizedBox(
              width: 220,
              height: 44,
              child: ChromeAssetButton.command(
                label: language.text(en: 'Start Game', ru: 'Начать игру'),
                prominent: true,
                tokens: tokens,
                onPressed: onStart,
                iconAsset: 'ios_resources/Icons/icon-play-tap.png',
                iconSize: 22,
              ),
            ),
          ],
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
  final ValueChanged<KolkhozGamePreset> onPresetChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 6,
      children: [
        for (final preset in KolkhozGamePreset.values)
          Expanded(
            child: _ImageTabButton(
              tokens: tokens,
              label: presetTitle(preset, language),
              selected: selectedPreset == preset,
              onPressed: () => onPresetChanged(preset),
            ),
          ),
      ],
    );
  }
}

class _SeatQuickControls extends StatelessWidget {
  const _SeatQuickControls({
    required this.tokens,
    required this.language,
    required this.controllers,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<KolkhozPlayerController> controllers;
  final ValueChanged<List<KolkhozPlayerController>> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = KolkhozPlayerController.normalized(controllers);
    return Row(
      spacing: 6,
      children: [
        for (var playerID = 0; playerID < kolkhozPlayerCount; playerID += 1)
          _SeatQuickButton(
            tokens: tokens,
            language: language,
            playerID: playerID,
            controller: normalized[playerID],
            onChanged: (controller) {
              final next = List<KolkhozPlayerController>.of(normalized);
              next[playerID] = controller;
              onChanged(KolkhozPlayerController.normalized(next));
            },
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
    required this.controller,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final int playerID;
  final KolkhozPlayerController controller;
  final ValueChanged<KolkhozPlayerController> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = controller == KolkhozPlayerController.human;
    final label = language.text(en: 'P${playerID + 1}', ru: 'И${playerID + 1}');
    return Tooltip(
      message: '$label ${controller.shortTitle(language)}',
      child: PopupMenuButton<KolkhozPlayerController>(
        tooltip: '$label ${controller.shortTitle(language)}',
        offset: const Offset(0, -158),
        color: tokens.colors.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        onSelected: onChanged,
        itemBuilder: (context) => [
          for (final option in KolkhozPlayerController.values)
            PopupMenuItem(
              value: option,
              child: Row(
                spacing: 8,
                children: [
                  _AssetIcon(
                    option.iconAsset,
                    size: 24,
                    opacity: option == controller ? 1 : 0.72,
                  ),
                  Text(
                    option.shortTitle(language).toUpperCase(),
                    style: kolkhozFontStyle.copyWith(
                      color: option == controller
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
        child: Semantics(
          button: true,
          label: '$label ${controller.shortTitle(language)}',
          child: Container(
            width: 48,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? tokens.colors.redDark.withValues(alpha: 0.86)
                  : tokens.colors.black.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: active
                    ? tokens.colors.gold.withValues(alpha: 0.70)
                    : tokens.colors.steel.withValues(alpha: 0.50),
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.colors.black.withValues(alpha: 0.20),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: _AssetIcon(
              controller.iconAsset,
              size: 30,
              opacity: active ? 1 : 0.82,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageTabButton extends StatelessWidget {
  const _ImageTabButton({
    required this.tokens,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ChromeAssetButton(
      label: label,
      backgroundAsset: selected
          ? 'ios_resources/ui-tab-selected.png'
          : 'ios_resources/ui-tab-unselected.png',
      tokens: tokens,
      textColor: selected ? tokens.colors.onAccent : tokens.colors.cardInk,
      textSize: PixelTextSize.caption,
      onPressed: onPressed,
      height: 48,
      padding: const EdgeInsets.fromLTRB(10, 3, 10, 0),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        _DeckSummary(
          tokens: tokens,
          language: language,
          deckType: variants.deckType,
        ),
        for (final row in rows)
          _VariantReadOnlyRow(tokens: tokens, language: language, row: row),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Row(
          spacing: 6,
          children: [
            Expanded(
              child: _ImageTabButton(
                tokens: tokens,
                label: language.text(en: '52 cards', ru: '52 карты'),
                selected: variants.deckType == 52,
                onPressed: () => onChanged(
                  variants.copyWith(deckType: 52, ordenNachalniku: false),
                ),
              ),
            ),
            Expanded(
              child: _ImageTabButton(
                tokens: tokens,
                label: language.text(en: '36 cards', ru: '36 карт'),
                selected: variants.deckType == 36,
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
            onChanged: (value) => onChanged(row.withValue(variants, value)),
          ),
      ],
    );
  }
}

class _DeckSummary extends StatelessWidget {
  const _DeckSummary({
    required this.tokens,
    required this.language,
    required this.deckType,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final int deckType;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        spacing: 8,
        children: [
          Text(
            language.text(en: 'DECK', ru: 'КОЛОДА'),
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.creamDim,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            language.text(en: '$deckType CARDS', ru: '$deckType КАРТ'),
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.gold,
              fontSize: 13,
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
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final _VariantRowData row;

  @override
  Widget build(BuildContext context) {
    return _VariantRowBackground(
      tokens: tokens,
      active: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 9,
        children: [
          const _AssetIcon('ios_resources/Icons/icon-check.png', size: 16),
          Expanded(
            child: _VariantText(tokens: tokens, language: language, row: row),
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
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final _VariantRowData row;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _VariantRowBackground(
      tokens: tokens,
      active: value,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 9,
        children: [
          Expanded(
            child: _VariantText(tokens: tokens, language: language, row: row),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _VariantRowBackground extends StatelessWidget {
  const _VariantRowBackground({
    required this.tokens,
    required this.active,
    required this.child,
  });

  final DesignTokens tokens;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: active
            ? tokens.colors.redDark.withValues(alpha: 0.18)
            : tokens.colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: active
              ? tokens.colors.gold.withValues(alpha: 0.34)
              : tokens.colors.steel.withValues(alpha: 0.30),
        ),
      ),
      child: child,
    );
  }
}

class _VariantText extends StatelessWidget {
  const _VariantText({
    required this.tokens,
    required this.language,
    required this.row,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final _VariantRowData row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          row.localizedTitle(language),
          style: kolkhozFontStyle.copyWith(
            color: tokens.colors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          row.localizedDescription(language),
          style: kolkhozFontStyle.copyWith(
            color: tokens.colors.smoke,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
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
                          language.text(en: 'HOW TO PLAY', ru: 'КАК ИГРАТЬ'),
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
              label: language.text(en: 'Tutorial', ru: 'Обучение'),
              prominent: true,
              tokens: tokens,
              onPressed: onTutorialPressed,
              iconAsset: 'ios_resources/Icons/icon-tutorial.png',
              iconSize: 22,
            ),
          ),
        ),
      ],
    );
  }
}

class _OnlinePanel extends StatefulWidget {
  const _OnlinePanel({
    required this.tokens,
    required this.language,
    required this.onHostOnline,
    required this.onJoinOnline,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
  )
  onHostOnline;
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
  late final TextEditingController serverController;
  late final TextEditingController inviteController;
  _OnlineMode mode = _OnlineMode.host;
  List<_OnlineSeatChoice> seatChoices = const [
    _OnlineSeatChoice.local,
    _OnlineSeatChoice.ai,
    _OnlineSeatChoice.ai,
    _OnlineSeatChoice.ai,
  ];
  int preferredSeat = -1;
  bool busy = false;
  String? status;

  @override
  void initState() {
    super.initState();
    serverController = TextEditingController(text: 'http://127.0.0.1:8787');
    inviteController = TextEditingController();
  }

  @override
  void dispose() {
    serverController.dispose();
    inviteController.dispose();
    super.dispose();
  }

  Future<void> host() async {
    await runOnlineAction(() async {
      final sessionID = await widget.onHostOnline(
        parseServerURL(),
        hostControllers,
      );
      status = widget.language.text(
        en: 'Hosted $sessionID',
        ru: 'Создано $sessionID',
      );
    });
  }

  Future<void> join() async {
    await runOnlineAction(() async {
      await widget.onJoinOnline(
        parseServerURL(),
        inviteController.text.trim(),
        preferredSeat >= 0 ? preferredSeat : null,
      );
      status = widget.language.text(
        en: 'Joined ${inviteController.text.trim()}',
        ru: 'Вошли ${inviteController.text.trim()}',
      );
    });
  }

  Future<void> runOnlineAction(Future<void> Function() action) async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      status = null;
    });
    try {
      await action();
    } catch (exception) {
      if (mounted) {
        setState(() => status = '$exception');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Uri parseServerURL() {
    final uri = Uri.parse(serverController.text.trim());
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('Enter a full server URL.');
    }
    return uri;
  }

  List<KolkhozPlayerController> get hostControllers {
    return [
      for (var index = 0; index < kolkhozPlayerCount; index += 1)
        index == 0 || seatChoices[index] == _OnlineSeatChoice.open
            ? KolkhozPlayerController.human
            : KolkhozPlayerController.heuristicAI,
    ];
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
                      'ios_resources/Icons/icon-play-tap.png',
                      size: 26,
                    ),
                    Text(
                      widget.language.text(
                        en: 'ONLINE PLAY',
                        ru: 'ОНЛАЙН ИГРА',
                      ),
                      style: kolkhozFontStyle.copyWith(
                        color: widget.tokens.colors.gold,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                _VariantRowBackground(
                  tokens: widget.tokens,
                  active: false,
                  child: Text(
                    widget.language.text(
                      en: 'Host with AI seats or join by invite code.',
                      ru: 'Создайте стол с ИИ или войдите по коду.',
                    ),
                    style: kolkhozFontStyle.copyWith(
                      color: widget.tokens.colors.creamDim,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _OnlineModeSelector(
                  tokens: widget.tokens,
                  language: widget.language,
                  mode: mode,
                  onChanged: busy
                      ? null
                      : (value) => setState(() => mode = value),
                ),
                _OnlineTextField(
                  tokens: widget.tokens,
                  controller: serverController,
                  label: widget.language.text(
                    en: 'SERVER URL',
                    ru: 'АДРЕС СЕРВЕРА',
                  ),
                ),
                if (mode == _OnlineMode.host)
                  _OnlineSeatOptions(
                    tokens: widget.tokens,
                    language: widget.language,
                    choices: seatChoices,
                    onChanged: busy
                        ? null
                        : (index, value) {
                            setState(() {
                              final next = [...seatChoices];
                              next[index] = index == 0
                                  ? _OnlineSeatChoice.local
                                  : value;
                              seatChoices = next;
                            });
                          },
                  )
                else ...[
                  _OnlineTextField(
                    tokens: widget.tokens,
                    controller: inviteController,
                    label: widget.language.text(
                      en: 'INVITE CODE',
                      ru: 'КОД ПРИГЛАШЕНИЯ',
                    ),
                  ),
                  _PreferredSeatSelector(
                    tokens: widget.tokens,
                    language: widget.language,
                    selected: preferredSeat,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => preferredSeat = value),
                  ),
                ],
                if (status != null)
                  Text(
                    status!,
                    style: kolkhozFontStyle.copyWith(
                      color: widget.tokens.colors.creamDim,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 220,
            height: 44,
            child: Opacity(
              opacity: busy ? 0.55 : 1,
              child: ChromeAssetButton.command(
                label: busy
                    ? widget.language.text(en: 'Working...', ru: 'Идёт...')
                    : mode == _OnlineMode.host
                    ? widget.language.text(
                        en: 'Host & Play',
                        ru: 'Создать и играть',
                      )
                    : widget.language.text(
                        en: 'Join & Play',
                        ru: 'Войти и играть',
                      ),
                prominent: true,
                tokens: widget.tokens,
                onPressed: busy
                    ? null
                    : mode == _OnlineMode.host
                    ? host
                    : join,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _OnlineMode { host, join }

enum _OnlineSeatChoice { local, open, ai }

class _OnlineModeSelector extends StatelessWidget {
  const _OnlineModeSelector({
    required this.tokens,
    required this.language,
    required this.mode,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final _OnlineMode mode;
  final ValueChanged<_OnlineMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 6,
      children: [
        for (final option in _OnlineMode.values)
          Expanded(
            child: ChromeChoiceButton(
              tokens: tokens,
              label: option == _OnlineMode.host
                  ? language.text(en: 'Host', ru: 'Создать')
                  : language.text(en: 'Join', ru: 'Войти'),
              selected: mode == option,
              onPressed: onChanged == null ? null : () => onChanged!(option),
            ),
          ),
      ],
    );
  }
}

class _OnlineSeatOptions extends StatelessWidget {
  const _OnlineSeatOptions({
    required this.tokens,
    required this.language,
    required this.choices,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<_OnlineSeatChoice> choices;
  final void Function(int index, _OnlineSeatChoice value)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 7,
      children: [
        Text(
          language.text(en: 'SEATS', ru: 'МЕСТА'),
          style: kolkhozFontStyle.copyWith(
            color: tokens.colors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        for (var index = 0; index < kolkhozPlayerCount; index += 1)
          Row(
            spacing: 6,
            children: [
              SizedBox(
                width: 58,
                child: Text(
                  language.text(en: 'P${index + 1}', ru: 'И${index + 1}'),
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.creamDim,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (index == 0)
                Expanded(
                  child: ChromeChoiceButton(
                    tokens: tokens,
                    label: language.text(en: 'Local', ru: 'Здесь'),
                    selected: true,
                    onPressed: null,
                  ),
                )
              else
                for (final option in [
                  _OnlineSeatChoice.open,
                  _OnlineSeatChoice.ai,
                ])
                  Expanded(
                    child: ChromeChoiceButton(
                      tokens: tokens,
                      label: option == _OnlineSeatChoice.open
                          ? language.text(en: 'Open', ru: 'Открыто')
                          : language.text(en: 'AI', ru: 'ИИ'),
                      selected: choices[index] == option,
                      onPressed: onChanged == null
                          ? null
                          : () => onChanged!(index, option),
                    ),
                  ),
            ],
          ),
      ],
    );
  }
}

class _PreferredSeatSelector extends StatelessWidget {
  const _PreferredSeatSelector({
    required this.tokens,
    required this.language,
    required this.selected,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final int selected;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 6,
      children: [
        for (final value in [-1, 0, 1, 2, 3])
          Expanded(
            child: ChromeChoiceButton(
              tokens: tokens,
              label: value < 0
                  ? language.text(en: 'Any', ru: 'Любое')
                  : language.text(en: 'P${value + 1}', ru: 'И${value + 1}'),
              selected: selected == value,
              onPressed: onChanged == null ? null : () => onChanged!(value),
            ),
          ),
      ],
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

class _VariantRowData {
  _VariantRowData({
    required this.title,
    required this.ruTitle,
    required this.description,
    required this.ruDescription,
    required this.valueOf,
    required this.withValue,
    this.visibleInCustom = _alwaysVisible,
  });

  final String title;
  final String ruTitle;
  final String description;
  final String ruDescription;
  final bool Function(KolkhozGameVariants variants) valueOf;
  final KolkhozGameVariants Function(KolkhozGameVariants variants, bool value)
  withValue;
  final bool Function(KolkhozGameVariants variants) visibleInCustom;

  static final nomenclature = _VariantRowData(
    title: 'NOMENCLATURE',
    ruTitle: 'НОМЕНКЛАТУРА',
    description:
        'Trump face cards have special powers: Jack gets exiled, Queen exposes everyone, King doubles exile.',
    ruDescription:
        'Козырные фигуры имеют особые силы: Валет ссылается, Дама раскрывает всех, Король удваивает ссылку.',
    valueOf: (variants) => variants.nomenclature,
    withValue: (variants, value) => variants.copyWith(nomenclature: value),
  );
  static final allowSwap = _VariantRowData(
    title: 'SWAP',
    ruTitle: 'ОБМЕН',
    description:
        'Swap cards between your hand and plot at the start of each year.',
    ruDescription:
        'Обменивайте карты между рукой и участком в начале каждого года.',
    valueOf: (variants) => variants.allowSwap,
    withValue: (variants, value) => variants.copyWith(allowSwap: value),
  );
  static final northernStyle = _VariantRowData(
    title: 'NORTHERN STYLE',
    ruTitle: 'СЕВЕРНЫЙ СТИЛЬ',
    description: 'No rewards for completing jobs - everyone stays vulnerable.',
    ruDescription: 'Нет наград за работы - все остаются уязвимы.',
    valueOf: (variants) => variants.northernStyle,
    withValue: (variants, value) => variants.copyWith(northernStyle: value),
  );
  static final miceVariant = _VariantRowData(
    title: 'MICE',
    ruTitle: 'МЫШИ',
    description: 'All players reveal their entire plot during requisition.',
    ruDescription: 'Все игроки раскрывают весь участок при реквизиции.',
    valueOf: (variants) => variants.miceVariant,
    withValue: (variants, value) => variants.copyWith(miceVariant: value),
  );
  static final ordenNachalniku = _VariantRowData(
    title: 'ORDER TO THE BOSS',
    ruTitle: 'ОРДЕН НАЧАЛЬНИКУ',
    description: 'Cards assigned to completed jobs stack as bonus rewards.',
    ruDescription:
        'Карты, назначенные на выполненные работы, копятся как награды.',
    valueOf: (variants) => variants.ordenNachalniku,
    withValue: (variants, value) => variants.copyWith(ordenNachalniku: value),
    visibleInCustom: (variants) => variants.deckType == 36,
  );
  static final medalsCount = _VariantRowData(
    title: 'MEDALS',
    ruTitle: 'МЕДАЛИ',
    description: 'Trick victories count toward your final score.',
    ruDescription: 'Победы во взятках идут в итоговый счёт.',
    valueOf: (variants) => variants.medalsCount,
    withValue: (variants, value) => variants.copyWith(medalsCount: value),
  );
  static final heroOfSovietUnion = _VariantRowData(
    title: 'HERO',
    ruTitle: 'ГЕРОЙ',
    description:
        'Win all 4 tricks in a year to become immune from requisition.',
    ruDescription: 'Выиграйте все 4 взятки за год, чтобы получить иммунитет.',
    valueOf: (variants) => variants.heroOfSovietUnion,
    withValue: (variants, value) => variants.copyWith(heroOfSovietUnion: value),
  );
  static final accumulateJobs = _VariantRowData(
    title: 'ACCUMULATION',
    ruTitle: 'НАКОПЛЕНИЕ',
    description: 'Unclaimed job rewards carry over to the next year.',
    ruDescription:
        'Невостребованные награды за работы переносятся на следующий год.',
    valueOf: (variants) => variants.accumulateJobs,
    withValue: (variants, value) => variants.copyWith(accumulateJobs: value),
    visibleInCustom: (variants) => variants.deckType != 36,
  );
  static final wrecker = _VariantRowData(
    title: 'SABOTEUR',
    ruTitle: 'ВРЕДИТЕЛЬ',
    description:
        'Add a 14-value all-suit face card that sabotages its job at requisition.',
    ruDescription:
        'Добавляет фигуру со значением 14: она считается всеми мастями и проваливает свою работу при реквизиции.',
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

  String localizedTitle(KolkhozLanguage language) =>
      language.text(en: title, ru: ruTitle);

  String localizedDescription(KolkhozLanguage language) =>
      language.text(en: description, ru: ruDescription);
}

bool _alwaysVisible(KolkhozGameVariants variants) => true;

extension _ControllerLobbyLabels on KolkhozPlayerController {
  String shortTitle(KolkhozLanguage language) {
    return switch (this) {
      KolkhozPlayerController.human => language.text(en: 'Human', ru: 'Игрок'),
      KolkhozPlayerController.heuristicAI => language.text(
        en: 'Basic',
        ru: 'Базовый',
      ),
      KolkhozPlayerController.neuralAI => language.text(
        en: 'Neural',
        ru: 'Нейро',
      ),
    };
  }

  String get iconAsset {
    return switch (this) {
      KolkhozPlayerController.human =>
        'ios_resources/Icons/icon-human-seat.png',
      KolkhozPlayerController.heuristicAI =>
        'ios_resources/Icons/icon-basic-ai.png',
      KolkhozPlayerController.neuralAI =>
        'ios_resources/Icons/icon-neural-ai.png',
    };
  }
}

String presetTitle(KolkhozGamePreset preset, KolkhozLanguage language) {
  return switch (preset) {
    KolkhozGamePreset.kolkhoz => language.text(en: 'Kolkhoz', ru: 'Колхоз'),
    KolkhozGamePreset.littleKolkhoz => language.text(
      en: 'Little Kolkhoz',
      ru: 'Колхозик',
    ),
    KolkhozGamePreset.campStyle => language.text(
      en: 'Camp Style',
      ru: 'Лагерный',
    ),
    KolkhozGamePreset.custom => language.text(en: 'Custom', ru: 'Свой'),
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
