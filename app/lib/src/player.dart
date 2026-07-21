import 'c_engine_bridge.dart';
import 'game_engine.dart';

abstract class GamePlayer {
  const GamePlayer({required this.seatID, required this.controller});

  final int seatID;
  final KolkhozPlayerController controller;

  bool get waitsForHumanInput;

  CEngineActionValue? chooseAction(GameEngine engine);
}
