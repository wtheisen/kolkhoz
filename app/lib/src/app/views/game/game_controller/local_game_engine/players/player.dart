import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/native_game_engine.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_player.dart';

export 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_player.dart';

abstract class LocalGamePlayer extends GamePlayer {
  const LocalGamePlayer({required super.seatID, required super.controller});

  bool get waitsForHumanInput;

  CEngineActionValue? chooseAction(NativeGameEngine engine);
}
