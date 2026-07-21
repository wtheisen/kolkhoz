import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app_settings.dart';
import 'src/board/board_widgets.dart';
import 'src/design_tokens.dart';
import 'src/diorama/brigade_fields_diorama.dart';
import 'src/render_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BrigadeFieldsDioramaLabApp());
}

enum _DioramaJourneyPhase { ready, outbound, staging, returning, complete }

DioramaPoint _lerpPoint(DioramaPoint from, DioramaPoint to, double t) =>
    DioramaPoint(
      lerpDouble(from.x, to.x, t)!,
      lerpDouble(from.y, to.y, t)!,
      lerpDouble(from.z, to.z, t)!,
    );

class BrigadeFieldsDioramaLabApp extends StatelessWidget {
  const BrigadeFieldsDioramaLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kolkhoz · Brigade to Fields to North Diorama',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff9f2d31)),
        fontFamily: 'PTSansNarrow',
        useMaterial3: true,
      ),
      home: const BrigadeFieldsDioramaLabScreen(),
    );
  }
}

class BrigadeFieldsDioramaLabScreen extends StatefulWidget {
  const BrigadeFieldsDioramaLabScreen({super.key});

  @override
  State<BrigadeFieldsDioramaLabScreen> createState() =>
      _BrigadeFieldsDioramaLabScreenState();
}

class _BrigadeFieldsDioramaLabScreenState
    extends State<BrigadeFieldsDioramaLabScreen>
    with TickerProviderStateMixin {
  late final AnimationController cameraController;
  late final AnimationController journeyController;
  late final AnimationController assignmentController;
  Timer? scrollSettleTimer;
  double cameraProgress = 0;
  bool showGuides = false;
  String? selectedCardID;
  String? movingCardID;
  String? movingFieldID;
  _DioramaJourneyPhase journeyPhase = _DioramaJourneyPhase.ready;
  final assignments = <String, String>{};
  final claimedRewardSuits = <String>{};
  int northYear = 3;

  static const trickCards = <TableCard>[
    TableCard(
      id: 'wheat-11',
      suit: 'wheat',
      value: 11,
      rank: 'J',
      selected: false,
      highlighted: false,
      pending: false,
      ownerSeatID: 0,
    ),
    TableCard(
      id: 'sunflower-8',
      suit: 'sunflower',
      value: 8,
      rank: '8',
      selected: false,
      highlighted: false,
      pending: false,
      ownerSeatID: 1,
    ),
    TableCard(
      id: 'potato-10',
      suit: 'potato',
      value: 10,
      rank: '10',
      selected: false,
      highlighted: false,
      pending: false,
      ownerSeatID: 2,
    ),
    TableCard(
      id: 'beet-6',
      suit: 'beet',
      value: 6,
      rank: '6',
      selected: false,
      highlighted: false,
      pending: false,
      ownerSeatID: 3,
    ),
  ];

  static const fieldCards = <TableCard>[
    TableCard(
      id: 'wheat-9',
      suit: 'wheat',
      value: 9,
      rank: '9',
      selected: false,
      highlighted: false,
      pending: false,
      assignmentRound: 1,
    ),
    TableCard(
      id: 'sunflower-7',
      suit: 'sunflower',
      value: 7,
      rank: '7',
      selected: false,
      highlighted: false,
      pending: false,
      assignmentRound: 1,
    ),
    TableCard(
      id: 'potato-12',
      suit: 'potato',
      value: 12,
      rank: 'Q',
      selected: false,
      highlighted: false,
      pending: false,
      assignmentRound: 2,
    ),
    TableCard(
      id: 'beet-10',
      suit: 'beet',
      value: 10,
      rank: '10',
      selected: false,
      highlighted: false,
      pending: false,
      assignmentRound: 2,
    ),
  ];

  static const rewardCards = <TableCard>[
    TableCard(
      id: 'reward-wheat',
      suit: 'wheat',
      value: 14,
      rank: 'A',
      selected: false,
      highlighted: true,
      pending: false,
    ),
    TableCard(
      id: 'reward-sunflower',
      suit: 'sunflower',
      value: 14,
      rank: 'A',
      selected: false,
      highlighted: true,
      pending: false,
    ),
    TableCard(
      id: 'reward-potato',
      suit: 'potato',
      value: 14,
      rank: 'A',
      selected: false,
      highlighted: true,
      pending: false,
    ),
    TableCard(
      id: 'reward-beet',
      suit: 'beet',
      value: 14,
      rank: 'A',
      selected: false,
      highlighted: true,
      pending: false,
    ),
  ];

  static const handCards = <TableCard>[
    TableCard(
      id: 'hand-wheat-13',
      suit: 'wheat',
      value: 13,
      rank: 'K',
      selected: false,
      highlighted: true,
      pending: false,
    ),
    TableCard(
      id: 'hand-sunflower-9',
      suit: 'sunflower',
      value: 9,
      rank: '9',
      selected: false,
      highlighted: false,
      pending: false,
    ),
    TableCard(
      id: 'hand-potato-7',
      suit: 'potato',
      value: 7,
      rank: '7',
      selected: false,
      highlighted: false,
      pending: false,
    ),
    TableCard(
      id: 'hand-beet-6',
      suit: 'beet',
      value: 6,
      rank: '6',
      selected: false,
      highlighted: false,
      pending: false,
    ),
  ];

  static const removedCardsByYear = <List<TableCard>>[
    [
      TableCard(
        id: 'north-y1-wheat-q',
        suit: 'wheat',
        value: 12,
        rank: 'Q',
        selected: false,
        highlighted: false,
        pending: false,
      ),
      TableCard(
        id: 'north-y1-beet-9',
        suit: 'beet',
        value: 9,
        rank: '9',
        selected: false,
        highlighted: false,
        pending: false,
      ),
      TableCard(
        id: 'north-y1-potato-7',
        suit: 'potato',
        value: 7,
        rank: '7',
        selected: false,
        highlighted: false,
        pending: false,
      ),
    ],
    [
      TableCard(
        id: 'north-y2-sunflower-k',
        suit: 'sunflower',
        value: 13,
        rank: 'K',
        selected: false,
        highlighted: false,
        pending: false,
      ),
      TableCard(
        id: 'north-y2-wheat-10',
        suit: 'wheat',
        value: 10,
        rank: '10',
        selected: false,
        highlighted: false,
        pending: false,
      ),
      TableCard(
        id: 'north-y2-beet-j',
        suit: 'beet',
        value: 11,
        rank: 'J',
        selected: false,
        highlighted: false,
        pending: false,
      ),
      TableCard(
        id: 'north-y2-potato-8',
        suit: 'potato',
        value: 8,
        rank: '8',
        selected: false,
        highlighted: false,
        pending: false,
      ),
    ],
    [],
    [
      TableCard(
        id: 'north-y4-beet-k',
        suit: 'beet',
        value: 13,
        rank: 'K',
        selected: false,
        highlighted: false,
        pending: false,
      ),
      TableCard(
        id: 'north-y4-sunflower-q',
        suit: 'sunflower',
        value: 12,
        rank: 'Q',
        selected: false,
        highlighted: false,
        pending: false,
      ),
      TableCard(
        id: 'north-y4-wheat-j',
        suit: 'wheat',
        value: 11,
        rank: 'J',
        selected: false,
        highlighted: false,
        pending: false,
      ),
    ],
    [
      TableCard(
        id: 'north-y5-potato-a',
        suit: 'potato',
        value: 14,
        rank: 'A',
        selected: false,
        highlighted: false,
        pending: false,
      ),
      TableCard(
        id: 'north-y5-wheat-k',
        suit: 'wheat',
        value: 13,
        rank: 'K',
        selected: false,
        highlighted: false,
        pending: false,
      ),
      TableCard(
        id: 'north-y5-beet-q',
        suit: 'beet',
        value: 12,
        rank: 'Q',
        selected: false,
        highlighted: false,
        pending: false,
      ),
      TableCard(
        id: 'north-y5-sunflower-10',
        suit: 'sunflower',
        value: 10,
        rank: '10',
        selected: false,
        highlighted: false,
        pending: false,
      ),
      TableCard(
        id: 'north-y5-potato-9',
        suit: 'potato',
        value: 9,
        rank: '9',
        selected: false,
        highlighted: false,
        pending: false,
      ),
    ],
  ];

  @override
  void initState() {
    super.initState();
    cameraController = AnimationController(vsync: this, upperBound: 1)
      ..addListener(() {
        setState(() => cameraProgress = cameraController.value);
      });
    journeyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
    );
    assignmentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
  }

  @override
  void dispose() {
    scrollSettleTimer?.cancel();
    cameraController.dispose();
    journeyController.dispose();
    assignmentController.dispose();
    super.dispose();
  }

  void _setCameraProgress(double value) {
    cameraController.stop();
    setState(() {
      cameraProgress = value.clamp(0.0, 1.0);
      cameraController.value = cameraProgress;
    });
  }

  void _moveCamera(double delta) {
    final resisted = brigadeFieldsResistedDelta(
      progress: cameraProgress,
      delta: delta,
    );
    _setCameraProgress(cameraProgress + resisted);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _moveCamera(event.scrollDelta.dy / 900);
    scrollSettleTimer?.cancel();
    scrollSettleTimer = Timer(
      const Duration(milliseconds: 180),
      () => _settle(0),
    );
  }

  void _handleDragUpdate(DragUpdateDetails details, double height) {
    _moveCamera((details.primaryDelta ?? 0) / math.max(1, height * 1.45));
  }

  void _handleDragEnd(DragEndDetails details, double height) {
    final velocity = (details.primaryVelocity ?? 0) / math.max(1, height);
    _settle(velocity);
  }

  void _settle(double velocity) {
    final target = brigadeFieldsSnapTarget(cameraProgress, velocity);
    if ((target - cameraProgress).abs() < 0.0001) return;
    cameraController.animateTo(
      target,
      duration: Duration(
        milliseconds: (220 + (target - cameraProgress).abs() * 520).round(),
      ),
      curve: Curves.easeOutCubic,
    );
  }

  void _animateTo(double target) {
    cameraController.animateTo(
      target,
      duration: Duration(
        milliseconds: (300 + (target - cameraProgress).abs() * 700).round(),
      ),
      curve: Curves.easeInOutCubic,
    );
  }

  double _interval(double value, double start, double end) =>
      ((value - start) / (end - start)).clamp(0.0, 1.0);

  double get _truckRouteProgress => switch (journeyPhase) {
    _DioramaJourneyPhase.ready => 0,
    _DioramaJourneyPhase.outbound => _interval(
      journeyController.value,
      0.16,
      0.80,
    ),
    _DioramaJourneyPhase.staging => 1,
    _DioramaJourneyPhase.returning =>
      1 - _interval(journeyController.value, 0.16, 0.80),
    _DioramaJourneyPhase.complete => 0,
  };

  double get _fieldsDeparture => _interval(cameraProgress, 0.48, 0.66);

  double get _northArrival => _interval(cameraProgress, 0.66, 0.94);

  void _changeNorthYear(int delta) {
    setState(() => northYear = (northYear + delta).clamp(1, 5));
  }

  DioramaPoint _truckBed(int index) => DioramaPoint(
    -0.45 + index * 0.30,
    0.78,
    lerpDouble(9.5, 29.0, _truckRouteProgress)! + 0.12,
  );

  static const _trickCenters = <DioramaPoint>[
    DioramaPoint(1.05, 0.04, 4.1),
    DioramaPoint(-1.05, 0.04, 6.6),
    DioramaPoint(-0.75, 0.04, 8.1),
    DioramaPoint(0.75, 0.04, 6.7),
  ];

  static const _stagingCenters = <DioramaPoint>[
    DioramaPoint(-1.05, 0.04, 28.4),
    DioramaPoint(0.55, 0.04, 29.2),
    DioramaPoint(-0.55, 0.04, 30.3),
    DioramaPoint(1.05, 0.04, 31.1),
  ];

  static const _fieldCenters = <String, DioramaPoint>{
    'wheat': DioramaPoint(-5.2, 0.05, 38.4),
    'sunflower': DioramaPoint(5.2, 0.05, 38.4),
    'potato': DioramaPoint(-5.2, 0.05, 30.3),
    'beet': DioramaPoint(5.2, 0.05, 30.3),
  };

  static const _rewardSignCenters = <String, DioramaPoint>{
    'wheat': DioramaPoint(-8.2, 0.06, 42.2),
    'sunflower': DioramaPoint(8.2, 0.06, 42.2),
    'potato': DioramaPoint(-8.2, 0.06, 33.1),
    'beet': DioramaPoint(8.2, 0.06, 33.1),
  };

  static const _rewardYardCenters = <DioramaPoint>[
    DioramaPoint(-1.35, 0.05, 29.0),
    DioramaPoint(-0.45, 0.05, 30.0),
    DioramaPoint(0.45, 0.05, 30.0),
    DioramaPoint(1.35, 0.05, 29.0),
  ];

  static const _winningPlotCenters = <DioramaPoint>[
    DioramaPoint(5.1, 0.05, 3.2),
    DioramaPoint(6.2, 0.05, 3.8),
    DioramaPoint(5.6, 0.05, 5.1),
    DioramaPoint(6.7, 0.05, 5.6),
  ];

  List<DioramaWorldCardPlacement> get _worldCardPlacements {
    final placements = <DioramaWorldCardPlacement>[];
    for (final indexed in fieldCards.indexed) {
      final index = indexed.$1;
      final card = indexed.$2;
      final center = switch (index % 4) {
        0 => DioramaPoint(-5.0 + index * 0.35, 0.04, 33.0 + index * 0.6),
        1 => DioramaPoint(5.0 + index * 0.20, 0.04, 33.2 + index * 0.6),
        2 => DioramaPoint(-5.2 + index * 0.20, 0.04, 40.0 + index * 0.35),
        _ => DioramaPoint(5.1 + index * 0.15, 0.04, 40.0 + index * 0.35),
      };
      placements.add(
        DioramaWorldCardPlacement(
          card: card,
          center: center,
          role: 'field',
          interactive: false,
        ),
      );
    }

    for (final indexed in trickCards.indexed) {
      final index = indexed.$1;
      final card = indexed.$2;
      final assignedField = assignments[card.id];
      if (assignedField != null) {
        placements.add(
          DioramaWorldCardPlacement(
            card: card,
            center: _fieldCenters[assignedField]!,
            role: 'assigned',
            interactive: false,
          ),
        );
        continue;
      }
      if (movingCardID == card.id) {
        final t = Curves.easeInOutCubic.transform(assignmentController.value);
        placements.add(
          DioramaWorldCardPlacement(
            card: card,
            center: _lerpPoint(
              _stagingCenters[index],
              _fieldCenters[movingFieldID]!,
              t,
            ),
            role: 'moving-worker',
            interactive: false,
          ),
        );
        continue;
      }

      var center = _trickCenters[index];
      var width = 1.35;
      var height = 1.95;
      var role = 'trick';
      var interactive = journeyPhase == _DioramaJourneyPhase.ready;
      if (journeyPhase == _DioramaJourneyPhase.outbound) {
        final load = _interval(journeyController.value, 0, 0.16);
        final unload = _interval(journeyController.value, 0.80, 1);
        if (journeyController.value < 0.16) {
          center = _lerpPoint(_trickCenters[index], _truckBed(index), load);
          width = lerpDouble(1.35, 0.48, load)!;
          height = lerpDouble(1.95, 0.70, load)!;
        } else if (journeyController.value < 0.80) {
          center = _truckBed(index);
          width = 0.48;
          height = 0.70;
        } else {
          center = _lerpPoint(_truckBed(index), _stagingCenters[index], unload);
          width = lerpDouble(0.48, 1.35, unload)!;
          height = lerpDouble(0.70, 1.95, unload)!;
        }
        role = 'traveling-worker';
        interactive = false;
      } else if (journeyPhase == _DioramaJourneyPhase.staging ||
          journeyPhase == _DioramaJourneyPhase.returning ||
          journeyPhase == _DioramaJourneyPhase.complete) {
        center = _stagingCenters[index];
        role = 'staging';
        interactive =
            journeyPhase == _DioramaJourneyPhase.staging &&
            movingCardID == null;
      }
      placements.add(
        DioramaWorldCardPlacement(
          card: card,
          center: center,
          role: role,
          interactive: interactive,
          worldWidth: width,
          worldHeight: height,
        ),
      );
    }

    for (final indexed in rewardCards.indexed) {
      final index = indexed.$1;
      final card = indexed.$2;
      final suit = card.suit;
      var center = _rewardSignCenters[suit]!;
      var role = 'reward';
      var width = 0.92;
      var height = 1.32;
      if (movingFieldID == suit) {
        final t = Curves.easeInOutCubic.transform(assignmentController.value);
        center = _lerpPoint(center, _rewardYardCenters[index], t);
        role = 'moving-reward';
      } else if (claimedRewardSuits.contains(suit)) {
        center = _rewardYardCenters[index];
        role = 'reward-yard';
      }
      if (journeyPhase == _DioramaJourneyPhase.returning) {
        final load = _interval(journeyController.value, 0, 0.16);
        final unload = _interval(journeyController.value, 0.80, 1);
        if (journeyController.value < 0.16) {
          center = _lerpPoint(
            _rewardYardCenters[index],
            _truckBed(index),
            load,
          );
        } else if (journeyController.value < 0.80) {
          center = _truckBed(index);
        } else {
          center = _lerpPoint(
            _truckBed(index),
            _winningPlotCenters[index],
            unload,
          );
        }
        width = journeyController.value < 0.80
            ? lerpDouble(0.92, 0.48, math.min(1, load))!
            : lerpDouble(0.48, 1.12, unload)!;
        height = journeyController.value < 0.80
            ? lerpDouble(1.32, 0.70, math.min(1, load))!
            : lerpDouble(0.70, 1.62, unload)!;
        role = 'returning-reward';
      } else if (journeyPhase == _DioramaJourneyPhase.complete) {
        center = _winningPlotCenters[index];
        width = 1.12;
        height = 1.62;
        role = 'won-reward';
      }
      placements.add(
        DioramaWorldCardPlacement(
          card: card,
          center: center,
          role: role,
          interactive: false,
          worldWidth: width,
          worldHeight: height,
        ),
      );
    }
    return placements;
  }

  Set<String> get _legalFieldIDs {
    if (journeyPhase != _DioramaJourneyPhase.staging ||
        selectedCardID == null ||
        movingCardID != null) {
      return const {};
    }
    return _fieldCenters.keys
        .where((fieldID) => !assignments.containsValue(fieldID))
        .toSet();
  }

  void _startOutbound() {
    if (journeyPhase != _DioramaJourneyPhase.ready) return;
    setState(() {
      selectedCardID = null;
      journeyPhase = _DioramaJourneyPhase.outbound;
    });
    journeyController.forward(from: 0).whenComplete(() {
      if (!mounted || journeyPhase != _DioramaJourneyPhase.outbound) return;
      setState(() => journeyPhase = _DioramaJourneyPhase.staging);
    });
  }

  void _handleWorldCardTap(String cardID) {
    if (journeyPhase != _DioramaJourneyPhase.staging ||
        assignments.containsKey(cardID) ||
        movingCardID != null) {
      return;
    }
    setState(() => selectedCardID = selectedCardID == cardID ? null : cardID);
  }

  void _handleFieldTap(String fieldID) {
    final cardID = selectedCardID;
    if (cardID == null || !_legalFieldIDs.contains(fieldID)) return;
    setState(() {
      movingCardID = cardID;
      movingFieldID = fieldID;
      selectedCardID = null;
    });
    assignmentController.forward(from: 0).whenComplete(() {
      if (!mounted || movingCardID != cardID || movingFieldID != fieldID) {
        return;
      }
      setState(() {
        assignments[cardID] = fieldID;
        claimedRewardSuits.add(fieldID);
        movingCardID = null;
        movingFieldID = null;
      });
      if (assignments.length == trickCards.length) {
        Future<void>.delayed(const Duration(milliseconds: 420), () {
          if (mounted && journeyPhase == _DioramaJourneyPhase.staging) {
            _startReturn();
          }
        });
      }
    });
  }

  void _startReturn() {
    setState(() => journeyPhase = _DioramaJourneyPhase.returning);
    journeyController.forward(from: 0).whenComplete(() {
      if (!mounted || journeyPhase != _DioramaJourneyPhase.returning) return;
      setState(() => journeyPhase = _DioramaJourneyPhase.complete);
    });
  }

  void _resetJourney() {
    journeyController.stop();
    assignmentController.stop();
    journeyController.value = 0;
    assignmentController.value = 0;
    setState(() {
      selectedCardID = null;
      movingCardID = null;
      movingFieldID = null;
      assignments.clear();
      claimedRewardSuits.clear();
      journeyPhase = _DioramaJourneyPhase.ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KolkhozAppearance.light.tokens;
    final pose = const BrigadeFieldsCameraPath().poseAt(cameraProgress);
    return Scaffold(
      backgroundColor: const Color(0xffded3ad),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const handHeight = 116.0;
          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.digit1): () =>
                  _animateTo(0),
              const SingleActivator(LogicalKeyboardKey.digit2): () =>
                  _animateTo(BrigadeFieldsCameraPath.fieldsProgress),
              const SingleActivator(LogicalKeyboardKey.digit3): () =>
                  _animateTo(1),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _moveCamera(-0.08),
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _moveCamera(0.08),
            },
            child: Focus(
              autofocus: true,
              child: Listener(
                onPointerSignal: _handlePointerSignal,
                child: GestureDetector(
                  key: const Key('brigade-fields-diorama-scroll-surface'),
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) => cameraController.stop(),
                  onVerticalDragUpdate: (details) =>
                      _handleDragUpdate(details, constraints.maxHeight),
                  onVerticalDragEnd: (details) =>
                      _handleDragEnd(details, constraints.maxHeight),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        bottom: handHeight,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            journeyController,
                            assignmentController,
                          ]),
                          builder: (context, _) => Stack(
                            fit: StackFit.expand,
                            children: [
                              BrigadeFieldsDioramaScene(
                                cameraProgress: cameraProgress,
                                truckProgress: _truckRouteProgress,
                                cardPlacements: _worldCardPlacements,
                                legalFieldIDs: _legalFieldIDs,
                                selectedCardID: selectedCardID,
                                onCardTap: _handleWorldCardTap,
                                onFieldTap: _handleFieldTap,
                                visibleNorthYear: northYear,
                                removedCardsByYear: removedCardsByYear,
                                showGuides: showGuides,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        top: 14,
                        child: _DioramaLabReadout(
                          cameraProgress: cameraProgress,
                          pose: pose,
                        ),
                      ),
                      Positioned(
                        left: 14,
                        top: 86,
                        child: AnimatedOpacity(
                          opacity: 1 - _fieldsDeparture,
                          duration: const Duration(milliseconds: 160),
                          child: IgnorePointer(
                            ignoring: _fieldsDeparture > 0.15,
                            child: AnimatedBuilder(
                              animation: Listenable.merge([
                                journeyController,
                                assignmentController,
                              ]),
                              builder: (context, _) => _DioramaJourneyPanel(
                                phase: journeyPhase,
                                assignedCount: assignments.length,
                                hasSelection: selectedCardID != null,
                                onSend: _startOutbound,
                                onReset: _resetJourney,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        top: 14,
                        child: _DioramaLabToolbar(
                          showGuides: showGuides,
                          onBrigade: () => _animateTo(0),
                          onFields: () => _animateTo(
                            BrigadeFieldsCameraPath.fieldsProgress,
                          ),
                          onNorth: () => _animateTo(1),
                          onToggleGuides: () =>
                              setState(() => showGuides = !showGuides),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        top: 72,
                        child: AnimatedOpacity(
                          opacity: _northArrival,
                          duration: const Duration(milliseconds: 160),
                          child: IgnorePointer(
                            ignoring: _northArrival < 0.85,
                            child: _NorthYearPanel(
                              year: northYear,
                              onPrevious: northYear > 1
                                  ? () => _changeNorthYear(-1)
                                  : null,
                              onNext: northYear < 5
                                  ? () => _changeNorthYear(1)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: handHeight + 10,
                        child: _DioramaScrubber(
                          progress: cameraProgress,
                          onChanged: _setCameraProgress,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: handHeight,
                        child: _DioramaHandTray(
                          cards: handCards,
                          tokens: tokens,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DioramaLabReadout extends StatelessWidget {
  const _DioramaLabReadout({required this.cameraProgress, required this.pose});

  final double cameraProgress;
  final DioramaCameraPose pose;

  @override
  Widget build(BuildContext context) {
    return _DioramaHudSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BRIGADE → FIELDS → NORTH DIORAMA',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.1),
          ),
          Text(
            '${cameraProgress < 0.12
                ? 'BRIGADE HERO'
                : (cameraProgress - BrigadeFieldsCameraPath.fieldsProgress).abs() < 0.08
                ? 'FIELDS HERO'
                : cameraProgress > 0.90
                ? 'NORTH HERO'
                : 'TRAVEL'}  ·  '
            'Z ${pose.routeZ.toStringAsFixed(1)}  ·  '
            'H ${pose.height.toStringAsFixed(1)}  ·  '
            'P ${(pose.pitchRadians * 180 / math.pi).toStringAsFixed(0)}°',
            style: const TextStyle(
              color: Color(0xff9f2d31),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _DioramaJourneyPanel extends StatelessWidget {
  const _DioramaJourneyPanel({
    required this.phase,
    required this.assignedCount,
    required this.hasSelection,
    required this.onSend,
    required this.onReset,
  });

  final _DioramaJourneyPhase phase;
  final int assignedCount;
  final bool hasSelection;
  final VoidCallback onSend;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final instruction = switch (phase) {
      _DioramaJourneyPhase.ready => 'THE TRICK WAITS IN THE ROAD',
      _DioramaJourneyPhase.outbound => 'WORKERS RIDING TO THE FIELDS',
      _DioramaJourneyPhase.staging when hasSelection =>
        'CHOOSE ONE OF THE OPEN FIELDS',
      _DioramaJourneyPhase.staging => 'SELECT A WORKER FROM THE ROAD',
      _DioramaJourneyPhase.returning => 'REWARDS RIDING BACK TO THE PLOT',
      _DioramaJourneyPhase.complete => 'THE WINNING PLOT HAS ITS REWARDS',
    };
    return _DioramaHudSurface(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      child: SizedBox(
        width: 238,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              instruction,
              style: const TextStyle(
                color: Color(0xff28434a),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 5),
            if (phase == _DioramaJourneyPhase.ready)
              FilledButton.icon(
                key: const Key('diorama-send-trick'),
                onPressed: onSend,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff9f2d31),
                  foregroundColor: const Color(0xfff4e8bd),
                  minimumSize: const Size.fromHeight(34),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: const Text('SEND TRICK TO FIELDS'),
              )
            else if (phase == _DioramaJourneyPhase.complete)
              FilledButton.icon(
                key: const Key('diorama-reset-journey'),
                onPressed: onReset,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff28434a),
                  foregroundColor: const Color(0xfff4e8bd),
                  minimumSize: const Size.fromHeight(34),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('RESET PHYSICAL LOOP'),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: phase == _DioramaJourneyPhase.staging
                          ? assignedCount / 4
                          : null,
                      color: const Color(0xff9f2d31),
                      backgroundColor: const Color(0x3328434a),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$assignedCount/4',
                    style: const TextStyle(
                      color: Color(0xff9f2d31),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    key: const Key('diorama-reset-journey'),
                    tooltip: 'Reset physical loop',
                    visualDensity: VisualDensity.compact,
                    onPressed: onReset,
                    icon: const Icon(Icons.replay, size: 18),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _NorthYearPanel extends StatelessWidget {
  const _NorthYearPanel({
    required this.year,
    required this.onPrevious,
    required this.onNext,
  });

  final int year;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return _DioramaHudSurface(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('diorama-north-previous-year'),
            tooltip: 'Remove newest barracks',
            onPressed: onPrevious,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 112,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'NORTH HISTORY',
                  style: TextStyle(
                    color: Color(0xff263f47),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'THROUGH YEAR $year',
                  key: const Key('diorama-north-year-label'),
                  style: const TextStyle(
                    color: Color(0xff9f2d31),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('diorama-north-next-year'),
            tooltip: 'Construct next barracks',
            onPressed: onNext,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

class _DioramaLabToolbar extends StatelessWidget {
  const _DioramaLabToolbar({
    required this.showGuides,
    required this.onBrigade,
    required this.onFields,
    required this.onNorth,
    required this.onToggleGuides,
  });

  final bool showGuides;
  final VoidCallback onBrigade;
  final VoidCallback onFields;
  final VoidCallback onNorth;
  final VoidCallback onToggleGuides;

  @override
  Widget build(BuildContext context) {
    return _DioramaHudSurface(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            key: const Key('diorama-stop-brigade'),
            onPressed: onBrigade,
            child: const Text('BRIGADE'),
          ),
          TextButton(
            key: const Key('diorama-stop-fields'),
            onPressed: onFields,
            child: const Text('FIELDS'),
          ),
          TextButton(
            key: const Key('diorama-stop-north'),
            onPressed: onNorth,
            child: const Text('NORTH'),
          ),
          IconButton(
            key: const Key('diorama-toggle-guides'),
            tooltip: 'Toggle route-space guides',
            onPressed: onToggleGuides,
            icon: Icon(showGuides ? Icons.grid_on : Icons.grid_off),
          ),
        ],
      ),
    );
  }
}

class _DioramaScrubber extends StatelessWidget {
  const _DioramaScrubber({required this.progress, required this.onChanged});

  final double progress;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _DioramaHudSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const Text('BRIGADE'),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Slider(
                  key: const Key('diorama-camera-scrubber'),
                  min: 0,
                  max: 1,
                  value: progress,
                  onChanged: onChanged,
                ),
                const IgnorePointer(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: BrigadeFieldsCameraPath.fieldsProgress,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Color(0xeedfd5b2)),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5),
                            child: Text('FIELDS'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Text('NORTH'),
        ],
      ),
    );
  }
}

class _DioramaHandTray extends StatelessWidget {
  const _DioramaHandTray({required this.cards, required this.tokens});

  final List<TableCard> cards;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xffe7dbb7),
        border: Border(top: BorderSide(color: Color(0xff28434a), width: 2)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 18),
          const SizedBox(
            width: 92,
            child: Text(
              'YOUR HAND',
              style: TextStyle(
                color: Color(0xff28434a),
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final card in cards)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GameCard(
                          key: Key('diorama-hand-card-${card.id}'),
                          card: card,
                          tokens: tokens,
                          sizeOverride: tokens.card.medium,
                          motionTracked: false,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
        ],
      ),
    );
  }
}

class _DioramaHudSurface extends StatelessWidget {
  const _DioramaHudSurface({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xeedfd5b2),
        border: Border.all(color: const Color(0xff28434a), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x3328434a), offset: Offset(2, 2)),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
