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
    required this.year,
    this.hasUnreadLogMessages = false,
    this.onPanelSelected,
    super.key,
  });

  final String activePanel;
  final String actionPanel;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;
  final KolkhozLanguage language;
  final int year;
  final bool hasUnreadLogMessages;
  final ValueChanged<String>? onPanelSelected;

  @override
  Widget build(BuildContext context) {
    final buttons = boardRailButtons(
      activePanel: activePanel,
      actionPanel: actionPanel,
      tokens: tokens,
      metrics: metrics,
      language: language,
      year: year,
      hasUnreadLogMessages: hasUnreadLogMessages,
      onPanelSelected: onPanelSelected,
    );
    return Container(
      color: tokens.colors.table,
      padding: EdgeInsets.symmetric(
        horizontal: metrics.railHorizontalPadding,
        vertical: metrics.railVerticalPadding,
      ),
      child: Column(
        children: [
          buttons.first,
          for (final button in buttons.skip(1).take(buttons.length - 2))
            Padding(
              padding: EdgeInsets.only(top: metrics.railSpacing),
              child: button,
            ),
          const Spacer(),
          buttons.last,
        ],
      ),
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
    required this.year,
    this.hasUnreadLogMessages = false,
    this.onPanelSelected,
    super.key,
  });

  final String activePanel;
  final String actionPanel;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;
  final KolkhozLanguage language;
  final int year;
  final bool hasUnreadLogMessages;
  final ValueChanged<String>? onPanelSelected;

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
      year: widget.year,
      hasUnreadLogMessages: widget.hasUnreadLogMessages,
      onPanelSelected: widget.onPanelSelected,
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
                              widget.year,
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
  int year,
) {
  return switch (index) {
    0 => language.t(KolkhozText.lowerbaractionsYearValue1, {'value1': year}),
    1 => language.t(KolkhozText.boardBoardrailBrigade),
    2 => language.t(KolkhozText.boardBoardrailJobs),
    3 => language.t(KolkhozText.boardBoardrailTheNorth),
    4 => language.t(KolkhozText.boardBoardrailCellar),
    5 => language == KolkhozLanguage.en ? 'Log' : 'Журнал',
    6 => language.t(KolkhozText.boardOptionspanelMenu),
    _ => '',
  };
}

List<Widget> boardRailButtons({
  required String activePanel,
  required String actionPanel,
  required DesignTokens tokens,
  required ResponsiveBoardMetrics metrics,
  required KolkhozLanguage language,
  required int year,
  bool hasUnreadLogMessages = false,
  ValueChanged<String>? onPanelSelected,
}) {
  return [
    RailStatusIcon(
      asset: 'icon-year-${year.clamp(1, 5)}.png',
      label: language.t(KolkhozText.lowerbaractionsYearValue1, {
        'value1': year,
      }),
      tokens: tokens,
      metrics: metrics,
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
      asset: 'icon-game-log.png',
      active: activePanel == panelLog,
      action: false,
      label: language == KolkhozLanguage.en ? 'Game Log' : 'Журнал игры',
      muted: activePanel != panelLog,
      unread: hasUnreadLogMessages,
      tokens: tokens,
      metrics: metrics,
      onTap: () => onPanelSelected?.call(panelLog),
    ),
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
  ];
}

class RailStatusIcon extends StatelessWidget {
  const RailStatusIcon({
    required this.asset,
    required this.label,
    required this.tokens,
    required this.metrics,
    super.key,
  });

  final String asset;
  final String label;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        container: true,
        image: true,
        label: label,
        child: ExcludeSemantics(
          child: SizedBox(
            width: metrics.railButtonSize,
            height: metrics.railButtonSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned.fill(
                  child: ChromeButtonBackground(
                    asset: 'assets/ui/ui-nav-button-inactive.png',
                  ),
                ),
                ChromeAssetIcon(
                  asset: 'assets/ui/Icons/$asset',
                  width: metrics.railIconSize,
                  height: metrics.railIconSize,
                ),
              ],
            ),
          ),
        ),
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
    this.unread = false,
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
  final bool unread;
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
                          asset: 'assets/ui/$backgroundAsset',
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: action ? _actionIconYOffset : 0,
                        ),
                        child: ChromeAssetIcon(
                          asset: 'assets/ui/Icons/$asset',
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
                      if (unread)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            key: const Key('game-log-unread-dot'),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: tokens.colors.redBright,
                              shape: BoxShape.circle,
                              border: Border.all(color: tokens.colors.cream),
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
