import 'c_engine_bridge.dart';
import 'game_engine.dart';
import 'player.dart';

class HeuristicAIPlayer extends LocalGamePlayer {
  const HeuristicAIPlayer({
    required super.seatID,
    super.controller = KolkhozPlayerController.heuristicAI,
  });

  @override
  bool get waitsForHumanInput => false;

  @override
  CEngineActionValue? chooseAction(GameEngine engine) =>
      engine.heuristicAction();
}
