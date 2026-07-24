import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';
import 'package:kolkhoz_app/src/app/settings/game_motion.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_presentation_transition.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'card_flight.dart';
import 'card_motion_resolver.dart';
import 'card_motion_tracking.dart';

export 'card_flight.dart';
export 'card_motion_plan.dart';
export 'card_motion_resolver.dart';
export 'card_motion_tracking.dart';

/// Captures frame geometry and plays immutable card-motion plans.
///
/// Zone derivation and route planning live outside this widget. This class owns
/// only Flutter lifecycle, active playback stages, and completion delivery.
class CardMotionLayer extends StatefulWidget {
  const CardMotionLayer({
    required this.model,
    required this.tokens,
    required this.speed,
    required this.child,
    this.transition,
    this.onTransitionComplete,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final GameAnimationSpeed speed;
  final Widget child;
  final GamePresentationTransition? transition;
  final ValueChanged<int>? onTransitionComplete;

  @override
  State<CardMotionLayer> createState() => _CardMotionLayerState();
}

class _CardMotionLayerState extends State<CardMotionLayer> {
  final GlobalKey _rootKey = GlobalKey();
  final CardMotionController _controller = CardMotionController();
  final List<CardFlight> _flights = [];
  final Set<String> _presentedAssignmentCardIDs = {};
  final Set<int> _landedFlightIDs = {};
  Set<String> _pendingFlightCardIDs = const {};
  int _nextFlightID = 0;
  int _planGeneration = 0;
  CardMotionPlan? _activePlan;
  int _activeStageIndex = 0;
  Timer? _transitionHoldTimer;

  GameMotion get _motion => GameMotion.of(context, speed: widget.speed);

  @override
  void initState() {
    super.initState();
    final initialTransitionID = widget.transition?.id;
    _afterCardLayout(() {
      _controller.commitFrame();
      if (widget.transition?.id == initialTransitionID) {
        _completeTransition(initialTransitionID);
      }
    });
  }

  @override
  void didUpdateWidget(CardMotionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transition != null &&
        oldWidget.transition?.id == widget.transition?.id) {
      return;
    }
    if (oldWidget.model == widget.model &&
        oldWidget.transition?.id == widget.transition?.id) {
      return;
    }
    final previousModel = widget.transition?.before ?? oldWidget.model;
    final nextModel = widget.transition?.after ?? widget.model;
    final previousCards = cardMotionCards(previousModel);
    final nextCards = cardMotionCards(nextModel);
    final event = widget.transition?.event;
    final routesCardMotion =
        (event?.kind == kcTransitionCardMoved ||
            event?.kind == kcTransitionAssignmentTargeted) &&
        !(event?.fromZone == kcObjectZoneJobPile &&
            event?.toZone == kcObjectZoneRevealedJob);
    final eventCardID = routesCardMotion && event?.card.isValid == true
        ? engineTransitionCardID(event!.card)
        : null;
    final explicitFromZone = event == null || eventCardID == null
        ? null
        : motionZoneForEngineTransition(
            zone: event.fromZone,
            owner: event.fromOwner,
            targetSuit: event.targetSuit,
          );
    final explicitToZone = event == null || eventCardID == null
        ? null
        : motionZoneForEngineTransition(
            zone: event.toZone,
            owner: event.toOwner,
            targetSuit: event.targetSuit,
          );
    final previousZones = event == null
        ? cardMotionZones(previousModel)
        : {
            if (eventCardID != null && explicitFromZone != null)
              eventCardID: explicitFromZone,
          };
    final nextZones = event == null
        ? cardMotionZones(nextModel)
        : {
            if (eventCardID != null && explicitToZone != null)
              eventCardID: explicitToZone,
          };
    final previousGeometry = MotionGeometry(_controller.previousRects);
    final transitionID = widget.transition?.id;
    final assignmentCardIDs = List<String>.of(
      widget.transition?.assignmentCardIDs ?? const [],
    );
    final assignmentTargets = Map<String, String>.of(
      widget.transition?.assignmentTargets ?? const {},
    );
    final suppressedCardIDs = Set<String>.of(
      widget.transition?.suppressedCardIDs ?? const {},
    );
    _pendingFlightCardIDs = {
      for (final entry in nextZones.entries)
        if (previousZones[entry.key] != entry.value &&
            !suppressedCardIDs.contains(entry.key))
          entry.key,
    };
    final planGeneration = ++_planGeneration;
    _afterCardLayout(() {
      if (planGeneration != _planGeneration ||
          widget.transition?.id != transitionID) {
        return;
      }
      final currentGeometry = MotionGeometry(_controller.currentRects);
      final plan = addParallelJobPanelFlights(
        currentGeometry: currentGeometry,
        tokens: widget.tokens,
        plan: planCardFlights(
          motionEnabled: _motion.enabled,
          minimumFlightDistance: GameMotion.minimumFlightDistance,
          previousModel: previousModel,
          nextModel: nextModel,
          previousZones: previousZones,
          nextZones: nextZones,
          previousCards: previousCards,
          nextCards: nextCards,
          previousGeometry: previousGeometry,
          currentGeometry: currentGeometry,
          geometry: DefaultCardMotionGeometryResolver(widget.tokens),
          transitionID: transitionID,
          assignmentCardIDs: assignmentCardIDs,
          assignmentTargets: assignmentTargets,
          suppressedCardIDs: suppressedCardIDs,
          presentedAssignmentCardIDs: _presentedAssignmentCardIDs,
          initialFlightID: _nextFlightID,
          explicitTransition: event != null,
        ),
      );
      _nextFlightID = plan.nextFlightID;
      _presentedAssignmentCardIDs
        ..clear()
        ..addAll(plan.presentedAssignmentCardIDs);
      for (final arrival in plan.immediateJobArrivals) {
        _controller.recordJobCardArrival(arrival);
      }
      _controller.commitFrame();
      _play(plan);
    });
  }

  void _afterCardLayout(VoidCallback action) {
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) {
        action();
      }
    });
  }

  void _play(CardMotionPlan plan) {
    if (plan.stages.isEmpty) {
      if (_pendingFlightCardIDs.isNotEmpty) {
        setState(() => _pendingFlightCardIDs = const {});
      }
      _completeTransition(plan.transitionID);
      return;
    }
    final newFlightCardIDs = {
      for (final flight in plan.flights) flight.card.id,
    };
    setState(() {
      _pendingFlightCardIDs = const {};
      _flights.removeWhere(
        (flight) => newFlightCardIDs.contains(flight.card.id),
      );
      _activePlan = plan;
      _activeStageIndex = 0;
      _flights.addAll(plan.stages.first);
    });
  }

  void _landFlight(int id) {
    if (!mounted) {
      return;
    }
    final flight = _flights.where((flight) => flight.id == id).firstOrNull;
    if (flight == null || !_landedFlightIDs.add(id)) {
      return;
    }
    if (flight.destinationZone.kind == MotionZoneKind.job) {
      if (flight.reportsJobArrival) {
        _controller.recordJobCardArrival(
          JobCardArrival(
            cardID: flight.card.id,
            suit: flight.destinationZone.suit!,
          ),
        );
      }
      Future<void>.delayed(_motion.cardLandingHold, () => _removeFlight(id));
      return;
    }
    _removeFlight(
      id,
      transitionHold: flight.destinationZone.kind == MotionZoneKind.trick
          ? _motion.cardLandingHold
          : Duration.zero,
    );
  }

  void _removeFlight(int id, {Duration transitionHold = Duration.zero}) {
    if (!mounted) {
      return;
    }
    int? completedTransitionID;
    setState(() {
      _flights.removeWhere((flight) => flight.id == id);
      _landedFlightIDs.remove(id);
      if (_flights.isEmpty && _activePlan != null) {
        final nextStageIndex = _activeStageIndex + 1;
        if (nextStageIndex < _activePlan!.stages.length) {
          _activeStageIndex = nextStageIndex;
          _flights.addAll(_activePlan!.stages[nextStageIndex]);
        } else {
          completedTransitionID = _activePlan!.transitionID;
          _activePlan = null;
          _activeStageIndex = 0;
        }
      }
    });
    if (completedTransitionID == null || transitionHold == Duration.zero) {
      _completeTransition(completedTransitionID);
      return;
    }
    _transitionHoldTimer?.cancel();
    _transitionHoldTimer = Timer(transitionHold, () {
      _transitionHoldTimer = null;
      if (mounted) {
        _completeTransition(completedTransitionID);
      }
    });
  }

  void _completeTransition(int? transitionID) {
    if (transitionID != null) {
      widget.onTransitionComplete?.call(transitionID);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = _controller.beginFrame();
    final presentedModel = widget.transition?.after ?? widget.model;
    final winnerSeatID = presentedModel.table.trick.winnerSeatID;
    String? winningTrickCardID;
    for (final play in presentedModel.table.trick.plays) {
      if (play.seatID == winnerSeatID) {
        winningTrickCardID = play.card.id;
        break;
      }
    }
    final activeCardIDs = {
      ..._pendingFlightCardIDs,
      for (final flight in _flights) flight.card.id,
    };
    return CardMotionScope(
      controller: _controller,
      frame: frame,
      rootKey: _rootKey,
      activeCardIDs: activeCardIDs,
      child: Stack(
        key: _rootKey,
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final flight in _flights)
                    FlyingCard(
                      key: ValueKey(flight.id),
                      flight: flight,
                      tokens: widget.tokens,
                      trump: widget.model.table.trump,
                      duration: _motion.cardFlightDuration,
                      visible: _flightVisibleOnPanel(
                        flight,
                        widget.model.panels.active,
                      ),
                      winningTrick:
                          flight.destinationZone.kind == MotionZoneKind.trick &&
                          flight.card.id == winningTrickCardID,
                      onDone: () => _landFlight(flight.id),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _transitionHoldTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

MotionZone? motionZoneForEngineTransition({
  required int zone,
  required int owner,
  required int targetSuit,
}) {
  final suit = engineSuitName(targetSuit);
  return switch (zone) {
    kcObjectZoneHand when owner >= 0 => MotionZone.hand(owner),
    kcObjectZonePlotRevealed when owner >= 0 => MotionZone.plotRevealed(owner),
    kcObjectZonePlotHidden when owner >= 0 => MotionZone.plotHidden(owner),
    kcObjectZoneJobPile when suit != null => MotionZone.rewardReveal(suit),
    kcObjectZoneRevealedJob when suit != null => MotionZone.reward(suit),
    kcObjectZoneCurrentTrick ||
    kcObjectZoneLastTrick when owner >= 0 => MotionZone.trick(owner),
    kcObjectZoneJobBucket when suit != null => MotionZone.job(suit),
    kcObjectZonePendingAssignment when suit != null => MotionZone.job(suit),
    kcObjectZoneExiled => const MotionZone.northExile(),
    _ => null,
  };
}

String engineTransitionCardID(EngineCardValue card) =>
    '${engineSuitName(card.suit) ?? 'unknown'}-${card.value}';

bool _flightVisibleOnPanel(CardFlight flight, String activePanel) {
  return switch (flight.audiencePanel) {
    null => true,
    panelBrigade => activePanel == panelBrigade || activePanel == panelPlot,
    final panel => activePanel == panel,
  };
}
