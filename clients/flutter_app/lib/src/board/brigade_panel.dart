part of '../board_view.dart';

class BrigadePanel extends StatefulWidget {
  const BrigadePanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.heroOfSovietUnion = true,
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
  final bool heroOfSovietUnion;
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
            heroOfSovietUnion: widget.heroOfSovietUnion,
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
    required this.heroOfSovietUnion,
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
  final bool heroOfSovietUnion;
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
                        heroWithinReach:
                            heroOfSovietUnion &&
                            seat.medals == maxTricks - 1 &&
                            (phase == phaseTrick || phase == phaseAssignment),
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
    return HeroMedalPulse(active: heroWithinReach, child: medalStrip);
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
