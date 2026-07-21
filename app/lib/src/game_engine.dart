import 'dart:ffi';

import 'c_engine_bridge.dart';
import 'game_ui_state.dart';
import 'policy_model.dart';
import 'render_model.dart';
import 'table_view_projection.dart';

class GameEngine {
  GameEngine({
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

  GameEngine._(
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
      throw StateError('GameEngine has been disposed');
    }
    return native;
  }

  int get phase => _bridge.phase(_pointer);
  bool get isFamine => _bridge.isFamine(_pointer);
  int get currentPlayer => _bridge.currentPlayer(_pointer);
  int get lastWinner => _bridge.lastWinner(_pointer);
  List<CEngineActionValue> get legalActions => _bridge.legalActions(_pointer);
  int get requisitionEventCount => _bridge.requisitionEventCount(_pointer);

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

  TableViewModel project({
    required GameUiState uiState,
    required int? revealedPlayerID,
  }) => TableViewProjection(
    bridge: _bridge,
    engine: _pointer,
    controllers: controllers,
    variants: variants,
    uiState: uiState,
    revealedPlayerID: revealedPlayerID,
  ).project();

  GameEngine clone() => GameEngine._(
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
