import 'dart:ffi';

import 'c_engine_bridge.dart';
import 'policy_model.dart';

abstract class GamePlayer {
  const GamePlayer({required this.seatID, required this.controller});

  final int seatID;
  final KolkhozPlayerController controller;

  bool get waitsForHumanInput;

  CEngineActionValue? chooseAction(
    Pointer<KCEngine> engine,
    KolkhozCEngineBridge bridge,
  );
}

class HumanGamePlayer extends GamePlayer {
  const HumanGamePlayer({required super.seatID})
    : super(controller: KolkhozPlayerController.human);

  @override
  bool get waitsForHumanInput => true;

  @override
  CEngineActionValue? chooseAction(
    Pointer<KCEngine> engine,
    KolkhozCEngineBridge bridge,
  ) => null;
}

class HeuristicGamePlayer extends GamePlayer {
  const HeuristicGamePlayer({
    required super.seatID,
    super.controller = KolkhozPlayerController.heuristicAI,
  });

  @override
  bool get waitsForHumanInput => false;

  @override
  CEngineActionValue? chooseAction(
    Pointer<KCEngine> engine,
    KolkhozCEngineBridge bridge,
  ) => bridge.heuristicAction(engine);
}

class PolicyGamePlayer extends GamePlayer {
  PolicyGamePlayer({
    required super.seatID,
    required super.controller,
    required this.model,
    required this.modelUnavailable,
  });

  final KolkhozNativePolicyModel? Function() model;
  final bool Function() modelUnavailable;

  @override
  bool get waitsForHumanInput => false;

  @override
  CEngineActionValue? chooseAction(
    Pointer<KCEngine> engine,
    KolkhozCEngineBridge bridge,
  ) {
    final policy = model();
    if (policy != null) {
      return bridge.policyAction(
        engine,
        policy.native,
        policy.workspace(bridge),
      );
    }
    return modelUnavailable() ? bridge.heuristicAction(engine) : null;
  }
}
