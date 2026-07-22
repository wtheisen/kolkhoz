import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/views/brigade/brigade_fields_scope.dart';
import 'package:kolkhoz_app/src/app/views/game/views/brigade/brigade_layout.dart';
import 'package:kolkhoz_app/src/app/views/game/views/brigade/planning_phase_view.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';
import 'package:kolkhoz_app/src/app/views/game/views/fields/fields_view.dart';
import 'package:kolkhoz_app/src/app/views/game/views/game_log/game_log_view.dart';
import 'package:kolkhoz_app/src/app/views/game/views/north/north_view.dart';
import 'package:kolkhoz_app/src/app/views/game/views/plots/plots_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/app_text.dart';
import 'package:kolkhoz_app/src/app/views/shared/art_direction.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/assignment_projection.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_sign.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_typography.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_world_scene.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/shared/pixel_text.dart';
import 'package:kolkhoz_app/src/app/profile/views/player_profile_panel.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/display/plot_display.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/display/table_display.dart';

class BrigadePanel extends StatefulWidget {
  const BrigadePanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.heroOfSovietUnion = true,
    this.activeReaction,
    this.compact = false,
    this.planningTrumpFocusedSuit,
    this.onPlanningTrumpActionSelected,
    this.currentProfileUserID,
    this.comradeUserIDs = const {},
    this.incomingComradeRequestUserIDs = const {},
    this.outgoingComradeRequestUserIDs = const {},
    this.onComradeRequestToUser,
    this.onAction,
    this.onPlotCardTap,
    this.fieldPlanBoardWidth,
    this.fieldPlanBoardHeight,
    this.fieldPlanBoardLeftInset = 0,
    this.fieldPlanBoardTopInset = 0,
    this.fieldPlanEnvironmentPage,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool heroOfSovietUnion;
  final OnlineReaction? activeReaction;
  final bool compact;
  final String? planningTrumpFocusedSuit;
  final ValueChanged<LegalAction>? onPlanningTrumpActionSelected;
  final String? currentProfileUserID;
  final Set<String> comradeUserIDs;
  final Set<String> incomingComradeRequestUserIDs;
  final Set<String> outgoingComradeRequestUserIDs;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final ValueChanged<LegalAction>? onAction;
  final void Function(String cardID, String zone)? onPlotCardTap;
  final double? fieldPlanBoardWidth;
  final double? fieldPlanBoardHeight;
  final double fieldPlanBoardLeftInset;
  final double fieldPlanBoardTopInset;
  final int? fieldPlanEnvironmentPage;

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
        if (configuredKolkhozArtStyle.usesNewArt && !widget.compact) {
          final verticalPage =
              widget.fieldPlanEnvironmentPage ??
              BrigadeFieldsScope.verticalPageOf(context);
          if (verticalPage == 2) {
            return Stack(
              key: const Key('north-brigade-board'),
              children: [
                Positioned.fill(
                  child: NorthPanel(
                    model: model,
                    tokens: tokens,
                    language: language,
                    fieldPlanEnvironment: true,
                  ),
                ),
                Positioned(
                  left: constraints.maxWidth * 0.43,
                  right: constraints.maxWidth * 0.43,
                  bottom: 3,
                  child: Semantics(
                    label: 'Swipe down to return to the fields',
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: tokens.colors.cream.withValues(alpha: 0.88),
                      size: 22,
                    ),
                  ),
                ),
              ],
            );
          }
          if (verticalPage == 1) {
            return FieldsBrigadeBoard(
              model: model,
              tokens: tokens,
              language: language,
              onAction: widget.onAction,
              onInspectField: (index) =>
                  BrigadeFieldsScope.focusSurfaceHandlerOf(
                    context,
                  )?.call('field-$index'),
            );
          }
          return FarmsteadBrigadePlotBoard(
            model: model,
            playerOrder: playerOrder,
            trick: trick,
            tokens: tokens,
            language: language,
            activeReaction: widget.activeReaction,
            planningTrumpFocusedSuit: widget.planningTrumpFocusedSuit,
            onPlanningTrumpActionSelected: widget.onPlanningTrumpActionSelected,
            onInspectSeat: (seatID) => BrigadeFieldsScope.focusSurfaceHandlerOf(
              context,
            )?.call('plot-$seatID'),
            onPlotCardTap: widget.onPlotCardTap,
          );
        }
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
            heroOfSovietUnion: widget.heroOfSovietUnion,
            activeReaction: widget.activeReaction,
            planningTrumpFocusedSuit: widget.planningTrumpFocusedSuit,
            onPlanningTrumpActionSelected: widget.onPlanningTrumpActionSelected,
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

        final calibratedFieldPlan =
            configuredKolkhozArtStyle.usesNewArt &&
            model.table.phase == phaseTrick &&
            widget.fieldPlanBoardWidth != null &&
            widget.fieldPlanBoardHeight != null;
        final columns = Padding(
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
                            ? PlanningPhasePanel(
                                model: model,
                                tokens: tokens,
                                language: language,
                                focusedSuit: widget.planningTrumpFocusedSuit,
                                onAction: widget.onPlanningTrumpActionSelected,
                              )
                            : null,
                        columnWidth: columnWidth,
                        columnHeight: columnHeight,
                        playerPanelWidth: playerPanelWidth,
                        playerPanelHeight: playerPanelHeight,
                        playObjectWidth: playObjectWidth,
                        playObjectHeight: playObjectHeight,
                        maxTricks: model.table.maxTricks,
                        heroOfSovietUnion: widget.heroOfSovietUnion,
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
                        hidePlayerBadge: calibratedFieldPlan,
                        hidePlayArea: calibratedFieldPlan,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        if (!calibratedFieldPlan) {
          return columns;
        }
        final boardWidth = widget.fieldPlanBoardWidth!;
        final boardHeight = widget.fieldPlanBoardHeight!;
        final boardSize = Size(boardWidth, boardHeight);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            columns,
            for (final seat in playerOrder)
              Builder(
                builder: (context) {
                  final play = trick.playForSeat(seat.id);
                  final pending = selectedTrickPreviewCard(model, seat, play);
                  final destination = fieldPlanCardDestinationQuad(
                    seat.id,
                    boardSize,
                    Offset(
                      widget.fieldPlanBoardLeftInset,
                      widget.fieldPlanBoardTopInset,
                    ),
                  );
                  final sourceSize = Size(playObjectWidth, playObjectHeight);
                  final child = play == null
                      ? pending == null
                            ? CardSlot(
                                active: seat.isCurrentTurn,
                                human: seat.isViewer,
                                width: playObjectWidth,
                                height: playObjectHeight,
                                tokens: tokens,
                                language: language,
                              )
                            : PendingTrickPreview(
                                card: pending,
                                active: seat.isCurrentTurn,
                                human: seat.isViewer,
                                width: playObjectWidth,
                                height: playObjectHeight,
                                trump: model.table.trump,
                                tokens: tokens,
                                language: language,
                              )
                      : MotionTrackedRegion(
                          motionKey: trickCardMotionSourceKey(play.card.id),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: GameCard(
                              card: play.card,
                              tokens: tokens,
                              trump: model.table.trump,
                              sizeOverride: tokens.card.large,
                              fieldPlanSeatID: seat.id,
                            ),
                          ),
                        );
                  return Positioned(
                    left: 0,
                    top: 0,
                    width: sourceSize.width,
                    height: sourceSize.height,
                    child: Transform(
                      alignment: Alignment.topLeft,
                      transform: fieldPlanCardHomographyToQuad(
                        sourceSize,
                        destination,
                      ),
                      transformHitTests: false,
                      child: child,
                    ),
                  );
                },
              ),
            for (final seat in playerOrder)
              if (inspectedSeatID != seat.id)
                Builder(
                  builder: (context) {
                    final rect = fieldPlanSignDestinationRect(
                      seat.id,
                      boardSize,
                      Offset(
                        widget.fieldPlanBoardLeftInset,
                        widget.fieldPlanBoardTopInset,
                      ),
                    );
                    final play = trick.playForSeat(seat.id);
                    final active = seat.isCurrentTurn && play == null;
                    return Positioned.fromRect(
                      rect: rect,
                      child: PlayerBadge(
                        seat: seat,
                        tokens: tokens,
                        active: active,
                        language: language,
                        width: rect.width,
                        height: rect.height,
                        maxTricks: model.table.maxTricks,
                        heroWithinReach:
                            widget.heroOfSovietUnion &&
                            seat.medals == model.table.maxTricks - 1,
                        reaction: widget.activeReaction?.playerID == seat.id
                            ? widget.activeReaction
                            : null,
                        onInspect: () => togglePlayerInspect(seat.id),
                      ),
                    );
                  },
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

class CompactBrigadeGrid extends StatelessWidget {
  const CompactBrigadeGrid({
    required this.playerOrder,
    required this.trick,
    required this.model,
    required this.tokens,
    required this.language,
    required this.heroOfSovietUnion,
    this.activeReaction,
    this.planningTrumpFocusedSuit,
    this.onPlanningTrumpActionSelected,
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
  final bool heroOfSovietUnion;
  final OnlineReaction? activeReaction;
  final String? planningTrumpFocusedSuit;
  final ValueChanged<LegalAction>? onPlanningTrumpActionSelected;
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
          brigadeColumnMinHeight,
          constraints.maxHeight - brigadePanelLocalPadding.vertical,
        );
        final cellWidth = math.max(
          0.0,
          (constraints.maxWidth - gridSpacing * (playerOrder.length - 1)) /
              playerOrder.length,
        );
        final cellHeight = gridHeight;
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
            child: Row(
              spacing: gridSpacing,
              children: [
                for (final seat in playerOrder)
                  Expanded(
                    child: compactGridColumn(
                      seat,
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
          ? PlanningPhasePanel(
              model: model,
              tokens: tokens,
              language: language,
              focusedSuit: planningTrumpFocusedSuit,
              onAction: onPlanningTrumpActionSelected,
            )
          : null,
      columnWidth: columnWidth,
      columnHeight: columnHeight,
      playerPanelWidth: playerPanelWidth,
      playerPanelHeight: playerPanelHeight,
      playObjectWidth: playObjectWidth,
      playObjectHeight: playObjectHeight,
      maxTricks: model.table.maxTricks,
      heroOfSovietUnion: heroOfSovietUnion,
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

class FieldsBrigadeBoard extends StatelessWidget {
  const FieldsBrigadeBoard({
    required this.model,
    required this.tokens,
    required this.language,
    this.onAction,
    this.onInspectField,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final ValueChanged<LegalAction>? onAction;
  final ValueChanged<int>? onInspectField;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final jobs = jobsInDisplayOrder(model.table.jobs);
        return Stack(
          key: const Key('fields-brigade-board'),
          children: [
            for (final (index, job) in jobs.indexed)
              FarmsteadPerspectivePositioned(
                sourceQuad: fieldPlanFieldsJobPileSourceQuad(index),
                surfaceID: 'field-$index',
                child: FieldsJobPile(
                  job: job,
                  model: model,
                  tokens: tokens,
                  language: language,
                  onAction: onAction,
                  onInspect: onInspectField == null
                      ? null
                      : () => onInspectField!(index),
                ),
              ),
            for (final (index, job) in jobs.indexed)
              FarmsteadPerspectivePositioned(
                sourceQuad: fieldPlanFieldsJobSignSourceQuad(index),
                child: FarmsteadJobSign(
                  job: job,
                  tokens: tokens,
                  language: language,
                  highlighted: model.table.trump == job.suit,
                ),
              ),
            Positioned(
              left: size.width * 0.43,
              right: size.width * 0.43,
              top: 3,
              child: Semantics(
                label: 'Swipe up to view the North',
                child: MotionTrackedRegion(
                  motionKey: northCardMotionTargetKey,
                  child: Icon(
                    Icons.keyboard_arrow_up,
                    color: tokens.colors.cream.withValues(alpha: 0.88),
                    size: 22,
                  ),
                ),
              ),
            ),
            Positioned(
              left: size.width * 0.43,
              right: size.width * 0.43,
              bottom: 3,
              child: Semantics(
                label: 'Swipe down to return to the brigade and plots',
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: tokens.colors.cream.withValues(alpha: 0.88),
                  size: 22,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class FieldsJobPile extends StatelessWidget {
  const FieldsJobPile({
    required this.job,
    required this.model,
    required this.tokens,
    required this.language,
    this.onAction,
    this.onInspect,
    super.key,
  });

  final Job job;
  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final ValueChanged<LegalAction>? onAction;
  final VoidCallback? onInspect;

  @override
  Widget build(BuildContext context) {
    final assignmentAction = assignmentActionForJob(model, job);
    final actionHandler = onAction;
    final canAssign = assignmentAction != null && actionHandler != null;
    return Semantics(
      button: canAssign,
      label: language.suitName(job.suit),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: assignmentAction != null && actionHandler != null
            ? () => actionHandler(assignmentAction)
            : onInspect,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: canAssign
                ? tokens.colors.cream.withValues(alpha: 0.08)
                : Colors.transparent,
            border: Border.all(
              color: canAssign
                  ? tokens.colors.gold.withValues(alpha: 0.55)
                  : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: job.assignedCards.isEmpty
                ? const SizedBox.expand()
                : AssignedJobCardStack(
                    cards: job.assignedCards,
                    tokens: tokens,
                    trump: model.table.trump,
                  ),
          ),
        ),
      ),
    );
  }
}

class FarmsteadBrigadePlotBoard extends StatelessWidget {
  const FarmsteadBrigadePlotBoard({
    required this.model,
    required this.playerOrder,
    required this.trick,
    required this.tokens,
    required this.language,
    required this.onInspectSeat,
    this.activeReaction,
    this.planningTrumpFocusedSuit,
    this.onPlanningTrumpActionSelected,
    this.onPlotCardTap,
    super.key,
  });

  final TableViewModel model;
  final List<Seat> playerOrder;
  final Trick trick;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineReaction? activeReaction;
  final String? planningTrumpFocusedSuit;
  final ValueChanged<LegalAction>? onPlanningTrumpActionSelected;
  final ValueChanged<int> onInspectSeat;
  final void Function(String cardID, String zone)? onPlotCardTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          key: const Key('farmstead-brigade-plot-board'),
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < playerOrder.length; index++)
              FarmsteadPerspectivePositioned(
                sourceQuad: fieldPlanPlayerPortraitSourceQuad(index),
                child: FarmsteadPlayerPortrait(
                  seat: playerOrder[index],
                  tokens: tokens,
                  reaction: activeReaction?.playerID == playerOrder[index].id
                      ? activeReaction
                      : null,
                  onInspect: () => onInspectSeat(playerOrder[index].id),
                ),
              ),
            for (var index = 0; index < playerOrder.length; index++)
              FarmsteadPerspectivePositioned(
                sourceQuad: fieldPlanPlayerNameSourceQuad(index),
                child: FarmsteadPlayerName(
                  seat: playerOrder[index],
                  language: language,
                  tokens: tokens,
                ),
              ),
            for (var index = 0; index < playerOrder.length; index++)
              FarmsteadPerspectivePositioned(
                sourceQuad: fieldPlanCellarCountSourceQuad(index),
                child: FarmsteadCellarCount(
                  seat: playerOrder[index],
                  tokens: tokens,
                ),
              ),
            for (var index = 0; index < playerOrder.length; index++)
              FarmsteadPerspectivePositioned(
                sourceQuad: fieldPlanPlotCardsSourceQuad(index),
                surfaceID: 'plot-${playerOrder[index].id}',
                child: FarmsteadPlotCards(
                  seat: playerOrder[index],
                  model: model,
                  tokens: tokens,
                  onPlotCardTap: onPlotCardTap,
                ),
              ),
            for (final (index, job) in jobsInDisplayOrder(
              model.table.jobs,
            ).indexed)
              FarmsteadPerspectivePositioned(
                sourceQuad: fieldPlanJobSignSourceQuad(index),
                child: FarmsteadJobSign(
                  job: job,
                  tokens: tokens,
                  language: language,
                  highlighted: model.table.trump == job.suit,
                ),
              ),
            for (var index = 0; index < playerOrder.length; index++)
              FarmsteadPerspectivePositioned(
                sourceQuad: fieldPlanCrossroadsCardSourceQuad(index),
                child: FarmsteadTrickCard(
                  seat: playerOrder[index],
                  play: trick.playForSeat(playerOrder[index].id),
                  pendingPlayCard: selectedTrickPreviewCard(
                    model,
                    playerOrder[index],
                    trick.playForSeat(playerOrder[index].id),
                  ),
                  phase: model.table.phase,
                  trump: model.table.trump,
                  tokens: tokens,
                  language: language,
                ),
              ),
            if (model.table.phase == phasePlanning)
              FarmsteadPerspectivePositioned(
                sourceQuad: fieldPlanPlanningSourceQuad(0),
                child: PlanningPhasePanel(
                  model: model,
                  tokens: tokens,
                  language: language,
                  focusedSuit: planningTrumpFocusedSuit,
                  onAction: onPlanningTrumpActionSelected,
                ),
              ),
            Positioned(
              left: size.width * 0.43,
              right: size.width * 0.43,
              top: 2,
              child: Semantics(
                label: 'Swipe up to view the fields',
                child: MotionTrackedRegion(
                  motionKey: northCardMotionTargetKey,
                  child: Icon(
                    Icons.keyboard_arrow_up,
                    color: tokens.colors.cream.withValues(alpha: 0.88),
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class FarmsteadPerspectivePositioned extends StatelessWidget {
  const FarmsteadPerspectivePositioned({
    required this.sourceQuad,
    required this.child,
    this.surfaceID,
    super.key,
  });

  final FieldPlanCardQuad sourceQuad;
  final Widget child;
  final String? surfaceID;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          var destination = fieldPlanBackgroundDestinationQuad(
            sourceQuad,
            constraints.biggest,
          );
          final focus = FieldPlanWorldFocusScope.maybeOf(context);
          if (surfaceID != null && focus?.surfaceID == surfaceID) {
            final progress = Curves.easeInOutCubic.transform(
              focus!.progress.clamp(0, 1),
            );
            final center = fieldPlanQuadCenter(destination);
            final flatRect = Rect.fromCenter(
              center: center,
              width: constraints.maxWidth * 0.42,
              height: constraints.maxHeight * 0.34,
            );
            destination = fieldPlanLerpQuad(
              destination,
              FieldPlanCardQuad(
                flatRect.topLeft,
                flatRect.topRight,
                flatRect.bottomRight,
                flatRect.bottomLeft,
              ),
              progress,
            );
          }
          final width =
              <double>[
                destination.topLeft.dx,
                destination.topRight.dx,
                destination.bottomRight.dx,
                destination.bottomLeft.dx,
              ].reduce(math.max) -
              <double>[
                destination.topLeft.dx,
                destination.topRight.dx,
                destination.bottomRight.dx,
                destination.bottomLeft.dx,
              ].reduce(math.min);
          final height =
              <double>[
                destination.topLeft.dy,
                destination.topRight.dy,
                destination.bottomRight.dy,
                destination.bottomLeft.dy,
              ].reduce(math.max) -
              <double>[
                destination.topLeft.dy,
                destination.topRight.dy,
                destination.bottomRight.dy,
                destination.bottomLeft.dy,
              ].reduce(math.min);
          final childSize = Size(width, height);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Transform(
                alignment: Alignment.topLeft,
                transform: fieldPlanCardHomographyToQuad(
                  childSize,
                  destination,
                ),
                child: SizedBox.fromSize(size: childSize, child: child),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FarmsteadPlayerPortrait extends StatelessWidget {
  const FarmsteadPlayerPortrait({
    required this.seat,
    required this.tokens,
    required this.onInspect,
    this.reaction,
    super.key,
  });

  final Seat seat;
  final DesignTokens tokens;
  final OnlineReaction? reaction;
  final VoidCallback onInspect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: seat.name,
      child: GestureDetector(
        key: Key('player-portrait-${seat.id}-inspect'),
        behavior: HitTestBehavior.opaque,
        onTap: onInspect,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              PlayerPortrait(
                seat: seat,
                tokens: tokens,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                badgeVisible: false,
              ),
              if (reaction != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.colors.black.withValues(alpha: 0.62),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/ui/Icons/${reactionAsset(reaction!.reactionID)}',
                      filterQuality: FilterQuality.none,
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

class FarmsteadPlayerName extends StatelessWidget {
  const FarmsteadPlayerName({
    required this.seat,
    required this.language,
    required this.tokens,
    super.key,
  });

  final Seat seat;
  final KolkhozLanguage language;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        seatDisplayName(seat, language: language).toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: fieldPlanDisplayTextStyle.copyWith(
          color: seat.isCurrentTurn
              ? tokens.colors.red
              : const Color(0xff24251d),
          fontSize: 18,
          shadows: const [Shadow(color: Color(0xbbe8d9ad), blurRadius: 3)],
        ),
      ),
    );
  }
}

class FarmsteadCellarCount extends StatelessWidget {
  const FarmsteadCellarCount({
    required this.seat,
    required this.tokens,
    super.key,
  });

  final Seat seat;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/ui/Icons/icon-cellar.png',
            width: 30,
            height: 30,
            filterQuality: FilterQuality.none,
          ),
          const SizedBox(width: 4),
          PixelText(
            '${seat.plot.effectiveHiddenCardCount}',
            size: PixelTextSize.title,
            variant: PixelTextVariant.heavy,
            color: tokens.colors.cream,
          ),
        ],
      ),
    );
  }
}

class FarmsteadPlotCards extends StatelessWidget {
  const FarmsteadPlotCards({
    required this.seat,
    required this.model,
    required this.tokens,
    this.onPlotCardTap,
    super.key,
  });

  final Seat seat;
  final TableViewModel model;
  final DesignTokens tokens;
  final void Function(String cardID, String zone)? onPlotCardTap;

  @override
  Widget build(BuildContext context) {
    final hiddenExiledCardIDs = hiddenExiledPlotCardIDs(model);
    final cards = visiblePlotCards(seat.plot.revealed, hiddenExiledCardIDs);
    final exiledCardIDs = requisitionExiledCardIDs(model);
    final selectable = seat.isViewer && model.table.phase == phaseSwap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxHeight / tokens.card.small.height;
        final cardSize = scaledPlotCardSize(tokens.card.small, scale);
        return ClipRect(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: OverlappedCardRow(
              itemWidth: cardSize.width,
              itemHeight: cardSize.height,
              spacing: -cardSize.width * 0.32,
              children: plotOverviewCardItems(
                cards: cards,
                stacks: seat.plot.stacks,
                hiddenCards: false,
                cardSize: cardSize,
                selectedCardID: model.selection.plotCardID,
                selectable: selectable,
                zone: plotZoneRevealed,
                exiledCardIDs: exiledCardIDs,
                tokens: tokens,
                onPlotCardTap: onPlotCardTap,
              ),
            ),
          ),
        );
      },
    );
  }
}

class FarmsteadJobSign extends StatelessWidget {
  const FarmsteadJobSign({
    required this.job,
    required this.tokens,
    required this.language,
    required this.highlighted,
    super.key,
  });

  final Job job;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? tokens.colors.red : const Color(0xff24251d);
    return MotionTrackedRegion(
      motionKey: jobGaugeMotionTargetKey(job.suit),
      child: FieldPlanSign(
        borderColor: highlighted ? tokens.colors.red : Colors.transparent,
        borderWidth: highlighted ? 2 : 0,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 210,
            height: 42,
            child: Row(
              children: [
                SuitMark(suit: job.suit, tokens: tokens, size: 26),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    language.suitName(job.suit).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: fieldPlanBodyStrongTextStyle.copyWith(
                      color: color,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${displayedJobHours(job)}/$jobRequiredHours',
                  style: fieldPlanDisplayTextStyle.copyWith(
                    color: color,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FarmsteadTrickCard extends StatelessWidget {
  const FarmsteadTrickCard({
    required this.seat,
    required this.play,
    required this.pendingPlayCard,
    required this.phase,
    required this.trump,
    required this.tokens,
    required this.language,
    super.key,
  });

  final Seat seat;
  final TrickPlay? play;
  final TableCard? pendingPlayCard;
  final String phase;
  final String? trump;
  final DesignTokens tokens;
  final KolkhozLanguage language;

  @override
  Widget build(BuildContext context) {
    final active = phase == phaseTrick && seat.isCurrentTurn && play == null;
    if (play != null) {
      return MotionTrackedRegion(
        motionKey: trickCardMotionSourceKey(play!.card.id),
        child: FittedBox(
          fit: BoxFit.contain,
          child: GameCard(
            card: play!.card,
            tokens: tokens,
            trump: trump,
            sizeOverride: tokens.card.medium,
          ),
        ),
      );
    }
    if (pendingPlayCard != null) {
      return PendingTrickPreview(
        card: pendingPlayCard!,
        active: active,
        human: seat.isViewer,
        width: tokens.card.medium.width,
        height: tokens.card.medium.height,
        trump: trump,
        tokens: tokens,
        language: language,
      );
    }
    return CardSlot(
      active: active,
      human: seat.isViewer,
      width: tokens.card.medium.width,
      height: tokens.card.medium.height,
      tokens: tokens,
      language: language,
    );
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
    required this.heroOfSovietUnion,
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
    this.hidePlayerBadge = false,
    this.hidePlayArea = false,
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
  final bool heroOfSovietUnion;
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
  final bool hidePlayerBadge;
  final bool hidePlayArea;

  @override
  Widget build(BuildContext context) {
    final fieldPlanTrick =
        configuredKolkhozArtStyle.usesNewArt && phase == phaseTrick;
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
                fieldPlanSeatID: fieldPlanTrick ? seat.id : null,
              ),
            ),
          );
    final presentedPlayAreaChild = hidePlayArea
        ? const SizedBox.shrink()
        : fieldPlanTrick
        ? FieldPlanCardPerspective(seatID: seat.id, child: playAreaChild)
        : playAreaChild;

    return SizedBox(
      width: columnWidth,
      height: columnHeight,
      child: DecoratedBox(
        decoration: fieldPlanTrick
            ? const BoxDecoration()
            : BoxDecoration(
                color: tokens.colors.black.withValues(
                  alpha: human ? 0.28 : 0.22,
                ),
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
                      child: hidePlayerBadge
                          ? null
                          : PlayerBadge(
                              seat: seat,
                              tokens: tokens,
                              active: active || planningSelector,
                              width: playerPanelWidth,
                              height: playerPanelHeight,
                              maxTricks: maxTricks,
                              heroWithinReach:
                                  heroOfSovietUnion &&
                                  seat.medals == maxTricks - 1 &&
                                  (phase == phaseTrick ||
                                      phase == phaseAssignment),
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
                          child: presentedPlayAreaChild,
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

class FieldPlanCardQuad {
  const FieldPlanCardQuad(
    this.topLeft,
    this.topRight,
    this.bottomRight,
    this.bottomLeft,
  );

  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;
}

Offset fieldPlanQuadCenter(FieldPlanCardQuad quad) =>
    (quad.topLeft + quad.topRight + quad.bottomRight + quad.bottomLeft) / 4;

FieldPlanCardQuad fieldPlanLerpQuad(
  FieldPlanCardQuad begin,
  FieldPlanCardQuad end,
  double progress,
) => FieldPlanCardQuad(
  Offset.lerp(begin.topLeft, end.topLeft, progress)!,
  Offset.lerp(begin.topRight, end.topRight, progress)!,
  Offset.lerp(begin.bottomRight, end.bottomRight, progress)!,
  Offset.lerp(begin.bottomLeft, end.bottomLeft, progress)!,
);

FieldPlanCardQuad fieldPlanCardQuad(int seatID) => switch (seatID) {
  1 => const FieldPlanCardQuad(
    Offset(0.492, 0.241),
    Offset(1.162, 0.241),
    Offset(0.696, 1.035),
    Offset(-0.237, 1.035),
  ),
  2 => const FieldPlanCardQuad(
    Offset(0.196, 0.241),
    Offset(0.87, 0.241),
    Offset(0.807, 1.035),
    Offset(-0.171, 1.035),
  ),
  3 => const FieldPlanCardQuad(
    Offset(-0.092, 0.241),
    Offset(0.564, 0.241),
    Offset(0.994, 1.035),
    Offset(-0.033, 1.035),
  ),
  _ => const FieldPlanCardQuad(
    Offset(-0.416, 0.241),
    Offset(0.257, 0.241),
    Offset(1.163, 1.035),
    Offset(0.101, 1.035),
  ),
};

const fieldPlanBackgroundSourceSize = Size(1672, 941);

// Coordinates are pixels in brigade-plot-light.png. The calibration editor emits
// replacements for these groups.
Rect fieldPlanPlayerPortraitSourceRect(int index) => switch (index) {
  0 => const Rect.fromLTWH(589.718, 211.857, 93.743, 63.96),
  1 => const Rect.fromLTWH(991.441, 214.903, 111.361, 60.713),
  2 => const Rect.fromLTWH(485.937, 531.789, 103.846, 83.807),
  _ => const Rect.fromLTWH(1059.383, 531.789, 95.946, 81.25),
};

Rect fieldPlanPlayerNameSourceRect(int index) => switch (index) {
  0 => const Rect.fromLTWH(344.148, 214.234, 241.581, 56.603),
  1 => const Rect.fromLTWH(1108.429, 214.961, 238.614, 59.479),
  2 => const Rect.fromLTWH(252.35, 531.083, 231.786, 83.547),
  _ => const Rect.fromLTWH(1154.775, 532.293, 241.878, 80.359),
};

Rect fieldPlanPlotCardsSourceRect(int index) => switch (index) {
  0 => const Rect.fromLTWH(308.284, 322.991, 324.44, 104.793),
  1 => const Rect.fromLTWH(1033.278, 319.69, 332.018, 107.171),
  2 => const Rect.fromLTWH(127.093, 680.503, 418.505, 135.796),
  _ => const Rect.fromLTWH(1081.238, 673.378, 455.249, 141.466),
};

Rect fieldPlanCellarCountSourceRect(int index) => switch (index) {
  0 => const Rect.fromLTWH(248.829, 277.215, 102.499, 48.608),
  1 => const Rect.fromLTWH(1330.285, 275.89, 89.523, 45.554),
  2 => const Rect.fromLTWH(51.319, 616.2, 126.601, 69.916),
  _ => const Rect.fromLTWH(1483.228, 619.455, 139.635, 69.93),
};

Rect fieldPlanJobSignSourceRect(int index) => switch (index) {
  0 => const Rect.fromLTWH(120.318, 65.836, 241.387, 77.002),
  1 => const Rect.fromLTWH(903.589, 68.715, 240.269, 75.608),
  2 => const Rect.fromLTWH(506.602, 67.856, 238.972, 77.623),
  _ => const Rect.fromLTWH(1323.521, 69.153, 240.712, 77.622),
};

Rect fieldPlanCrossroadsCardSourceRect(int index) => switch (index) {
  0 => const Rect.fromLTWH(848.559, 573.584, 201.829, 247.27),
  1 => const Rect.fromLTWH(841.091, 364.535, 201.751, 186.387),
  2 => const Rect.fromLTWH(621.006, 366.861, 191.072, 182.224),
  _ => const Rect.fromLTWH(617.99, 568.169, 194.557, 244.712),
};

Rect fieldPlanPlanningSourceRect(int index) =>
    const Rect.fromLTWH(634.746, 340.152, 382.792, 289.341);

FieldPlanCardQuad fieldPlanPlayerPortraitSourceQuad(int index) =>
    switch (index) {
      0 => const FieldPlanCardQuad(
        Offset(601.499, 211.857),
        Offset(683.461, 212.534),
        Offset(671.229, 275.74),
        Offset(589.718, 275.818),
      ),
      1 => const FieldPlanCardQuad(
        Offset(991.441, 215.638),
        Offset(1095.791, 214.903),
        Offset(1102.802, 275.617),
        Offset(998.066, 275.407),
      ),
      2 => const FieldPlanCardQuad(
        Offset(501.433, 533.072),
        Offset(589.783, 531.789),
        Offset(574.675, 614.299),
        Offset(485.937, 615.595),
      ),
      _ => const FieldPlanCardQuad(
        Offset(1059.383, 531.789),
        Offset(1143.016, 532.106),
        Offset(1155.329, 613.039),
        Offset(1069.493, 612.391),
      ),
    };

FieldPlanCardQuad fieldPlanPlayerNameSourceQuad(int index) => switch (index) {
  0 => const FieldPlanCardQuad(
    Offset(361.662, 214.817),
    Offset(585.729, 214.234),
    Offset(574.148, 270.836),
    Offset(344.148, 270.836),
  ),
  1 => const FieldPlanCardQuad(
    Offset(1108.429, 215.357),
    Offset(1336.86, 214.961),
    Offset(1347.043, 274.44),
    Offset(1117.043, 274.44),
  ),
  2 => const FieldPlanCardQuad(
    Offset(280.261, 531.083),
    Offset(484.137, 531.652),
    Offset(467.473, 614.631),
    Offset(252.35, 614.256),
  ),
  _ => const FieldPlanCardQuad(
    Offset(1154.775, 532.502),
    Offset(1384.66, 532.293),
    Offset(1396.653, 612.651),
    Offset(1166.653, 612.651),
  ),
};

FieldPlanCardQuad fieldPlanPlotCardsSourceQuad(int index) => switch (index) {
  0 => const FieldPlanCardQuad(
    Offset(355.01, 324.553),
    Offset(632.724, 322.991),
    Offset(600.594, 427.784),
    Offset(308.284, 425.761),
  ),
  1 => const FieldPlanCardQuad(
    Offset(1033.278, 320.977),
    Offset(1318.809, 319.69),
    Offset(1365.295, 426.861),
    Offset(1066.952, 425.317),
  ),
  2 => const FieldPlanCardQuad(
    Offset(189.791, 682.73),
    Offset(545.598, 680.503),
    Offset(522.057, 816.299),
    Offset(127.093, 815.554),
  ),
  _ => const FieldPlanCardQuad(
    Offset(1081.238, 673.378),
    Offset(1475.51, 674.3),
    Offset(1536.486, 812.51),
    Offset(1108.727, 814.844),
  ),
};

FieldPlanCardQuad fieldPlanCellarCountSourceQuad(int index) => switch (index) {
  0 => const FieldPlanCardQuad(
    Offset(270.266, 277.769),
    Offset(351.328, 277.215),
    Offset(335.054, 324.879),
    Offset(248.829, 325.822),
  ),
  1 => const FieldPlanCardQuad(
    Offset(1330.285, 276.026),
    Offset(1404.765, 275.89),
    Offset(1419.808, 321.444),
    Offset(1343.377, 320.825),
  ),
  2 => const FieldPlanCardQuad(
    Offset(81.621, 616.388),
    Offset(177.92, 616.2),
    Offset(157.462, 685.979),
    Offset(51.319, 686.116),
  ),
  _ => const FieldPlanCardQuad(
    Offset(1483.228, 619.455),
    Offset(1595.24, 619.815),
    Offset(1622.863, 689.385),
    Offset(1512.349, 688.142),
  ),
};

FieldPlanCardQuad fieldPlanJobSignSourceQuad(int index) => switch (index) {
  0 => const FieldPlanCardQuad(
    Offset(120.318, 65.836),
    Offset(361.704, 65.836),
    Offset(361.704, 142.838),
    Offset(120.318, 142.838),
  ),
  1 => const FieldPlanCardQuad(
    Offset(903.589, 68.715),
    Offset(1143.857, 68.715),
    Offset(1143.857, 144.323),
    Offset(903.589, 144.323),
  ),
  2 => const FieldPlanCardQuad(
    Offset(506.602, 67.856),
    Offset(745.574, 67.856),
    Offset(745.574, 145.478),
    Offset(506.602, 145.478),
  ),
  _ => const FieldPlanCardQuad(
    Offset(1323.521, 69.153),
    Offset(1564.233, 69.153),
    Offset(1564.233, 146.775),
    Offset(1323.521, 146.775),
  ),
};

FieldPlanCardQuad fieldPlanFieldsJobPileSourceQuad(int index) =>
    switch (index) {
      0 => const FieldPlanCardQuad(
        Offset(313.035, 181.186),
        Offset(752.564, 179.234),
        Offset(734.615, 332.289),
        Offset(110.111, 329.644),
      ),
      1 => const FieldPlanCardQuad(
        Offset(906.639, 174.294),
        Offset(1340.058, 176.067),
        Offset(1567.682, 330.037),
        Offset(939.518, 333.031),
      ),
      2 => const FieldPlanCardQuad(
        Offset(243.909, 503.519),
        Offset(702.933, 507.148),
        Offset(628.734, 802.201),
        Offset(21.959, 798.046),
      ),
      _ => const FieldPlanCardQuad(
        Offset(960.722, 513.846),
        Offset(1379.459, 515.95),
        Offset(1653.82, 818.011),
        Offset(1021.954, 821.449),
      ),
    };

FieldPlanCardQuad fieldPlanFieldsJobSignSourceQuad(int index) =>
    switch (index) {
      0 => const FieldPlanCardQuad(
        Offset(544.001, 30.917),
        Offset(784.001, 30.917),
        Offset(784.001, 108.917),
        Offset(544.001, 108.917),
      ),
      1 => const FieldPlanCardQuad(
        Offset(888.451, 30.781),
        Offset(1128.451, 30.781),
        Offset(1128.451, 108.781),
        Offset(888.451, 108.781),
      ),
      2 => const FieldPlanCardQuad(
        Offset(488.552, 350.096),
        Offset(728.552, 350.096),
        Offset(728.552, 428.096),
        Offset(488.552, 428.096),
      ),
      _ => const FieldPlanCardQuad(
        Offset(923.039, 353.347),
        Offset(1163.039, 353.347),
        Offset(1163.039, 431.347),
        Offset(923.039, 431.347),
      ),
    };

FieldPlanCardQuad fieldPlanCrossroadsCardSourceQuad(int index) =>
    switch (index) {
      0 => const FieldPlanCardQuad(
        Offset(848.559, 573.584),
        Offset(1012.231, 574.571),
        Offset(1050.387, 820.854),
        Offset(870.392, 818.394),
      ),
      1 => const FieldPlanCardQuad(
        Offset(841.091, 365.212),
        Offset(1002.668, 364.535),
        Offset(1042.842, 550.922),
        Offset(863.53, 548.661),
      ),
      2 => const FieldPlanCardQuad(
        Offset(662.218, 366.861),
        Offset(812.078, 367.005),
        Offset(787.688, 548.323),
        Offset(621.006, 549.086),
      ),
      _ => const FieldPlanCardQuad(
        Offset(647.196, 568.169),
        Offset(812.546, 570.488),
        Offset(796.927, 811.574),
        Offset(617.99, 812.88),
      ),
    };

FieldPlanCardQuad fieldPlanPlanningSourceQuad(int index) =>
    const FieldPlanCardQuad(
      Offset(700.635, 340.152),
      Offset(967.909, 340.152),
      Offset(1017.538, 629.494),
      Offset(634.746, 627.888),
    );

FieldPlanCardQuad fieldPlanCardSourceQuad(int seatID) => switch (seatID) {
  1 => const FieldPlanCardQuad(
    Offset(353.936, 404.533),
    Offset(541.687, 404.533),
    Offset(411.023, 720.412),
    Offset(149.693, 720.412),
  ),
  2 => const FieldPlanCardQuad(
    Offset(638.1, 404.533),
    Offset(827.12, 404.533),
    Offset(809.36, 720.412),
    Offset(535.344, 720.412),
  ),
  3 => const FieldPlanCardQuad(
    Offset(924.801, 404.533),
    Offset(1108.747, 404.533),
    Offset(1229.263, 720.412),
    Offset(941.293, 720.412),
  ),
  _ => const FieldPlanCardQuad(
    Offset(1211.502, 404.533),
    Offset(1400.522, 404.533),
    Offset(1654.24, 720.412),
    Offset(1356.121, 720.412),
  ),
};

Rect fieldPlanSignSourceRect(int seatID) => switch (seatID) {
  1 => const Rect.fromLTWH(377.872, 262.855, 178.904, 74.492),
  2 => const Rect.fromLTWH(648.736, 262.855, 178.904, 74.492),
  3 => const Rect.fromLTWH(912.912, 262.855, 178.904, 74.492),
  _ => const Rect.fromLTWH(1190.464, 262.855, 178.904, 74.492),
};

Offset fieldPlanBackgroundPoint(Offset source, Size destination) {
  final scale = math.min(
    destination.width / fieldPlanBackgroundSourceSize.width,
    destination.height / fieldPlanBackgroundSourceSize.height,
  );
  final offset = Offset(
    (destination.width - fieldPlanBackgroundSourceSize.width * scale) / 2,
    (destination.height - fieldPlanBackgroundSourceSize.height * scale) / 2,
  );
  return offset + source * scale;
}

Rect fieldPlanBackgroundRect(Rect source, Size destination) {
  return Rect.fromPoints(
    fieldPlanBackgroundPoint(source.topLeft, destination),
    fieldPlanBackgroundPoint(source.bottomRight, destination),
  );
}

FieldPlanCardQuad fieldPlanBackgroundDestinationQuad(
  FieldPlanCardQuad source,
  Size destination,
) {
  return FieldPlanCardQuad(
    fieldPlanBackgroundPoint(source.topLeft, destination),
    fieldPlanBackgroundPoint(source.topRight, destination),
    fieldPlanBackgroundPoint(source.bottomRight, destination),
    fieldPlanBackgroundPoint(source.bottomLeft, destination),
  );
}

FieldPlanCardQuad fieldPlanCardDestinationQuad(
  int seatID,
  Size boardSize,
  Offset panelOrigin,
) {
  final source = fieldPlanCardSourceQuad(seatID);
  Offset destination(Offset point) =>
      fieldPlanBackgroundPoint(point, boardSize) - panelOrigin;
  return FieldPlanCardQuad(
    destination(source.topLeft),
    destination(source.topRight),
    destination(source.bottomRight),
    destination(source.bottomLeft),
  );
}

Rect fieldPlanSignDestinationRect(
  int seatID,
  Size boardSize,
  Offset panelOrigin,
) {
  final source = fieldPlanSignSourceRect(seatID);
  final topLeft =
      fieldPlanBackgroundPoint(source.topLeft, boardSize) - panelOrigin;
  final bottomRight =
      fieldPlanBackgroundPoint(source.bottomRight, boardSize) - panelOrigin;
  return Rect.fromPoints(topLeft, bottomRight);
}

Rect fieldPlanSignRect(int seatID) => switch (seatID) {
  1 => const Rect.fromLTWH(0.226, 0.277, 0.107, 0.08),
  2 => const Rect.fromLTWH(0.388, 0.277, 0.107, 0.08),
  3 => const Rect.fromLTWH(0.546, 0.277, 0.107, 0.08),
  _ => const Rect.fromLTWH(0.712, 0.277, 0.107, 0.08),
};

Matrix4 fieldPlanCardHomography(Size size, FieldPlanCardQuad normalized) {
  final p0 = Offset(
    normalized.topLeft.dx * size.width,
    normalized.topLeft.dy * size.height,
  );
  final p1 = Offset(
    normalized.topRight.dx * size.width,
    normalized.topRight.dy * size.height,
  );
  final p2 = Offset(
    normalized.bottomRight.dx * size.width,
    normalized.bottomRight.dy * size.height,
  );
  final p3 = Offset(
    normalized.bottomLeft.dx * size.width,
    normalized.bottomLeft.dy * size.height,
  );
  return fieldPlanCardHomographyToQuad(size, FieldPlanCardQuad(p0, p1, p2, p3));
}

Matrix4 fieldPlanCardHomographyToQuad(
  Size size,
  FieldPlanCardQuad destination,
) {
  final p0 = destination.topLeft;
  final p1 = destination.topRight;
  final p2 = destination.bottomRight;
  final p3 = destination.bottomLeft;
  final dx1 = p1.dx - p2.dx;
  final dx2 = p3.dx - p2.dx;
  final dx3 = p0.dx - p1.dx + p2.dx - p3.dx;
  final dy1 = p1.dy - p2.dy;
  final dy2 = p3.dy - p2.dy;
  final dy3 = p0.dy - p1.dy + p2.dy - p3.dy;
  final determinant = dx1 * dy2 - dx2 * dy1;
  final projectiveX = (dx3 * dy2 - dx2 * dy3) / determinant;
  final projectiveY = (dx1 * dy3 - dx3 * dy1) / determinant;
  final a = p1.dx - p0.dx + projectiveX * p1.dx;
  final b = p3.dx - p0.dx + projectiveY * p3.dx;
  final d = p1.dy - p0.dy + projectiveX * p1.dy;
  final e = p3.dy - p0.dy + projectiveY * p3.dy;
  return Matrix4.identity()
    ..setEntry(0, 0, a / size.width)
    ..setEntry(0, 1, b / size.height)
    ..setEntry(0, 3, p0.dx)
    ..setEntry(1, 0, d / size.width)
    ..setEntry(1, 1, e / size.height)
    ..setEntry(1, 3, p0.dy)
    ..setEntry(3, 0, projectiveX / size.width)
    ..setEntry(3, 1, projectiveY / size.height);
}

class FieldPlanCardPerspective extends StatelessWidget {
  const FieldPlanCardPerspective({
    required this.seatID,
    required this.child,
    super.key,
  });

  final int seatID;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Transform(
        alignment: Alignment.topLeft,
        transform: fieldPlanCardHomography(
          constraints.biggest,
          fieldPlanCardQuad(seatID),
        ),
        transformHitTests: false,
        child: child,
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
    this.heroWithinReach = false,
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
  final bool heroWithinReach;
  final VoidCallback? onInspect;

  @override
  Widget build(BuildContext context) {
    if (configuredKolkhozArtStyle.usesNewArt) {
      return _buildFieldPlanBadge();
    }
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
                  'assets/ui/ui-player-panel.png',
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
                              'assets/ui/Icons/${reactionAsset(reaction!.reactionID)}',
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
                        heroWithinReach: heroWithinReach,
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

  Widget _buildFieldPlanBadge() {
    final human = seat.isViewer;
    final ink = const Color(0xff24251d);
    final accent = active ? const Color(0xffa33a28) : const Color(0xff4c5940);
    return MotionTrackedRegion(
      motionKey: playerCardMotionSourceKey(seat.id),
      child: Semantics(
        button: true,
        label: displayName,
        child: GestureDetector(
          key: Key('player-portrait-${seat.id}-inspect'),
          behavior: HitTestBehavior.opaque,
          onTap: onInspect,
          child: SizedBox(
            width: width,
            height: height,
            child: FieldPlanSign(
              borderColor: human ? const Color(0xffa33a28) : accent,
              borderWidth: active ? 2 : 1,
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: height,
                    child: PlayerPortrait(
                      seat: seat,
                      tokens: tokens,
                      width: height,
                      height: height,
                      badgeVisible: false,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: fieldPlanDisplayTextStyle.copyWith(
                              color: ink,
                              fontSize: math.max(10, height * 0.24),
                            ),
                          ),
                          Text(
                            '${seat.visibleScore}  •  ${seat.medals}/$maxTricks',
                            maxLines: 1,
                            style: fieldPlanBodyStrongTextStyle.copyWith(
                              color: accent,
                              fontSize: math.max(8, height * 0.18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get displayName {
    final base = seatDisplayName(seat, language: language);
    return seat.statusText.isEmpty ||
            RegExp(r'^\d+s$').hasMatch(seat.statusText)
        ? base
        : '$base ${seat.statusText}';
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

class ExpandedPlayerInfoPanel extends StatelessWidget {
  const ExpandedPlayerInfoPanel({
    required this.seat,
    required this.tokens,
    required this.language,
    required this.maxTricks,
    this.heroWithinReach = false,
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
  final bool heroWithinReach;
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
      if (seat.statusText.isNotEmpty &&
          !RegExp(r'^\d+s$').hasMatch(seat.statusText))
        seat.statusText,
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
        ? 'assets/ui/Icons/icon-comrade.png'
        : hasOutgoingRequest
        ? 'assets/ui/Icons/icon-status-connecting.png'
        : 'assets/ui/Icons/icon-add-friend.png';
    final actionEnabled =
        showComradeAction && !isComrade && !hasOutgoingRequest;

    return ExpandedPlayerProfile(
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
                      'assets/ui/Icons/$asset',
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
    if (width < iconSize + 12 * scale) {
      return SizedBox(
        width: width,
        height: 18 * scale,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: PixelText(
            '$score',
            size: PixelTextSize.headline,
            variant: PixelTextVariant.heavy,
            color: tokens.colors.smoke,
          ),
        ),
      );
    }
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
              'assets/ui/Icons/icon-plot.png',
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
    this.heroWithinReach = false,
    required this.tokens,
    required this.statColumnWidth,
    required this.scale,
    super.key,
  });

  final int medals;
  final int maxTricks;
  final bool heroWithinReach;
  final DesignTokens tokens;
  final double statColumnWidth;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final iconSize = playerPanelMedalIconSize * scale;
    final spacing = playerPanelMedalSpacing * scale;
    final medalStrip = SizedBox(
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
                          asset: 'assets/ui/Icons/icon-medal-star.png',
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
    return HeroMedalPulse(active: heroWithinReach, child: medalStrip);
  }

  Widget playerMedalIcon(double size, int index) {
    return Image.asset(
      'assets/ui/Icons/icon-medal-star.png',
      key: ValueKey('earned-medal-$index'),
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
    );
  }
}

class HeroMedalPulse extends StatefulWidget {
  const HeroMedalPulse({required this.active, required this.child, super.key});

  final bool active;
  final Widget child;

  @override
  State<HeroMedalPulse> createState() => _HeroMedalPulseState();
}

class _HeroMedalPulseState extends State<HeroMedalPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> pulse = CurvedAnimation(
    parent: controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    updateAnimation();
  }

  @override
  void didUpdateWidget(HeroMedalPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      updateAnimation();
    }
  }

  void updateAnimation() {
    if (widget.active) {
      controller.repeat(reverse: true);
    } else {
      controller.stop();
      controller.value = 0;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return widget.child;
    }
    return Semantics(
      label: 'One trick from Hero of Socialist Labor',
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          return DecoratedBox(
            key: const ValueKey('hero-medal-warning'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xffffd75a,
                  ).withValues(alpha: 0.28 + pulse.value * 0.5),
                  blurRadius: 3 + pulse.value * 6,
                  spreadRadius: pulse.value * 2,
                ),
              ],
            ),
            child: Transform.scale(scale: 1 + pulse.value * 0.12, child: child),
          );
        },
        child: widget.child,
      ),
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
              'assets/ui/Icons/icon-cellar.png',
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
          cardBack.displayedIconAssetPath,
          fit: BoxFit.cover,
          filterQuality: configuredKolkhozArtStyle.usesNewArt
              ? FilterQuality.medium
              : FilterQuality.none,
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
