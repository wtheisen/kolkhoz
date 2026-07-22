import 'package:kolkhoz_app/src/app/views/game/game_controller/game_ui_state.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/table_view_projection.dart';
import 'native_game_engine.dart';

TableViewModel projectLocalGame({
  required NativeGameEngine engine,
  required GameUiState uiState,
  required int? revealedPlayerID,
}) {
  return engine.readNative(
    (bridge, native) => TableViewProjection(
      bridge: bridge,
      engine: native,
      controllers: engine.controllers,
      variants: engine.variants,
      uiState: uiState,
      revealedPlayerID: revealedPlayerID,
    ).project().withSeed(engine.seed),
  );
}
