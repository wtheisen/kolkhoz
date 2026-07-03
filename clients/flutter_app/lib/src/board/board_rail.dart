import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../game_constants.dart';
import 'board_metrics.dart';

class BoardRail extends StatelessWidget {
  const BoardRail({
    required this.activePanel,
    required this.actionPanel,
    required this.tokens,
    required this.metrics,
    this.onPanelSelected,
    super.key,
  });

  final String activePanel;
  final String actionPanel;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;
  final ValueChanged<String>? onPanelSelected;

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
            label: 'Menu',
            muted: activePanel != panelOptions,
            tokens: tokens,
            metrics: metrics,
            onTap: () => onPanelSelected?.call(panelOptions),
          ),
          RailButton(
            asset: 'icon-brigade.png',
            active: activePanel == panelBrigade,
            action: actionPanel == panelBrigade,
            label: 'Brigade',
            muted: activePanel != panelBrigade,
            tokens: tokens,
            metrics: metrics,
            onTap: () => onPanelSelected?.call(panelBrigade),
          ),
          RailButton(
            asset: 'icon-jobs.png',
            active: activePanel == panelJobs,
            action: actionPanel == panelJobs,
            label: 'Jobs',
            muted: activePanel != panelJobs,
            tokens: tokens,
            metrics: metrics,
            onTap: () => onPanelSelected?.call(panelJobs),
          ),
          RailButton(
            asset: 'icon-north.png',
            active: activePanel == panelNorth,
            action: actionPanel == panelNorth,
            label: 'The North',
            muted: activePanel != panelNorth,
            tokens: tokens,
            metrics: metrics,
            onTap: () => onPanelSelected?.call(panelNorth),
          ),
          RailButton(
            asset: 'icon-plot.png',
            active: activePanel == panelPlot,
            action: actionPanel == panelPlot,
            label: 'Cellar',
            muted: activePanel != panelPlot,
            tokens: tokens,
            metrics: metrics,
            onTap: () => onPanelSelected?.call(panelPlot),
          ),
          RailButton(
            asset: 'icon-language-ru.png',
            active: false,
            action: false,
            label: 'Language',
            tokens: tokens,
            metrics: metrics,
          ),
          RailButton(
            asset: 'icon-appearance.png',
            active: false,
            action: false,
            label: 'Appearance',
            tokens: tokens,
            metrics: metrics,
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
    return Tooltip(
      message: label,
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
                  child: Opacity(
                    opacity: muted ? _iconMutedOpacity : 1,
                    child: muted
                        ? ColorFiltered(
                            colorFilter: const ColorFilter.matrix(
                              _iconMutedSaturationMatrix,
                            ),
                            child: iconImage(),
                          )
                        : iconImage(),
                  ),
                ),
              ],
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

  Widget iconImage() {
    return Image.asset(
      'ios_resources/Icons/$asset',
      width: metrics.railIconSize,
      height: metrics.railIconSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, _, _) => Icon(
        Icons.crop_square,
        size: metrics.railIconSize,
        color: active ? tokens.colors.cream : tokens.colors.creamDim,
      ),
    );
  }
}

const _actionIconYOffset = 2.0;
const _activeShadowRadius = 8.0;
const _activeShadowYOffset = 3.0;
const _iconMutedOpacity = 0.82;
const _iconMutedSaturationMatrix = <double>[
  0.76378,
  0.21456,
  0.02166,
  0,
  0,
  0.06378,
  0.91456,
  0.02166,
  0,
  0,
  0.06378,
  0.21456,
  0.72166,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];
