// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_remote_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OnlinePlayerProfile _$OnlinePlayerProfileFromJson(Map<String, dynamic> json) =>
    _OnlinePlayerProfile(
      playerID: (json['playerID'] as num).toInt(),
      userID: json['userID'] as String?,
      displayName: json['displayName'] as String?,
      avatarURL: json['avatarURL'] as String?,
      stats: json['stats'] == null
          ? defaultProfileStats
          : profileStatsFromJson(json['stats']),
    );

_OnlineComradeProfile _$OnlineComradeProfileFromJson(
  Map<String, dynamic> json,
) => _OnlineComradeProfile(
  userID: json['userID'] as String,
  displayName: json['displayName'] as String?,
  avatarURL: json['avatarURL'] as String?,
  comradeCode: json['comradeCode'] as String?,
  requestedAt: _dateTimeFromEpochSeconds(json['requestedAt']),
  isOnline: json['isOnline'] as bool? ?? false,
  inGame: json['inGame'] as bool? ?? false,
  inLobby: json['inLobby'] as bool? ?? false,
  isComrade: json['isComrade'] as bool? ?? false,
  rank: (json['rank'] as num?)?.toInt(),
  stats: json['stats'] == null
      ? defaultProfileStats
      : profileStatsFromJson(json['stats']),
  progression: json['progression'] == null
      ? const ProgressionState()
      : _progressionFromJson(json['progression']),
);

_OnlineComradesResponse _$OnlineComradesResponseFromJson(
  Map<String, dynamic> json,
) => _OnlineComradesResponse(
  userID: json['userID'] as String?,
  comradeCode: json['comradeCode'] as String?,
  comrades:
      (json['comrades'] as List<dynamic>?)
          ?.map((e) => OnlineComradeProfile.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  incomingRequests:
      (json['incomingRequests'] as List<dynamic>?)
          ?.map((e) => OnlineComradeProfile.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  outgoingRequests:
      (json['outgoingRequests'] as List<dynamic>?)
          ?.map((e) => OnlineComradeProfile.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);
