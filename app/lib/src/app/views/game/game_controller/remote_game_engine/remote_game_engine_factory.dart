import 'package:kolkhoz_app/src/app/views/game/game_controller/game_lobby.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_ui_state.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_remote_connection.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/remote_game_engine.dart';

class RemoteGameEngineFactory {
  const RemoteGameEngineFactory(
    this.connection, {
    this.realtimeReconnectDelay = const Duration(seconds: 1),
  });

  final GameRemoteConnection connection;
  final Duration realtimeReconnectDelay;

  RemoteGameEngine create({
    required String sessionID,
    required String inviteCode,
    required int playerID,
    required String seatToken,
    required OnlineSessionUpdate update,
    required GameUiState Function() uiState,
    required void Function(GameUiState) setUiState,
    required GameLobby Function() lobby,
    required void Function(OnlineSessionUpdate) onUpdate,
    required void Function() onStateChanged,
    required void Function(String?) onError,
    bool spectator = false,
  }) => RemoteGameEngine(
    client: connection,
    sessionID: sessionID,
    inviteCode: inviteCode,
    playerID: playerID,
    seatToken: seatToken,
    initialUpdate: update,
    realtimeReconnectDelay: realtimeReconnectDelay,
    uiState: uiState,
    setUiState: setUiState,
    lobby: lobby,
    onUpdate: onUpdate,
    onStateChanged: onStateChanged,
    onError: onError,
    spectator: spectator,
  );
}
