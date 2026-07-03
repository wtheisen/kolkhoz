import 'package:flutter/material.dart';

import 'c_engine_bridge.dart';
import 'design_tokens.dart';
import 'game_constants.dart';
import 'board_view.dart';
import 'live_game_store.dart';
import 'pixel_text.dart';

class KolkhozApp extends StatefulWidget {
  const KolkhozApp({super.key});

  @override
  State<KolkhozApp> createState() => _KolkhozAppState();
}

class _KolkhozAppState extends State<KolkhozApp> {
  late final LiveGameStore store;
  bool showingLobby = true;
  bool showingRules = false;
  bool showingOnline = false;
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
    store = LiveGameStore();
  }

  @override
  void dispose() {
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
          final tokens = store.tokens;
          if (store.error != null && store.model == null) {
            return StandaloneErrorView(error: store.error!, tokens: tokens);
          }
          final model = store.model;
          if (model == null || showingLobby) {
            return StandaloneLobby(
              tokens: tokens,
              error: store.error,
              selectedPreset: selectedPreset,
              customVariants: customVariants,
              playerControllers: playerControllers,
              showingRules: showingRules,
              showingOnline: showingOnline,
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
                  showingRules = !(showingRules || showingOnline);
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
                setState(() {
                  showingRules = true;
                  showingOnline = false;
                });
              },
            );
          }
          return Stack(
            children: [
              KolkhozBoard(
                model: model,
                tokens: tokens,
                onAction: store.applyLegalAction,
                onPanelSelected: store.setActivePanel,
                onSwapHandCardTap: store.selectSwapHandCard,
                onPlotCardTap: store.selectPlotCard,
                onAssignmentCardTap: store.selectAssignmentCard,
              ),
              Positioned(
                left: 10,
                top: 10,
                child: SafeArea(
                  child: StandaloneMenuButton(
                    tokens: tokens,
                    onPressed: () => setState(() => showingLobby = true),
                  ),
                ),
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
        },
      ),
    );
  }
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
    required this.onStart,
    required this.selectedPreset,
    required this.customVariants,
    required this.playerControllers,
    required this.showingRules,
    required this.showingOnline,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
    required this.onRulesPressed,
    required this.onOnlinePressed,
    required this.onTutorialPressed,
    this.error,
    super.key,
  });

  final DesignTokens tokens;
  final VoidCallback onStart;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final bool showingRules;
  final bool showingOnline;
  final ValueChanged<KolkhozGamePreset> onPresetChanged;
  final ValueChanged<KolkhozGameVariants> onCustomVariantsChanged;
  final ValueChanged<List<KolkhozPlayerController>> onPlayerControllersChanged;
  final VoidCallback onRulesPressed;
  final VoidCallback onOnlinePressed;
  final VoidCallback onTutorialPressed;
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
                  showingPanel: showingRules || showingOnline,
                  onStart: onStart,
                  onOnlinePressed: onOnlinePressed,
                  onTutorialPressed: onTutorialPressed,
                  onRulesPressed: onRulesPressed,
                ),
              );
              final panel = SizedBox(
                width: panelWidth,
                height: panelHeight,
                child: _LobbyPanel(
                  tokens: tokens,
                  selectedPreset: selectedPreset,
                  customVariants: customVariants,
                  playerControllers: playerControllers,
                  variants: activeVariants,
                  showingRules: showingRules,
                  showingOnline: showingOnline,
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
    required this.showingPanel,
    required this.onStart,
    required this.onOnlinePressed,
    required this.onTutorialPressed,
    required this.onRulesPressed,
  });

  final DesignTokens tokens;
  final bool showingPanel;
  final VoidCallback onStart;
  final VoidCallback onOnlinePressed;
  final VoidCallback onTutorialPressed;
  final VoidCallback onRulesPressed;

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
              showingPanel: showingPanel,
              onStart: onStart,
              onOnlinePressed: onOnlinePressed,
              onTutorialPressed: onTutorialPressed,
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
            _LobbyFooter(tokens: tokens),
          ],
        );
      },
    );
  }
}

class _LobbyButtonStack extends StatelessWidget {
  const _LobbyButtonStack({
    required this.tokens,
    required this.showingPanel,
    required this.onStart,
    required this.onOnlinePressed,
    required this.onTutorialPressed,
    required this.onRulesPressed,
  });

  final DesignTokens tokens;
  final bool showingPanel;
  final VoidCallback onStart;
  final VoidCallback onOnlinePressed;
  final VoidCallback onTutorialPressed;
  final VoidCallback onRulesPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 9,
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: StandaloneCommandButton(
            label: 'Start Game',
            prominent: true,
            tokens: tokens,
            onPressed: onStart,
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: StandaloneCommandButton(
            label: 'Online Play',
            prominent: false,
            tokens: tokens,
            onPressed: onOnlinePressed,
            iconAsset: 'ios_resources/Icons/icon-play-tap.png',
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: StandaloneCommandButton(
            label: 'How to Play',
            prominent: false,
            tokens: tokens,
            onPressed: onTutorialPressed,
            iconAsset: 'ios_resources/Icons/icon-tutorial.png',
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: StandaloneCommandButton(
            label: showingPanel ? 'Options' : 'Rules',
            prominent: false,
            tokens: tokens,
            onPressed: onRulesPressed,
          ),
        ),
      ],
    );
  }
}

class _LobbyFooter extends StatelessWidget {
  const _LobbyFooter({required this.tokens});

  final DesignTokens tokens;

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
              label: 'EN',
              iconAsset: 'ios_resources/Icons/icon-language-en.png',
            ),
            _SmallChromeButton(
              tokens: tokens,
              label: 'DARK',
              iconAsset: 'ios_resources/Icons/icon-appearance.png',
            ),
          ],
        ),
        _SmallChromeButton(
          tokens: tokens,
          label: 'STANDARD',
          iconAsset: 'ios_resources/Icons/icon-gears.png',
          wide: true,
        ),
        Column(
          spacing: 2,
          children: [
            Text(
              'GAME BY',
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'WILLIAM THEISEN',
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
    this.wide = false,
  });

  final DesignTokens tokens;
  final String label;
  final String iconAsset;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 126 : 60,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 5,
        children: [
          Image.asset(
            iconAsset,
            width: 15,
            height: 15,
            filterQuality: FilterQuality.none,
          ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.creamDim,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyPanel extends StatelessWidget {
  const _LobbyPanel({
    required this.tokens,
    required this.selectedPreset,
    required this.customVariants,
    required this.playerControllers,
    required this.variants,
    required this.showingRules,
    required this.showingOnline,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
  });

  final DesignTokens tokens;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final KolkhozGameVariants variants;
  final bool showingRules;
  final bool showingOnline;
  final ValueChanged<KolkhozGamePreset> onPresetChanged;
  final ValueChanged<KolkhozGameVariants> onCustomVariantsChanged;
  final ValueChanged<List<KolkhozPlayerController>> onPlayerControllersChanged;

  @override
  Widget build(BuildContext context) {
    return _PanelSurface(
      tokens: tokens,
      child: showingOnline
          ? _OnlinePanel(tokens: tokens)
          : showingRules
          ? _RulesPanel(tokens: tokens)
          : _VariantPanel(
              tokens: tokens,
              selectedPreset: selectedPreset,
              customVariants: customVariants,
              playerControllers: playerControllers,
              variants: variants,
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
    required this.selectedPreset,
    required this.customVariants,
    required this.playerControllers,
    required this.variants,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
  });

  final DesignTokens tokens;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final KolkhozGameVariants variants;
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
          selectedPreset: selectedPreset,
          onPresetChanged: onPresetChanged,
        ),
        _GoldDivider(tokens: tokens),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                _SeatControllerOptions(
                  tokens: tokens,
                  controllers: playerControllers,
                  onChanged: onPlayerControllersChanged,
                ),
                _GoldDivider(tokens: tokens, opacity: 0.28),
                if (selectedPreset == KolkhozGamePreset.custom)
                  _CustomVariantOptions(
                    tokens: tokens,
                    variants: customVariants,
                    onChanged: onCustomVariantsChanged,
                  )
                else
                  _PresetSummary(tokens: tokens, variants: variants),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PresetSelector extends StatelessWidget {
  const _PresetSelector({
    required this.tokens,
    required this.selectedPreset,
    required this.onPresetChanged,
  });

  final DesignTokens tokens;
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
              label: preset.title,
              selected: selectedPreset == preset,
              onPressed: () => onPresetChanged(preset),
            ),
          ),
      ],
    );
  }
}

class _SeatControllerOptions extends StatelessWidget {
  const _SeatControllerOptions({
    required this.tokens,
    required this.controllers,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final List<KolkhozPlayerController> controllers;
  final ValueChanged<List<KolkhozPlayerController>> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = KolkhozPlayerController.normalized(controllers);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 7,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: tokens.colors.black.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: tokens.colors.gold.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            spacing: 7,
            children: [
              _AssetIcon('ios_resources/Icons/icon-brigade.png'),
              Text(
                'SEATS',
                style: kolkhozFontStyle.copyWith(
                  color: tokens.colors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              _AssetIcon('ios_resources/Icons/icon-neural-badge.png'),
              Flexible(
                child: Text(
                  'LOCAL / AI',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.creamDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var playerID = 0; playerID < kolkhozPlayerCount; playerID += 1)
          _SeatControllerRow(
            tokens: tokens,
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

class _SeatControllerRow extends StatelessWidget {
  const _SeatControllerRow({
    required this.tokens,
    required this.playerID,
    required this.controller,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final int playerID;
  final KolkhozPlayerController controller;
  final ValueChanged<KolkhozPlayerController> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = controller == KolkhozPlayerController.human;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: active
              ? [
                  tokens.colors.gold.withValues(alpha: 0.10),
                  tokens.colors.redDark.withValues(alpha: 0.08),
                ]
              : [
                  tokens.colors.black.withValues(alpha: 0.28),
                  tokens.colors.iron.withValues(alpha: 0.18),
                ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active
              ? tokens.colors.gold.withValues(alpha: 0.36)
              : tokens.colors.steel.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        spacing: 9,
        children: [
          _SeatBadge(tokens: tokens, playerID: playerID, active: active),
          Expanded(
            child: Row(
              spacing: 5,
              children: [
                for (final option in KolkhozPlayerController.values)
                  Expanded(
                    child: _ImageTabButton(
                      tokens: tokens,
                      label: option.shortTitle,
                      iconAsset: option.iconAsset,
                      selected: controller == option,
                      onPressed: () => onChanged(option),
                      height: 44,
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

class _SeatBadge extends StatelessWidget {
  const _SeatBadge({
    required this.tokens,
    required this.playerID,
    required this.active,
  });

  final DesignTokens tokens;
  final int playerID;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 44,
      decoration: BoxDecoration(
        color: active
            ? tokens.colors.redDark.withValues(alpha: 0.38)
            : tokens.colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active
              ? tokens.colors.gold.withValues(alpha: 0.52)
              : tokens.colors.steel.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 1,
        children: [
          Text(
            'P${playerID + 1}',
            style: kolkhozFontStyle.copyWith(
              color: active ? tokens.colors.goldBright : tokens.colors.creamDim,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          _AssetIcon(
            active
                ? 'ios_resources/Icons/icon-human-seat.png'
                : 'ios_resources/Icons/icon-basic-ai.png',
            size: 14,
            opacity: active ? 1 : 0.62,
          ),
        ],
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
    this.iconAsset,
    this.height = 48,
  });

  final DesignTokens tokens;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final String? iconAsset;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              selected
                  ? 'ios_resources/ui-tab-selected.png'
                  : 'ios_resources/ui-tab-unselected.png',
            ),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
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
        ),
        padding: const EdgeInsets.fromLTRB(10, 3, 10, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 5,
          children: [
            if (iconAsset != null)
              _AssetIcon(iconAsset!, size: 15, opacity: selected ? 1 : 0.62),
            Expanded(
              child: _PixelChromeLabel(
                label.toUpperCase(),
                color: selected
                    ? tokens.colors.onAccent
                    : tokens.colors.cardInk,
                size: iconAsset == null
                    ? PixelTextSize.caption
                    : PixelTextSize.caption2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetSummary extends StatelessWidget {
  const _PresetSummary({required this.tokens, required this.variants});

  final DesignTokens tokens;
  final KolkhozGameVariants variants;

  @override
  Widget build(BuildContext context) {
    final rows = _VariantRowData.enabledRows(variants);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        _DeckSummary(tokens: tokens, deckType: variants.deckType),
        for (final row in rows) _VariantReadOnlyRow(tokens: tokens, row: row),
      ],
    );
  }
}

class _CustomVariantOptions extends StatelessWidget {
  const _CustomVariantOptions({
    required this.tokens,
    required this.variants,
    required this.onChanged,
  });

  final DesignTokens tokens;
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
                label: '52 cards',
                selected: variants.deckType == 52,
                onPressed: () => onChanged(
                  variants.copyWith(deckType: 52, ordenNachalniku: false),
                ),
              ),
            ),
            Expanded(
              child: _ImageTabButton(
                tokens: tokens,
                label: '36 cards',
                selected: variants.deckType == 36,
                onPressed: () => onChanged(
                  variants.copyWith(deckType: 36, accumulateJobs: false),
                ),
              ),
            ),
          ],
        ),
        _VariantToggleRow(
          tokens: tokens,
          row: _VariantRowData.nomenclature,
          value: variants.nomenclature,
          onChanged: (value) =>
              onChanged(variants.copyWith(nomenclature: value)),
        ),
        _VariantToggleRow(
          tokens: tokens,
          row: _VariantRowData.allowSwap,
          value: variants.allowSwap,
          onChanged: (value) => onChanged(variants.copyWith(allowSwap: value)),
        ),
        _VariantToggleRow(
          tokens: tokens,
          row: _VariantRowData.northernStyle,
          value: variants.northernStyle,
          onChanged: (value) =>
              onChanged(variants.copyWith(northernStyle: value)),
        ),
        _VariantToggleRow(
          tokens: tokens,
          row: _VariantRowData.miceVariant,
          value: variants.miceVariant,
          onChanged: (value) =>
              onChanged(variants.copyWith(miceVariant: value)),
        ),
        if (variants.deckType == 36)
          _VariantToggleRow(
            tokens: tokens,
            row: _VariantRowData.ordenNachalniku,
            value: variants.ordenNachalniku,
            onChanged: (value) =>
                onChanged(variants.copyWith(ordenNachalniku: value)),
          ),
        _VariantToggleRow(
          tokens: tokens,
          row: _VariantRowData.medalsCount,
          value: variants.medalsCount,
          onChanged: (value) =>
              onChanged(variants.copyWith(medalsCount: value)),
        ),
        _VariantToggleRow(
          tokens: tokens,
          row: _VariantRowData.heroOfSovietUnion,
          value: variants.heroOfSovietUnion,
          onChanged: (value) =>
              onChanged(variants.copyWith(heroOfSovietUnion: value)),
        ),
        if (variants.deckType != 36)
          _VariantToggleRow(
            tokens: tokens,
            row: _VariantRowData.accumulateJobs,
            value: variants.accumulateJobs,
            onChanged: (value) =>
                onChanged(variants.copyWith(accumulateJobs: value)),
          ),
      ],
    );
  }
}

class _DeckSummary extends StatelessWidget {
  const _DeckSummary({required this.tokens, required this.deckType});

  final DesignTokens tokens;
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
            'DECK',
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.creamDim,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '$deckType CARDS',
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
  const _VariantReadOnlyRow({required this.tokens, required this.row});

  final DesignTokens tokens;
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
            child: _VariantText(tokens: tokens, row: row),
          ),
        ],
      ),
    );
  }
}

class _VariantToggleRow extends StatelessWidget {
  const _VariantToggleRow({
    required this.tokens,
    required this.row,
    required this.value,
    required this.onChanged,
  });

  final DesignTokens tokens;
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
            child: _VariantText(tokens: tokens, row: row),
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
  const _VariantText({required this.tokens, required this.row});

  final DesignTokens tokens;
  final _VariantRowData row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          row.title,
          style: kolkhozFontStyle.copyWith(
            color: tokens.colors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          row.description,
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
  const _RulesPanel({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            spacing: 8,
            children: [
              const _AssetIcon(
                'ios_resources/Icons/icon-rules-scroll.png',
                size: 26,
              ),
              Text(
                'RULES',
                style: kolkhozFontStyle.copyWith(
                  color: tokens.colors.gold,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Center(
            child: Image.asset(
              'ios_resources/Embellishments/art-rules-divider.png',
              height: 44,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ),
          _RuleBlock(
            tokens: tokens,
            title: 'Objective',
            body:
                'Complete collective farm jobs while protecting your private plot. Highest score wins!',
          ),
          _RuleBlock(
            tokens: tokens,
            title: 'Gameplay',
            body: 'Play cards to tricks - must follow lead suit if able.',
          ),
          _RuleBlock(
            tokens: tokens,
            title: 'Jobs',
            body: 'Jobs need 40 work hours to complete.',
          ),
          _RuleBlock(
            tokens: tokens,
            title: 'Trump Face Cards',
            body:
                'Jack, Queen, and King have special powers in nomenclature games.',
          ),
          _RuleBlock(
            tokens: tokens,
            title: 'Scoring',
            body: 'Cards in your plot equal your score. Highest score wins.',
          ),
        ],
      ),
    );
  }
}

class _OnlinePanel extends StatelessWidget {
  const _OnlinePanel({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                'ONLINE PLAY',
                style: kolkhozFontStyle.copyWith(
                  color: tokens.colors.gold,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          _VariantRowBackground(
            tokens: tokens,
            active: false,
            child: Text(
              'Host with AI seats or join by invite code.',
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.creamDim,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _DisabledOnlineField(tokens: tokens, label: 'SERVER URL'),
          _DisabledOnlineField(tokens: tokens, label: 'INVITE CODE'),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: Opacity(
              opacity: 0.45,
              child: StandaloneCommandButton(
                label: 'Host & Play',
                prominent: true,
                tokens: tokens,
                onPressed: null,
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: Opacity(
              opacity: 0.45,
              child: StandaloneCommandButton(
                label: 'Join & Play',
                prominent: false,
                tokens: tokens,
                onPressed: null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisabledOnlineField extends StatelessWidget {
  const _DisabledOnlineField({required this.tokens, required this.label});

  final DesignTokens tokens;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.creamDim.withValues(alpha: 0.62),
          fontSize: 12,
          fontWeight: FontWeight.w800,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(
          title.toUpperCase(),
          style: kolkhozFontStyle.copyWith(
            color: tokens.colors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          body,
          style: kolkhozFontStyle.copyWith(
            color: tokens.colors.creamDim,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _GoldDivider extends StatelessWidget {
  const _GoldDivider({required this.tokens, this.opacity = 0.35});

  final DesignTokens tokens;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: tokens.colors.gold.withValues(alpha: opacity),
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
  const _VariantRowData({
    required this.key,
    required this.title,
    required this.description,
  });

  final String key;
  final String title;
  final String description;

  static const nomenclature = _VariantRowData(
    key: 'nomenclature',
    title: 'NOMENCLATURE',
    description:
        'Trump face cards have special powers: Jack gets exiled, Queen exposes everyone, King doubles exile.',
  );
  static const allowSwap = _VariantRowData(
    key: 'allowSwap',
    title: 'SWAP',
    description:
        'Swap cards between your hand and plot at the start of each year.',
  );
  static const northernStyle = _VariantRowData(
    key: 'northernStyle',
    title: 'NORTHERN STYLE',
    description: 'No rewards for completing jobs - everyone stays vulnerable.',
  );
  static const miceVariant = _VariantRowData(
    key: 'miceVariant',
    title: 'MICE',
    description: 'All players reveal their entire plot during requisition.',
  );
  static const ordenNachalniku = _VariantRowData(
    key: 'ordenNachalniku',
    title: 'ORDER TO THE BOSS',
    description: 'Cards assigned to completed jobs stack as bonus rewards.',
  );
  static const medalsCount = _VariantRowData(
    key: 'medalsCount',
    title: 'MEDALS',
    description: 'Trick victories count toward your final score.',
  );
  static const heroOfSovietUnion = _VariantRowData(
    key: 'heroOfSovietUnion',
    title: 'HERO',
    description:
        'Win all 4 tricks in a year to become immune from requisition.',
  );
  static const accumulateJobs = _VariantRowData(
    key: 'accumulateJobs',
    title: 'ACCUMULATION',
    description: 'Unclaimed job rewards carry over to the next year.',
  );

  static List<_VariantRowData> enabledRows(KolkhozGameVariants variants) {
    return [
      if (variants.nomenclature) nomenclature,
      if (variants.allowSwap) allowSwap,
      if (variants.northernStyle) northernStyle,
      if (variants.miceVariant) miceVariant,
      if (variants.ordenNachalniku) ordenNachalniku,
      if (variants.medalsCount) medalsCount,
      if (variants.heroOfSovietUnion) heroOfSovietUnion,
      if (variants.accumulateJobs) accumulateJobs,
    ];
  }
}

extension _ControllerLobbyLabels on KolkhozPlayerController {
  String get shortTitle {
    return switch (this) {
      KolkhozPlayerController.human => 'Human',
      KolkhozPlayerController.heuristicAI => 'Basic',
      KolkhozPlayerController.neuralAI => 'Neural',
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

class StandaloneMenuButton extends StatelessWidget {
  const StandaloneMenuButton({
    required this.tokens,
    required this.onPressed,
    super.key,
  });

  final DesignTokens tokens;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Menu',
      child: IconButton(
        onPressed: onPressed,
        icon: Image.asset(
          'ios_resources/Icons/icon-menu.png',
          width: 26,
          height: 26,
          filterQuality: FilterQuality.none,
        ),
        style: IconButton.styleFrom(
          backgroundColor: tokens.colors.black.withValues(alpha: 0.62),
          foregroundColor: tokens.colors.gold,
          side: BorderSide(color: tokens.colors.gold.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

class StandaloneCommandButton extends StatelessWidget {
  const StandaloneCommandButton({
    required this.label,
    required this.prominent,
    required this.tokens,
    required this.onPressed,
    this.iconAsset,
    super.key,
  });

  final String label;
  final bool prominent;
  final DesignTokens tokens;
  final VoidCallback? onPressed;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              prominent
                  ? 'ios_resources/ui-button-primary.png'
                  : 'ios_resources/ui-button-secondary.png',
            ),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            if (iconAsset != null)
              Image.asset(
                iconAsset!,
                width: 20,
                height: 20,
                filterQuality: FilterQuality.none,
              ),
            Expanded(
              child: _PixelChromeLabel(
                label.toUpperCase(),
                color: prominent
                    ? tokens.colors.onAccent
                    : tokens.colors.cardInk,
                size: PixelTextSize.headline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PixelChromeLabel extends StatelessWidget {
  const _PixelChromeLabel(this.text, {required this.color, required this.size});

  final String text;
  final Color color;
  final PixelTextSize size;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: PixelText(
        text,
        size: size,
        variant: PixelTextVariant.heavy,
        color: color,
        textAlign: TextAlign.center,
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
