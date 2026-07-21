import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show clampDouble, lerpDouble;

import 'package:flutter/material.dart';
import 'animation_speed.dart';
import 'art_direction.dart';
import 'app_settings.dart';
import 'app_text.dart';
import 'assignment_display.dart';
import 'chrome_button.dart';
import 'render_model.dart';
import 'design_tokens.dart';
import 'game_constants.dart';
import 'field_plan_sign.dart';
import 'field_plan_typography.dart';
import 'field_plan_world_scene.dart';
import 'online_game_models.dart';
import 'pixel_text.dart';
import 'player_profile_panel.dart';
import 'plot_display.dart';
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

double fieldPlanCameraTravelProgress(double dragProgress) {
  final progress = clampDouble(dragProgress, 0, 1);
  return progress * progress * (3 - 2 * progress);
}

const fieldPlanCameraFullTravelDuration = Duration(milliseconds: 760);

Duration fieldPlanCameraTravelDuration(
  double distance, {
  int minimumMilliseconds = 80,
}) {
  return Duration(
    milliseconds: math.max(
      minimumMilliseconds,
      (fieldPlanCameraFullTravelDuration.inMilliseconds *
              clampDouble(distance, 0, 1))
          .round(),
    ),
  );
}

class BrigadeFieldsCoordinator extends StatefulWidget {
  const BrigadeFieldsCoordinator({
    required this.active,
    required this.builder,
    super.key,
  });

  final bool active;
  final Widget Function(BuildContext context, int verticalPage) builder;

  @override
  State<BrigadeFieldsCoordinator> createState() =>
      _BrigadeFieldsCoordinatorState();
}

class _BrigadeFieldsCoordinatorState extends State<BrigadeFieldsCoordinator>
    with TickerProviderStateMixin {
  int verticalPage = 0;
  late final AnimationController snapController;
  late final AnimationController focusController;
  double cameraPosition = 0;
  double rawCameraPosition = 0;
  int? dragStartPage;
  bool settlingTransition = false;
  String? focusedSurfaceID;

  @override
  void initState() {
    super.initState();
    snapController = AnimationController(vsync: this, upperBound: 2)
      ..addListener(() {
        if (mounted) {
          setState(() => cameraPosition = snapController.value);
        }
      });
    focusController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 440),
          reverseDuration: const Duration(milliseconds: 320),
        )..addListener(() {
          if (mounted) setState(() {});
        });
  }

  @override
  void didUpdateWidget(BrigadeFieldsCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && verticalPage != 0) {
      verticalPage = 0;
    }
    if (!widget.active &&
        (dragStartPage != null ||
            cameraPosition != 0 ||
            focusedSurfaceID != null)) {
      snapController.stop();
      focusController.stop();
      dragStartPage = null;
      cameraPosition = 0;
      rawCameraPosition = 0;
      snapController.value = 0;
      focusController.value = 0;
      focusedSurfaceID = null;
      settlingTransition = false;
    }
  }

  void handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!widget.active || settlingTransition || focusedSurfaceID != null) {
      return;
    }
    final delta = details.primaryDelta ?? 0;
    if (delta == 0) return;
    if (dragStartPage == null) {
      final targetPage = verticalPage + (delta > 0 ? 1 : -1);
      if (targetPage < 0 || targetPage > 2) return;
      dragStartPage = verticalPage;
      rawCameraPosition = verticalPage.toDouble();
      snapController.value = rawCameraPosition;
    }

    final dragDistance = math.max(1.0, (context.size?.height ?? 600) * 0.8);
    rawCameraPosition = clampDouble(
      rawCameraPosition + delta / dragDistance,
      0,
      2,
    );
    final followDistance = (snapController.value - rawCameraPosition).abs();
    unawaited(
      snapController.animateTo(
        rawCameraPosition,
        duration: Duration(
          milliseconds: math.max(45, (180 * followDistance).round()),
        ),
        curve: Curves.easeOut,
      ),
    );
  }

  void handleVerticalDragEnd(DragEndDetails details) {
    if (!widget.active || settlingTransition) return;
    final startPage = dragStartPage;
    if (startPage == null) return;
    final velocity = details.primaryVelocity ?? 0;
    final movement = rawCameraPosition - startPage;
    final direction = movement == 0
        ? (velocity >= 0 ? 1 : -1)
        : movement.sign.toInt();
    final complete = movement.abs() >= 0.35 || velocity.abs() > 250;
    final target = complete ? (startPage + direction).clamp(0, 2) : startPage;
    unawaited(_settleTransition(target));
  }

  void handleVerticalDragCancel() {
    final startPage = dragStartPage;
    if (startPage != null && !settlingTransition) {
      unawaited(_settleTransition(startPage));
    }
  }

  Future<void> _settleTransition(int targetPage) async {
    settlingTransition = true;
    final target = targetPage.toDouble();
    final distance = (cameraPosition - target).abs();
    await snapController.animateTo(
      target,
      duration: fieldPlanCameraTravelDuration(
        distance,
        minimumMilliseconds: 180,
      ),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      verticalPage = targetPage;
      cameraPosition = target;
      rawCameraPosition = target;
      dragStartPage = null;
      settlingTransition = false;
    });
  }

  Future<void> focusSurface(String? surfaceID) async {
    if (surfaceID == focusedSurfaceID && surfaceID != null) surfaceID = null;
    if (surfaceID == null) {
      await focusController.reverse();
      if (mounted) setState(() => focusedSurfaceID = null);
      return;
    }
    setState(() => focusedSurfaceID = surfaceID);
    await focusController.forward(from: 0);
  }

  @override
  void dispose() {
    snapController.dispose();
    focusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        BrigadeFieldsScope(
          verticalPage: verticalPage,
          transitionProgress: dragStartPage == null && !settlingTransition
              ? null
              : cameraPosition,
          focusedSurfaceID: focusedSurfaceID,
          focusProgress: focusController.value,
          onFocusSurface: focusSurface,
          child: GestureDetector(
            key: const Key('brigade-fields-swipe-surface'),
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: widget.active
                ? handleVerticalDragUpdate
                : null,
            onVerticalDragEnd: widget.active ? handleVerticalDragEnd : null,
            onVerticalDragCancel: widget.active
                ? handleVerticalDragCancel
                : null,
            child: Builder(
              builder: (context) => widget.builder(context, verticalPage),
            ),
          ),
        ),
      ],
    );
  }
}

class BrigadeFieldsScope extends InheritedWidget {
  const BrigadeFieldsScope({
    required this.verticalPage,
    required this.transitionProgress,
    required this.focusedSurfaceID,
    required this.focusProgress,
    required this.onFocusSurface,
    required super.child,
    super.key,
  });

  final int verticalPage;
  final double? transitionProgress;
  final String? focusedSurfaceID;
  final double focusProgress;
  final ValueChanged<String?> onFocusSurface;

  static int verticalPageOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BrigadeFieldsScope>()
          ?.verticalPage ??
      0;

  static double? transitionProgressOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BrigadeFieldsScope>()
      ?.transitionProgress;

  static double cameraPositionOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BrigadeFieldsScope>();
    return scope?.transitionProgress ?? scope?.verticalPage.toDouble() ?? 0;
  }

  static String? focusedSurfaceOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BrigadeFieldsScope>()
      ?.focusedSurfaceID;

  static double focusProgressOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BrigadeFieldsScope>()
          ?.focusProgress ??
      0;

  static ValueChanged<String?>? focusSurfaceHandlerOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BrigadeFieldsScope>()
          ?.onFocusSurface;

  @override
  bool updateShouldNotify(BrigadeFieldsScope oldWidget) =>
      verticalPage != oldWidget.verticalPage ||
      transitionProgress != oldWidget.transitionProgress ||
      focusedSurfaceID != oldWidget.focusedSurfaceID ||
      focusProgress != oldWidget.focusProgress;
}

class ConsumableRevealDriver extends StatefulWidget {
  const ConsumableRevealDriver({
    required this.model,
    required this.speed,
    required this.onAction,
    required this.child,
    this.presentationActive = false,
    super.key,
  });

  final TableViewModel model;
  final GameAnimationSpeed speed;
  final ValueChanged<LegalAction>? onAction;
  final Widget child;
  final bool presentationActive;

  @override
  State<ConsumableRevealDriver> createState() => _ConsumableRevealDriverState();
}

class _ConsumableRevealDriverState extends State<ConsumableRevealDriver> {
  Timer? timer;
  String? scheduledAction;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(ConsumableRevealDriver oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    final action = widget.presentationActive
        ? null
        : widget.model.legalActions
              .where(
                (candidate) =>
                    candidate.kind == actionRevealReward ||
                    candidate.kind == actionRevealTrump,
              )
              .firstOrNull;
    final signature = action == null
        ? null
        : '${widget.model.table.year}:${action.kind}:${action.engineAction.suit ?? ''}';
    if (signature == scheduledAction) {
      return;
    }
    timer?.cancel();
    scheduledAction = signature;
    if (action == null || widget.onAction == null) {
      return;
    }
    timer = Timer(
      switch (widget.speed) {
        GameAnimationSpeed.instant => Duration.zero,
        GameAnimationSpeed.fast => const Duration(milliseconds: 280),
        GameAnimationSpeed.normal => const Duration(milliseconds: 420),
        GameAnimationSpeed.slow => const Duration(milliseconds: 700),
      },
      () {
        if (mounted && scheduledAction == signature) {
          widget.onAction?.call(action);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    this.onHandCardTap,
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
    this.presentationRevision,
    this.assignmentPresentationCardIDs = const [],
    this.onPresentationComplete,
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
  final ValueChanged<String>? onHandCardTap;
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
  final int? presentationRevision;
  final List<String> assignmentPresentationCardIDs;
  final ValueChanged<int>? onPresentationComplete;
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
    final fieldsNavigationActive =
        configuredKolkhozArtStyle.usesNewArt &&
        (model.panels.active == panelBrigade ||
            model.panels.active == panelPlot) &&
        model.table.phase != phaseGameOver;
    return BrigadeFieldsCoordinator(
      active: fieldsNavigationActive,
      builder: (context, verticalPage) => KolkhozCardBackScope(
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
              final safePadding = MediaQuery.paddingOf(context);
              final compact = shouldUseCompactBoardShell(
                contentWidth: contentWidth,
                contentHeight: contentHeight,
              );
              final showFieldPlanBrigadeEnvironment =
                  configuredKolkhozArtStyle.usesNewArt &&
                  !compact &&
                  (model.table.phase == phaseAssignment ||
                      model.panels.active == panelBrigade ||
                      model.panels.active == panelPlot) &&
                  model.table.phase != phaseGameOver;
              final fieldPlanEnvironmentPage = showFieldPlanBrigadeEnvironment
                  ? model.table.phase == phaseAssignment
                        ? 1
                        : verticalPage
                  : null;
              final gameWidth = showFieldPlanBrigadeEnvironment
                  ? boardWidth
                  : boardWidth - railWidth - separatorWidth;

              return DecoratedBox(
                decoration: boardBackdropDecoration(tokens),
                child: CardMotionLayer(
                  model: model,
                  tokens: tokens,
                  speed: animationSpeed,
                  presentationRevision: presentationRevision,
                  assignmentPresentationCardIDs: assignmentPresentationCardIDs,
                  onPresentationComplete: onPresentationComplete,
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
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (compact)
                                  CompactBoardShell(
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
                                    onHandCardTap: onHandCardTap,
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
                                else
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (!showFieldPlanBrigadeEnvironment) ...[
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
                                      ],
                                      SizedBox(
                                        width: gameWidth,
                                        height: contentHeight,
                                        child: BoardPlayArea(
                                          model: model,
                                          tokens: tokens,
                                          metrics: metrics,
                                          fieldPlanBoardWidth: boardWidth,
                                          fieldPlanBoardHeight: contentHeight,
                                          fieldPlanBoardLeftInset:
                                              showFieldPlanBrigadeEnvironment
                                              ? 0
                                              : railWidth + separatorWidth,
                                          fieldPlanEnvironmentPage:
                                              fieldPlanEnvironmentPage,
                                          heroOfSovietUnion: heroOfSovietUnion,
                                          onAction: onAction,
                                          onPanelSelected: onPanelSelected,
                                          onSwapHandCardTap: onSwapHandCardTap,
                                          onHandCardTap: onHandCardTap,
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
                                          onAppearanceToggle:
                                              onAppearanceToggle,
                                          onCardBackChanged: onCardBackChanged,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (model.viewer.privacyMode ==
                          viewerPrivacyHotSeatHidden)
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
    this.onHandCardTap,
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
  final ValueChanged<String>? onHandCardTap;
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
            onHandCardTap: onHandCardTap,
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
                        iconPath: 'assets/ui/Icons/icon-pass-device.png',
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
                          'assets/ui/Embellishments/art-pass-device-placard.png',
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
    this.fieldPlanBoardWidth,
    this.fieldPlanBoardHeight,
    this.fieldPlanBoardLeftInset = 0,
    this.fieldPlanEnvironmentPage,
    this.heroOfSovietUnion = true,
    this.onAction,
    this.onPanelSelected,
    this.onSwapHandCardTap,
    this.onHandCardTap,
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
  final double? fieldPlanBoardWidth;
  final double? fieldPlanBoardHeight;
  final double fieldPlanBoardLeftInset;
  final int? fieldPlanEnvironmentPage;
  final bool heroOfSovietUnion;
  final ValueChanged<LegalAction>? onAction;
  final ValueChanged<String>? onPanelSelected;
  final ValueChanged<String>? onSwapHandCardTap;
  final ValueChanged<String>? onHandCardTap;
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
    final fieldPlanEnvironmentActive = fieldPlanEnvironmentPage != null;
    final topInfoHeight = fieldPlanEnvironmentActive
        ? 0.0
        : metrics.topInfoHeight;
    final fieldPlanTransitionProgress = BrigadeFieldsScope.transitionProgressOf(
      context,
    );
    final fieldPlanCameraPosition = BrigadeFieldsScope.cameraPositionOf(
      context,
    );
    final fieldPlanFocusedSurface = BrigadeFieldsScope.focusedSurfaceOf(
      context,
    );
    final fieldPlanFocusProgress = BrigadeFieldsScope.focusProgressOf(context);
    final fieldPlanFocusHandler = BrigadeFieldsScope.focusSurfaceHandlerOf(
      context,
    );
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
            constraints.maxHeight - topInfoHeight,
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
            builder:
                (
                  context,
                  planningTrumpFocusedSuit,
                  planningTrumpAction,
                  onPlanningTrumpActionSelected,
                ) {
                  final activePanelWithFocus = IgnorePointer(
                    ignoring: fieldPlanTransitionProgress != null,
                    child: Stack(
                      children: [
                        if (fieldPlanEnvironmentPage == null)
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
                              onConfirmMainMenuChanged:
                                  onConfirmMainMenuChanged,
                              showInvalidTapHints: showInvalidTapHints,
                              onShowInvalidTapHintsChanged:
                                  onShowInvalidTapHintsChanged,
                              language: language,
                              appearance: appearance,
                              cardBack: cardBack,
                              compact: compact,
                              planningTrumpFocusedSuit:
                                  planningTrumpFocusedSuit,
                              onPlanningTrumpActionSelected:
                                  onPlanningTrumpActionSelected,
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
                              fieldPlanBoardWidth: fieldPlanBoardWidth,
                              fieldPlanBoardHeight: fieldPlanBoardHeight,
                              fieldPlanBoardLeftInset:
                                  fieldPlanBoardLeftInset +
                                  metrics.playAreaHorizontalPadding,
                              fieldPlanBoardTopInset: topInfoHeight,
                              fieldPlanEnvironmentPage:
                                  fieldPlanEnvironmentPage,
                            ),
                          ),
                        ),
                        if (!fieldPlanEnvironmentActive) ...[
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
                      ],
                    ),
                  );
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (fieldPlanEnvironmentPage case final page?)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: handTrayHeight,
                          child: FieldPlanWorldScene(
                            key: const Key('field-plan-world-scene'),
                            cameraPosition: fieldPlanCameraPosition,
                            overlayPage: page,
                            focusedSurfaceID: fieldPlanFocusedSurface,
                            focusProgress: fieldPlanFocusProgress,
                            onFocusSurface: fieldPlanFocusHandler ?? (_) {},
                            overlay: activePanelWithFocus,
                          ),
                        ),
                      Column(
                        children: [
                          if (topInfoHeight > 0)
                            SizedBox(height: topInfoHeight),
                          if (panelHeight == null)
                            Expanded(
                              child: fieldPlanEnvironmentActive
                                  ? const SizedBox.expand()
                                  : activePanelWithFocus,
                            )
                          else
                            SizedBox(
                              height: panelHeight,
                              child: fieldPlanEnvironmentActive
                                  ? const SizedBox.expand()
                                  : activePanelWithFocus,
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
                                  confirmActionOverride: planningTrumpAction,
                                  onAction: onAction,
                                  onPanelSelected: onPanelSelected,
                                  onSwapHandCardTap: onSwapHandCardTap,
                                  onHandCardTap: onHandCardTap,
                                  onAssignmentCardTap: onAssignmentCardTap,
                                  onInvalidHandCardTap: onInvalidHandCardTap,
                                  canUndo: canUndo,
                                  onUndo: onUndo,
                                  contentOverride:
                                      model.panels.active == panelLog
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
                      if (!fieldPlanEnvironmentActive)
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
                                      language: language,
                                      animationSpeed: animationSpeed,
                                    ),
                                  ),
                                )
                              : TopInfoStrip(
                                  model: model,
                                  tokens: tokens,
                                  metrics: metrics,
                                  language: language,
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
  final Widget Function(
    BuildContext context,
    String? focusedSuit,
    LegalAction? selectedAction,
    ValueChanged<LegalAction> onActionSelected,
  )
  builder;

  @override
  State<PlanningTrumpFocusHost> createState() => _PlanningTrumpFocusHostState();
}

class _PlanningTrumpFocusHostState extends State<PlanningTrumpFocusHost> {
  final math.Random selectorRandom = math.Random();
  Timer? selectorTimer;
  int selectorIndex = 0;
  LegalAction? selectedAction;

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
            widget.model.table.currentPlayerID ||
        oldWidget.model.table.phase != widget.model.table.phase) {
      selectedAction = null;
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
        : selectedAction?.engineAction.suit;
    return widget.builder(context, focusedSuit, selectedAction, (action) {
      setState(() => selectedAction = action);
    });
  }
}

class TopInfoStrip extends StatefulWidget {
  const TopInfoStrip({
    required this.model,
    required this.tokens,
    required this.metrics,
    required this.language,
    required this.animationSpeed,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final ResponsiveBoardMetrics metrics;
  final KolkhozLanguage language;
  final GameAnimationSpeed animationSpeed;

  @override
  State<TopInfoStrip> createState() => _TopInfoStripState();
}

class _TopInfoStripState extends State<TopInfoStrip> {
  final Map<String, LayerLink> jobGaugeLinks = {
    for (final suit in displaySuitOrder) suit: LayerLink(),
  };
  OverlayEntry? jobOverlay;
  String? openJobSuit;

  @override
  void didUpdateWidget(TopInfoStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (openJobSuit != null &&
        !widget.model.table.jobs.any((job) => job.suit == openJobSuit)) {
      closeJobOverlay();
    } else {
      jobOverlay?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    jobOverlay?.remove();
    super.dispose();
  }

  void toggleJobOverlay(String suit) {
    if (openJobSuit == suit) {
      closeJobOverlay();
      return;
    }
    closeJobOverlay();
    openJobSuit = suit;
    jobOverlay = OverlayEntry(builder: buildJobOverlay);
    Overlay.of(context).insert(jobOverlay!);
    setState(() {});
  }

  void closeJobOverlay() {
    jobOverlay?.remove();
    jobOverlay = null;
    openJobSuit = null;
    if (mounted) {
      setState(() {});
    }
  }

  Widget buildJobOverlay(BuildContext context) {
    final suit = openJobSuit;
    if (suit == null) {
      return const SizedBox.shrink();
    }
    final job = widget.model.table.jobs.firstWhere(
      (job) => job.suit == suit,
      orElse: () => emptyVisualJob(suit),
    );
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(240.0, screenSize.width - 16);
    final height = math.min(320.0, screenSize.height * 0.56);
    final firstGauge = suit == displaySuitOrder.first;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: closeJobOverlay,
          ),
        ),
        CompositedTransformFollower(
          link: jobGaugeLinks[suit]!,
          targetAnchor: firstGauge
              ? Alignment.bottomLeft
              : Alignment.bottomCenter,
          followerAnchor: firstGauge ? Alignment.topLeft : Alignment.topCenter,
          offset: const Offset(0, 7),
          showWhenUnlinked: false,
          child: SizedBox(
            key: ValueKey('job-gauge-overlay-$suit'),
            width: width,
            height: height,
            child: JobTile(
              job: job,
              assignmentPhase: false,
              trump: widget.model.table.trump,
              tokens: widget.tokens,
              language: widget.language,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final tokens = widget.tokens;
    final metrics = widget.metrics;
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
    String? turnClock;
    for (final seat in model.table.seats) {
      if (RegExp(r'^\d+s$').hasMatch(seat.statusText)) {
        turnClock = seat.statusText;
        break;
      }
    }
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
          final scoreWidth = clampDouble(
            constraints.maxWidth * topInfo.scoreWidthFactor,
            topInfo.scoreWidthMin,
            topInfo.scoreWidthMax,
          );
          final scoreGroupWidth = scoreWidth * 2 + rowSpacing;
          final contentWidth =
              gaugesWidth +
              scoreGroupWidth +
              rowSpacing +
              (turnClock == null ? 0 : scoreWidth + rowSpacing);

          return ClipRect(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight,
                child: Row(
                  spacing: rowSpacing,
                  children: [
                    SizedBox(
                      width: gaugesWidth,
                      height: gaugeHeight,
                      child: Row(
                        spacing: gaugeSpacing,
                        children: [
                          for (final job in jobs)
                            SizedBox(
                              width: gaugeFrameWidth,
                              child: Center(
                                child: CompositedTransformTarget(
                                  link: jobGaugeLinks[job.suit]!,
                                  child: Semantics(
                                    button: true,
                                    label:
                                        '${widget.language.suitName(job.suit)} job',
                                    expanded: openJobSuit == job.suit,
                                    child: GestureDetector(
                                      key: ValueKey(
                                        'job-gauge-button-${job.suit}',
                                      ),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => toggleJobOverlay(job.suit),
                                      child: MotionTrackedRegion(
                                        motionKey: jobGaugeMotionTargetKey(
                                          job.suit,
                                        ),
                                        child: JobGauge(
                                          job: job,
                                          highlighted:
                                              model.table.trump == job.suit,
                                          width:
                                              gaugeWidth *
                                              topInfo
                                                  .gaugeContentWidthMultiplier,
                                          height: gaugeHeight,
                                          tokens: tokens,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: scoreGroupWidth,
                      child: Row(
                        spacing: rowSpacing,
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
                    if (turnClock != null) ...[
                      const Spacer(),
                      SizedBox(
                        key: const Key('online-turn-clock'),
                        width: scoreWidth,
                        child: TopInfoCell(
                          icon: 'icon-turn-timer-clock.png',
                          value: turnClock,
                          iconSize: gaugeHeight * 0.68,
                          contentSpacing: rowSpacing,
                          height: metrics.topInfoHeight,
                          tokens: tokens,
                        ),
                      ),
                    ],
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
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          spacing: contentSpacing,
          children: [
            Image.asset(
              'assets/ui/Icons/$icon',
              width: iconSize,
              height: iconSize,
              filterQuality: FilterQuality.none,
            ),
            if (value.isNotEmpty)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: PixelText(
                    value,
                    size: PixelTextSize.cardRank,
                    variant: PixelTextVariant.heavy,
                    color: tokens.colors.gold,
                  ),
                ),
              ),
          ],
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
    super.key,
  });

  final Job job;
  final bool highlighted;
  final double width;
  final double height;
  final DesignTokens tokens;

  @override
  State<JobGauge> createState() => _JobGaugeState();
}

class _JobGaugeState extends State<JobGauge> {
  int deltaSerial = 0;
  CardMotionController? motionController;
  final Map<String, int> pendingCardDeltas = {};
  final List<_VisibleJobGaugeDelta> visibleDeltas = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = CardMotionScope.maybeOf(context)?.controller;
    if (identical(next, motionController)) {
      return;
    }
    motionController?.jobCardArrival.removeListener(_handleJobCardArrival);
    motionController = next;
    motionController?.jobCardArrival.addListener(_handleJobCardArrival);
  }

  @override
  void didUpdateWidget(JobGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousCardIDs = {
      for (final card in oldWidget.job.assignedCards)
        if (!card.pending) card.id,
    };
    for (final card in widget.job.assignedCards) {
      if (!card.pending && !previousCardIDs.contains(card.id)) {
        pendingCardDeltas[card.id] = card.value;
      }
    }
  }

  @override
  void dispose() {
    motionController?.jobCardArrival.removeListener(_handleJobCardArrival);
    super.dispose();
  }

  void _handleJobCardArrival() {
    final arrival = motionController?.jobCardArrival.value;
    if (!mounted || arrival == null || arrival.suit != widget.job.suit) {
      return;
    }
    final delta = pendingCardDeltas.remove(arrival.cardID);
    if (delta == null) {
      return;
    }
    setState(() {
      visibleDeltas.add(
        _VisibleJobGaugeDelta(serial: deltaSerial++, delta: delta),
      );
    });
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
    final pileEffectIconSize = height * 0.4;
    final nomenklaturaValues = jobNomenklaturaValues(job);
    final markerWidth =
        rewardMarkerWidth +
        (job.claimed ? 3 : 0) +
        (containsWrecker ? pileEffectIconSize + 2 : 0) +
        nomenklaturaValues.length * (pileEffectIconSize + 2);
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
                image: AssetImage('assets/ui/ui-header-counter.png'),
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 2,
                            children: [
                              Image.asset(
                                'assets/ui/Icons/icon-check.png',
                                width:
                                    height *
                                    tokens
                                        .layout
                                        .topInfo
                                        .checkIconHeightMultiplier,
                                height:
                                    height *
                                    tokens
                                        .layout
                                        .topInfo
                                        .checkIconHeightMultiplier,
                                filterQuality: FilterQuality.none,
                              ),
                              SuitMark(
                                key: ValueKey(
                                  'job-gauge-completed-suit-${job.suit}',
                                ),
                                suit: job.suit,
                                tokens: tokens,
                                size: height * 0.4,
                              ),
                            ],
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
                            'assets/ui/Icons/icon-variant-saboteur.png',
                            key: ValueKey('job-gauge-wrecker-${job.suit}'),
                            width: pileEffectIconSize,
                            height: pileEffectIconSize,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                          ),
                        for (final value in nomenklaturaValues)
                          Image.asset(
                            nomenklaturaPileIconAsset(value),
                            key: ValueKey(
                              'job-gauge-nomenklatura-$value-${job.suit}',
                            ),
                            width: pileEffectIconSize,
                            height: pileEffectIconSize,
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
const jobGaugeDeltaDropDistance = 46.0;
const jobGaugeDeltaStartScale = 1.64;
const jobGaugeDeltaEndScale = 2.16;

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
    this.onPlanningTrumpActionSelected,
    this.currentProfileUserID,
    this.comradeUserIDs = const {},
    this.incomingComradeRequestUserIDs = const {},
    this.outgoingComradeRequestUserIDs = const {},
    this.onComradeRequestToUser,
    this.onLanguageToggle,
    this.onAppearanceToggle,
    this.onCardBackChanged,
    this.fieldPlanBoardWidth,
    this.fieldPlanBoardHeight,
    this.fieldPlanBoardLeftInset = 0,
    this.fieldPlanBoardTopInset = 0,
    this.fieldPlanEnvironmentPage,
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
  final ValueChanged<LegalAction>? onPlanningTrumpActionSelected;
  final String? currentProfileUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onAppearanceToggle;
  final ValueChanged<KolkhozCardBack>? onCardBackChanged;
  final double? fieldPlanBoardWidth;
  final double? fieldPlanBoardHeight;
  final double fieldPlanBoardLeftInset;
  final double fieldPlanBoardTopInset;
  final int? fieldPlanEnvironmentPage;

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
        if (configuredKolkhozArtStyle.usesNewArt &&
            model.table.phase == phaseAssignment) {
          return BrigadePanel(
            model: model,
            tokens: tokens,
            language: language,
            heroOfSovietUnion: heroOfSovietUnion,
            activeReaction: activeReaction,
            compact: compact,
            onAction: onAction,
            fieldPlanEnvironmentPage: fieldPlanEnvironmentPage,
          );
        }
        return JobsPanel(
          model: model,
          tokens: tokens,
          language: language,
          onAction: onAction,
        );
      case panelPlot:
        if (!configuredKolkhozArtStyle.usesNewArt) {
          return PlotPanel(
            model: model,
            tokens: tokens,
            onPlotCardTap: onPlotCardTap,
          );
        }
        return BrigadePanel(
          model: model,
          tokens: tokens,
          language: language,
          heroOfSovietUnion: heroOfSovietUnion,
          activeReaction: activeReaction,
          compact: compact,
          planningTrumpFocusedSuit: planningTrumpFocusedSuit,
          onPlanningTrumpActionSelected: onPlanningTrumpActionSelected,
          currentProfileUserID: currentProfileUserID,
          comradeUserIDs: comradeUserIDs,
          incomingComradeRequestUserIDs: incomingComradeRequestUserIDs,
          outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs,
          onComradeRequestToUser: onComradeRequestToUser,
          onAction: onAction,
          onPlotCardTap: onPlotCardTap,
          fieldPlanBoardWidth: fieldPlanBoardWidth,
          fieldPlanBoardHeight: fieldPlanBoardHeight,
          fieldPlanBoardLeftInset: fieldPlanBoardLeftInset,
          fieldPlanBoardTopInset: fieldPlanBoardTopInset,
          fieldPlanEnvironmentPage: fieldPlanEnvironmentPage,
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
          onPlanningTrumpActionSelected: onPlanningTrumpActionSelected,
          currentProfileUserID: currentProfileUserID,
          comradeUserIDs: comradeUserIDs,
          incomingComradeRequestUserIDs: incomingComradeRequestUserIDs,
          outgoingComradeRequestUserIDs: outgoingComradeRequestUserIDs,
          onComradeRequestToUser: onComradeRequestToUser,
          onAction: onAction,
          onPlotCardTap: onPlotCardTap,
          fieldPlanBoardWidth: fieldPlanBoardWidth,
          fieldPlanBoardHeight: fieldPlanBoardHeight,
          fieldPlanBoardLeftInset: fieldPlanBoardLeftInset,
          fieldPlanBoardTopInset: fieldPlanBoardTopInset,
          fieldPlanEnvironmentPage: fieldPlanEnvironmentPage,
        );
    }
  }
}
