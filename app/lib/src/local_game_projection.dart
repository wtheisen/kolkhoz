import 'game_engine.dart';
import 'game_ui_state.dart';
import 'render_model.dart';
import 'table_view_projection.dart';

TableViewModel projectLocalGame({
  required GameEngine engine,
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
