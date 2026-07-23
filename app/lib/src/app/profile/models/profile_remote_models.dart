import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/progression.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';

part 'profile_remote_models.freezed.dart';
part 'profile_remote_models.g.dart';

@Freezed(toJson: false)
abstract class OnlinePlayerProfile with _$OnlinePlayerProfile {
  const OnlinePlayerProfile._();

  const factory OnlinePlayerProfile({
    required int playerID,
    String? userID,
    String? displayName,
    String? avatarURL,
    @JsonKey(fromJson: profileStatsFromJson)
    @Default(defaultProfileStats)
    KolkhozProfileStats stats,
  }) = _OnlinePlayerProfile;

  factory OnlinePlayerProfile.fromJson(Map<String, Object?> json) =>
      _$OnlinePlayerProfileFromJson(json);

  String? get portraitAsset =>
      profilePortraitAssets.contains(avatarURL) ? avatarURL : null;
}

@Freezed(toJson: false)
abstract class OnlineComradeProfile with _$OnlineComradeProfile {
  const OnlineComradeProfile._();

  const factory OnlineComradeProfile({
    required String userID,
    String? displayName,
    String? avatarURL,
    String? comradeCode,
    @JsonKey(fromJson: _dateTimeFromEpochSeconds) DateTime? requestedAt,
    @Default(false) bool isOnline,
    @Default(false) bool inGame,
    @Default(false) bool inLobby,
    @Default(false) bool isComrade,
    int? rank,
    @JsonKey(fromJson: profileStatsFromJson)
    @Default(defaultProfileStats)
    KolkhozProfileStats stats,
    @JsonKey(fromJson: _progressionFromJson)
    @Default(ProgressionState())
    ProgressionState progression,
  }) = _OnlineComradeProfile;

  factory OnlineComradeProfile.fromJson(Map<String, Object?> json) =>
      _$OnlineComradeProfileFromJson(json);

  String get displayLabel {
    final trimmed = displayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return comradeCode ?? userID;
  }

  String? get portraitAsset =>
      profilePortraitAssets.contains(avatarURL) ? avatarURL : null;
}

@Freezed(toJson: false)
abstract class OnlineComradesResponse with _$OnlineComradesResponse {
  const OnlineComradesResponse._();

  const factory OnlineComradesResponse({
    String? userID,
    String? comradeCode,
    @Default([]) List<OnlineComradeProfile> comrades,
    @Default([]) List<OnlineComradeProfile> incomingRequests,
    @Default([]) List<OnlineComradeProfile> outgoingRequests,
  }) = _OnlineComradesResponse;

  factory OnlineComradesResponse.fromJson(Map<String, Object?> json) =>
      _$OnlineComradesResponseFromJson(json);

  Set<String> get userIDs => {for (final comrade in comrades) comrade.userID};
}

ProgressionState _progressionFromJson(Object? value) =>
    ProgressionState.fromJson(value);

DateTime? _dateTimeFromEpochSeconds(Object? value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }
  if (value is double) {
    return DateTime.fromMillisecondsSinceEpoch(
      (value * 1000).round(),
      isUtc: true,
    );
  }
  return null;
}
