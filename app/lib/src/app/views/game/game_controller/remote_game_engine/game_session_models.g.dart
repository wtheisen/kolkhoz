// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_session_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OnlineTournamentGameStatus _$OnlineTournamentGameStatusFromJson(
  Map<String, dynamic> json,
) => _OnlineTournamentGameStatus(
  tournamentID: json['tournamentID'] as String,
  roundNumber: (json['roundNumber'] as num).toInt(),
  tableNumber: (json['tableNumber'] as num).toInt(),
  totalRounds: (json['totalRounds'] as num?)?.toInt() ?? 4,
  status: json['status'] as String,
);

_OnlineSessionUpdate _$OnlineSessionUpdateFromJson(
  Map<String, dynamic> json,
) => _OnlineSessionUpdate(
  sessionID: json['sessionID'] as String,
  seed: (json['seed'] as num?)?.toInt(),
  inviteCode: _inviteCodeFromJson(json, 'inviteCode') as String,
  viewerID: (json['viewerID'] as num?)?.toInt(),
  actionLogCount: (json['actionLogCount'] as num).toInt(),
  isViewerTurn: json['isViewerTurn'] as bool? ?? false,
  legalActions:
      (json['legalActions'] as List<dynamic>?)
          ?.map((e) => OnlineEngineAction.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  variants: _variantsFromJson(json['variants']),
  controllers: _controllersFromJson(json['controllers']),
  playerProfiles:
      (json['playerProfiles'] as List<dynamic>?)
          ?.map((e) => OnlinePlayerProfile.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  ranked: json['ranked'] as bool? ?? true,
  browserJoinable: json['browserJoinable'] as bool? ?? true,
  seatPresence:
      (json['seatPresence'] as List<dynamic>?)
          ?.map((e) => OnlineSeatPresence.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  turnPlayerID: (json['turnPlayerID'] as num?)?.toInt(),
  turnDeadlineAt: (json['turnDeadlineAt'] as num?)?.toDouble(),
  started: json['started'] as bool? ?? true,
  lobbyCountdownEndsAt: (json['lobbyCountdownEndsAt'] as num?)?.toDouble(),
  gameLogActions:
      (json['gameLogActions'] as List<dynamic>?)
          ?.map((e) => OnlineEngineAction.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  reactions:
      (json['reactions'] as List<dynamic>?)
          ?.map((e) => OnlineReaction.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  series: json['series'] == null
      ? null
      : OnlineSeriesStatus.fromJson(json['series'] as Map<String, dynamic>),
  tournament: json['tournament'] == null
      ? null
      : OnlineTournamentGameStatus.fromJson(
          json['tournament'] as Map<String, dynamic>,
        ),
  snapshot: OnlineEngineSnapshot.fromJson(
    json['snapshot'] as Map<String, dynamic>,
  ),
);

_OnlineSeriesStatus _$OnlineSeriesStatusFromJson(Map<String, dynamic> json) =>
    _OnlineSeriesStatus(
      seriesID: json['seriesID'] as String,
      bestOf: (json['bestOf'] as num).toInt(),
      roundNumber: (json['roundNumber'] as num).toInt(),
      completed: json['completed'] as bool? ?? false,
      winnerPlayerID: (json['winnerPlayerID'] as num?)?.toInt(),
      wins: _winsFromJson(json['wins']),
    );

_OnlineReaction _$OnlineReactionFromJson(Map<String, dynamic> json) =>
    _OnlineReaction(
      revision: (json['revision'] as num).toInt(),
      playerID: (json['playerID'] as num).toInt(),
      reactionID: json['reactionID'] as String,
      year: (json['year'] as num).toInt(),
      phase: (json['phase'] as num).toInt(),
      createdAt: (json['createdAt'] as num).toDouble(),
    );

_OnlineSeatPresence _$OnlineSeatPresenceFromJson(Map<String, dynamic> json) =>
    _OnlineSeatPresence(
      playerID: (json['playerID'] as num).toInt(),
      connected: json['connected'] as bool? ?? false,
      lastSeenAt: (json['lastSeenAt'] as num?)?.toDouble(),
      timeouts: (json['timeouts'] as num?)?.toInt() ?? 0,
      autopilot: json['autopilot'] as bool? ?? false,
      abandoned: json['abandoned'] as bool? ?? false,
    );

_OnlineSessionResponse _$OnlineSessionResponseFromJson(
  Map<String, dynamic> json,
) => _OnlineSessionResponse(
  sessionID: json['sessionID'] as String,
  inviteCode: _inviteCodeFromJson(json, 'inviteCode') as String,
  playerID: (json['playerID'] as num).toInt(),
  seatToken: json['seatToken'] as String,
  update: OnlineSessionUpdate.fromJson(json['update'] as Map<String, dynamic>),
);

_OnlineActionUpdate _$OnlineActionUpdateFromJson(
  Map<String, dynamic> json,
) => _OnlineActionUpdate(
  revision: (json['revision'] as num).toInt(),
  action: OnlineEngineAction.fromJson(json['action'] as Map<String, dynamic>),
  update: OnlineSessionUpdate.fromJson(json['update'] as Map<String, dynamic>),
);

_OnlineActionUpdatesResponse _$OnlineActionUpdatesResponseFromJson(
  Map<String, dynamic> json,
) => _OnlineActionUpdatesResponse(
  sessionID: json['sessionID'] as String,
  actionLogCount: (json['actionLogCount'] as num).toInt(),
  updates:
      (json['updates'] as List<dynamic>?)
          ?.map((e) => OnlineActionUpdate.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  resyncUpdate: json['resyncUpdate'] == null
      ? null
      : OnlineSessionUpdate.fromJson(
          json['resyncUpdate'] as Map<String, dynamic>,
        ),
);
