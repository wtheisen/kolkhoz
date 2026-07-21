import 'c_engine_bridge.dart';
import 'game_engine.dart';
import 'player.dart';

class HumanPlayer extends GamePlayer {
  const HumanPlayer({required super.seatID})
    : super(controller: KolkhozPlayerController.human);

  @override
  bool get waitsForHumanInput => true;

  @override
  CEngineActionValue? chooseAction(GameEngine engine) => null;
}
