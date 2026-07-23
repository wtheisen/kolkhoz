import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_serialization.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_state_models.dart';

part 'game_session_models.freezed.dart';
part 'game_session_models.g.dart';

@Freezed(toJson: false)
abstract class OnlineTournamentGameStatus with _$OnlineTournamentGameStatus {
  const factory OnlineTournamentGameStatus({
    required String tournamentID,
    required int roundNumber,
    required int tableNumber,
    @Default(4) int totalRounds,
    required String status,
  }) = _OnlineTournamentGameStatus;

  factory OnlineTournamentGameStatus.fromJson(Map<String, Object?> json) =>
      _$OnlineTournamentGameStatusFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineSessionUpdate with _$OnlineSessionUpdate {
  const OnlineSessionUpdate._();

  const factory OnlineSessionUpdate({
    required String sessionID,
    int? seed,
    @JsonKey(readValue: _inviteCodeFromJson) required String inviteCode,
    required int? viewerID,
    required int actionLogCount,
    @Default(false) bool isViewerTurn,
    @Default([]) List<OnlineEngineAction> legalActions,
    @JsonKey(fromJson: _variantsFromJson) required KolkhozGameVariants variants,
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
    @Default([]) List<OnlineEngineAction> gameLogActions,
    @Default([]) List<OnlineReaction> reactions,
    OnlineSeriesStatus? series,
    OnlineTournamentGameStatus? tournament,
    required OnlineEngineSnapshot snapshot,
  }) = _OnlineSessionUpdate;

  factory OnlineSessionUpdate.fromJson(Map<String, Object?> json) =>
      _$OnlineSessionUpdateFromJson(json);

  int? get lobbyCountdownSeconds {
    final deadline = lobbyCountdownEndsAt;
    if (deadline == null || started) {
      return null;
    }
    final remaining = deadline - DateTime.now().millisecondsSinceEpoch / 1000;
    return remaining.ceil().clamp(0, 30).toInt();
  }
}

@Freezed(toJson: false)
abstract class OnlineSeriesStatus with _$OnlineSeriesStatus {
  const OnlineSeriesStatus._();

  const factory OnlineSeriesStatus({
    required String seriesID,
    required int bestOf,
    required int roundNumber,
    @Default(false) bool completed,
    required int? winnerPlayerID,
    @JsonKey(fromJson: _winsFromJson) required Map<int, int> wins,
  }) = _OnlineSeriesStatus;

  factory OnlineSeriesStatus.fromJson(Map<String, Object?> json) =>
      _$OnlineSeriesStatusFromJson(json);

  int winsFor(int playerID) => wins[playerID] ?? 0;
}

@Freezed(toJson: false)
abstract class OnlineReaction with _$OnlineReaction {
  const factory OnlineReaction({
    required int revision,
    required int playerID,
    required String reactionID,
    required int year,
    required int phase,
    required double createdAt,
  }) = _OnlineReaction;

  factory OnlineReaction.fromJson(Map<String, Object?> json) =>
      _$OnlineReactionFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineSeatPresence with _$OnlineSeatPresence {
  const factory OnlineSeatPresence({
    required int playerID,
    @Default(false) bool connected,
    double? lastSeenAt,
    @Default(0) int timeouts,
    @Default(false) bool autopilot,
    @Default(false) bool abandoned,
  }) = _OnlineSeatPresence;

  factory OnlineSeatPresence.fromJson(Map<String, Object?> json) =>
      _$OnlineSeatPresenceFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineSessionResponse with _$OnlineSessionResponse {
  const factory OnlineSessionResponse({
    required String sessionID,
    @JsonKey(readValue: _inviteCodeFromJson) required String inviteCode,
    required int playerID,
    required String seatToken,
    required OnlineSessionUpdate update,
  }) = _OnlineSessionResponse;

  factory OnlineSessionResponse.fromJson(Map<String, Object?> json) =>
      _$OnlineSessionResponseFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineActionUpdate with _$OnlineActionUpdate {
  const factory OnlineActionUpdate({
    required int revision,
    required OnlineEngineAction action,
    required OnlineSessionUpdate update,
  }) = _OnlineActionUpdate;

  factory OnlineActionUpdate.fromJson(Map<String, Object?> json) =>
      _$OnlineActionUpdateFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineActionUpdatesResponse with _$OnlineActionUpdatesResponse {
  const factory OnlineActionUpdatesResponse({
    required String sessionID,
    required int actionLogCount,
    @Default([]) List<OnlineActionUpdate> updates,
    OnlineSessionUpdate? resyncUpdate,
  }) = _OnlineActionUpdatesResponse;

  factory OnlineActionUpdatesResponse.fromJson(Map<String, Object?> json) =>
      _$OnlineActionUpdatesResponseFromJson(json);
}

Object? _inviteCodeFromJson(Map<dynamic, dynamic> json, String key) =>
    json[key] ?? json['sessionID'];

KolkhozGameVariants _variantsFromJson(Object? value) =>
    variantsFromJson(jsonObject(value));

List<KolkhozPlayerController> _controllersFromJson(Object? value) =>
    KolkhozPlayerController.normalized([
      for (final controller in jsonList(value)) controllerFromJson(controller),
    ]);

Map<int, int> _winsFromJson(Object? value) {
  final json = jsonObject(value ?? const <String, Object?>{});
  return {
    for (final entry in json.entries)
      ?int.tryParse(entry.key): entry.value as int,
  };
}
