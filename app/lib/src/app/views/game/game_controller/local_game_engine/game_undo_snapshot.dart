import 'package:kolkhoz_app/src/app/views/game/game_controller/game_ui_state.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'native_game_engine.dart';

class GameUndoSnapshot {
  const GameUndoSnapshot({
    required this.engine,
    required this.actionLog,
    required this.localGameLog,
    required this.uiState,
    required this.revealedPlayerID,
    required this.lastSyncedPhase,
  });

  final NativeGameEngine engine;
  final List<EngineAction> actionLog;
  final List<EngineAction> localGameLog;
  final GameUiState uiState;
  final int? revealedPlayerID;
  final String? lastSyncedPhase;

  void dispose() => engine.dispose();
}
