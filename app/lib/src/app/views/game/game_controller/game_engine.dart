import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

enum GameEngineMode { local, remote }

abstract interface class GameEngine {
  GameEngineMode get mode;

  int? get presentationRevision;

  TableViewModel project();

  void sendHumanAction(LegalAction action);

  void acknowledgePresentation(int revision);

  void dispose();
}
