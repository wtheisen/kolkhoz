import 'c_engine_bridge.dart';
import 'game_engine.dart';
import 'policy_model.dart';

abstract class GamePlayer {
  const GamePlayer({required this.seatID, required this.controller});

  final int seatID;
  final KolkhozPlayerController controller;

  bool get waitsForHumanInput;

  CEngineActionValue? chooseAction(GameEngine engine);
}

class HumanGamePlayer extends GamePlayer {
  const HumanGamePlayer({required super.seatID})
    : super(controller: KolkhozPlayerController.human);

  @override
  bool get waitsForHumanInput => true;

  @override
  CEngineActionValue? chooseAction(GameEngine engine) => null;
}

class HeuristicGamePlayer extends GamePlayer {
  const HeuristicGamePlayer({
    required super.seatID,
    super.controller = KolkhozPlayerController.heuristicAI,
  });

  @override
  bool get waitsForHumanInput => false;

  @override
  CEngineActionValue? chooseAction(GameEngine engine) =>
      engine.heuristicAction();
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
  CEngineActionValue? chooseAction(GameEngine engine) {
    final policy = model();
    if (policy != null) {
      return engine.policyAction(policy);
    }
    return modelUnavailable() ? engine.heuristicAction() : null;
  }
}
