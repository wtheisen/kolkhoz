import 'package:kolkhoz_app/src/app/views/game/game_controller/game_lobby.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_ui_state.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/table_projection_helpers.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/terminal_game_record.dart';

class FinishedGameLobby {
  FinishedGameLobby({
    required this.lobby,
    required this.gameRecord,
    required this.model,
    required List<EngineAction> gameLogActions,
    required List<OnlineReaction> reactions,
    this.onlineUpdate,
    this.onlinePlayerID,
    this.spectator = false,
  }) : gameLogActions = List.unmodifiable(gameLogActions),
       reactions = List.unmodifiable(reactions) {
    if (model.table.gameResult == null) {
      throw ArgumentError.value(model, 'model', 'must contain a game result');
    }
  }

  final GameLobby lobby;
  final TerminalGameRecord gameRecord;
  final TableViewModel model;
  final List<EngineAction> gameLogActions;
  final List<OnlineReaction> reactions;
  final OnlineSessionUpdate? onlineUpdate;
  final int? onlinePlayerID;
  final bool spectator;

  int get seed => gameRecord.seed;
  GameResult get result => model.table.gameResult!;
  bool get isOnline => onlineUpdate != null;
  bool get canRematch {
    final update = onlineUpdate;
    return update != null && !update.ranked && update.series?.completed != true;
  }

  FinishedGameLobby withUiState(GameUiState uiState) => FinishedGameLobby(
    lobby: lobby,
    gameRecord: gameRecord,
    model: TableViewModel(
      viewer: model.viewer,
      table: model.table,
      panels: panelsForPhase(
        uiState,
        model.table.phase,
        seats: model.table.seats,
        lastTrick: model.table.lastTrick,
        legalActions: const [],
      ),
      selection: uiState.selection,
      legalActions: const [],
      seed: model.seed,
    ),
    gameLogActions: gameLogActions,
    reactions: reactions,
    onlineUpdate: onlineUpdate,
    onlinePlayerID: onlinePlayerID,
    spectator: spectator,
  );
}
