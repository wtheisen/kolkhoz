import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';

enum GameEngineMode { local, remote }

class GameEngineUpdate {
  const GameEngineUpdate({this.action, this.transitions = const []});

  final EngineAction? action;
  final List<EngineTransitionEvent> transitions;
}

abstract interface class GameEngine {
  GameEngineMode get mode;

  TableViewModel project();

  void sendHumanAction(LegalAction action);

  void dispose();
}
