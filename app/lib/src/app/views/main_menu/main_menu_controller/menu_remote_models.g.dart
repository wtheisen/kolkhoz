// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_remote_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OnlineRecentGame _$OnlineRecentGameFromJson(Map<String, dynamic> json) =>
    _OnlineRecentGame(
      sessionID: json['sessionID'] as String,
      playerID: (json['playerID'] as num).toInt(),
      score: (json['score'] as num).toInt(),
      rank: (json['rank'] as num).toInt(),
      won: json['won'] as bool,
      ranked: json['ranked'] as bool,
      completedAt: (json['completedAt'] as num).toDouble(),
    );

_OnlineReplayResult _$OnlineReplayResultFromJson(Map<String, dynamic> json) =>
    _OnlineReplayResult(
      playerID: (json['playerID'] as num).toInt(),
      score: (json['score'] as num).toInt(),
      rank: (json['rank'] as num).toInt(),
      displayName: json['displayName'] as String? ?? 'Player',
    );

_OnlineReplayEvent _$OnlineReplayEventFromJson(Map<String, dynamic> json) =>
    _OnlineReplayEvent(
      revision: (json['revision'] as num).toInt(),
      kind: json['kind'] as String,
      action: OnlineEngineAction.fromJson(
        json['action'] as Map<String, dynamic>,
      ),
      createdAt: (json['createdAt'] as num).toDouble(),
    );

_OnlineGameReplay _$OnlineGameReplayFromJson(Map<String, dynamic> json) =>
    _OnlineGameReplay(
      sessionID: json['sessionID'] as String,
      seed: (json['seed'] as num).toInt(),
      variants: _variantsFromJson(json['variants']),
      controllers: _controllersFromJson(json['controllers']),
      ranked: json['ranked'] as bool? ?? false,
      results: (json['results'] as List<dynamic>)
          .map((e) => OnlineReplayResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      events: (json['events'] as List<dynamic>)
          .map((e) => OnlineReplayEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

_OnlineDailyLeader _$OnlineDailyLeaderFromJson(Map<String, dynamic> json) =>
    _OnlineDailyLeader(
      displayName: json['displayName'] as String? ?? 'Player',
      score: (json['score'] as num).toInt(),
    );

_OnlineDailyChallenge _$OnlineDailyChallengeFromJson(
  Map<String, dynamic> json,
) => _OnlineDailyChallenge(
  date: json['date'] as String,
  seed: (json['seed'] as num).toInt(),
  bestScore: (_bestScoreFromJson(json, 'bestScore') as num?)?.toInt(),
  leaders:
      (json['leaders'] as List<dynamic>?)
          ?.map((e) => OnlineDailyLeader.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

_OnlineTournamentStanding _$OnlineTournamentStandingFromJson(
  Map<String, dynamic> json,
) => _OnlineTournamentStanding(
  rank: (json['rank'] as num).toInt(),
  userID: json['userID'] as String,
  displayName: json['displayName'] as String? ?? 'Player',
  points: (json['points'] as num).toDouble(),
  wins: (json['wins'] as num?)?.toInt() ?? 0,
  gameScore: (json['gameScore'] as num?)?.toInt() ?? 0,
  isBot: json['isBot'] as bool? ?? false,
  forfeited: json['forfeited'] as bool? ?? false,
);

_OnlineTournamentTable _$OnlineTournamentTableFromJson(
  Map<String, dynamic> json,
) => _OnlineTournamentTable(
  tableID: json['tableID'] as String,
  sessionID: json['sessionID'] as String,
  roundNumber: (json['roundNumber'] as num).toInt(),
  tableNumber: (json['tableNumber'] as num).toInt(),
  status: json['status'] as String,
  playerID: (json['playerID'] as num).toInt(),
);

_OnlineWeeklyTournament _$OnlineWeeklyTournamentFromJson(
  Map<String, dynamic> json,
) => _OnlineWeeklyTournament(
  available: json['available'] as bool,
  tournamentID: json['tournamentID'] as String?,
  startsAt: (json['startsAt'] as num?)?.toDouble(),
  joinOpensAt: (json['joinOpensAt'] as num?)?.toDouble(),
  joinClosesAt: (json['joinClosesAt'] as num?)?.toDouble(),
  status: json['status'] as String? ?? 'unavailable',
  roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 0,
  totalRounds: (json['totalRounds'] as num?)?.toInt() ?? 4,
  joined: json['joined'] as bool? ?? false,
  forfeited: json['forfeited'] as bool? ?? false,
  entrantCount: (json['entrantCount'] as num?)?.toInt() ?? 0,
  standings:
      (json['standings'] as List<dynamic>?)
          ?.map(
            (e) => OnlineTournamentStanding.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  table: json['table'] == null
      ? null
      : OnlineTournamentTable.fromJson(json['table'] as Map<String, dynamic>),
);

_OnlineSessionListing _$OnlineSessionListingFromJson(
  Map<String, dynamic> json,
) => _OnlineSessionListing(
  sessionID: json['sessionID'] as String,
  inviteCode: json['inviteCode'] as String?,
  openSeats: (json['openSeats'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  occupiedSeats: (json['occupiedSeats'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
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
  actionLogCount: (json['actionLogCount'] as num).toInt(),
  createdAt: (json['createdAt'] as num).toDouble(),
  expiresAt: (json['expiresAt'] as num?)?.toDouble() ?? 0.0,
);

_OnlineSessionInvite _$OnlineSessionInviteFromJson(Map<String, dynamic> json) =>
    _OnlineSessionInvite(
      sessionID: json['sessionID'] as String,
      openSeats: (json['openSeats'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      occupiedSeats: (json['occupiedSeats'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      controllers: _controllersFromJson(json['controllers']),
      playerProfiles:
          (json['playerProfiles'] as List<dynamic>?)
              ?.map(
                (e) => OnlinePlayerProfile.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      hostProfile: json['hostProfile'] == null
          ? null
          : OnlinePlayerProfile.fromJson(
              json['hostProfile'] as Map<String, dynamic>,
            ),
      ranked: json['ranked'] as bool? ?? false,
      browserJoinable: json['browserJoinable'] as bool? ?? false,
      started: json['started'] as bool? ?? false,
      lobbyCountdownEndsAt: (json['lobbyCountdownEndsAt'] as num?)?.toDouble(),
      createdAt: (json['createdAt'] as num).toDouble(),
      expiresAt: (json['expiresAt'] as num?)?.toDouble() ?? 0.0,
    );

_OnlineServerStatus _$OnlineServerStatusFromJson(Map<String, dynamic> json) =>
    _OnlineServerStatus(
      citizensOnline: (_citizensOnlineFromJson(json, 'citizensOnline') as num)
          .toInt(),
    );
