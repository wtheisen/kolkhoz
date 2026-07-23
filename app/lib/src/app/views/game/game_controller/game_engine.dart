import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

enum GameEngineMode { local, remote }

class GameEngineUpdate {
  const GameEngineUpdate({this.action});

  final EngineAction? action;
}

abstract interface class GameEngine {
  GameEngineMode get mode;

  TableViewModel project();

  void sendHumanAction(LegalAction action);

  void dispose();
}
