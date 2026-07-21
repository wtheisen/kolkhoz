import 'c_engine_bridge.dart';
import 'game_engine.dart';
import 'player.dart';
import 'policy_model.dart';

class NeuralAIPlayer extends GamePlayer {
  NeuralAIPlayer({
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
