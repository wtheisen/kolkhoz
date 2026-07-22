import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/native_game_engine.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/players/player.dart';

class HeuristicAIPlayer extends LocalGamePlayer {
  const HeuristicAIPlayer({
    required super.seatID,
    super.controller = KolkhozPlayerController.heuristicAI,
  });

  @override
  bool get waitsForHumanInput => false;

  @override
  CEngineActionValue? chooseAction(NativeGameEngine engine) =>
      engine.heuristicAction();
}
