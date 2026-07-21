import 'game_engine.dart';
import 'game_ui_state.dart';
import 'render_model.dart';

class GameUndoSnapshot {
  const GameUndoSnapshot({
    required this.engine,
    required this.actionLog,
    required this.localGameLog,
    required this.uiState,
    required this.revealedPlayerID,
    required this.lastSyncedPhase,
  });

  final GameEngine engine;
  final List<EngineAction> actionLog;
  final List<EngineAction> localGameLog;
  final GameUiState uiState;
  final int? revealedPlayerID;
  final String? lastSyncedPhase;

  void dispose() => engine.dispose();
}
