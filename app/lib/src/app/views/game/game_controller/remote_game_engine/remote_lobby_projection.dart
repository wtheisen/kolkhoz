import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_lobby.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/profile/models/player_presence.dart';
import 'package:kolkhoz_app/src/app/profile/models/player_profile.dart';
import 'package:kolkhoz_app/src/app/profile/models/player_server.dart';

PlayerProfile playerProfileFromOnline(OnlinePlayerProfile profile) =>
    PlayerProfile(
      seatID: profile.playerID,
      userID: profile.userID,
      displayName: profile.displayName,
      avatarURL: profile.avatarURL,
      stats: profile.stats,
    );

GameLobby gameLobbyFromOnlineUpdate(
  OnlineSessionUpdate update, {
  required int? viewerSeatID,
  List<GameSpectator> spectators = const [],
}) {
  final profiles = {
    for (final profile in update.playerProfiles)
      profile.playerID: playerProfileFromOnline(profile),
  };
  final presence = {
    for (final value in update.seatPresence)
      value.playerID: PlayerPresence(
        seatID: value.playerID,
        connected: value.connected,
        lastSeenAt: value.lastSeenAt,
        timeouts: value.timeouts,
        autopilot: value.autopilot,
        abandoned: value.abandoned,
      ),
  };
  return GameLobby(
    variants: update.variants,
    seats: [
      for (final (seatID, controller) in update.controllers.indexed)
        GameSeat(
          seatID: seatID,
          player: ServerGamePlayer(seatID: seatID, controller: controller),
          profile: profiles[seatID],
          presence: presence[seatID],
          isViewer: seatID == viewerSeatID,
          ready:
              controller != KolkhozPlayerController.human ||
              profiles[seatID] != null,
        ),
    ],
    spectators: spectators,
  );
}
