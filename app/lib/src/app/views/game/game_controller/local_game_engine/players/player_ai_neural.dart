import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/native_game_engine.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/players/player.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/policy_model.dart';

class NeuralAIPlayer extends LocalGamePlayer {
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
  CEngineActionValue? chooseAction(NativeGameEngine engine) {
    final policy = model();
    if (policy != null) {
      return engine.policyAction(policy);
    }
    return modelUnavailable() ? engine.heuristicAction() : null;
  }
}
