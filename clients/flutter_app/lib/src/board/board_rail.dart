import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../chrome_button.dart';
import '../design_tokens.dart';
import '../game_constants.dart';
import 'board_metrics.dart';

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
    return Container(
      color: tokens.colors.table,
      padding: EdgeInsets.symmetric(
        horizontal: metrics.railHorizontalPadding,
        vertical: metrics.railVerticalPadding,
      ),
      child: Column(
        spacing: metrics.railSpacing,
        children: [
          RailButton(
            asset: 'icon-menu.png',
            active: activePanel == panelOptions,
            action: false,
            label: language.text(en: 'Menu', ru: 'Меню'),
            muted: activePanel != panelOptions,
            tokens: tokens,
            metrics: metrics,
            onTap: () => onPanelSelected?.call(panelOptions),
          ),
          RailButton(
            asset: 'icon-brigade.png',
            active: activePanel == panelBrigade,
            action: actionPanel == panelBrigade,
            label: language.text(en: 'Brigade', ru: 'Бригада'),
            muted: activePanel != panelBrigade,
            tokens: tokens,
            metrics: metrics,
            onTap: () => onPanelSelected?.call(panelBrigade),
          ),
          RailButton(
            asset: 'icon-jobs.png',
            active: activePanel == panelJobs,
            action: actionPanel == panelJobs,
            label: language.text(en: 'Jobs', ru: 'Работы'),
            muted: activePanel != panelJobs,
            tokens: tokens,
            metrics: metrics,
            onTap: () => onPanelSelected?.call(panelJobs),
          ),
          RailButton(
            asset: 'icon-north.png',
            active: activePanel == panelNorth,
            action: actionPanel == panelNorth,
            label: language.text(en: 'The North', ru: 'Север'),
            muted: activePanel != panelNorth,
            tokens: tokens,
            metrics: metrics,
            onTap: () => onPanelSelected?.call(panelNorth),
          ),
          RailButton(
            asset: 'icon-plot.png',
            active: activePanel == panelPlot,
            action: actionPanel == panelPlot,
            label: language.text(en: 'Cellar', ru: 'Подвал'),
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
            asset: 'icon-appearance.png',
            active: false,
            action: false,
            label: appearance.toggleTitle(language),
            tokens: tokens,
            metrics: metrics,
            onTap: onAppearanceToggle,
          ),
        ],
      ),
    );
  }
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
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
                        child: Image.asset(
                          'ios_resources/$backgroundAsset',
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.none,
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
