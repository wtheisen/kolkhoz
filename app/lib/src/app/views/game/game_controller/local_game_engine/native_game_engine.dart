import 'dart:ffi';

import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/policy_model.dart';

class NativeGameEngine {
  NativeGameEngine({
    required KolkhozCEngineBridge bridge,
    required this.seed,
    required this.variants,
    required List<KolkhozPlayerController> controllers,
  }) : _bridge = bridge,
       controllers = List.unmodifiable(controllers),
       _native = bridge.newEngine(
         seed: seed,
         variants: variants,
         controllers: controllers,
       );

  NativeGameEngine._(
    this._bridge,
    this._native,
    this.seed,
    this.variants,
    this.controllers,
  );

  final KolkhozCEngineBridge _bridge;
  final int seed;
  final KolkhozGameVariants variants;
  final List<KolkhozPlayerController> controllers;
  Pointer<KCEngine>? _native;

  Pointer<KCEngine> get _pointer {
    final native = _native;
    if (native == null) {
      throw StateError('NativeGameEngine has been disposed');
    }
    return native;
  }

  int get phase => _bridge.phase(_pointer);
  bool get isFamine => _bridge.isFamine(_pointer);
  int get currentPlayer => _bridge.currentPlayer(_pointer);
  int get lastWinner => _bridge.lastWinner(_pointer);
  int get winnerID => _bridge.winnerID(_pointer);
  List<int> get finalScores => List.unmodifiable([
    for (var playerID = 0; playerID < 4; playerID += 1)
      _bridge.finalScore(_pointer, playerID),
  ]);
  List<CEngineActionValue> get legalActions => _bridge.legalActions(_pointer);
  int get requisitionEventCount => _bridge.requisitionEventCount(_pointer);
  List<EngineTransitionEvent> get transitionEvents =>
      List.unmodifiable(_bridge.transitionEvents(_pointer));

  CEngineActionValue? heuristicAction() => _bridge.heuristicAction(_pointer);

  CEngineActionValue? policyAction(KolkhozNativePolicyModel policy) =>
      _bridge.policyAction(_pointer, policy.native, policy.workspace(_bridge));

  int applyManual(CEngineActionValue action) =>
      _bridge.applyManual(_pointer, action);

  int applyAIAction(CEngineActionValue action) =>
      _bridge.applyAIAction(_pointer, action);

  int stepAutomatic() => _bridge.stepAutomatic(_pointer);

  EngineCardValue requisitionEventCard(int index) =>
      _bridge.requisitionEventCard(_pointer, index);

  int requisitionEventPlayer(int index) =>
      _bridge.requisitionEventPlayer(_pointer, index);

  int requisitionEventSuit(int index) =>
      _bridge.requisitionEventSuit(_pointer, index);

  int requisitionEventMessageKind(int index) =>
      _bridge.requisitionEventMessageKind(_pointer, index);

  /// Allows read-only adapters to inspect native state without making this
  /// engine owner depend on any particular presentation model.
  T readNative<T>(
    T Function(KolkhozCEngineBridge bridge, Pointer<KCEngine> engine) read,
  ) => read(_bridge, _pointer);

  NativeGameEngine clone() => NativeGameEngine._(
    _bridge,
    _bridge.cloneEngine(_pointer),
    seed,
    variants,
    controllers,
  );

  void dispose() {
    final native = _native;
    if (native == null) {
      return;
    }
    _bridge.freeEngine(native);
    _native = null;
  }
}
