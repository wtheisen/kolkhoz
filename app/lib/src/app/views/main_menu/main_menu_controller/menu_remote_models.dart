import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_serialization.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_state_models.dart';

part 'menu_remote_models.freezed.dart';
part 'menu_remote_models.g.dart';

@Freezed(toJson: false)
abstract class OnlineRecentGame with _$OnlineRecentGame {
  const factory OnlineRecentGame({
    required String sessionID,
    required int playerID,
    required int score,
    required int rank,
    required bool won,
    required bool ranked,
    required double completedAt,
  }) = _OnlineRecentGame;

  factory OnlineRecentGame.fromJson(Map<String, Object?> json) =>
      _$OnlineRecentGameFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineReplayResult with _$OnlineReplayResult {
  const factory OnlineReplayResult({
    required int playerID,
    required int score,
    required int rank,
    @Default('Player') String displayName,
  }) = _OnlineReplayResult;

  factory OnlineReplayResult.fromJson(Map<String, Object?> json) =>
      _$OnlineReplayResultFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineReplayEvent with _$OnlineReplayEvent {
  const factory OnlineReplayEvent({
    required int revision,
    required String kind,
    required OnlineEngineAction action,
    required double createdAt,
  }) = _OnlineReplayEvent;

  factory OnlineReplayEvent.fromJson(Map<String, Object?> json) =>
      _$OnlineReplayEventFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineGameReplay with _$OnlineGameReplay {
  const factory OnlineGameReplay({
    required String sessionID,
    required int seed,
    @JsonKey(fromJson: _variantsFromJson) required KolkhozGameVariants variants,
    @JsonKey(fromJson: _controllersFromJson)
    required List<KolkhozPlayerController> controllers,
    @Default(false) bool ranked,
    required List<OnlineReplayResult> results,
    required List<OnlineReplayEvent> events,
  }) = _OnlineGameReplay;

  factory OnlineGameReplay.fromJson(Map<String, Object?> json) =>
      _$OnlineGameReplayFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineDailyLeader with _$OnlineDailyLeader {
  const factory OnlineDailyLeader({
    @Default('Player') String displayName,
    required int score,
  }) = _OnlineDailyLeader;

  factory OnlineDailyLeader.fromJson(Map<String, Object?> json) =>
      _$OnlineDailyLeaderFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineDailyChallenge with _$OnlineDailyChallenge {
  const factory OnlineDailyChallenge({
    required String date,
    required int seed,
    @JsonKey(readValue: _bestScoreFromJson) int? bestScore,
    @Default([]) List<OnlineDailyLeader> leaders,
  }) = _OnlineDailyChallenge;

  factory OnlineDailyChallenge.fromJson(Map<String, Object?> json) =>
      _$OnlineDailyChallengeFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineTournamentStanding with _$OnlineTournamentStanding {
  const factory OnlineTournamentStanding({
    required int rank,
    required String userID,
    @Default('Player') String displayName,
    required double points,
    @Default(0) int wins,
    @Default(0) int gameScore,
    @Default(false) bool isBot,
    @Default(false) bool forfeited,
  }) = _OnlineTournamentStanding;

  factory OnlineTournamentStanding.fromJson(Map<String, Object?> json) =>
      _$OnlineTournamentStandingFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineTournamentTable with _$OnlineTournamentTable {
  const factory OnlineTournamentTable({
    required String tableID,
    required String sessionID,
    required int roundNumber,
    required int tableNumber,
    required String status,
    required int playerID,
  }) = _OnlineTournamentTable;

  factory OnlineTournamentTable.fromJson(Map<String, Object?> json) =>
      _$OnlineTournamentTableFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineWeeklyTournament with _$OnlineWeeklyTournament {
  const OnlineWeeklyTournament._();

  const factory OnlineWeeklyTournament({
    required bool available,
    String? tournamentID,
    double? startsAt,
    double? joinOpensAt,
    double? joinClosesAt,
    @Default('unavailable') String status,
    @Default(0) int roundNumber,
    @Default(4) int totalRounds,
    @Default(false) bool joined,
    @Default(false) bool forfeited,
    @Default(0) int entrantCount,
    @Default([]) List<OnlineTournamentStanding> standings,
    OnlineTournamentTable? table,
  }) = _OnlineWeeklyTournament;

  factory OnlineWeeklyTournament.fromJson(Map<String, Object?> json) =>
      _$OnlineWeeklyTournamentFromJson(json);

  bool get enrollmentOpen {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    return status == 'enrollment' &&
        joinOpensAt != null &&
        joinClosesAt != null &&
        now >= joinOpensAt! &&
        now < joinClosesAt!;
  }
}

@Freezed(toJson: false)
abstract class OnlineSessionListing with _$OnlineSessionListing {
  const OnlineSessionListing._();

  const factory OnlineSessionListing({
    required String sessionID,
    String? inviteCode,
    required List<int> openSeats,
    required List<int> occupiedSeats,
    @JsonKey(fromJson: _controllersFromJson)
    required List<KolkhozPlayerController> controllers,
    @Default([]) List<OnlinePlayerProfile> playerProfiles,
    @Default(true) bool ranked,
    @Default(true) bool browserJoinable,
    @Default([]) List<OnlineSeatPresence> seatPresence,
    int? turnPlayerID,
    double? turnDeadlineAt,
    @Default(true) bool started,
    double? lobbyCountdownEndsAt,
    required int actionLogCount,
    required double createdAt,
    @Default(0.0) double expiresAt,
  }) = _OnlineSessionListing;

  factory OnlineSessionListing.fromJson(Map<String, Object?> json) =>
      _$OnlineSessionListingFromJson(json);

  String get shortID =>
      inviteCode ??
      (sessionID.length <= 8
          ? sessionID
          : sessionID.substring(0, 8).toUpperCase());

  int get connectedHumanSeatCount {
    bool isHumanSeat(int playerID) =>
        playerID >= 0 &&
        playerID < controllers.length &&
        controllers[playerID] == KolkhozPlayerController.human;

    if (seatPresence.isNotEmpty) {
      return seatPresence
          .where(
            (presence) => presence.connected && isHumanSeat(presence.playerID),
          )
          .length;
    }
    return occupiedSeats.where(isHumanSeat).length;
  }
}

@Freezed(toJson: false)
abstract class OnlineSessionInvite with _$OnlineSessionInvite {
  const OnlineSessionInvite._();

  const factory OnlineSessionInvite({
    required String sessionID,
    required List<int> openSeats,
    required List<int> occupiedSeats,
    @JsonKey(fromJson: _controllersFromJson)
    required List<KolkhozPlayerController> controllers,
    @Default([]) List<OnlinePlayerProfile> playerProfiles,
    OnlinePlayerProfile? hostProfile,
    @Default(false) bool ranked,
    @Default(false) bool browserJoinable,
    @Default(false) bool started,
    double? lobbyCountdownEndsAt,
    required double createdAt,
    @Default(0.0) double expiresAt,
  }) = _OnlineSessionInvite;

  factory OnlineSessionInvite.fromJson(Map<String, Object?> json) =>
      _$OnlineSessionInviteFromJson(json);

  String get hostDisplayName {
    final trimmed = hostProfile?.displayName?.trim();
    return trimmed != null && trimmed.isNotEmpty ? trimmed : 'Comrade';
  }
}

@Freezed(toJson: false)
abstract class OnlineServerStatus with _$OnlineServerStatus {
  const factory OnlineServerStatus({
    @JsonKey(readValue: _citizensOnlineFromJson) required int citizensOnline,
  }) = _OnlineServerStatus;

  factory OnlineServerStatus.fromJson(Map<String, Object?> json) =>
      _$OnlineServerStatusFromJson(json);
}

KolkhozGameVariants _variantsFromJson(Object? value) =>
    variantsFromJson(jsonObject(value));

List<KolkhozPlayerController> _controllersFromJson(Object? value) =>
    KolkhozPlayerController.normalized([
      for (final controller in jsonList(value)) controllerFromJson(controller),
    ]);

Object? _bestScoreFromJson(Map<dynamic, dynamic> json, String key) {
  final attempt = json['attempt'];
  return attempt is Map ? attempt['score'] : null;
}

Object? _citizensOnlineFromJson(Map<dynamic, dynamic> json, String key) {
  final service = jsonObject(json['service']);
  final value = service['citizensOnline'] ?? service['activeSeats'];
  return value is int && value >= 0 ? value : 0;
}
