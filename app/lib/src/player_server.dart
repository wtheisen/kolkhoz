import 'c_engine_bridge.dart';
import 'game_lobby.dart';
import 'online_game_models.dart';
import 'player.dart';

class ServerGamePlayer extends GamePlayer {
  const ServerGamePlayer({
    required super.seatID,
    required super.controller,
    required this.isViewer,
    this.profile,
    this.presence,
  });

  final bool isViewer;
  final OnlinePlayerProfile? profile;
  final OnlineSeatPresence? presence;

  bool get occupied =>
      controller != KolkhozPlayerController.human || profile != null;
}

GameLobby gameLobbyFromServerUpdate(
  OnlineSessionUpdate update, {
  required int? viewerSeatID,
  List<GameSpectator> spectators = const [],
}) {
  final profiles = {
    for (final profile in update.playerProfiles) profile.playerID: profile,
  };
  final presence = {
    for (final value in update.seatPresence) value.playerID: value,
  };
  final players = [
    for (final (seatID, controller) in update.controllers.indexed)
      ServerGamePlayer(
        seatID: seatID,
        controller: controller,
        isViewer: seatID == viewerSeatID,
        profile: profiles[seatID],
        presence: presence[seatID],
      ),
  ];
  return GameLobby(
    variants: update.variants,
    seats: [
      for (final player in players)
        GameSeat(seatID: player.seatID, player: player, ready: player.occupied),
    ],
    spectators: spectators,
  );
}
