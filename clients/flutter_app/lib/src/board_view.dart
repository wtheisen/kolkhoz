import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show clampDouble, lerpDouble;

import 'package:flutter/material.dart';

import 'animation_speed.dart';
import 'app_settings.dart';
import 'app_text.dart';
import 'assignment_display.dart';
import 'chrome_button.dart';
import 'render_model.dart';
import 'design_tokens.dart';
import 'game_constants.dart';
import 'online_game_models.dart';
import 'pixel_text.dart';
import 'player_profile_panel.dart';
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

part 'board/brigade_panel.dart';

String hotSeatPhaseLine(TableViewModel model, {KolkhozLanguage? language}) {
  final resolvedLanguage = language ?? KolkhozLanguage.en;
  final phaseName = resolvedLanguage.phaseName(model.table.phase);
  return resolvedLanguage.t(KolkhozText.phasedisplayYearValue1Phasename, {
    'value1': model.table.year,
    'phaseName': phaseName,
  });
}

const hotSeatScrimOpacity = 0.96;
const hotSeatPanelWidthFactor = 0.58;
const hotSeatPanelMinWidth = 300.0;
const hotSeatPanelMaxWidth = 470.0;
const hotSeatPanelHorizontalPadding = 20.0;
const hotSeatPanelVerticalPadding = 18.0;
const hotSeatContentSpacing = 14.0;
const hotSeatTitleRowHeight = 62.0;
const hotSeatPlacardMaxWidth = 310.0;
const hotSeatPlacardMaxHeight = 78.0;
const hotSeatPlacardOpacity = 0.92;
const hotSeatPortraitHeightFactor = 0.20;
const hotSeatPortraitMinSize = 58.0;
const hotSeatPortraitMaxSize = 86.0;
const hotSeatPortraitShadowOpacity = 0.35;
const hotSeatPortraitShadowRadius = 8.0;
const hotSeatPortraitShadowYOffset = 4.0;
const hotSeatLabelSpacing = 4.0;
const hotSeatPhaseLineFontSize = 13.0;
const hotSeatReadyButtonMaxWidth = 210.0;

double hotSeatPanelWidth(double availableWidth) {
  return clampDouble(
    availableWidth * hotSeatPanelWidthFactor,
    hotSeatPanelMinWidth,
    hotSeatPanelMaxWidth,
  );
}

double hotSeatPortraitSlotSize(double availableHeight) {
  return clampDouble(
    availableHeight * hotSeatPortraitHeightFactor,
    hotSeatPortraitMinSize,
    hotSeatPortraitMaxSize,
  );
}

Seat hotSeatPrivacyPlayer(TableViewModel model) {
  return localSeat(model);
}

const playerPanelActiveShadowOpacity = 0.18;
const playerPanelInactiveShadowOpacity = 0.24;
const playerPanelShadowRadius = 4.0;

double playerPanelScale(double height) => clampDouble(height / 48, 1, 2.35);

double playerPanelOuterInset(double width, [double height = 48]) =>
    clampDouble(width * 0.04, 5, 7) * playerPanelScale(height);

double playerPanelPortraitColumnWidth(double width, double height) {
  return math.min(math.max(34, width * 0.28), math.max(34, height * 0.92));
}

double playerPanelPortraitSize(double width, double height) {
  final outerInset = playerPanelOuterInset(width, height);
  final naturalSize =
      math.max(24, height - outerInset * 2 - 2 * playerPanelScale(height)) *
      1.1;
  return clampDouble(naturalSize, 24, height * 0.75);
}

double playerPanelPortraitLeft(double width, double portraitSize) {
  return math.max(0, width * 0.18 - portraitSize / 2);
}

double playerPanelPortraitTop(double height, double portraitSize) {
  return math.max(0, height * 0.5 - portraitSize / 2);
}

double playerPanelContentLeft(double width) => width * 0.35;

double playerPanelContentRight(double width) => width * 0.86;

double playerPanelNameTop(double height) => height * 0.29;

double playerPanelScoreTop(double height) => height * 0.22;

double playerPanelLowerStatsTop(double height) => height * 0.51;

double playerPanelRowSpacing(double width, [double height = 48]) =>
    clampDouble(width * 0.025, 3, 5) * playerPanelScale(height);

double playerPanelStackSpacing(double width) =>
    clampDouble(width * 0.01, -1, -1);

double playerPanelStatColumnWidth(double width, [double height = 48]) =>
    clampDouble(width * 0.22, 44, 50) * playerPanelScale(height);

double playerPanelTopPadding(double height) => clampDouble(height * 0.07, 2, 8);

double playerPanelContentNaturalWidth(double width) {
  final statWidth = playerPanelStatColumnWidth(width);
  return math.max(80, statWidth * 2 + playerPanelRowSpacing(width) + 8);
}

double playerPanelContentNaturalWidthForSize(double width, double height) {
  final statWidth = playerPanelStatColumnWidth(width, height);
  return math.max(
    80 * playerPanelScale(height),
    statWidth * 2 + playerPanelRowSpacing(width, height) + 8,
  );
}

double playerPanelCellarCardSpacing(double width, [double height = 48]) {
  return -clampDouble(width * 0.03, 5, 6) * playerPanelScale(height);
}

const brigadePanelLocalPadding = EdgeInsets.only(top: 8);
const brigadeColumnSpacingWidthFactor = 0.012;
const brigadeColumnSpacingMin = 8.0;
const brigadeColumnSpacingMax = 14.0;
const brigadeColumnMinHeight = 120.0;
const brigadeColumnPadding = EdgeInsets.only(
  left: 8,
  top: 6,
  right: 8,
  bottom: 4,
);
const brigadePlayerPanelAspectRatio = 672 / 262;
const brigadePlayerPanelHeightMin = 42.0;
const brigadePlayObjectWidthFactor = 0.9;
const brigadePlayAreaTopInset = 10.0;
const brigadeColumnContentBottomPadding = 4.0;

double brigadeColumnSpacing(double width) {
  return clampDouble(
    width * brigadeColumnSpacingWidthFactor,
    brigadeColumnSpacingMin,
    brigadeColumnSpacingMax,
  );
}

double brigadeExpandedColumnWidth({
  required double maxWidth,
  required int columnCount,
  required double spacing,
}) {
  if (columnCount <= 0) {
    return 0;
  }
  return math.max(0, (maxWidth - spacing * (columnCount - 1)) / columnCount);
}

double brigadeColumnHeight(double availableHeight) {
  return math.max(
    brigadeColumnMinHeight,
    availableHeight - brigadePanelLocalPadding.vertical,
  );
}

double brigadeContentColumnHeight({
  required double playerPanelHeight,
  required double playObjectHeight,
}) {
  return math.max(
    brigadeColumnMinHeight,
    brigadeColumnPadding.vertical +
        playerPanelHeight +
        brigadePlayAreaTopInset +
        playObjectHeight +
        brigadeColumnContentBottomPadding,
  );
}

double brigadePanelHeightForWidth({
  required double maxWidth,
  required int columnCount,
  required double minCardWidth,
  required double cardAspectRatio,
}) {
  final spacing = brigadeColumnSpacing(maxWidth);
  final columnWidth = brigadeExpandedColumnWidth(
    maxWidth: maxWidth,
    columnCount: columnCount,
    spacing: spacing,
  );
  final playerPanelHeight = brigadePlayerPanelHeight(
    brigadePlayerPanelWidth(columnWidth),
  );
  final playObjectWidth = brigadePlayObjectWidth(
    columnWidth: columnWidth,
    minWidth: minCardWidth,
  );
  return brigadePanelLocalPadding.vertical +
      brigadeContentColumnHeight(
        playerPanelHeight: playerPanelHeight,
        playObjectHeight: brigadePlayObjectHeight(
          playObjectWidth,
          cardAspectRatio,
        ),
      );
}

double brigadeColumnContentWidth(double columnWidth) {
  return math.max(0, columnWidth - brigadeColumnPadding.horizontal);
}

double brigadePlayerPanelWidth(double columnWidth) {
  return brigadeColumnContentWidth(columnWidth);
}

double brigadePlayerPanelHeight(double panelWidth) {
  return math.max(
    brigadePlayerPanelHeightMin,
    panelWidth / brigadePlayerPanelAspectRatio,
  );
}

double brigadePlayObjectWidth({
  required double columnWidth,
  required double minWidth,
}) {
  return clampDouble(
    brigadeColumnContentWidth(columnWidth) * brigadePlayObjectWidthFactor,
    minWidth,
    double.infinity,
  );
}

double brigadePlayObjectMaxHeight(
  double columnHeight,
  double playerPanelHeight,
) {
  return math.max(
    0,
    columnHeight -
        brigadeColumnPadding.vertical -
        playerPanelHeight -
        brigadePlayAreaTopInset -
        brigadeColumnContentBottomPadding,
  );
}

double brigadePlayObjectFittingWidth({
  required double desiredWidth,
  required double maxHeight,
  required double aspectRatio,
}) {
  if (aspectRatio <= 0) {
    return desiredWidth;
  }
  return math.max(0, math.min(desiredWidth, maxHeight / aspectRatio));
}

double brigadePlayObjectHeight(double width, double aspectRatio) =>
    width * aspectRatio;

class TrumpActionOption {
  const TrumpActionOption({
    required this.suit,
    required this.label,
    required this.action,
  });

  final String suit;
  final String label;
  final LegalAction? action;

  bool get enabled => action != null;
}

List<TrumpActionOption> planningTrumpOptions(
  List<LegalAction> actions, {
  KolkhozLanguage? language,
}) {
  final bySuit = {
    for (final action in actions)
      if (action.kind == actionSetTrump && action.engineAction.suit != null)
        action.engineAction.suit!: action,
  };
  return displaySuitOrder
      .map(
        (suit) => TrumpActionOption(
          suit: suit,
          label: (language ?? KolkhozLanguage.en).suitName(suit),
          action: bySuit[suit],
        ),
      )
      .toList(growable: false);
}

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
    this.heroOfSovietUnion = true,
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
  final bool heroOfSovietUnion;
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
                                  heroOfSovietUnion: heroOfSovietUnion,
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
                                        heroOfSovietUnion: heroOfSovietUnion,
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
    required this.heroOfSovietUnion,
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
  final bool heroOfSovietUnion;
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
            heroOfSovietUnion: heroOfSovietUnion,
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
    this.heroOfSovietUnion = true,
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
  final bool heroOfSovietUnion;
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
                        heroOfSovietUnion: heroOfSovietUnion,
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
    required this.heroOfSovietUnion,
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
  final bool heroOfSovietUnion;
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
          heroOfSovietUnion: heroOfSovietUnion,
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
