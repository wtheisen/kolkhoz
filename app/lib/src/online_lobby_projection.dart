import 'c_engine_bridge.dart';
import 'game_lobby.dart';
import 'online_game_models.dart';
import 'player_presence.dart';
import 'player_profile.dart';
import 'player_server.dart';

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
