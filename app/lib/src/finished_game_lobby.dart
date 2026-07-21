import 'game_lobby.dart';
import 'game_state_snapshot.dart';
import 'game_ui_state.dart';
import 'online_game_models.dart';
import 'render_model.dart';
import 'table_projection_helpers.dart';

class FinishedGameLobby {
  FinishedGameLobby({
    required this.lobby,
    required this.gameState,
    required List<EngineAction> gameLogActions,
    required List<OnlineReaction> reactions,
    this.onlineUpdate,
    this.onlinePlayerID,
    this.spectator = false,
  }) : gameLogActions = List.unmodifiable(gameLogActions),
       reactions = List.unmodifiable(reactions) {
    if (gameState.model.table.gameResult == null) {
      throw ArgumentError.value(
        gameState,
        'gameState',
        'must contain a game result',
      );
    }
  }

  final GameLobby lobby;
  final GameStateSnapshot gameState;
  final List<EngineAction> gameLogActions;
  final List<OnlineReaction> reactions;
  final OnlineSessionUpdate? onlineUpdate;
  final int? onlinePlayerID;
  final bool spectator;

  TableViewModel get model => gameState.model;
  int get seed => gameState.seed;
  GameResult get result => model.table.gameResult!;
  bool get isOnline => onlineUpdate != null;
  bool get canRematch {
    final update = onlineUpdate;
    return update != null && !update.ranked && update.series?.completed != true;
  }

  FinishedGameLobby withUiState(GameUiState uiState) => FinishedGameLobby(
    lobby: lobby,
    gameState: GameStateSnapshot(
      seed: gameState.seed,
      variants: gameState.variants,
      controllers: gameState.controllers,
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
    ),
    gameLogActions: gameLogActions,
    reactions: reactions,
    onlineUpdate: onlineUpdate,
    onlinePlayerID: onlinePlayerID,
    spectator: spectator,
  );
}
