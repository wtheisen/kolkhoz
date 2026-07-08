import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../app_text.dart';
import '../chrome_button.dart';
import '../design_tokens.dart';
import '../game_constants.dart';
import '../pixel_text.dart';
import 'board_metrics.dart';
import 'board_widgets.dart';

const compactBoardToolbarCollapsedHeight = 56.0;
const compactBoardToolbarExpandedHeight = 94.0;

class BoardRail extends StatelessWidget {
  const BoardRail({
    required this.activePanel,
    required this.actionPanel,
    required this.tokens,
    required this.metrics,
    required this.language,
    required this.appearance,
    this.onPanelSelected,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    super.key,
  });

  final String activePanel;
  final String actionPanel;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final ValueChanged<String>? onPanelSelected;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    final buttons = boardRailButtons(
      activePanel: activePanel,
      actionPanel: actionPanel,
      tokens: tokens,
      metrics: metrics,
      language: language,
      appearance: appearance,
      onPanelSelected: onPanelSelected,
      onLanguageToggle: onLanguageToggle,
      onAppearanceToggle: onAppearanceToggle,
    );
    return Container(
      color: tokens.colors.table,
      padding: EdgeInsets.symmetric(
        horizontal: metrics.railHorizontalPadding,
        vertical: metrics.railVerticalPadding,
      ),
      child: Column(spacing: metrics.railSpacing, children: buttons),
    );
  }
}

class CompactBoardToolbar extends StatefulWidget {
  const CompactBoardToolbar({
    required this.activePanel,
    required this.actionPanel,
    required this.tokens,
    required this.metrics,
    required this.language,
    required this.appearance,
    this.onPanelSelected,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    super.key,
  });

  final String activePanel;
  final String actionPanel;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final ValueChanged<String>? onPanelSelected;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;

  @override
  State<CompactBoardToolbar> createState() => _CompactBoardToolbarState();
}

class _CompactBoardToolbarState extends State<CompactBoardToolbar> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final buttons = boardRailButtons(
      activePanel: widget.activePanel,
      actionPanel: widget.actionPanel,
      tokens: widget.tokens,
      metrics: widget.metrics,
      language: widget.language,
      appearance: widget.appearance,
      onPanelSelected: widget.onPanelSelected,
      onLanguageToggle: widget.onLanguageToggle,
      onAppearanceToggle: widget.onAppearanceToggle,
    );
    return Container(
      height: expanded
          ? compactBoardToolbarExpandedHeight
          : compactBoardToolbarCollapsedHeight,
      color: widget.tokens.colors.table,
      padding: EdgeInsets.symmetric(
        horizontal: widget.metrics.railHorizontalPadding,
        vertical: widget.metrics.railVerticalPadding,
      ),
      child: Column(
        spacing: 3,
        children: [
          GestureDetector(
            key: const Key('compact-toolbar-resize-handle'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => expanded = !expanded),
            child: SizedBox(
              height: expanded ? 18 : 8,
              child: Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.tokens.colors.gold.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: widget.metrics.railSpacing,
                children: [
                  for (var index = 0; index < buttons.length; index++)
                    expanded
                        ? CompactToolbarButtonLabel(
                            label: compactToolbarLabelForIndex(
                              index,
                              widget.language,
                              widget.appearance,
                            ),
                            tokens: widget.tokens,
                            child: buttons[index],
                          )
                        : buttons[index],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CompactToolbarButtonLabel extends StatelessWidget {
  const CompactToolbarButtonLabel({
    required this.label,
    required this.tokens,
    required this.child,
    super.key,
  });

  final String label;
  final DesignTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 2,
        children: [
          child,
          Flexible(
            child: ChromeScaledLabel(
              label,
              color: tokens.colors.creamDim,
              size: PixelTextSize.caption,
            ),
          ),
        ],
      ),
    );
  }
}

String compactToolbarLabelForIndex(
  int index,
  KolkhozLanguage language,
  KolkhozAppearance appearance,
) {
  return switch (index) {
    0 => language.t(KolkhozText.boardOptionspanelMenu),
    1 => language.t(KolkhozText.boardBoardrailBoard),
    2 => language.t(KolkhozText.boardBoardrailJobs),
    3 => language.t(KolkhozText.boardBoardrailNorth),
    4 => language.t(KolkhozText.boardBoardrailCellar),
    5 => language.t(KolkhozText.boardBoardrailLang),
    6 => appearance.label(language),
    _ => '',
  };
}

List<Widget> boardRailButtons({
  required String activePanel,
  required String actionPanel,
  required DesignTokens tokens,
  required ResponsiveBoardMetrics metrics,
  required KolkhozLanguage language,
  required KolkhozAppearance appearance,
  ValueChanged<String>? onPanelSelected,
  VoidCallback? onLanguageToggle,
  VoidCallback? onAppearanceToggle,
}) {
  return [
    RailButton(
      asset: 'icon-menu.png',
      active: activePanel == panelOptions,
      action: false,
      label: language.t(KolkhozText.boardOptionspanelMenu),
      muted: activePanel != panelOptions,
      tokens: tokens,
      metrics: metrics,
      onTap: () => onPanelSelected?.call(panelOptions),
    ),
    RailButton(
      asset: 'icon-brigade.png',
      active: activePanel == panelBrigade,
      action: actionPanel == panelBrigade,
      label: language.t(KolkhozText.boardBoardrailBrigade),
      muted: activePanel != panelBrigade,
      tokens: tokens,
      metrics: metrics,
      onTap: () => onPanelSelected?.call(panelBrigade),
    ),
    RailButton(
      asset: 'icon-jobs.png',
      active: activePanel == panelJobs,
      action: actionPanel == panelJobs,
      label: language.t(KolkhozText.boardBoardrailJobs),
      muted: activePanel != panelJobs,
      tokens: tokens,
      metrics: metrics,
      onTap: () => onPanelSelected?.call(panelJobs),
    ),
    RailButton(
      asset: 'icon-north.png',
      active: activePanel == panelNorth,
      action: actionPanel == panelNorth,
      label: language.t(KolkhozText.boardBoardrailTheNorth),
      muted: activePanel != panelNorth,
      motionKey: northCardMotionTargetKey,
      tokens: tokens,
      metrics: metrics,
      onTap: () => onPanelSelected?.call(panelNorth),
    ),
    RailButton(
      asset: 'icon-plot.png',
      active: activePanel == panelPlot,
      action: actionPanel == panelPlot,
      label: language.t(KolkhozText.boardBoardrailCellar),
      muted: activePanel != panelPlot,
      tokens: tokens,
      metrics: metrics,
      onTap: () => onPanelSelected?.call(panelPlot),
    ),
    RailButton(
      asset: language.toggleIconAsset,
      active: false,
      action: false,
      label: language.toggleTitle,
      tokens: tokens,
      metrics: metrics,
      onTap: onLanguageToggle,
    ),
    RailButton(
      asset: appearance.toggleIconAsset,
      active: false,
      action: false,
      label: appearance.toggleTitle(language),
      tokens: tokens,
      metrics: metrics,
      onTap: onAppearanceToggle,
    ),
  ];
}

class RailButton extends StatelessWidget {
  const RailButton({
    required this.asset,
    required this.active,
    required this.action,
    required this.label,
    required this.tokens,
    required this.metrics,
    this.muted = false,
    this.motionKey,
    this.onTap,
    super.key,
  });

  final String asset;
  final bool active;
  final bool action;
  final String label;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;
  final bool muted;
  final String? motionKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final button = Tooltip(
      message: label,
      child: Semantics(
        container: true,
        button: true,
        enabled: enabled,
        label: label,
        selected: active,
        onTap: onTap,
        child: ExcludeSemantics(
          child: FocusableActionDetector(
            enabled: enabled,
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  onTap?.call();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: SizedBox(
                width: metrics.railButtonSize,
                height: metrics.railButtonSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      if (active)
                        BoxShadow(
                          color: tokens.colors.red.withValues(alpha: 0.35),
                          blurRadius: _activeShadowRadius,
                          offset: const Offset(0, _activeShadowYOffset),
                        ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: ChromeButtonBackground(
                          asset: 'ios_resources/$backgroundAsset',
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: action ? _actionIconYOffset : 0,
                        ),
                        child: ChromeAssetIcon(
                          asset: 'ios_resources/Icons/$asset',
                          width: metrics.railIconSize,
                          height: metrics.railIconSize,
                          muted: muted,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.crop_square,
                            size: metrics.railIconSize,
                            color: active
                                ? tokens.colors.cream
                                : tokens.colors.creamDim,
                          ),
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
    final motionKey = this.motionKey;
    if (motionKey == null) {
      return button;
    }
    return MotionTrackedRegion(motionKey: motionKey, child: button);
  }

  String get backgroundAsset {
    return switch ((active, action)) {
      (true, true) => 'ui-nav-button-active-current.png',
      (false, true) => 'ui-nav-button-inactive-current.png',
      (true, false) => 'ui-nav-button-active.png',
      (false, false) => 'ui-nav-button-inactive.png',
    };
  }
}

const _actionIconYOffset = 2.0;
const _activeShadowRadius = 8.0;
const _activeShadowYOffset = 3.0;
