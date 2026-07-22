import 'package:kolkhoz_app/src/app/profile/profile_controller/progression.dart';
import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';

class OnlinePlayerProfile {
  const OnlinePlayerProfile({
    required this.playerID,
    this.userID,
    this.displayName,
    this.avatarURL,
    this.stats = defaultProfileStats,
  });

  final int playerID;
  final String? userID;
  final String? displayName;
  final String? avatarURL;
  final KolkhozProfileStats stats;

  String? get portraitAsset =>
      profilePortraitAssets.contains(avatarURL) ? avatarURL : null;

  static OnlinePlayerProfile fromJson(Map<String, Object?> json) {
    return OnlinePlayerProfile(
      playerID: json['playerID'] as int,
      userID: json['userID'] as String?,
      displayName: json['displayName'] as String?,
      avatarURL: json['avatarURL'] as String?,
      stats: profileStatsFromJson(json['stats']),
    );
  }
}

class OnlineComradeProfile {
  const OnlineComradeProfile({
    required this.userID,
    this.displayName,
    this.avatarURL,
    this.comradeCode,
    this.requestedAt,
    this.isOnline = false,
    this.inGame = false,
    this.inLobby = false,
    this.isComrade = false,
    this.rank,
    this.stats = defaultProfileStats,
    this.progression = const ProgressionState(),
  });

  final String userID;
  final String? displayName;
  final String? avatarURL;
  final String? comradeCode;
  final DateTime? requestedAt;
  final bool isOnline;
  final bool inGame;
  final bool inLobby;
  final bool isComrade;
  final int? rank;
  final KolkhozProfileStats stats;
  final ProgressionState progression;

  String get displayLabel {
    final trimmed = displayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return comradeCode ?? userID;
  }

  String? get portraitAsset =>
      profilePortraitAssets.contains(avatarURL) ? avatarURL : null;

  static OnlineComradeProfile fromJson(Map<String, Object?> json) {
    return OnlineComradeProfile(
      userID: json['userID'] as String,
      displayName: json['displayName'] as String?,
      avatarURL: json['avatarURL'] as String?,
      comradeCode: json['comradeCode'] as String?,
      requestedAt: _dateTimeFromEpochSeconds(json['requestedAt']),
      isOnline: json['isOnline'] as bool? ?? false,
      inGame: json['inGame'] as bool? ?? false,
      inLobby: json['inLobby'] as bool? ?? false,
      isComrade: json['isComrade'] as bool? ?? false,
      rank: json['rank'] as int?,
      stats: profileStatsFromJson(json['stats']),
      progression: ProgressionState.fromJson(json['progression']),
    );
  }
}

class OnlineComradesResponse {
  const OnlineComradesResponse({
    this.userID,
    this.comradeCode,
    this.comrades = const [],
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
  });

  final String? userID;
  final String? comradeCode;
  final List<OnlineComradeProfile> comrades;
  final List<OnlineComradeProfile> incomingRequests;
  final List<OnlineComradeProfile> outgoingRequests;

  Set<String> get userIDs => {for (final comrade in comrades) comrade.userID};

  static OnlineComradesResponse fromJson(Map<String, Object?> json) {
    return OnlineComradesResponse(
      userID: json['userID'] as String?,
      comradeCode: json['comradeCode'] as String?,
      comrades: [
        for (final value in jsonList(json['comrades'] ?? const []))
          OnlineComradeProfile.fromJson(jsonObject(value)),
      ],
      incomingRequests: [
        for (final value in jsonList(json['incomingRequests'] ?? const []))
          OnlineComradeProfile.fromJson(jsonObject(value)),
      ],
      outgoingRequests: [
        for (final value in jsonList(json['outgoingRequests'] ?? const []))
          OnlineComradeProfile.fromJson(jsonObject(value)),
      ],
    );
  }
}

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
