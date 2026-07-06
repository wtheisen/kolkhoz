import 'dart:math' as math;
import 'dart:ui' show clampDouble, lerpDouble;

import 'package:flutter/material.dart';

import 'animation_speed.dart';
import 'app_settings.dart';
import 'brigade_display.dart';
import 'chrome_button.dart';
import 'render_model.dart';
import 'design_tokens.dart';
import 'game_constants.dart';
import 'hot_seat_display.dart';
import 'phase_display.dart';
import 'pixel_text.dart';
import 'player_panel_display.dart';
import 'trump_actions.dart';
import 'table_display.dart';
import 'table_projection_helpers.dart';
import 'board/board_chrome.dart';
import 'board/board_metrics.dart';
import 'board/board_rail.dart';
import 'board/board_widgets.dart';
import 'board/hand_tray.dart';
import 'board/jobs_panel.dart';
import 'board/north_panel.dart';
import 'board/options_panel.dart';
import 'board/plot_panel.dart';

export 'board/board_chrome.dart';
export 'board/board_metrics.dart';
export 'board/board_rail.dart';
export 'board/board_widgets.dart';
export 'board/hand_tray.dart';
export 'board/jobs_panel.dart';
export 'board/north_panel.dart';
export 'board/options_panel.dart';
export 'board/plot_panel.dart';
export 'chrome_button.dart';

BoxDecoration boardBackdropDecoration(DesignTokens tokens) {
  return BoxDecoration(color: tokens.colors.table);
}

BoxDecoration playAreaBackdropDecoration(DesignTokens tokens) {
  return BoxDecoration(
    color: tokens.colors.table,
    borderRadius: BorderRadius.circular(playAreaPanelCornerRadius),
  );
}

const double boardContentWidthMax = 1320;

double boardPlayableContentWidth(double contentWidth) {
  return math.min(contentWidth, boardContentWidthMax).toDouble();
}

class KolkhozBoard extends StatelessWidget {
  const KolkhozBoard({
    required this.model,
    required this.tokens,
    required this.language,
    required this.appearance,
    this.onAction,
    this.onPanelSelected,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    this.onSwapHandCardTap,
    this.onPlotCardTap,
    this.onAssignmentCardTap,
    this.onInvalidHandCardTap,
    this.onHotSeatReady,
    this.onNewGame,
    this.onReturnToLobby,
    this.onTutorial,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final ValueChanged<LegalAction>? onAction;
  final ValueChanged<String>? onPanelSelected;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;
  final ValueChanged<String>? onSwapHandCardTap;
  final void Function(String cardID, String zone)? onPlotCardTap;
  final ValueChanged<String>? onAssignmentCardTap;
  final VoidCallback? onInvalidHandCardTap;
  final VoidCallback? onHotSeatReady;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onTutorial;
  final GameAnimationSpeed animationSpeed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: kolkhozFontStyle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = ResponsiveBoardMetrics.fromSize(
            constraints.biggest,
            tokens,
          );
          final margin = metrics.margin;
          final contentWidth = constraints.maxWidth - margin * 2;
          final contentHeight = constraints.maxHeight - margin * 2;
          final boardWidth = boardPlayableContentWidth(contentWidth);
          final railWidth = metrics.railWidth(boardWidth);
          final separatorWidth = metrics.separatorWidth;
          final gameWidth = boardWidth - railWidth - separatorWidth;
          final safePadding = MediaQuery.paddingOf(context);

          return DecoratedBox(
            decoration: boardBackdropDecoration(tokens),
            child: CardMotionLayer(
              model: model,
              tokens: tokens,
              speed: animationSpeed,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  if (safePadding.left > 0)
                    Positioned(
                      left: boardLeftGutterOffset(safePadding.left),
                      top: 0,
                      bottom: 0,
                      child: BoardGutterInfill(
                        side: BoardGutterInfillSide.left,
                        width: boardLeftGutterWidth(safePadding.left),
                        light: appearance == KolkhozAppearance.light,
                      ),
                    ),
                  if (safePadding.right > 0)
                    Positioned(
                      right: boardRightGutterOffset(safePadding.right),
                      top: 0,
                      bottom: 0,
                      child: BoardGutterInfill(
                        side: BoardGutterInfillSide.right,
                        width: boardRightGutterWidth(safePadding.right),
                        light: appearance == KolkhozAppearance.light,
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.all(margin),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: boardWidth,
                        height: contentHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: railWidth,
                              child: BoardRail(
                                activePanel: model.panels.active,
                                actionPanel: actionPanelForPhase(
                                  model.table.phase,
                                ),
                                tokens: tokens,
                                metrics: metrics,
                                language: language,
                                appearance: appearance,
                                onPanelSelected: onPanelSelected,
                                onLanguageToggle: onLanguageToggle,
                                onAppearanceToggle: onAppearanceToggle,
                              ),
                            ),
                            BoardSeparator(
                              tokens: tokens,
                              vertical: true,
                              thickness: separatorWidth,
                            ),
                            SizedBox(
                              width: gameWidth,
                              height: contentHeight,
                              child: BoardPlayArea(
                                model: model,
                                tokens: tokens,
                                metrics: metrics,
                                onAction: onAction,
                                onPanelSelected: onPanelSelected,
                                onSwapHandCardTap: onSwapHandCardTap,
                                onPlotCardTap: onPlotCardTap,
                                onAssignmentCardTap: onAssignmentCardTap,
                                onInvalidHandCardTap: onInvalidHandCardTap,
                                onNewGame: onNewGame,
                                onReturnToLobby: onReturnToLobby,
                                onTutorial: onTutorial,
                                animationSpeed: animationSpeed,
                                onAnimationSpeedChanged:
                                    onAnimationSpeedChanged,
                                language: language,
                                appearance: appearance,
                                onLanguageToggle: onLanguageToggle,
                                onAppearanceToggle: onAppearanceToggle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (model.viewer.privacyMode == viewerPrivacyHotSeatHidden)
                    Positioned.fill(
                      child: HotSeatPrivacyOverlay(
                        model: model,
                        tokens: tokens,
                        language: language,
                        onReady: onHotSeatReady,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class HotSeatPrivacyOverlay extends StatelessWidget {
  const HotSeatPrivacyOverlay({
    required this.model,
    required this.tokens,
    required this.language,
    this.onReady,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback? onReady;

  @override
  Widget build(BuildContext context) {
    final player = hotSeatPrivacyPlayer(model);
    return ColoredBox(
      color: tokens.colors.black.withValues(alpha: hotSeatScrimOpacity),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panelWidth = hotSeatPanelWidth(constraints.maxWidth);
          final portraitSlotSize = hotSeatPortraitSlotSize(
            constraints.maxHeight,
          );
          return Center(
            child: SizedBox(
              width: panelWidth,
              child: PanelStyleSurface(
                tokens: tokens,
                padding: const EdgeInsets.symmetric(
                  horizontal: hotSeatPanelHorizontalPadding,
                  vertical: hotSeatPanelVerticalPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: hotSeatContentSpacing,
                  children: [
                    SizedBox(
                      height: hotSeatTitleRowHeight,
                      child: PanelTitleRow(
                        title: language.text(
                          en: 'Pass Device',
                          ru: 'Передайте устройство',
                        ),
                        subtitle: language.text(
                          en: 'Seat ${player.id + 1} is up.',
                          ru: 'Ходит место ${player.id + 1}.',
                        ),
                        iconPath: 'ios_resources/Icons/icon-pass-device.png',
                        tokens: tokens,
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: hotSeatPlacardMaxWidth,
                        maxHeight: hotSeatPlacardMaxHeight,
                      ),
                      child: Opacity(
                        opacity: hotSeatPlacardOpacity,
                        child: Image.asset(
                          'ios_resources/Embellishments/art-pass-device-placard.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: portraitSlotSize,
                      height: portraitSlotSize,
                      child: Center(
                        child: DecoratedBox(
                          key: const Key('hot-seat-portrait-shadow'),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: tokens.colors.black.withValues(
                                  alpha: hotSeatPortraitShadowOpacity,
                                ),
                                blurRadius: hotSeatPortraitShadowRadius,
                                offset: const Offset(
                                  0,
                                  hotSeatPortraitShadowYOffset,
                                ),
                              ),
                            ],
                          ),
                          child: PlayerPortrait(
                            seat: player,
                            tokens: tokens,
                            width: playerPortraitFrameWidth,
                            height: playerPortraitFrameHeight,
                            badgeVisible: true,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: hotSeatLabelSpacing,
                      children: [
                        PixelText(
                          player.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          size: PixelTextSize.title,
                          variant: PixelTextVariant.heavy,
                          color: tokens.colors.gold,
                        ),
                        Text(
                          hotSeatPhaseLine(
                            model,
                            language: language,
                          ).toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: kolkhozFontStyle.copyWith(
                            color: tokens.colors.creamDim,
                            fontSize: hotSeatPhaseLineFontSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: hotSeatReadyButtonMaxWidth,
                      child: HotSeatReadyButton(
                        tokens: tokens,
                        label: language.text(en: 'Ready', ru: 'Готов'),
                        onPressed: onReady,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class HotSeatReadyButton extends StatelessWidget {
  const HotSeatReadyButton({
    required this.tokens,
    required this.label,
    this.onPressed,
    super.key,
  });

  final DesignTokens tokens;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ChromeAssetButton.command(
      label: label,
      prominent: true,
      tokens: tokens,
      onPressed: onPressed,
      width: double.infinity,
      surfaceKey: const Key('hot-seat-ready-button'),
    );
  }
}

const playAreaPanelCornerRadius = 10.0;

double? activePanelPreferredHeight({
  required TableViewModel model,
  required DesignTokens tokens,
  required double width,
}) {
  if (model.panels.active != panelBrigade) {
    return null;
  }
  return brigadePanelHeightForWidth(
    maxWidth: width,
    columnCount: model.table.seats.length,
    minCardWidth: tokens.card.large.width,
    cardAspectRatio: tokens.card.aspectRatio,
  );
}

class BoardPlayArea extends StatelessWidget {
  const BoardPlayArea({
    required this.model,
    required this.tokens,
    required this.metrics,
    this.onAction,
    this.onPanelSelected,
    this.onSwapHandCardTap,
    this.onPlotCardTap,
    this.onAssignmentCardTap,
    this.onInvalidHandCardTap,
    this.onNewGame,
    this.onReturnToLobby,
    this.onTutorial,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    required this.language,
    required this.appearance,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;
  final ValueChanged<LegalAction>? onAction;
  final ValueChanged<String>? onPanelSelected;
  final ValueChanged<String>? onSwapHandCardTap;
  final void Function(String cardID, String zone)? onPlotCardTap;
  final ValueChanged<String>? onAssignmentCardTap;
  final VoidCallback? onInvalidHandCardTap;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onTutorial;
  final GameAnimationSpeed animationSpeed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.playAreaHorizontalPadding,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final preferredPanelHeight = activePanelPreferredHeight(
            model: model,
            tokens: tokens,
            width: constraints.maxWidth,
          );
          final remainingHeight = math.max(
            0.0,
            constraints.maxHeight - metrics.topInfoHeight,
          );
          final panelHeight = preferredPanelHeight == null
              ? null
              : math.max(
                  0.0,
                  math.min(
                    remainingHeight - metrics.handTrayHeight,
                    preferredPanelHeight + metrics.panelContentBottomPadding,
                  ),
                );
          final handTrayHeight = preferredPanelHeight == null
              ? metrics.handTrayLayoutHeightForBoardHeight(
                  constraints.maxHeight,
                )
              : clampDouble(
                  remainingHeight - panelHeight!,
                  metrics.handTrayHeight,
                  handTrayLayoutHeightMax,
                );
          final handTrayVisibleHeight = metrics
              .handTrayVisibleHeightForLayoutHeight(handTrayHeight);
          final activePanelStack = Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: playAreaBackdropDecoration(tokens),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: metrics.panelContentBottomPadding,
                  ),
                  child: ActivePanelView(
                    model: model,
                    tokens: tokens,
                    onAction: onAction,
                    onPlotCardTap: onPlotCardTap,
                    onNewGame: onNewGame,
                    onReturnToLobby: onReturnToLobby,
                    onTutorial: onTutorial,
                    animationSpeed: animationSpeed,
                    onAnimationSpeedChanged: onAnimationSpeedChanged,
                    language: language,
                    appearance: appearance,
                    onLanguageToggle: onLanguageToggle,
                    onAppearanceToggle: onAppearanceToggle,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: BoardSeparator(
                  tokens: tokens,
                  thickness: metrics.playAreaSeparatorThickness,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: BoardSeparator(
                  tokens: tokens,
                  thickness: metrics.playAreaSeparatorThickness,
                ),
              ),
            ],
          );
          return Column(
            children: [
              TopInfoStrip(model: model, tokens: tokens, metrics: metrics),
              if (panelHeight == null)
                Expanded(child: activePanelStack)
              else
                SizedBox(height: panelHeight, child: activePanelStack),
              SizedBox(
                height: handTrayHeight,
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: handTrayVisibleHeight,
                  maxHeight: handTrayVisibleHeight,
                  child: HandTray(
                    model: model,
                    tokens: tokens,
                    language: language,
                    visibleTrayHeight: handTrayVisibleHeight,
                    onAction: onAction,
                    onSwapHandCardTap: onSwapHandCardTap,
                    onAssignmentCardTap: onAssignmentCardTap,
                    onInvalidHandCardTap: onInvalidHandCardTap,
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

class TopInfoStrip extends StatelessWidget {
  const TopInfoStrip({
    required this.model,
    required this.tokens,
    required this.metrics,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final localPlayer = localSeat(model);
    final jobs = jobsInDisplayOrder(model.table.jobs);
    final cellarScore = localPlayer.plot.hidden.fold<int>(
      0,
      (score, card) => score + card.value,
    );
    final plotScore = localPlayer.plot.revealed.fold<int>(
      0,
      (score, card) => score + card.value,
    );
    final topInfo = tokens.layout.topInfo;
    return SizedBox(
      height: metrics.topInfoHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rowSpacing = clampDouble(
            constraints.maxWidth * topInfo.rowSpacingFactor,
            topInfo.rowSpacingMin,
            topInfo.rowSpacingMax,
          );
          final yearWidth = clampDouble(
            constraints.maxWidth * topInfo.yearWidthFactor,
            topInfo.yearWidthMin,
            topInfo.yearWidthMax,
          );
          final gaugeWidth = clampDouble(
            constraints.maxWidth * topInfo.gaugeWidthFactor,
            topInfo.gaugeWidthMin,
            topInfo.gaugeWidthMax,
          );
          final gaugeHeight = clampDouble(
            constraints.maxHeight * topInfo.gaugeHeightFactor,
            topInfo.gaugeHeightMin,
            topInfo.gaugeHeightMax,
          );
          final gaugeSpacing = clampDouble(
            constraints.maxWidth * topInfo.gaugeSpacingFactor,
            topInfo.gaugeSpacingMin,
            topInfo.gaugeSpacingMax,
          );
          final gaugeFrameWidth =
              gaugeWidth * topInfo.gaugeFrameWidthMultiplier;
          final gaugesWidth =
              gaugeFrameWidth * jobs.length + gaugeSpacing * (jobs.length - 1);
          final gaugeClusterLeftOffset = -clampDouble(
            constraints.maxWidth * topInfo.gaugeClusterLeftOffsetFactor,
            topInfo.gaugeClusterLeftOffsetMin,
            topInfo.gaugeClusterLeftOffsetMax,
          );
          final scoreWidth = clampDouble(
            constraints.maxWidth * topInfo.scoreWidthFactor,
            topInfo.scoreWidthMin,
            topInfo.scoreWidthMax,
          );
          final scoreGroupWidth = scoreWidth * 2 + rowSpacing;

          return ClipRect(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  spacing: rowSpacing,
                  children: [
                    SizedBox(
                      width: yearWidth,
                      child: TopInfoCell(
                        icon: 'icon-year-${model.table.year.clamp(1, 5)}.png',
                        value: '',
                        iconSize: gaugeHeight * 1.3,
                        contentSpacing: rowSpacing,
                        height: metrics.topInfoHeight,
                        tokens: tokens,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: scoreGroupWidth,
                      child: Row(
                        spacing: rowSpacing,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: scoreWidth,
                            child: TopInfoCell(
                              icon: 'icon-cellar.png',
                              value: '$cellarScore',
                              iconSize: gaugeHeight * 0.8,
                              contentSpacing: rowSpacing,
                              height: metrics.topInfoHeight,
                              tokens: tokens,
                            ),
                          ),
                          SizedBox(
                            width: scoreWidth,
                            child: TopInfoCell(
                              icon: 'icon-plot.png',
                              value: '$plotScore',
                              iconSize: gaugeHeight * 0.8,
                              contentSpacing: rowSpacing,
                              height: metrics.topInfoHeight,
                              tokens: tokens,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Transform.translate(
                  offset: Offset(gaugeClusterLeftOffset, 0),
                  child: OverflowBox(
                    minWidth: 0,
                    maxWidth: gaugesWidth,
                    minHeight: 0,
                    maxHeight: gaugeHeight,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: gaugesWidth,
                      height: gaugeHeight,
                      child: Row(
                        spacing: gaugeSpacing,
                        children: [
                          for (final job in jobs)
                            SizedBox(
                              width: gaugeFrameWidth,
                              child: Center(
                                child: JobGauge(
                                  job: job,
                                  highlighted: model.table.trump == job.suit,
                                  width:
                                      gaugeWidth *
                                      topInfo.gaugeContentWidthMultiplier,
                                  height: gaugeHeight,
                                  tokens: tokens,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TopInfoCell extends StatelessWidget {
  const TopInfoCell({
    required this.icon,
    required this.value,
    required this.tokens,
    required this.height,
    this.iconSize = 24,
    this.contentSpacing = 5,
    this.horizontalPadding = 6,
    super.key,
  });

  final String icon;
  final String value;
  final DesignTokens tokens;
  final double height;
  final double iconSize;
  final double contentSpacing;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.centerLeft,
        child: OverflowBox(
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: height,
          maxHeight: height,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: contentSpacing,
                children: [
                  Image.asset(
                    'ios_resources/Icons/$icon',
                    width: iconSize,
                    height: iconSize,
                    filterQuality: FilterQuality.none,
                  ),
                  if (value.isNotEmpty)
                    PixelText(
                      value,
                      size: PixelTextSize.cardRank,
                      variant: PixelTextVariant.heavy,
                      color: tokens.colors.gold,
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

class JobGauge extends StatelessWidget {
  const JobGauge({
    required this.job,
    required this.highlighted,
    required this.width,
    required this.height,
    required this.tokens,
    super.key,
  });

  final Job job;
  final bool highlighted;
  final double width;
  final double height;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final markerWidth =
        height * tokens.layout.topInfo.rewardMarkerHeightMultiplier;
    const contentSpacing = 4.0;
    final contentWidth = width - markerWidth - contentSpacing;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('ios_resources/ui-header-counter.png'),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
          ),
        ),
        child: Row(
          spacing: contentSpacing,
          children: [
            SizedBox(
              width: markerWidth,
              height: height,
              child: Center(
                child: job.reward == null
                    ? EmptyRewardMarker(
                        size: 34,
                        checkSize: topInfoEmptyRewardCheckSize,
                        tokens: tokens,
                      )
                    : MiniRewardCard(
                        card: job.reward!,
                        claimed: job.claimed,
                        height: height * 0.84,
                        tokens: tokens,
                      ),
              ),
            ),
            SizedBox(
              width: contentWidth,
              height: height,
              child: job.claimed
                  ? Center(
                      child: Image.asset(
                        'ios_resources/Icons/icon-check.png',
                        width:
                            height *
                            tokens.layout.topInfo.checkIconHeightMultiplier,
                        height:
                            height *
                            tokens.layout.topInfo.checkIconHeightMultiplier,
                        filterQuality: FilterQuality.none,
                      ),
                    )
                  : Center(
                      child: PixelText(
                        '${job.hours}/$jobRequiredHours',
                        textAlign: TextAlign.center,
                        size: PixelTextSize.title,
                        variant: PixelTextVariant.regular,
                        color: highlighted
                            ? tokens.colors.red
                            : tokens.colors.smoke,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivePanelView extends StatelessWidget {
  const ActivePanelView({
    required this.model,
    required this.tokens,
    this.onAction,
    this.onPlotCardTap,
    this.onNewGame,
    this.onReturnToLobby,
    this.onTutorial,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    required this.language,
    required this.appearance,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final ValueChanged<LegalAction>? onAction;
  final void Function(String cardID, String zone)? onPlotCardTap;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onTutorial;
  final GameAnimationSpeed animationSpeed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    switch (model.panels.active) {
      case panelJobs:
        return JobsPanel(
          model: model,
          tokens: tokens,
          language: language,
          onAction: onAction,
        );
      case panelPlot:
        return PlotPanel(
          model: model,
          tokens: tokens,
          language: language,
          onPlotCardTap: onPlotCardTap,
        );
      case panelNorth:
        return NorthPanel(model: model, tokens: tokens, language: language);
      case panelOptions:
        return OptionsPanel(
          model: model,
          tokens: tokens,
          onNewGame: onNewGame,
          onReturnToLobby: onReturnToLobby,
          onTutorial: onTutorial,
          animationSpeed: animationSpeed,
          onAnimationSpeedChanged: onAnimationSpeedChanged,
          language: language,
          appearance: appearance,
          onLanguageToggle: onLanguageToggle,
          onAppearanceToggle: onAppearanceToggle,
        );
      default:
        return BrigadePanel(
          model: model,
          tokens: tokens,
          language: language,
          onAction: onAction,
          onNewGame: onNewGame,
        );
    }
  }
}

class BrigadePanel extends StatelessWidget {
  const BrigadePanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.onAction,
    this.onNewGame,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final ValueChanged<LegalAction>? onAction;
  final VoidCallback? onNewGame;

  @override
  Widget build(BuildContext context) {
    final seats = model.table.seats;
    final trick = model.table.phase == phaseAssignment
        ? model.table.lastTrick
        : model.table.trick;
    return LayoutBuilder(
      builder: (context, constraints) {
        final playerOrder = orderedSeats(seats);
        final spacing = brigadeColumnSpacing(constraints.maxWidth);
        final columnWidth = brigadeExpandedColumnWidth(
          maxWidth: constraints.maxWidth,
          columnCount: playerOrder.length,
          spacing: spacing,
        );
        final playerPanelWidth = brigadePlayerPanelWidth(columnWidth);
        final playerPanelHeight = brigadePlayerPanelHeight(playerPanelWidth);
        final desiredPlayObjectWidth = brigadePlayObjectWidth(
          columnWidth: columnWidth,
          minWidth: tokens.card.large.width,
        );
        final desiredPlayObjectHeight = brigadePlayObjectHeight(
          desiredPlayObjectWidth,
          tokens.card.aspectRatio,
        );
        final columnHeight = math.min(
          brigadeColumnHeight(constraints.maxHeight),
          brigadeContentColumnHeight(
            playerPanelHeight: playerPanelHeight,
            playObjectHeight: desiredPlayObjectHeight,
          ),
        );
        final playObjectMaxHeight = brigadePlayObjectMaxHeight(
          columnHeight,
          playerPanelHeight,
        );
        final playObjectWidth = brigadePlayObjectFittingWidth(
          desiredWidth: desiredPlayObjectWidth,
          maxHeight: playObjectMaxHeight,
          aspectRatio: tokens.card.aspectRatio,
        );
        final playObjectHeight = brigadePlayObjectHeight(
          playObjectWidth,
          tokens.card.aspectRatio,
        );

        return Stack(
          children: [
            Padding(
              padding: brigadePanelLocalPadding,
              child: SizedBox(
                height: columnHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < playerOrder.length; index++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == playerOrder.length - 1
                                ? 0
                                : spacing,
                          ),
                          child: BrigadePlayerColumn(
                            seat: playerOrder[index],
                            play: trick.playForSeat(playerOrder[index].id),
                            columnWidth: columnWidth,
                            columnHeight: columnHeight,
                            playerPanelWidth: playerPanelWidth,
                            playerPanelHeight: playerPanelHeight,
                            playObjectWidth: playObjectWidth,
                            playObjectHeight: playObjectHeight,
                            maxTricks: model.table.maxTricks,
                            trump: model.table.trump,
                            phase: model.table.phase,
                            tokens: tokens,
                            language: language,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (model.table.phase == phasePlanning)
              PhaseOverlayFrame(
                tokens: tokens,
                child: PlanningTrumpPanel(
                  model: model,
                  tokens: tokens,
                  language: language,
                  onAction: onAction,
                ),
              ),
            if (model.table.phase == phaseGameOver)
              PhaseOverlayFrame(
                tokens: tokens,
                child: GameOverPanel(
                  model: model,
                  tokens: tokens,
                  language: language,
                  onNewGame: onNewGame,
                ),
              ),
          ],
        );
      },
    );
  }

  List<Seat> orderedSeats(List<Seat> seats) {
    final byID = {for (final seat in seats) seat.id: seat};
    return [
      1,
      2,
      3,
      0,
    ].map((id) => byID[id]).whereType<Seat>().toList(growable: false);
  }
}

class PhaseOverlayFrame extends StatelessWidget {
  const PhaseOverlayFrame({
    required this.tokens,
    required this.child,
    super.key,
  });

  final DesignTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radius.panelOuter),
              boxShadow: [
                BoxShadow(
                  color: tokens.colors.black.withValues(
                    alpha: phaseOverlayOuterShadowOpacity,
                  ),
                  blurRadius: phaseOverlayOuterShadowRadius,
                  offset: const Offset(0, phaseOverlayOuterShadowYOffset),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

const phaseOverlayOuterShadowOpacity = 0.5;
const phaseOverlayOuterShadowRadius = 16.0;
const phaseOverlayOuterShadowYOffset = 8.0;

extension on Trick {
  TrickPlay? playForSeat(int seatID) {
    for (final play in plays) {
      if (play.seatID == seatID) {
        return play;
      }
    }
    return null;
  }
}

class BrigadePlayerColumn extends StatelessWidget {
  const BrigadePlayerColumn({
    required this.seat,
    required this.play,
    required this.columnWidth,
    required this.columnHeight,
    required this.playerPanelWidth,
    required this.playerPanelHeight,
    required this.playObjectWidth,
    required this.playObjectHeight,
    required this.maxTricks,
    required this.trump,
    required this.phase,
    required this.tokens,
    required this.language,
    super.key,
  });

  final Seat seat;
  final TrickPlay? play;
  final double columnWidth;
  final double columnHeight;
  final double playerPanelWidth;
  final double playerPanelHeight;
  final double playObjectWidth;
  final double playObjectHeight;
  final int maxTricks;
  final String? trump;
  final String phase;
  final DesignTokens tokens;
  final KolkhozLanguage language;

  @override
  Widget build(BuildContext context) {
    final active = phase == phaseTrick && seat.isCurrentTurn && play == null;
    final activeColumn = active || (phase == phaseAssignment && play != null);
    final human = seat.isViewer;

    return SizedBox(
      width: columnWidth,
      height: columnHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.black.withValues(alpha: human ? 0.28 : 0.22),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: activeColumn
                ? (human ? tokens.colors.gold : tokens.colors.redBright)
                : tokens.colors.steel.withValues(alpha: 0.48),
            width: activeColumn ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: tokens.colors.black.withValues(alpha: 0.24),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: brigadeColumnPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: playerPanelWidth,
                height: playerPanelHeight,
                child: PlayerBadge(
                  seat: seat,
                  tokens: tokens,
                  active: active,
                  width: playerPanelWidth,
                  height: playerPanelHeight,
                  maxTricks: maxTricks,
                  language: language,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: brigadePlayAreaTopInset),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: playObjectWidth,
                    height: playObjectHeight,
                    child: play == null
                        ? CardSlot(
                            active: active,
                            human: human,
                            width: playObjectWidth,
                            height: playObjectHeight,
                            tokens: tokens,
                            language: language,
                          )
                        : FittedBox(
                            fit: BoxFit.contain,
                            child: GameCard(
                              card: play!.card,
                              tokens: tokens,
                              trump: trump,
                              sizeOverride: tokens.card.large,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerBadge extends StatelessWidget {
  const PlayerBadge({
    required this.seat,
    required this.tokens,
    required this.active,
    required this.language,
    this.width = 178,
    this.height = 40,
    this.maxTricks = 4,
    super.key,
  });

  final Seat seat;
  final DesignTokens tokens;
  final bool active;
  final KolkhozLanguage language;
  final double width;
  final double height;
  final int maxTricks;

  @override
  Widget build(BuildContext context) {
    final human = seat.isViewer;
    final scale = playerPanelScale(height);
    final portraitSize = playerPanelPortraitSize(width, height);
    final statColumnWidth = playerPanelStatColumnWidth(width, height);
    final cellarCardSpacing = playerPanelCellarCardSpacing(width, height);
    final contentLeft = playerPanelContentLeft(width);
    final contentRight = playerPanelContentRight(width);
    final contentWidth = math.max(0, contentRight - contentLeft);
    final portraitLeft = playerPanelPortraitLeft(width, portraitSize);
    final portraitTop = playerPanelPortraitTop(height, portraitSize);
    final nameTop = playerPanelNameTop(height);
    final scoreTop = playerPanelScoreTop(height);
    final lowerTop = playerPanelLowerStatsTop(height);
    final scoreWidth = math.min(statColumnWidth, contentWidth * 0.36);
    final statusWidth = math.min(contentWidth * 0.22, 34 * scale);
    final medalsWidth = contentWidth * 0.48;
    final cellarWidth = contentWidth * 0.48;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: active
                  ? tokens.colors.gold.withValues(
                      alpha: playerPanelActiveShadowOpacity,
                    )
                  : tokens.colors.black.withValues(
                      alpha: playerPanelInactiveShadowOpacity,
                    ),
              blurRadius: playerPanelShadowRadius,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Image.asset(
                'ios_resources/ui-player-panel.png',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
            Positioned.fill(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: portraitLeft,
                    top: portraitTop,
                    child: PortraitFrame(
                      seat: seat,
                      tokens: tokens,
                      width: portraitSize,
                      height: portraitSize,
                    ),
                  ),
                  Positioned(
                    left: contentLeft,
                    top: nameTop,
                    width: contentWidth - scoreWidth - 4 * scale,
                    height: 24 * scale,
                    child: ClipRect(
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.topLeft,
                        child: PixelText(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          size: PixelTextSize.caption,
                          variant: PixelTextVariant.heavy,
                          color: active
                              ? tokens.colors.gold
                              : tokens.colors.cardInk,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: contentRight - scoreWidth,
                    top: scoreTop,
                    width: scoreWidth,
                    child: PlayerPlotScoreStat(
                      score: seat.visibleScore,
                      tokens: tokens,
                      width: scoreWidth,
                      scale: scale,
                    ),
                  ),
                  if (statusBadgeAssets.isNotEmpty)
                    Positioned(
                      left: contentRight - statusWidth,
                      top: height * 0.42,
                      width: statusWidth,
                      child: PlayerStatusBadgeStrip(
                        assets: statusBadgeAssets,
                        tokens: tokens,
                        scale: scale,
                      ),
                    ),
                  Positioned(
                    left: contentLeft,
                    top: lowerTop,
                    width: medalsWidth,
                    child: PlayerMedalStat(
                      medals: seat.medals,
                      maxTricks: maxTricks,
                      tokens: tokens,
                      statColumnWidth: medalsWidth,
                      scale: scale,
                    ),
                  ),
                  Positioned(
                    left: contentRight - cellarWidth,
                    top: lowerTop,
                    width: cellarWidth,
                    child: PlayerCellarStat(
                      count: seat.plot.hidden.length,
                      tokens: tokens,
                      width: cellarWidth,
                      cardSpacing: cellarCardSpacing,
                      scale: scale,
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: EdgeInsets.all(2 * scale),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: active
                            ? tokens.colors.gold.withValues(alpha: 0.78)
                            : human
                            ? tokens.colors.redDark.withValues(alpha: 0.42)
                            : Colors.transparent,
                        width: active
                            ? 1.3 * scale
                            : human
                            ? scale
                            : 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get displayName {
    return seatDisplayName(seat, language: language);
  }

  List<String> get statusBadgeAssets {
    return [
      if (active)
        isHumanControlledSeat(seat)
            ? 'icon-status-current-turn.png'
            : 'icon-status-ai-thinking.png',
      if (seat.isBrigadeLeader) 'icon-status-brigade-leader.png',
    ];
  }
}

class PlayerStatusBadgeStrip extends StatelessWidget {
  const PlayerStatusBadgeStrip({
    required this.assets,
    required this.tokens,
    required this.scale,
    super.key,
  });

  final List<String> assets;
  final DesignTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2 * scale, vertical: scale),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(3 * scale),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.3)),
      ),
      child: SizedBox(
        width: (14 + (assets.take(3).length - 1) * 11) * scale,
        height: 14 * scale,
        child: Stack(
          children: [
            for (final (index, asset) in assets.take(3).indexed)
              Positioned(
                left: index * 11 * scale,
                top: 0,
                child: SizedBox(
                  width: 14 * scale,
                  height: 14 * scale,
                  child: Center(
                    child: Image.asset(
                      'ios_resources/Icons/$asset',
                      width: 13 * scale,
                      height: 13 * scale,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PlayerPlotScoreStat extends StatelessWidget {
  const PlayerPlotScoreStat({
    required this.score,
    required this.tokens,
    required this.width,
    required this.scale,
    super.key,
  });

  final int score;
  final DesignTokens tokens;
  final double width;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final iconSize = 16 * scale;
    final textWidth = math.max(0.0, width - iconSize - 2 * scale);
    return SizedBox(
      width: width,
      height: 18 * scale,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 2 * scale,
        children: [
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: Image.asset(
              'ios_resources/Icons/icon-plot.png',
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ),
          SizedBox(
            width: textWidth,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.centerLeft,
              child: PixelText(
                '$score',
                size: PixelTextSize.headline,
                variant: PixelTextVariant.heavy,
                color: tokens.colors.smoke,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerMedalStat extends StatelessWidget {
  const PlayerMedalStat({
    required this.medals,
    required this.maxTricks,
    required this.tokens,
    required this.statColumnWidth,
    required this.scale,
    super.key,
  });

  final int medals;
  final int maxTricks;
  final DesignTokens tokens;
  final double statColumnWidth;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final iconSize = playerPanelMedalIconSize * scale;
    final spacing = playerPanelMedalSpacing * scale;
    return SizedBox(
      width: statColumnWidth * 0.72,
      height: iconSize,
      child: Stack(
        children: [
          for (var index = 0; index < maxTricks; index++)
            Positioned(
              left: index * (iconSize + spacing),
              top: 0,
              child: Opacity(
                opacity: index < medals ? 1 : playerPanelUnearnedMedalOpacity,
                child: index < medals
                    ? playerMedalIcon(iconSize)
                    : ChromeAssetIcon(
                        asset: 'ios_resources/Icons/icon-medal-star.png',
                        width: iconSize,
                        height: iconSize,
                        muted: true,
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget playerMedalIcon(double size) {
    return Image.asset(
      'ios_resources/Icons/icon-medal-star.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
    );
  }
}

const playerPanelMedalIconSize = 12.0;
const playerPanelMedalSpacing = -4.0;
const playerPanelUnearnedMedalOpacity = 0.18;
const playerPanelCardBackWidth = 10.0;
const playerPanelCardBackHeight = 15.0;

class PlayerCellarStat extends StatelessWidget {
  const PlayerCellarStat({
    required this.count,
    required this.tokens,
    required this.width,
    required this.cardSpacing,
    required this.scale,
    super.key,
  });

  final int count;
  final DesignTokens tokens;
  final double width;
  final double cardSpacing;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final iconSize = 16 * scale;
    final cardWidth = playerPanelCardBackWidth * scale;
    final cardHeight = playerPanelCardBackHeight * scale;
    final cardsWidth = math.max(0.0, width - iconSize - 2 * scale);
    return SizedBox(
      width: width,
      height: 16 * scale,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 2 * scale,
        children: [
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: Image.asset(
              'ios_resources/Icons/icon-cellar.png',
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ),
          SizedBox(
            width: cardsWidth,
            height: cardHeight,
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (var index = 0; index < count; index++)
                    Positioned(
                      left: index * (cardWidth + cardSpacing),
                      top: 0,
                      child: PlayerCardBackThumbnail(
                        tokens: tokens,
                        scale: scale,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerCardBackThumbnail extends StatelessWidget {
  const PlayerCardBackThumbnail({
    required this.tokens,
    required this.scale,
    super.key,
  });

  final DesignTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2 * scale),
      child: Container(
        width: playerPanelCardBackWidth * scale,
        height: playerPanelCardBackHeight * scale,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2 * scale),
          border: Border.all(
            color: tokens.colors.gold.withValues(alpha: 0.62),
            width: 0.5 * scale,
          ),
        ),
        child: Image.asset(
          'ios_resources/Cards/card-back-icon.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }
}

class CardSlot extends StatelessWidget {
  const CardSlot({
    required this.active,
    required this.human,
    required this.width,
    required this.height,
    required this.tokens,
    required this.language,
    super.key,
  });

  final bool active;
  final bool human;
  final double width;
  final double height;
  final DesignTokens tokens;
  final KolkhozLanguage language;

  @override
  Widget build(BuildContext context) {
    final slotColor = active
        ? human
              ? tokens.colors.gold
              : tokens.colors.red
        : tokens.colors.steel.withValues(alpha: cardSlotInactiveSteelOpacity);
    final fillColor = active
        ? human
              ? tokens.colors.gold.withValues(alpha: cardSlotHumanFillOpacity)
              : tokens.colors.red.withValues(alpha: cardSlotOpponentFillOpacity)
        : Colors.transparent;
    final slot = CustomPaint(
      painter: CardSlotPainter(
        color: slotColor,
        fillColor: fillColor,
        active: active,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: active
              ? PixelText(
                  human
                      ? language.text(en: 'PLAY', ru: 'ХОД')
                      : language.text(en: 'WAIT', ru: 'ЖДИТЕ'),
                  size: PixelTextSize.caption2,
                  variant: PixelTextVariant.heavy,
                  color: human ? tokens.colors.gold : tokens.colors.redBright,
                )
              : null,
        ),
      ),
    );
    if (!active) {
      return slot;
    }
    return PulsingCardSlotFrame(human: human, tokens: tokens, child: slot);
  }
}

class PulsingCardSlotFrame extends StatefulWidget {
  const PulsingCardSlotFrame({
    required this.human,
    required this.tokens,
    required this.child,
    super.key,
  });

  final bool human;
  final DesignTokens tokens;
  final Widget child;

  @override
  State<PulsingCardSlotFrame> createState() => _PulsingCardSlotFrameState();
}

class _PulsingCardSlotFrameState extends State<PulsingCardSlotFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> pulse;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    pulse = CurvedAnimation(parent: controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.human
        ? widget.tokens.colors.gold
        : widget.tokens.colors.red;
    final restOpacity = widget.human
        ? cardSlotHumanShadowRestOpacity
        : cardSlotOpponentShadowRestOpacity;
    final pulseOpacity = widget.human
        ? cardSlotHumanShadowPulseOpacity
        : cardSlotOpponentShadowPulseOpacity;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final value = pulse.value;
        return Transform.scale(
          scale: lerpDouble(1, cardSlotActiveScale, value)!,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cardSlotCornerRadius),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(
                    alpha: lerpDouble(restOpacity, pulseOpacity, value)!,
                  ),
                  blurRadius: lerpDouble(
                    cardSlotShadowRestRadius,
                    cardSlotShadowPulseRadius,
                    value,
                  )!,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

const cardSlotCornerRadius = 8.0;
const cardSlotStrokeWidth = 2.0;
const cardSlotDashLength = 6.0;
const cardSlotDashGap = 6.0;
const cardSlotActiveScale = 1.035;
const cardSlotHumanFillOpacity = 0.10;
const cardSlotOpponentFillOpacity = 0.12;
const cardSlotInactiveSteelOpacity = 0.35;
const cardSlotShadowRestRadius = 10.0;
const cardSlotShadowPulseRadius = 18.0;
const cardSlotHumanShadowRestOpacity = 0.28;
const cardSlotHumanShadowPulseOpacity = 0.58;
const cardSlotOpponentShadowRestOpacity = 0.22;
const cardSlotOpponentShadowPulseOpacity = 0.48;

class CardSlotPainter extends CustomPainter {
  const CardSlotPainter({
    required this.color,
    required this.fillColor,
    required this.active,
  });

  final Color color;
  final Color fillColor;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(cardSlotCornerRadius),
    );
    if (active) {
      canvas.drawRRect(
        rect,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cardSlotStrokeWidth;
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + cardSlotDashLength),
          paint,
        );
        distance += cardSlotDashLength + cardSlotDashGap;
      }
    }
  }

  @override
  bool shouldRepaint(CardSlotPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.active != active;
}

class PlanningTrumpPanel extends StatelessWidget {
  const PlanningTrumpPanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.onAction,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final ValueChanged<LegalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final isFamine = model.table.isFamine;
    final trumpOptions = planningTrumpOptions(
      model.legalActions,
      language: language,
    );
    final title = isFamine
        ? language.text(en: 'Famine year', ru: 'Год неурожая')
        : language.text(en: 'Choose Trump', ru: 'Выберите козырь');
    final subtitle = isFamine
        ? language.text(
            en: 'No trump suit is used this year.',
            ru: 'В этом году козырь не используется.',
          )
        : language.text(
            en: 'Pick the trump suit for this year.',
            ru: 'Выберите козырную масть на этот год.',
          );
    const buttonSize = planningTrumpButtonSize;
    const gridSpacing = planningTrumpGridSpacing;
    return PanelStyleSurface(
      tokens: tokens,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: planningPanelContentSpacing,
        children: [
          PanelTitleRow(
            title: title,
            subtitle: subtitle,
            iconPath: isFamine
                ? 'ios_resources/Icons/icon-famine.png'
                : 'ios_resources/Icons/icon-jobs.png',
            urgent: isFamine,
            tokens: tokens,
          ),
          if (isFamine) ...[
            Center(
              child: Opacity(
                opacity: famineBannerOpacity,
                child: Image.asset(
                  'ios_resources/Embellishments/art-famine-banner.png',
                  width: famineBannerWidth,
                  height: famineBannerHeight,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            Text(
              subtitle,
              key: const Key('famine-body-text'),
              softWrap: true,
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.creamDim,
                fontSize: famineBodyFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else
            Center(
              child: SizedBox(
                width: buttonSize * 2 + gridSpacing,
                child: Wrap(
                  spacing: gridSpacing,
                  runSpacing: gridSpacing,
                  children: [
                    for (final option in trumpOptions)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: option.action != null && onAction != null
                            ? () {
                                onAction!(option.action!);
                              }
                            : null,
                        child: TrumpSelectionButton(
                          suit: option.suit,
                          label: option.label,
                          selected: option.suit == model.table.trump,
                          tokens: tokens,
                          size: buttonSize,
                          iconSize: planningTrumpIconSize,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const planningTrumpButtonSize = 54.0;
const planningTrumpIconSize = 34.0;
const planningTrumpGridSpacing = 8.0;
const planningPanelContentSpacing = 10.0;
const famineBannerWidth = 270.0;
const famineBannerHeight = 68.0;
const famineBannerOpacity = 0.9;
const famineBodyFontSize = 15.0;

class TrumpSelectionButton extends StatelessWidget {
  const TrumpSelectionButton({
    required this.suit,
    required this.label,
    required this.selected,
    required this.tokens,
    this.size = 54,
    this.iconSize = 34,
    super.key,
  });

  final String suit;
  final String label;
  final bool selected;
  final DesignTokens tokens;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scale = size / 54;
    return Tooltip(
      message: label,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: selected
                    ? tokens.colors.red.withValues(alpha: 0.38)
                    : tokens.colors.gold.withValues(alpha: 0.16),
                blurRadius: (selected ? 8 : 4) * scale,
                offset: Offset(0, 3 * scale),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  selected
                      ? 'ios_resources/ui-nav-button-active-current.png'
                      : 'ios_resources/ui-nav-button-inactive-current.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: selected ? 2 * scale : 0),
                child: Image.asset(
                  'ios_resources/Icons/icon-trump-$suit.png',
                  width: iconSize,
                  height: iconSize,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, _, _) =>
                      SuitMark(suit: suit, tokens: tokens, size: 28 * scale),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameOverPanel extends StatelessWidget {
  const GameOverPanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.onNewGame,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback? onNewGame;

  @override
  Widget build(BuildContext context) {
    final scores = model.table.gameResult?.scores ?? model.table.scoreboard;
    final winnerID =
        model.table.gameResult?.winnerSeatID ?? inferredWinnerID(scores);
    return PanelStyleSurface(
      tokens: tokens,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: gameOverPanelRowSpacing,
        children: [
          PanelTitleRow(
            title: language.text(en: 'Game Over!', ru: 'Игра окончена!'),
            subtitle: language.text(
              en: 'Final cellar and medal scores.',
              ru: 'Итоговые очки участка и медалей.',
            ),
            iconPath: 'ios_resources/Icons/icon-medal-star.png',
            tokens: tokens,
          ),
          for (final seat in model.table.seats)
            GameOverScoreRow(
              seat: seat,
              score: finalScoreForSeat(scores, seat.id),
              winner: seat.id == winnerID,
              tokens: tokens,
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: gameOverNewGameTopPadding),
              child: ChromeAssetButton.command(
                label: language.text(en: 'New game', ru: 'Новая игра'),
                prominent: true,
                tokens: tokens,
                onPressed: onNewGame,
                surfaceKey: const Key('command-surface-button'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GameOverScoreRow extends StatelessWidget {
  const GameOverScoreRow({
    required this.seat,
    required this.score,
    required this.winner,
    required this.tokens,
    super.key,
  });

  final Seat seat;
  final int score;
  final bool winner;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: gameOverRowVerticalPadding),
      child: Row(
        spacing: gameOverRowSpacing,
        children: [
          PlayerPortrait(
            seat: seat,
            tokens: tokens,
            width: gameOverPortraitWidth,
            height: gameOverPortraitHeight,
          ),
          Expanded(
            child: Row(
              spacing: gameOverNameIconSpacing,
              children: [
                Flexible(
                  child: PixelText(
                    seat.name,
                    size: PixelTextSize.title,
                    variant: winner
                        ? PixelTextVariant.heavy
                        : PixelTextVariant.regular,
                    color: winner ? tokens.colors.gold : tokens.colors.cream,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (winner)
                  Image.asset(
                    'ios_resources/Icons/icon-medal-star.png',
                    width: gameOverWinnerIconSize,
                    height: gameOverWinnerIconSize,
                    filterQuality: FilterQuality.none,
                  ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: gameOverScoreMinWidth),
            child: Align(
              alignment: Alignment.centerRight,
              child: PixelText(
                '$score',
                size: PixelTextSize.title,
                variant: PixelTextVariant.heavy,
                color: winner ? tokens.colors.gold : tokens.colors.cream,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const gameOverPanelRowSpacing = 1.0;
const gameOverNewGameTopPadding = 0.0;
const gameOverRowVerticalPadding = 1.0;
const gameOverRowSpacing = 10.0;
const gameOverNameIconSpacing = 2.0;
const gameOverPortraitWidth = 38.0;
const gameOverPortraitHeight = 42.0;
const gameOverWinnerIconSize = 32.0;
const gameOverScoreMinWidth = 28.0;
