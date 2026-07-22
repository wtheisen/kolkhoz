import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/native_game_engine.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/players/player.dart';

class HumanPlayer extends LocalGamePlayer {
  const HumanPlayer({required super.seatID})
    : super(controller: KolkhozPlayerController.human);

  @override
  bool get waitsForHumanInput => true;

  @override
  CEngineActionValue? chooseAction(NativeGameEngine engine) => null;
}
