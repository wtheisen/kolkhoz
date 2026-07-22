import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';

abstract class GamePlayer {
  const GamePlayer({required this.seatID, required this.controller});

  final int seatID;
  final KolkhozPlayerController controller;
}
