import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show clampDouble, lerpDouble;

import 'package:flutter/material.dart';

import 'animation_speed.dart';
import 'app_settings.dart';
import 'app_text.dart';
import 'assignment_display.dart';
import 'brigade_display.dart';
import 'chrome_button.dart';
import 'render_model.dart';
import 'design_tokens.dart';
import 'game_constants.dart';
import 'hot_seat_display.dart';
import 'online_game_models.dart';
import 'phase_display.dart';
import 'pixel_text.dart';
import 'player_panel_display.dart';
import 'player_profile_panel.dart';
import 'trump_actions.dart';
import 'table_display.dart';
import 'table_projection_helpers.dart';
import 'board/board_chrome.dart';
import 'board/board_metrics.dart';
import 'board/board_rail.dart';
import 'board/board_widgets.dart';
import 'board/game_log_panel.dart';
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
const double compactBoardWidthBreakpoint = 720;

double boardPlayableContentWidth(double contentWidth) {
  return math.min(contentWidth, boardContentWidthMax).toDouble();
}

bool shouldUseCompactBoardShell({
  required double contentWidth,
  required double contentHeight,
}) {
  return contentWidth < compactBoardWidthBreakpoint &&
      contentHeight >= contentWidth;
}

class KolkhozBoard extends StatelessWidget {
  const KolkhozBoard({
    required this.model,
    required this.tokens,
    required this.language,
    required this.appearance,
    this.cardBack = KolkhozCardBack.classic,
    this.onAction,
    this.onPanelSelected,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    this.onCardBackChanged,
    this.onSwapHandCardTap,
    this.onTrickHandCardTap,
    this.onPlotCardTap,
    this.onAssignmentCardTap,
    this.onInvalidHandCardTap,
    this.canUndo = false,
    this.onUndo,
    this.onHotSeatReady,
    this.onNewGame,
    this.onReturnToLobby,
    this.onCopyGameResult,
    this.onSaveGameLog,
    this.gameLogActions = const [],
    this.gameReactions = const [],
    this.hasUnreadLogMessages = false,
    this.canSendReaction = false,
    this.onReaction,
    this.activeReaction,
    this.gameOverReturnsToLobby = false,
    this.onTutorial,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    this.confirmNewGame = true,
    this.onConfirmNewGameChanged,
    this.confirmMainMenu = true,
    this.onConfirmMainMenuChanged,
    this.showInvalidTapHints = true,
    this.onShowInvalidTapHintsChanged,
    this.currentProfileUserID,
    this.comradeUserIDs = const {},
    this.incomingComradeRequestUserIDs = const {},
    this.outgoingComradeRequestUserIDs = const {},
    this.onComradeRequestToUser,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final KolkhozCardBack cardBack;
  final ValueChanged<LegalAction>? onAction;
  final ValueChanged<String>? onPanelSelected;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;
  final ValueChanged<KolkhozCardBack>? onCardBackChanged;
  final ValueChanged<String>? onSwapHandCardTap;
  final ValueChanged<String>? onTrickHandCardTap;
  final void Function(String cardID, String zone)? onPlotCardTap;
  final ValueChanged<String>? onAssignmentCardTap;
  final VoidCallback? onInvalidHandCardTap;
  final bool canUndo;
  final VoidCallback? onUndo;
  final VoidCallback? onHotSeatReady;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onCopyGameResult;
  final VoidCallback? onSaveGameLog;
  final List<EngineAction> gameLogActions;
  final List<OnlineReaction> gameReactions;
  final bool hasUnreadLogMessages;
  final bool canSendReaction;
  final ValueChanged<String>? onReaction;
  final OnlineReaction? activeReaction;
  final bool gameOverReturnsToLobby;
  final VoidCallback? onTutorial;
  final GameAnimationSpeed animationSpeed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final bool confirmNewGame;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final bool confirmMainMenu;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final bool showInvalidTapHints;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final String? currentProfileUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  @override
  Widget build(BuildContext context) {
    return KolkhozCardBackScope(
      cardBack: cardBack,
      child: DefaultTextStyle.merge(
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
            final compact = shouldUseCompactBoardShell(
              contentWidth: contentWidth,
              contentHeight: contentHeight,
            );

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
                          child: compact
                              ? CompactBoardShell(
                                  model: model,
                                  tokens: tokens,
                                  metrics: metrics,
                                  language: language,
                                  appearance: appearance,
                                  cardBack: cardBack,
                                  onAction: onAction,
                                  onPanelSelected: onPanelSelected,
                                  onSwapHandCardTap: onSwapHandCardTap,
                                  onTrickHandCardTap: onTrickHandCardTap,
                                  onPlotCardTap: onPlotCardTap,
                                  onAssignmentCardTap: onAssignmentCardTap,
                                  onInvalidHandCardTap: onInvalidHandCardTap,
                                  canUndo: canUndo,
                                  onUndo: onUndo,
                                  onNewGame: onNewGame,
                                  onReturnToLobby: onReturnToLobby,
                                  onCopyGameResult: onCopyGameResult,
                                  onSaveGameLog: onSaveGameLog,
                                  gameLogActions: gameLogActions,
                                  gameReactions: gameReactions,
                                  hasUnreadLogMessages: hasUnreadLogMessages,
                                  canSendReaction: canSendReaction,
                                  onReaction: onReaction,
                                  activeReaction: activeReaction,
                                  gameOverReturnsToLobby:
                                      gameOverReturnsToLobby,
                                  onTutorial: onTutorial,
                                  animationSpeed: animationSpeed,
                                  onAnimationSpeedChanged:
                                      onAnimationSpeedChanged,
                                  confirmNewGame: confirmNewGame,
                                  onConfirmNewGameChanged:
                                      onConfirmNewGameChanged,
                                  confirmMainMenu: confirmMainMenu,
                                  onConfirmMainMenuChanged:
                                      onConfirmMainMenuChanged,
                                  showInvalidTapHints: showInvalidTapHints,
                                  onShowInvalidTapHintsChanged:
                                      onShowInvalidTapHintsChanged,
                                  currentProfileUserID: currentProfileUserID,
                                  comradeUserIDs: comradeUserIDs,
                                  incomingComradeRequestUserIDs:
                                      incomingComradeRequestUserIDs,
                                  outgoingComradeRequestUserIDs:
                                      outgoingComradeRequestUserIDs,
                                  onComradeRequestToUser:
                                      onComradeRequestToUser,
                                  onLanguageToggle: onLanguageToggle,
                                  onAppearanceToggle: onAppearanceToggle,
                                  onCardBackChanged: onCardBackChanged,
                                )
                              : Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                                        year: model.table.year,
                                        hasUnreadLogMessages:
                                            hasUnreadLogMessages,
                                        onPanelSelected: onPanelSelected,
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
                                        onTrickHandCardTap: onTrickHandCardTap,
                                        onPlotCardTap: onPlotCardTap,
                                        onAssignmentCardTap:
                                            onAssignmentCardTap,
                                        onInvalidHandCardTap:
                                            onInvalidHandCardTap,
                                        canUndo: canUndo,
                                        onUndo: onUndo,
                                        onNewGame: onNewGame,
                                        onReturnToLobby: onReturnToLobby,
                                        onCopyGameResult: onCopyGameResult,
                                        onSaveGameLog: onSaveGameLog,
                                        gameLogActions: gameLogActions,
                                        gameReactions: gameReactions,
                                        canSendReaction: canSendReaction,
                                        onReaction: onReaction,
                                        activeReaction: activeReaction,
                                        gameOverReturnsToLobby:
                                            gameOverReturnsToLobby,
                                        onTutorial: onTutorial,
                                        animationSpeed: animationSpeed,
                                        onAnimationSpeedChanged:
                                            onAnimationSpeedChanged,
                                        confirmNewGame: confirmNewGame,
                                        onConfirmNewGameChanged:
                                            onConfirmNewGameChanged,
                                        confirmMainMenu: confirmMainMenu,
                                        onConfirmMainMenuChanged:
                                            onConfirmMainMenuChanged,
                                        showInvalidTapHints:
                                            showInvalidTapHints,
                                        onShowInvalidTapHintsChanged:
                                            onShowInvalidTapHintsChanged,
                                        currentProfileUserID:
                                            currentProfileUserID,
                                        comradeUserIDs: comradeUserIDs,
                                        incomingComradeRequestUserIDs:
                                            incomingComradeRequestUserIDs,
                                        outgoingComradeRequestUserIDs:
                                            outgoingComradeRequestUserIDs,
                                        onComradeRequestToUser:
                                            onComradeRequestToUser,
                                        language: language,
                                        appearance: appearance,
                                        cardBack: cardBack,
                                        onLanguageToggle: onLanguageToggle,
                                        onAppearanceToggle: onAppearanceToggle,
                                        onCardBackChanged: onCardBackChanged,
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
      ),
    );
  }
}

class CompactBoardShell extends StatelessWidget {
  const CompactBoardShell({
    required this.model,
    required this.tokens,
    required this.metrics,
    required this.language,
    required this.appearance,
    this.cardBack = KolkhozCardBack.classic,
    this.onAction,
    this.onPanelSelected,
    this.onSwapHandCardTap,
    this.onTrickHandCardTap,
    this.onPlotCardTap,
    this.onAssignmentCardTap,
    this.onInvalidHandCardTap,
    this.canUndo = false,
    this.onUndo,
    this.onNewGame,
    this.onReturnToLobby,
    this.onCopyGameResult,
    this.onSaveGameLog,
    this.gameLogActions = const [],
    this.gameReactions = const [],
    this.hasUnreadLogMessages = false,
    this.canSendReaction = false,
    this.onReaction,
    this.activeReaction,
    this.gameOverReturnsToLobby = false,
    this.onTutorial,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    this.confirmNewGame = true,
    this.onConfirmNewGameChanged,
    this.confirmMainMenu = true,
    this.onConfirmMainMenuChanged,
    this.showInvalidTapHints = true,
    this.onShowInvalidTapHintsChanged,
    this.currentProfileUserID,
    this.comradeUserIDs = const {},
    this.incomingComradeRequestUserIDs = const {},
    this.outgoingComradeRequestUserIDs = const {},
    this.onComradeRequestToUser,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    this.onCardBackChanged,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final KolkhozCardBack cardBack;
  final ValueChanged<LegalAction>? onAction;
  final ValueChanged<String>? onPanelSelected;
  final ValueChanged<String>? onSwapHandCardTap;
  final ValueChanged<String>? onTrickHandCardTap;
  final void Function(String cardID, String zone)? onPlotCardTap;
  final ValueChanged<String>? onAssignmentCardTap;
  final VoidCallback? onInvalidHandCardTap;
  final bool canUndo;
  final VoidCallback? onUndo;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onCopyGameResult;
  final VoidCallback? onSaveGameLog;
  final List<EngineAction> gameLogActions;
  final List<OnlineReaction> gameReactions;
  final bool hasUnreadLogMessages;
  final bool canSendReaction;
  final ValueChanged<String>? onReaction;
  final OnlineReaction? activeReaction;
  final bool gameOverReturnsToLobby;
  final VoidCallback? onTutorial;
  final GameAnimationSpeed animationSpeed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final bool confirmNewGame;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final bool confirmMainMenu;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final bool showInvalidTapHints;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final String? currentProfileUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;
  final ValueChanged<KolkhozCardBack>? onCardBackChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BoardPlayArea(
            model: model,
            tokens: tokens,
            metrics: metrics,
            compact: true,
            onAction: onAction,
            onPanelSelected: onPanelSelected,
            onSwapHandCardTap: onSwapHandCardTap,
            onTrickHandCardTap: onTrickHandCardTap,
            onPlotCardTap: onPlotCardTap,
            onAssignmentCardTap: onAssignmentCardTap,
            onInvalidHandCardTap: onInvalidHandCardTap,
            canUndo: canUndo,
            onUndo: onUndo,
            onNewGame: onNewGame,
            onReturnToLobby: onReturnToLobby,
            onCopyGameResult: onCopyGameResult,
            onSaveGameLog: onSaveGameLog,
            gameLogActions: gameLogActions,
            gameReactions: gameReactions,
            canSendReaction: canSendReaction,
            onReaction: onReaction,
            activeReaction: activeReaction,
            gameOverReturnsToLobby: gameOverReturnsToLobby,
            onTutorial: onTutorial,
            animationSpeed: animationSpeed,
            onAnimationSpeedChanged: onAnimationSpeedChanged,
            confirmNewGame: confirmNewGame,
            onConfirmNewGameChanged: onConfirmNewGameChanged,
            confirmMainMenu: confirmMainMenu,
            onConfirmMainMenuChanged: onConfirmMainMenuChanged,
            showInvalidTapHints: showInvalidTapHints,
            onShowInvalidTapHintsChanged: onShowInvalidTapHintsChanged,
            currentProfileUserID: currentProfileUserID,
            comradeUserIDs: comradeUserIDs,
            incomingComradeRequestUserIDs: incomingComradeRequestUserIDs,
            outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs,
            onComradeRequestToUser: onComradeRequestToUser,
            language: language,
            appearance: appearance,
            cardBack: cardBack,
            onLanguageToggle: onLanguageToggle,
            onAppearanceToggle: onAppearanceToggle,
            onCardBackChanged: onCardBackChanged,
          ),
        ),
        BoardSeparator(tokens: tokens, thickness: metrics.separatorWidth),
        CompactBoardToolbar(
          activePanel: model.panels.active,
          actionPanel: actionPanelForPhase(model.table.phase),
          tokens: tokens,
          metrics: metrics,
          language: language,
          year: model.table.year,
          hasUnreadLogMessages: hasUnreadLogMessages,
          onPanelSelected: onPanelSelected,
        ),
      ],
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
                        title: language.t(KolkhozText.boardviewPassDevice),
                        subtitle: language.t(
                          KolkhozText.boardviewSeatValue1IsUp,
                          {'value1': player.id + 1},
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
                        label: language.t(KolkhozText.boardviewReady),
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
    this.onTrickHandCardTap,
    this.onPlotCardTap,
    this.onAssignmentCardTap,
    this.onInvalidHandCardTap,
    this.canUndo = false,
    this.onUndo,
    this.onNewGame,
    this.onReturnToLobby,
    this.onCopyGameResult,
    this.onSaveGameLog,
    this.gameLogActions = const [],
    this.gameReactions = const [],
    this.canSendReaction = false,
    this.onReaction,
    this.activeReaction,
    this.gameOverReturnsToLobby = false,
    this.onTutorial,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    this.confirmNewGame = true,
    this.onConfirmNewGameChanged,
    this.confirmMainMenu = true,
    this.onConfirmMainMenuChanged,
    this.showInvalidTapHints = true,
    this.onShowInvalidTapHintsChanged,
    this.currentProfileUserID,
    this.comradeUserIDs = const {},
    this.incomingComradeRequestUserIDs = const {},
    this.outgoingComradeRequestUserIDs = const {},
    this.onComradeRequestToUser,
    this.compact = false,
    required this.language,
    required this.appearance,
    this.cardBack = KolkhozCardBack.classic,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    this.onCardBackChanged,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;
  final ValueChanged<LegalAction>? onAction;
  final ValueChanged<String>? onPanelSelected;
  final ValueChanged<String>? onSwapHandCardTap;
  final ValueChanged<String>? onTrickHandCardTap;
  final void Function(String cardID, String zone)? onPlotCardTap;
  final ValueChanged<String>? onAssignmentCardTap;
  final VoidCallback? onInvalidHandCardTap;
  final bool canUndo;
  final VoidCallback? onUndo;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onCopyGameResult;
  final VoidCallback? onSaveGameLog;
  final List<EngineAction> gameLogActions;
  final List<OnlineReaction> gameReactions;
  final bool canSendReaction;
  final ValueChanged<String>? onReaction;
  final OnlineReaction? activeReaction;
  final bool gameOverReturnsToLobby;
  final VoidCallback? onTutorial;
  final GameAnimationSpeed animationSpeed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final bool confirmNewGame;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final bool confirmMainMenu;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final bool showInvalidTapHints;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final String? currentProfileUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final bool compact;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final KolkhozCardBack cardBack;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;
  final ValueChanged<KolkhozCardBack>? onCardBackChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.playAreaHorizontalPadding,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final preferredPanelHeight = compact
              ? null
              : activePanelPreferredHeight(
                  model: model,
                  tokens: tokens,
                  width: constraints.maxWidth,
                );
          final gameOver = model.table.phase == phaseGameOver;
          final remainingHeight = math.max(
            0.0,
            constraints.maxHeight - metrics.topInfoHeight,
          );
          final panelHeight = gameOver
              ? remainingHeight
              : preferredPanelHeight == null
              ? null
              : math.max(
                  0.0,
                  math.min(
                    remainingHeight - metrics.handTrayHeight,
                    preferredPanelHeight + metrics.panelContentBottomPadding,
                  ),
                );
          final handTrayHeight = gameOver
              ? 0.0
              : preferredPanelHeight == null
              ? metrics.handTrayLayoutHeightForBoardHeight(
                  constraints.maxHeight,
                )
              : clampDouble(
                  remainingHeight - panelHeight!,
                  metrics.handTrayHeight,
                  handTrayLayoutHeightMax,
                );
          final handTrayVisibleHeight = gameOver
              ? 0.0
              : metrics.handTrayVisibleHeightForLayoutHeight(handTrayHeight);
          return PlanningTrumpFocusHost(
            model: model,
            builder: (context, planningTrumpFocusedSuit) {
              final activePanelWithFocus = Stack(
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
                        onCopyGameResult: onCopyGameResult,
                        onSaveGameLog: onSaveGameLog,
                        gameLogActions: gameLogActions,
                        gameReactions: gameReactions,
                        activeReaction: activeReaction,
                        gameOverReturnsToLobby: gameOverReturnsToLobby,
                        onTutorial: onTutorial,
                        animationSpeed: animationSpeed,
                        onAnimationSpeedChanged: onAnimationSpeedChanged,
                        confirmNewGame: confirmNewGame,
                        onConfirmNewGameChanged: onConfirmNewGameChanged,
                        confirmMainMenu: confirmMainMenu,
                        onConfirmMainMenuChanged: onConfirmMainMenuChanged,
                        showInvalidTapHints: showInvalidTapHints,
                        onShowInvalidTapHintsChanged:
                            onShowInvalidTapHintsChanged,
                        language: language,
                        appearance: appearance,
                        cardBack: cardBack,
                        compact: compact,
                        planningTrumpFocusedSuit: planningTrumpFocusedSuit,
                        currentProfileUserID: currentProfileUserID,
                        comradeUserIDs: comradeUserIDs,
                        incomingComradeRequestUserIDs:
                            incomingComradeRequestUserIDs,
                        outgoingComradeRequestUserIDs:
                            outgoingComradeRequestUserIDs,
                        onComradeRequestToUser: onComradeRequestToUser,
                        onLanguageToggle: onLanguageToggle,
                        onAppearanceToggle: onAppearanceToggle,
                        onCardBackChanged: onCardBackChanged,
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
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    children: [
                      SizedBox(height: metrics.topInfoHeight),
                      if (panelHeight == null)
                        Expanded(child: activePanelWithFocus)
                      else
                        SizedBox(
                          height: panelHeight,
                          child: activePanelWithFocus,
                        ),
                      if (!gameOver)
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
                              planningTrumpFocusedSuit:
                                  planningTrumpFocusedSuit,
                              onAction: onAction,
                              onPanelSelected: onPanelSelected,
                              onSwapHandCardTap: onSwapHandCardTap,
                              onTrickHandCardTap: onTrickHandCardTap,
                              onAssignmentCardTap: onAssignmentCardTap,
                              onInvalidHandCardTap: onInvalidHandCardTap,
                              canUndo: canUndo,
                              onUndo: onUndo,
                              contentOverride: model.panels.active == panelLog
                                  ? ReactionTray(
                                      tokens: tokens,
                                      language: language,
                                      enabled: canSendReaction,
                                      onReaction: onReaction,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: compact
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: math.max(640, constraints.maxWidth),
                              child: TopInfoStrip(
                                model: model,
                                tokens: tokens,
                                metrics: metrics,
                                animationSpeed: animationSpeed,
                              ),
                            ),
                          )
                        : TopInfoStrip(
                            model: model,
                            tokens: tokens,
                            metrics: metrics,
                            animationSpeed: animationSpeed,
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class PlanningTrumpFocusHost extends StatefulWidget {
  const PlanningTrumpFocusHost({
    required this.model,
    required this.builder,
    super.key,
  });

  final TableViewModel model;
  final Widget Function(BuildContext context, String? focusedSuit) builder;

  @override
  State<PlanningTrumpFocusHost> createState() => _PlanningTrumpFocusHostState();
}

class _PlanningTrumpFocusHostState extends State<PlanningTrumpFocusHost> {
  final math.Random selectorRandom = math.Random();
  Timer? selectorTimer;
  int selectorIndex = 0;

  @override
  void initState() {
    super.initState();
    syncSelectorTimer();
  }

  @override
  void didUpdateWidget(PlanningTrumpFocusHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldAnimating = planningTrumpSelectorIsAI(oldWidget.model);
    final nextAnimating = planningTrumpSelectorIsAI(widget.model);
    if (oldAnimating != nextAnimating ||
        oldWidget.model.table.currentPlayerID !=
            widget.model.table.currentPlayerID) {
      syncSelectorTimer();
    }
  }

  @override
  void dispose() {
    selectorTimer?.cancel();
    super.dispose();
  }

  void syncSelectorTimer() {
    selectorTimer?.cancel();
    selectorTimer = null;
    if (!planningTrumpSelectorIsAI(widget.model)) {
      return;
    }
    selectorIndex = selectorRandom.nextInt(displaySuitOrder.length);
    selectorTimer = Timer.periodic(planningTrumpAiSelectorHopDuration, (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        var nextIndex = selectorRandom.nextInt(displaySuitOrder.length);
        if (displaySuitOrder.length > 1 && nextIndex == selectorIndex) {
          nextIndex = (nextIndex + 1) % displaySuitOrder.length;
        }
        selectorIndex = nextIndex;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final focusedSuit = planningTrumpSelectorIsAI(widget.model)
        ? displaySuitOrder[selectorIndex]
        : null;
    return widget.builder(context, focusedSuit);
  }
}

class TopInfoStrip extends StatelessWidget {
  const TopInfoStrip({
    required this.model,
    required this.tokens,
    required this.metrics,
    required this.animationSpeed,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;
  final GameAnimationSpeed animationSpeed;

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
                                child: MotionTrackedRegion(
                                  motionKey: jobGaugeMotionTargetKey(job.suit),
                                  child: JobGauge(
                                    job: job,
                                    highlighted: model.table.trump == job.suit,
                                    animationSpeed: animationSpeed,
                                    width:
                                        gaugeWidth *
                                        topInfo.gaugeContentWidthMultiplier,
                                    height: gaugeHeight,
                                    tokens: tokens,
                                  ),
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

class JobGauge extends StatefulWidget {
  const JobGauge({
    required this.job,
    required this.highlighted,
    required this.width,
    required this.height,
    required this.tokens,
    this.animationSpeed = defaultGameAnimationSpeed,
    super.key,
  });

  final Job job;
  final bool highlighted;
  final double width;
  final double height;
  final DesignTokens tokens;
  final GameAnimationSpeed animationSpeed;

  @override
  State<JobGauge> createState() => _JobGaugeState();
}

class _JobGaugeState extends State<JobGauge> {
  int? previousDisplayHours;
  int deltaSerial = 0;
  int pendingDeltaBadgeCount = 0;
  final List<Timer> deltaTimers = [];
  final List<_VisibleJobGaugeDelta> visibleDeltas = [];

  @override
  void initState() {
    super.initState();
    previousDisplayHours = displayedJobHours(widget.job);
  }

  @override
  void didUpdateWidget(JobGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextHours = displayedJobHours(widget.job);
    final previous = previousDisplayHours ?? displayedJobHours(oldWidget.job);
    if (nextHours > previous) {
      queueDeltaBadge(nextHours - previous);
    }
    previousDisplayHours = nextHours;
  }

  @override
  void dispose() {
    for (final timer in deltaTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  void queueDeltaBadge(int delta) {
    final delay = jobGaugeDeltaRevealDelay(widget.animationSpeed);
    final stagger = Duration(
      milliseconds:
          jobGaugeDeltaRevealStagger.inMilliseconds * pendingDeltaBadgeCount,
    );
    pendingDeltaBadgeCount += 1;
    late final Timer timer;
    timer = Timer(delay + stagger, () {
      deltaTimers.remove(timer);
      pendingDeltaBadgeCount = math.max(0, pendingDeltaBadgeCount - 1);
      if (!mounted) {
        return;
      }
      setState(() {
        visibleDeltas.add(
          _VisibleJobGaugeDelta(serial: deltaSerial++, delta: delta),
        );
      });
    });
    deltaTimers.add(timer);
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final tokens = widget.tokens;
    final height = widget.height;
    final width = widget.width;
    final rewardMarkerWidth =
        height * tokens.layout.topInfo.rewardMarkerHeightMultiplier + 3;
    final containsWrecker = jobContainsWrecker(job);
    final wreckerIconSize = height * 0.4;
    final markerWidth =
        rewardMarkerWidth + (containsWrecker ? wreckerIconSize + 2 : 0);
    const contentSpacing = 4.0;
    final contentWidth = width - markerWidth - contentSpacing;
    final displayedHours = displayedJobHours(job);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: containsWrecker ? 2 : 0,
                      children: [
                        if (job.claimed)
                          Image.asset(
                            'ios_resources/Icons/icon-check.png',
                            width:
                                height *
                                tokens.layout.topInfo.checkIconHeightMultiplier,
                            height:
                                height *
                                tokens.layout.topInfo.checkIconHeightMultiplier,
                            filterQuality: FilterQuality.none,
                          )
                        else if (job.reward == null)
                          EmptyRewardMarker(
                            size: 34,
                            checkSize: topInfoEmptyRewardCheckSize,
                            tokens: tokens,
                          )
                        else
                          Row(
                            key: ValueKey('job-gauge-reward-${job.suit}'),
                            mainAxisSize: MainAxisSize.min,
                            spacing: 2,
                            children: [
                              PixelText(
                                job.reward!.rank,
                                size: PixelTextSize.caption,
                                variant: PixelTextVariant.heavy,
                                color: tokens.colors.cardInk,
                              ),
                              SuitMark(
                                key: ValueKey(
                                  'job-gauge-reward-suit-${job.suit}',
                                ),
                                suit: job.reward!.suit,
                                tokens: tokens,
                                size: height * 0.4,
                              ),
                            ],
                          ),
                        if (containsWrecker)
                          Image.asset(
                            'ios_resources/Icons/icon-variant-saboteur.png',
                            key: ValueKey('job-gauge-wrecker-${job.suit}'),
                            width: wreckerIconSize,
                            height: wreckerIconSize,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: contentWidth,
                  height: height,
                  child: Center(
                    child: PixelText(
                      '$displayedHours/$jobRequiredHours',
                      textAlign: TextAlign.center,
                      size: PixelTextSize.title,
                      variant: PixelTextVariant.regular,
                      color: widget.highlighted
                          ? tokens.colors.red
                          : tokens.colors.smoke,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final (index, delta) in visibleDeltas.indexed)
          Positioned(
            key: ValueKey(delta.serial),
            right: 6,
            top: index * 8,
            child: JobGaugeDeltaBadge(
              delta: delta.delta,
              tokens: tokens,
              onDone: () {
                if (mounted) {
                  setState(
                    () => visibleDeltas.removeWhere(
                      (entry) => entry.serial == delta.serial,
                    ),
                  );
                }
              },
            ),
          ),
      ],
    );
  }
}

class _VisibleJobGaugeDelta {
  const _VisibleJobGaugeDelta({required this.serial, required this.delta});

  final int serial;
  final int delta;
}

class JobGaugeDeltaBadge extends StatelessWidget {
  const JobGaugeDeltaBadge({
    required this.delta,
    required this.tokens,
    required this.onDone,
    super.key,
  });

  final int delta;
  final DesignTokens tokens;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: jobGaugeDeltaDuration,
      curve: Curves.easeOutCubic,
      onEnd: onDone,
      builder: (context, value, child) {
        return Opacity(
          opacity: (1 - value).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, jobGaugeDeltaDropDistance * value),
            child: Transform.scale(
              scale: lerpDouble(
                jobGaugeDeltaStartScale,
                jobGaugeDeltaEndScale,
                math.min(value * 1.8, 1),
              )!,
              child: child,
            ),
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(tokens.radius.sm),
          border: Border.all(color: tokens.colors.green, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          child: PixelText(
            '+$delta',
            size: PixelTextSize.caption,
            variant: PixelTextVariant.heavy,
            color: tokens.colors.green,
          ),
        ),
      ),
    );
  }
}

const jobGaugeDeltaDuration = Duration(milliseconds: 1600);
const jobGaugeDeltaRevealStagger = Duration(milliseconds: 80);
const jobGaugeDeltaRevealLead = Duration(milliseconds: 220);
const jobGaugeDeltaDropDistance = 46.0;
const jobGaugeDeltaStartScale = 1.64;
const jobGaugeDeltaEndScale = 2.16;

Duration jobGaugeDeltaRevealDelay(GameAnimationSpeed speed) {
  final flightDuration = scaledDuration(
    speed.cardFlightDuration,
    jobAssignmentCardFlightDurationScale,
  );
  if (flightDuration <= jobGaugeDeltaRevealLead) {
    return Duration.zero;
  }
  return flightDuration - jobGaugeDeltaRevealLead;
}

class ActivePanelView extends StatelessWidget {
  const ActivePanelView({
    required this.model,
    required this.tokens,
    this.onAction,
    this.onPlotCardTap,
    this.onNewGame,
    this.onReturnToLobby,
    this.onCopyGameResult,
    this.onSaveGameLog,
    this.gameLogActions = const [],
    this.gameReactions = const [],
    this.activeReaction,
    this.gameOverReturnsToLobby = false,
    this.onTutorial,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.onAnimationSpeedChanged,
    this.confirmNewGame = true,
    this.onConfirmNewGameChanged,
    this.confirmMainMenu = true,
    this.onConfirmMainMenuChanged,
    this.showInvalidTapHints = true,
    this.onShowInvalidTapHintsChanged,
    required this.language,
    required this.appearance,
    this.cardBack = KolkhozCardBack.classic,
    this.compact = false,
    this.planningTrumpFocusedSuit,
    this.currentProfileUserID,
    this.comradeUserIDs = const {},
    this.incomingComradeRequestUserIDs = const {},
    this.outgoingComradeRequestUserIDs = const {},
    this.onComradeRequestToUser,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    this.onCardBackChanged,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final ValueChanged<LegalAction>? onAction;
  final void Function(String cardID, String zone)? onPlotCardTap;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onCopyGameResult;
  final VoidCallback? onSaveGameLog;
  final List<EngineAction> gameLogActions;
  final List<OnlineReaction> gameReactions;
  final OnlineReaction? activeReaction;
  final bool gameOverReturnsToLobby;
  final VoidCallback? onTutorial;
  final GameAnimationSpeed animationSpeed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final bool confirmNewGame;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final bool confirmMainMenu;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final bool showInvalidTapHints;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final KolkhozCardBack cardBack;
  final bool compact;
  final String? planningTrumpFocusedSuit;
  final String? currentProfileUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;
  final ValueChanged<KolkhozCardBack>? onCardBackChanged;

  @override
  Widget build(BuildContext context) {
    if (model.table.phase == phaseGameOver) {
      return GameOverPlotPanel(
        model: model,
        tokens: tokens,
        language: language,
        onNewGame: onNewGame,
        onReturnToLobby: onReturnToLobby,
        onCopyGameResult: onCopyGameResult,
        onSaveGameLog: onSaveGameLog,
        returnsToLobby: gameOverReturnsToLobby,
      );
    }
    switch (model.panels.active) {
      case panelLog:
        return GameLogPanel(
          model: model,
          tokens: tokens,
          language: language,
          actions: gameLogActions,
          reactions: gameReactions,
        );
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
          confirmNewGame: confirmNewGame,
          onConfirmNewGameChanged: onConfirmNewGameChanged,
          confirmMainMenu: confirmMainMenu,
          onConfirmMainMenuChanged: onConfirmMainMenuChanged,
          showInvalidTapHints: showInvalidTapHints,
          onShowInvalidTapHintsChanged: onShowInvalidTapHintsChanged,
          language: language,
          appearance: appearance,
          cardBack: cardBack,
          onLanguageToggle: onLanguageToggle,
          onAppearanceToggle: onAppearanceToggle,
          onCardBackChanged: onCardBackChanged,
        );
      default:
        return BrigadePanel(
          model: model,
          tokens: tokens,
          language: language,
          activeReaction: activeReaction,
          compact: compact,
          planningTrumpFocusedSuit: planningTrumpFocusedSuit,
          currentProfileUserID: currentProfileUserID,
          comradeUserIDs: comradeUserIDs,
          incomingComradeRequestUserIDs: incomingComradeRequestUserIDs,
          outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs,
          onComradeRequestToUser: onComradeRequestToUser,
          onAction: onAction,
        );
    }
  }
}

class BrigadePanel extends StatefulWidget {
  const BrigadePanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.activeReaction,
    this.compact = false,
    this.planningTrumpFocusedSuit,
    this.currentProfileUserID,
    this.comradeUserIDs = const {},
    this.incomingComradeRequestUserIDs = const {},
    this.outgoingComradeRequestUserIDs = const {},
    this.onComradeRequestToUser,
    this.onAction,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineReaction? activeReaction;
  final bool compact;
  final String? planningTrumpFocusedSuit;
  final String? currentProfileUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final ValueChanged<LegalAction>? onAction;

  @override
  State<BrigadePanel> createState() => _BrigadePanelState();
}

class _BrigadePanelState extends State<BrigadePanel> {
  int? inspectedSeatID;

  @override
  void didUpdateWidget(BrigadePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = inspectedSeatID;
    if (selected != null &&
        !widget.model.table.seats.any((seat) => seat.id == selected)) {
      inspectedSeatID = null;
    }
  }

  void togglePlayerInspect(int seatID) {
    setState(() {
      inspectedSeatID = inspectedSeatID == seatID ? null : seatID;
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final tokens = widget.tokens;
    final language = widget.language;
    final seats = model.table.seats;
    final trick = model.table.phase == phaseAssignment
        ? visibleAssignmentTrick(model)
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

        if (widget.compact) {
          return CompactBrigadeGrid(
            playerOrder: playerOrder,
            trick: trick,
            model: model,
            tokens: tokens,
            language: language,
            activeReaction: widget.activeReaction,
            planningTrumpFocusedSuit: widget.planningTrumpFocusedSuit,
            inspectedSeatID: inspectedSeatID,
            onInspectSeat: togglePlayerInspect,
            currentProfileUserID: widget.currentProfileUserID,
            comradeUserIDs: widget.comradeUserIDs,
            incomingComradeRequestUserIDs: widget.incomingComradeRequestUserIDs,
            outgoingComradeRequestUserIDs: widget.outgoingComradeRequestUserIDs,
            onComradeRequestToUser: widget.onComradeRequestToUser,
            onAction: widget.onAction,
          );
        }

        return Padding(
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
                        right: index == playerOrder.length - 1 ? 0 : spacing,
                      ),
                      child: BrigadePlayerColumn(
                        seat: playerOrder[index],
                        play: trick.playForSeat(playerOrder[index].id),
                        pendingPlayCard: selectedTrickPreviewCard(
                          model,
                          playerOrder[index],
                          trick.playForSeat(playerOrder[index].id),
                        ),
                        planningTrumpChooser:
                            model.table.phase == phasePlanning &&
                                playerOrder[index].id ==
                                    model.table.currentPlayerID
                            ? PlanningTrumpPanel(
                                model: model,
                                tokens: tokens,
                                language: language,
                                focusedSuit: widget.planningTrumpFocusedSuit,
                                onAction: widget.onAction,
                              )
                            : null,
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
                        activeReaction: widget.activeReaction,
                        inspecting: inspectedSeatID == playerOrder[index].id,
                        onInspectSeat: togglePlayerInspect,
                        currentProfileUserID: widget.currentProfileUserID,
                        comradeUserIDs: widget.comradeUserIDs,
                        incomingComradeRequestUserIDs:
                            widget.incomingComradeRequestUserIDs,
                        outgoingComradeRequestUserIDs:
                            widget.outgoingComradeRequestUserIDs,
                        onComradeRequestToUser: widget.onComradeRequestToUser,
                      ),
                    ),
                  ),
              ],
            ),
          ),
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

class CompactBrigadeGrid extends StatelessWidget {
  const CompactBrigadeGrid({
    required this.playerOrder,
    required this.trick,
    required this.model,
    required this.tokens,
    required this.language,
    this.activeReaction,
    this.planningTrumpFocusedSuit,
    this.inspectedSeatID,
    this.onInspectSeat,
    this.currentProfileUserID,
    this.comradeUserIDs = const {},
    this.incomingComradeRequestUserIDs = const {},
    this.outgoingComradeRequestUserIDs = const {},
    this.onComradeRequestToUser,
    this.onAction,
    super.key,
  });

  final List<Seat> playerOrder;
  final Trick trick;
  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineReaction? activeReaction;
  final String? planningTrumpFocusedSuit;
  final int? inspectedSeatID;
  final ValueChanged<int>? onInspectSeat;
  final String? currentProfileUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final ValueChanged<LegalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gridSpacing = 8.0;
        final gridHeight = math.max(
          brigadeColumnMinHeight * 2 + gridSpacing,
          constraints.maxHeight - brigadePanelLocalPadding.vertical,
        );
        final cellWidth = math.max(
          0.0,
          (constraints.maxWidth - gridSpacing) / 2,
        );
        final cellHeight = math.max(
          brigadeColumnMinHeight,
          (gridHeight - gridSpacing) / 2,
        );
        final playerPanelWidth = brigadePlayerPanelWidth(cellWidth);
        final naturalPlayerPanelHeight = brigadePlayerPanelHeight(
          playerPanelWidth,
        );
        final playerPanelHeight = math.min(
          naturalPlayerPanelHeight,
          cellHeight * 0.34,
        );
        final desiredPlayObjectWidth = brigadePlayObjectWidth(
          columnWidth: cellWidth,
          minWidth: tokens.card.medium.width,
        );
        final playObjectMaxHeight = brigadePlayObjectMaxHeight(
          cellHeight,
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

        return Padding(
          padding: brigadePanelLocalPadding,
          child: SizedBox(
            height: gridHeight,
            child: Column(
              spacing: gridSpacing,
              children: [
                for (var row = 0; row < 2; row++)
                  Expanded(
                    child: Row(
                      spacing: gridSpacing,
                      children: [
                        for (var column = 0; column < 2; column++)
                          Expanded(
                            child: compactGridColumn(
                              playerOrder[row * 2 + column],
                              cellWidth,
                              cellHeight,
                              playerPanelWidth,
                              playerPanelHeight,
                              playObjectWidth,
                              playObjectHeight,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget compactGridColumn(
    Seat seat,
    double columnWidth,
    double columnHeight,
    double playerPanelWidth,
    double playerPanelHeight,
    double playObjectWidth,
    double playObjectHeight,
  ) {
    return BrigadePlayerColumn(
      seat: seat,
      play: trick.playForSeat(seat.id),
      pendingPlayCard: selectedTrickPreviewCard(
        model,
        seat,
        trick.playForSeat(seat.id),
      ),
      planningTrumpChooser:
          model.table.phase == phasePlanning &&
              seat.id == model.table.currentPlayerID
          ? PlanningTrumpPanel(
              model: model,
              tokens: tokens,
              language: language,
              focusedSuit: planningTrumpFocusedSuit,
              onAction: onAction,
            )
          : null,
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
      activeReaction: activeReaction,
      inspecting: inspectedSeatID == seat.id,
      onInspectSeat: onInspectSeat,
      currentProfileUserID: currentProfileUserID,
      comradeUserIDs: comradeUserIDs,
      incomingComradeRequestUserIDs: incomingComradeRequestUserIDs,
      outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs,
      onComradeRequestToUser: onComradeRequestToUser,
    );
  }
}

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

TableCard? selectedTrickPreviewCard(
  TableViewModel model,
  Seat seat,
  TrickPlay? play,
) {
  final selectedCardID = model.selection.handCardID;
  if (model.table.phase != phaseTrick ||
      selectedCardID == null ||
      seat.id != model.table.currentPlayerID ||
      play != null) {
    return null;
  }
  for (final card in seat.hand) {
    if (card.id == selectedCardID) {
      return card;
    }
  }
  return null;
}

class BrigadePlayerColumn extends StatelessWidget {
  const BrigadePlayerColumn({
    required this.seat,
    required this.play,
    required this.pendingPlayCard,
    required this.planningTrumpChooser,
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
    this.activeReaction,
    this.inspecting = false,
    this.onInspectSeat,
    this.currentProfileUserID,
    this.comradeUserIDs = const {},
    this.incomingComradeRequestUserIDs = const {},
    this.outgoingComradeRequestUserIDs = const {},
    this.onComradeRequestToUser,
    super.key,
  });

  final Seat seat;
  final TrickPlay? play;
  final TableCard? pendingPlayCard;
  final Widget? planningTrumpChooser;
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
  final OnlineReaction? activeReaction;
  final bool inspecting;
  final ValueChanged<int>? onInspectSeat;
  final String? currentProfileUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;

  @override
  Widget build(BuildContext context) {
    final active = phase == phaseTrick && seat.isCurrentTurn && play == null;
    final planningSelector =
        phase == phasePlanning && planningTrumpChooser != null;
    final activeColumn =
        active ||
        planningSelector ||
        (phase == phaseAssignment && play != null);
    final human = seat.isViewer;
    final playAreaChild = planningTrumpChooser != null
        ? FittedBox(fit: BoxFit.contain, child: planningTrumpChooser)
        : play == null
        ? pendingPlayCard == null
              ? CardSlot(
                  active: active,
                  human: human,
                  width: playObjectWidth,
                  height: playObjectHeight,
                  tokens: tokens,
                  language: language,
                )
              : PendingTrickPreview(
                  card: pendingPlayCard!,
                  active: active,
                  human: human,
                  width: playObjectWidth,
                  height: playObjectHeight,
                  trump: trump,
                  tokens: tokens,
                  language: language,
                )
        : MotionTrackedRegion(
            motionKey: trickCardMotionSourceKey(play!.card.id),
            child: FittedBox(
              fit: BoxFit.contain,
              child: GameCard(
                card: play!.card,
                tokens: tokens,
                trump: trump,
                sizeOverride: tokens.card.large,
              ),
            ),
          );

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
          child: inspecting
              ? SizedBox.expand(
                  child: ExpandedPlayerInfoPanel(
                    seat: seat,
                    tokens: tokens,
                    language: language,
                    maxTricks: maxTricks,
                    currentProfileUserID: currentProfileUserID,
                    comradeUserIDs: comradeUserIDs,
                    incomingComradeRequestUserIDs:
                        incomingComradeRequestUserIDs,
                    outgoingComradeRequestUserIDs:
                        outgoingComradeRequestUserIDs,
                    onComradeRequestToUser: onComradeRequestToUser,
                    onClose: onInspectSeat == null
                        ? null
                        : () => onInspectSeat!(seat.id),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: playerPanelWidth,
                      height: playerPanelHeight,
                      child: PlayerBadge(
                        seat: seat,
                        tokens: tokens,
                        active: active || planningSelector,
                        width: playerPanelWidth,
                        height: playerPanelHeight,
                        maxTricks: maxTricks,
                        language: language,
                        reaction: activeReaction?.playerID == seat.id
                            ? activeReaction
                            : null,
                        onInspect: onInspectSeat == null
                            ? null
                            : () => onInspectSeat!(seat.id),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        top: brigadePlayAreaTopInset,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: playObjectWidth,
                          height: playObjectHeight,
                          child: playAreaChild,
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

class PendingTrickPreview extends StatelessWidget {
  const PendingTrickPreview({
    required this.card,
    required this.active,
    required this.human,
    required this.width,
    required this.height,
    required this.trump,
    required this.tokens,
    required this.language,
    super.key,
  });

  final TableCard card;
  final bool active;
  final bool human;
  final double width;
  final double height;
  final String? trump;
  final DesignTokens tokens;
  final KolkhozLanguage language;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CardSlot(
          active: active,
          human: human,
          width: width,
          height: height,
          tokens: tokens,
          language: language,
          showPrompt: false,
        ),
        Positioned.fill(
          child: Center(
            child: FractionallySizedBox(
              widthFactor: pendingTrickPreviewScale,
              heightFactor: pendingTrickPreviewScale,
              child: Opacity(
                key: const Key('pending-trick-card-preview'),
                opacity: pendingTrickPreviewOpacity,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: GameCard(
                    card: card,
                    tokens: tokens,
                    trump: trump,
                    sizeOverride: tokens.card.large,
                    motionTracked: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const pendingTrickPreviewOpacity = 0.46;
const pendingTrickPreviewScale = 0.84;

class PlayerBadge extends StatelessWidget {
  const PlayerBadge({
    required this.seat,
    required this.tokens,
    required this.active,
    required this.language,
    this.reaction,
    this.width = 178,
    this.height = 40,
    this.maxTricks = 4,
    this.onInspect,
    super.key,
  });

  final Seat seat;
  final DesignTokens tokens;
  final bool active;
  final KolkhozLanguage language;
  final OnlineReaction? reaction;
  final double width;
  final double height;
  final int maxTricks;
  final VoidCallback? onInspect;

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
    return MotionTrackedRegion(
      motionKey: playerCardMotionSourceKey(seat.id),
      child: SizedBox(
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
                      child: Tooltip(
                        message: displayName,
                        child: Semantics(
                          button: true,
                          label: displayName,
                          child: GestureDetector(
                            key: Key('player-portrait-${seat.id}-inspect'),
                            behavior: HitTestBehavior.opaque,
                            onTap: onInspect,
                            child: PortraitFrame(
                              seat: seat,
                              tokens: tokens,
                              width: portraitSize,
                              height: portraitSize,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (reaction != null)
                      Positioned(
                        key: ValueKey(
                          'portrait-reaction-${reaction!.revision}',
                        ),
                        left: portraitLeft,
                        top: portraitTop,
                        width: portraitSize,
                        height: portraitSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: tokens.colors.black.withValues(alpha: 0.62),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(portraitSize * 0.18),
                            child: Image.asset(
                              'ios_resources/Icons/${reactionAsset(reaction!.reactionID)}',
                              filterQuality: FilterQuality.none,
                            ),
                          ),
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
      ),
    );
  }

  String get displayName {
    final base = seatDisplayName(seat, language: language);
    return seat.statusText.isEmpty ? base : '$base ${seat.statusText}';
  }

  List<String> get statusBadgeAssets {
    return [
      if (active)
        isHumanControlledSeat(seat)
            ? 'icon-status-current-turn.png'
            : 'icon-status-ai-thinking.png',
      if (seat.statusText.endsWith('s')) 'icon-turn-timer-clock.png',
      if (seat.isBrigadeLeader) 'icon-status-brigade-leader.png',
    ];
  }
}

class ExpandedPlayerInfoPanel extends StatelessWidget {
  const ExpandedPlayerInfoPanel({
    required this.seat,
    required this.tokens,
    required this.language,
    required this.maxTricks,
    this.currentProfileUserID,
    this.comradeUserIDs = const {},
    this.incomingComradeRequestUserIDs = const {},
    this.outgoingComradeRequestUserIDs = const {},
    this.onComradeRequestToUser,
    this.onClose,
    super.key,
  });

  final Seat seat;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final int maxTricks;
  final String? currentProfileUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final title = seatDisplayName(seat, language: language);
    final statusChips = [
      if (seat.isViewer) language.t(KolkhozText.tabledisplayYou),
      if (seat.isCurrentTurn) language.t(KolkhozText.kolkhozappCurrentTurn),
      if (seat.isBrigadeLeader) language.t(KolkhozText.kolkhozappBrigadeLeader),
      if (seat.statusText.isNotEmpty) seat.statusText,
    ];
    final stats = [
      PlayerProfileStat(
        label: language.t(KolkhozText.kolkhozappScore),
        value: seat.visibleScore.toString(),
      ),
      PlayerProfileStat(
        label: language.t(KolkhozText.kolkhozappMedals),
        value: '${seat.medals}/$maxTricks',
      ),
      PlayerProfileStat(
        label: language.t(KolkhozText.kolkhozappHand),
        value: playerInfoHandCount(seat).toString(),
      ),
      PlayerProfileStat(
        label: language.t(KolkhozText.kolkhozappCellar),
        value: playerInfoCellarCount(seat).toString(),
      ),
      PlayerProfileStat(
        label: language.t(KolkhozText.kolkhozappPlot),
        value: playerInfoVisiblePlotCount(seat).toString(),
      ),
      if (seat.profileStats != null)
        PlayerProfileStat(
          label: language.t(KolkhozText.kolkhozappRating),
          value: seat.profileStats!.rating.toString(),
          prominent: true,
        ),
    ];
    final profileUserID = seat.profileUserID;
    final showComradeAction =
        profileUserID != null &&
        profileUserID != currentProfileUserID &&
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

    return PlayerProfilePanel(
      key: Key('player-info-panel-${seat.id}'),
      tokens: tokens,
      displayName: title,
      portraitAsset: seat.portraitAsset,
      subtitle: playerInfoControllerLabel(seat),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelText(
            language.t(KolkhozText.kolkhozappPlayer),
            size: PixelTextSize.xSmall,
            variant: PixelTextVariant.heavy,
            color: tokens.colors.gold,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          PixelText(
            title,
            size: PixelTextSize.caption,
            variant: PixelTextVariant.heavy,
            color: tokens.colors.cream,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ],
      ),
      active: seat.isCurrentTurn,
      portraitSelected: seat.isViewer,
      portraitSize: 58,
      minHeight: 0,
      padding: const EdgeInsets.all(10),
      onPortraitPressed: onClose,
      chips: [
        for (final chip in statusChips)
          PlayerProfileChip(
            label: chip,
            active: chip == language.t(KolkhozText.kolkhozappCurrentTurn),
          ),
      ],
      statGroups: [
        for (final stat in stats)
          PlayerProfileStatGroup(label: stat.label, stats: [stat]),
      ],
      expandStats: true,
      scrollStats: true,
      action: showComradeAction
          ? PlayerProfileAction(
              label: actionLabel,
              prominent: hasIncomingRequest,
              iconAsset: actionIcon,
              iconSize: 18,
              onPressed: actionEnabled
                  ? () => unawaited(onComradeRequestToUser!(profileUserID))
                  : null,
            )
          : null,
      footer: onClose == null
          ? null
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: SizedBox(
                height: 26,
                child: Center(
                  child: PixelText(
                    language.t(KolkhozText.kolkhozappCancel),
                    size: PixelTextSize.xSmall,
                    variant: PixelTextVariant.heavy,
                    color: tokens.colors.gold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
    );
  }
}

int playerInfoHandCount(Seat seat) {
  return math.max(seat.hand.length, seat.hiddenHandCount);
}

int playerInfoVisiblePlotCount(Seat seat) {
  return seat.plot.revealed.length +
      seat.plot.stacks.fold<int>(
        0,
        (total, stack) => total + stack.revealed.length,
      );
}

int playerInfoCellarCount(Seat seat) {
  return seat.plot.hidden.length +
      seat.plot.stacks.fold<int>(
        0,
        (total, stack) => total + stack.hidden.length,
      );
}

String playerInfoControllerLabel(Seat seat) {
  return seat.controller
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .trim()
      .toUpperCase();
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
              child: AnimatedSwitcher(
                duration: playerPanelMedalAppearDuration,
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child: index < medals
                    ? playerMedalIcon(iconSize, index)
                    : Opacity(
                        key: ValueKey('empty-medal-$index'),
                        opacity: playerPanelUnearnedMedalOpacity,
                        child: ChromeAssetIcon(
                          asset: 'ios_resources/Icons/icon-medal-star.png',
                          width: iconSize,
                          height: iconSize,
                          muted: true,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget playerMedalIcon(double size, int index) {
    return Image.asset(
      'ios_resources/Icons/icon-medal-star.png',
      key: ValueKey('earned-medal-$index'),
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
    );
  }
}

const playerPanelMedalIconSize = 12.0;
const playerPanelMedalSpacing = -4.0;
const playerPanelUnearnedMedalOpacity = 0.18;
const playerPanelMedalAppearDuration = Duration(milliseconds: 520);
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
    final cardBack = KolkhozCardBackScope.of(context);
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
          cardBack.iconAssetPath,
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
    this.showPrompt = true,
    super.key,
  });

  final bool active;
  final bool human;
  final double width;
  final double height;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool showPrompt;

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
          child: active && showPrompt
              ? PixelText(
                  human
                      ? language.t(KolkhozText.boardviewYourTurn)
                      : language.t(KolkhozText.boardviewWait),
                  size: human ? PixelTextSize.headline : PixelTextSize.caption2,
                  variant: PixelTextVariant.heavy,
                  color: human
                      ? tokens.colors.goldBright
                      : tokens.colors.redBright,
                  textAlign: TextAlign.center,
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
      duration: cardSlotPulseDuration,
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
const cardSlotPulseDuration = Duration(milliseconds: 1800);
const cardSlotActiveScale = 1.035;
const cardSlotHumanFillOpacity = 0.18;
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
    this.focusedSuit,
    this.onAction,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String? focusedSuit;
  final ValueChanged<LegalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final isFamine = model.table.isFamine;
    final aiSelecting = planningTrumpSelectorIsAI(model) && focusedSuit != null;
    final actionHandler = onAction;
    final trumpOptions = planningTrumpOptions(
      model.legalActions,
      language: language,
    );
    final title = isFamine
        ? language.t(KolkhozText.boardviewFamineYear)
        : language.t(KolkhozText.boardviewChooseTrump);
    return PanelStyleSurface(
      tokens: tokens,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: planningTrumpPanelSpacing,
        children: [
          SizedBox(
            width: planningTrumpPanelWidth,
            child: PixelText(
              title,
              textAlign: TextAlign.center,
              size: PixelTextSize.caption,
              variant: PixelTextVariant.heavy,
              color: isFamine ? tokens.colors.redBright : tokens.colors.gold,
              maxLines: 2,
              overflow: TextOverflow.clip,
              softWrap: true,
            ),
          ),
          if (isFamine)
            Image.asset(
              'ios_resources/Icons/icon-famine.png',
              width: planningTrumpFamineIconSize,
              height: planningTrumpFamineIconSize,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          else
            SizedBox(
              width: planningTrumpPanelWidth,
              child: Wrap(
                spacing: planningTrumpGridSpacing,
                runSpacing: planningTrumpGridSpacing,
                alignment: WrapAlignment.center,
                children: [
                  for (final option in trumpOptions)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: option.action != null && actionHandler != null
                          ? () => actionHandler(option.action!)
                          : null,
                      child: TrumpSelectionButton(
                        suit: option.suit,
                        label: option.label,
                        selected: option.suit == model.table.trump,
                        aiFocused: aiSelecting && option.suit == focusedSuit,
                        tokens: tokens,
                        size: planningTrumpButtonSize,
                        iconSize: planningTrumpIconSize,
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

bool planningTrumpSelectorIsAI(TableViewModel model) {
  if (model.table.phase != phasePlanning || model.table.isFamine) {
    return false;
  }
  for (final seat in model.table.seats) {
    if (seat.id == model.table.currentPlayerID) {
      return seat.controller == controllerHeuristicAI ||
          seat.controller == controllerMediumAI ||
          seat.controller == controllerNeuralAI;
    }
  }
  return false;
}

const planningTrumpPanelWidth = 112.0;
const planningTrumpButtonSize = 46.0;
const planningTrumpIconSize = 29.0;
const planningTrumpGridSpacing = 6.0;
const planningTrumpPanelSpacing = 7.0;
const planningTrumpFamineIconSize = 46.0;
const planningTrumpAiSelectorHopDuration = Duration(milliseconds: 230);

class TrumpSelectionButton extends StatelessWidget {
  const TrumpSelectionButton({
    required this.suit,
    required this.label,
    required this.selected,
    required this.tokens,
    this.aiFocused = false,
    this.size = 54,
    this.iconSize = 34,
    super.key,
  });

  final String suit;
  final String label;
  final bool selected;
  final DesignTokens tokens;
  final bool aiFocused;
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
                child: ChromeButtonBackground(
                  asset: selected
                      ? chromeButtonPrimaryCurrentAsset
                      : chromeButtonSecondaryCurrentAsset,
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
              if (aiFocused)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: planningTrumpAiSelectorFrameDuration,
                      curve: Curves.easeOutBack,
                      margin: EdgeInsets.all(2 * scale),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7 * scale),
                        border: Border.all(
                          color: tokens.colors.green,
                          width: 3 * scale,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.colors.green.withValues(alpha: 0.62),
                            blurRadius: 10 * scale,
                            spreadRadius: 1.5 * scale,
                          ),
                        ],
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

const planningTrumpAiSelectorFrameDuration = Duration(milliseconds: 120);
