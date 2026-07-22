import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_serialization.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_state_models.dart';

class OnlineRecentGame {
  const OnlineRecentGame({
    required this.sessionID,
    required this.playerID,
    required this.score,
    required this.rank,
    required this.won,
    required this.ranked,
    required this.completedAt,
  });

  final String sessionID;
  final int playerID;
  final int score;
  final int rank;
  final bool won;
  final bool ranked;
  final double completedAt;

  factory OnlineRecentGame.fromJson(Map<String, Object?> json) {
    return OnlineRecentGame(
      sessionID: json['sessionID'] as String,
      playerID: json['playerID'] as int,
      score: json['score'] as int,
      rank: json['rank'] as int,
      won: json['won'] as bool,
      ranked: json['ranked'] as bool,
      completedAt: (json['completedAt'] as num).toDouble(),
    );
  }
}

class OnlineReplayResult {
  const OnlineReplayResult({
    required this.playerID,
    required this.score,
    required this.rank,
    required this.displayName,
  });
  final int playerID;
  final int score;
  final int rank;
  final String displayName;
  factory OnlineReplayResult.fromJson(Map<String, Object?> json) =>
      OnlineReplayResult(
        playerID: json['playerID'] as int,
        score: json['score'] as int,
        rank: json['rank'] as int,
        displayName: json['displayName'] as String? ?? 'Player',
      );
}

class OnlineReplayEvent {
  const OnlineReplayEvent({
    required this.revision,
    required this.kind,
    required this.action,
    required this.createdAt,
  });
  final int revision;
  final String kind;
  final OnlineEngineAction action;
  final double createdAt;
  factory OnlineReplayEvent.fromJson(Map<String, Object?> json) =>
      OnlineReplayEvent(
        revision: json['revision'] as int,
        kind: json['kind'] as String,
        action: OnlineEngineAction.fromJson(jsonObject(json['action'])),
        createdAt: (json['createdAt'] as num).toDouble(),
      );
}

class OnlineGameReplay {
  const OnlineGameReplay({
    required this.sessionID,
    required this.seed,
    required this.variants,
    required this.controllers,
    required this.ranked,
    required this.results,
    required this.events,
  });
  final String sessionID;
  final int seed;
  final KolkhozGameVariants variants;
  final List<KolkhozPlayerController> controllers;
  final bool ranked;
  final List<OnlineReplayResult> results;
  final List<OnlineReplayEvent> events;
  factory OnlineGameReplay.fromJson(Map<String, Object?> json) =>
      OnlineGameReplay(
        sessionID: json['sessionID'] as String,
        seed: json['seed'] as int,
        variants: variantsFromJson(jsonObject(json['variants'])),
        controllers: [
          for (final value in jsonList(json['controllers']))
            controllerFromJson(value),
        ],
        ranked: json['ranked'] as bool? ?? false,
        results: [
          for (final value in jsonList(json['results']))
            OnlineReplayResult.fromJson(jsonObject(value)),
        ],
        events: [
          for (final value in jsonList(json['events']))
            OnlineReplayEvent.fromJson(jsonObject(value)),
        ],
      );
}

class OnlineDailyLeader {
  const OnlineDailyLeader({required this.displayName, required this.score});
  final String displayName;
  final int score;
  factory OnlineDailyLeader.fromJson(Map<String, Object?> json) =>
      OnlineDailyLeader(
        displayName: json['displayName'] as String? ?? 'Player',
        score: json['score'] as int,
      );
}

class OnlineDailyChallenge {
  const OnlineDailyChallenge({
    required this.date,
    required this.seed,
    required this.bestScore,
    required this.leaders,
  });
  final String date;
  final int seed;
  final int? bestScore;
  final List<OnlineDailyLeader> leaders;
  factory OnlineDailyChallenge.fromJson(Map<String, Object?> json) {
    final attempt = json['attempt'];
    return OnlineDailyChallenge(
      date: json['date'] as String,
      seed: json['seed'] as int,
      bestScore: attempt is Map ? attempt['score'] as int? : null,
      leaders: [
        for (final value in jsonList(json['leaders'] ?? const []))
          OnlineDailyLeader.fromJson(jsonObject(value)),
      ],
    );
  }
}

class OnlineTournamentStanding {
  const OnlineTournamentStanding({
    required this.rank,
    required this.userID,
    required this.displayName,
    required this.points,
    required this.wins,
    required this.gameScore,
    required this.isBot,
    required this.forfeited,
  });

  final int rank;
  final String userID;
  final String displayName;
  final double points;
  final int wins;
  final int gameScore;
  final bool isBot;
  final bool forfeited;

  factory OnlineTournamentStanding.fromJson(Map<String, Object?> json) =>
      OnlineTournamentStanding(
        rank: json['rank'] as int,
        userID: json['userID'] as String,
        displayName: json['displayName'] as String? ?? 'Player',
        points: (json['points'] as num).toDouble(),
        wins: json['wins'] as int? ?? 0,
        gameScore: json['gameScore'] as int? ?? 0,
        isBot: json['isBot'] as bool? ?? false,
        forfeited: json['forfeited'] as bool? ?? false,
      );
}

class OnlineTournamentTable {
  const OnlineTournamentTable({
    required this.tableID,
    required this.sessionID,
    required this.roundNumber,
    required this.tableNumber,
    required this.status,
    required this.playerID,
  });

  final String tableID;
  final String sessionID;
  final int roundNumber;
  final int tableNumber;
  final String status;
  final int playerID;

  factory OnlineTournamentTable.fromJson(Map<String, Object?> json) =>
      OnlineTournamentTable(
        tableID: json['tableID'] as String,
        sessionID: json['sessionID'] as String,
        roundNumber: json['roundNumber'] as int,
        tableNumber: json['tableNumber'] as int,
        status: json['status'] as String,
        playerID: json['playerID'] as int,
      );
}

class OnlineWeeklyTournament {
  const OnlineWeeklyTournament({
    required this.available,
    this.tournamentID,
    this.startsAt,
    this.joinOpensAt,
    this.joinClosesAt,
    this.status = 'unavailable',
    this.roundNumber = 0,
    this.totalRounds = 4,
    this.joined = false,
    this.forfeited = false,
    this.entrantCount = 0,
    this.standings = const [],
    this.table,
  });

  final bool available;
  final String? tournamentID;
  final double? startsAt;
  final double? joinOpensAt;
  final double? joinClosesAt;
  final String status;
  final int roundNumber;
  final int totalRounds;
  final bool joined;
  final bool forfeited;
  final int entrantCount;
  final List<OnlineTournamentStanding> standings;
  final OnlineTournamentTable? table;

  bool get enrollmentOpen {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    return status == 'enrollment' &&
        joinOpensAt != null &&
        joinClosesAt != null &&
        now >= joinOpensAt! &&
        now < joinClosesAt!;
  }

  factory OnlineWeeklyTournament.fromJson(Map<String, Object?> json) {
    final rawTable = json['table'];
    return OnlineWeeklyTournament(
      available: json['available'] as bool? ?? false,
      tournamentID: json['tournamentID'] as String?,
      startsAt: (json['startsAt'] as num?)?.toDouble(),
      joinOpensAt: (json['joinOpensAt'] as num?)?.toDouble(),
      joinClosesAt: (json['joinClosesAt'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'unavailable',
      roundNumber: json['roundNumber'] as int? ?? 0,
      totalRounds: json['totalRounds'] as int? ?? 4,
      joined: json['joined'] as bool? ?? false,
      forfeited: json['forfeited'] as bool? ?? false,
      entrantCount: json['entrantCount'] as int? ?? 0,
      standings: [
        for (final value in jsonList(json['standings'] ?? const []))
          OnlineTournamentStanding.fromJson(jsonObject(value)),
      ],
      table: rawTable is Map
          ? OnlineTournamentTable.fromJson(jsonObject(rawTable))
          : null,
    );
  }
}

class OnlineSessionListing {
  const OnlineSessionListing({
    required this.sessionID,
    this.inviteCode,
    required this.openSeats,
    required this.occupiedSeats,
    required this.controllers,
    required this.playerProfiles,
    this.ranked = true,
    this.browserJoinable = true,
    this.seatPresence = const [],
    this.turnPlayerID,
    this.turnDeadlineAt,
    this.started = true,
    this.lobbyCountdownEndsAt,
    required this.actionLogCount,
    required this.createdAt,
    required this.expiresAt,
  });

  final String sessionID;
  final String? inviteCode;
  final List<int> openSeats;
  final List<int> occupiedSeats;
  final List<KolkhozPlayerController> controllers;
  final List<OnlinePlayerProfile> playerProfiles;
  final bool ranked;
  final bool browserJoinable;
  final List<OnlineSeatPresence> seatPresence;
  final int? turnPlayerID;
  final double? turnDeadlineAt;
  final bool started;
  final double? lobbyCountdownEndsAt;
  final int actionLogCount;
  final double createdAt;
  final double expiresAt;

  String get shortID =>
      inviteCode ??
      (sessionID.length <= 8
          ? sessionID
          : sessionID.substring(0, 8).toUpperCase());

  int get connectedHumanSeatCount {
    bool isHumanSeat(int playerID) {
      return playerID >= 0 &&
          playerID < controllers.length &&
          controllers[playerID] == KolkhozPlayerController.human;
    }

    if (seatPresence.isNotEmpty) {
      return seatPresence
          .where(
            (presence) => presence.connected && isHumanSeat(presence.playerID),
          )
          .length;
    }
    return occupiedSeats.where(isHumanSeat).length;
  }

  static OnlineSessionListing fromJson(Map<String, Object?> json) {
    return OnlineSessionListing(
      sessionID: json['sessionID'] as String,
      inviteCode: json['inviteCode'] as String?,
      openSeats: _ints(json['openSeats']),
      occupiedSeats: _ints(json['occupiedSeats']),
      controllers: KolkhozPlayerController.normalized([
        for (final value in jsonList(json['controllers']))
          controllerFromJson(value),
      ]),
      playerProfiles: [
        for (final value in jsonList(json['playerProfiles'] ?? const []))
          OnlinePlayerProfile.fromJson(jsonObject(value)),
      ],
      ranked: json['ranked'] as bool? ?? true,
      browserJoinable: json['browserJoinable'] as bool? ?? true,
      seatPresence: [
        for (final value in jsonList(json['seatPresence'] ?? const []))
          OnlineSeatPresence.fromJson(jsonObject(value)),
      ],
      turnPlayerID: json['turnPlayerID'] as int?,
      turnDeadlineAt: (json['turnDeadlineAt'] as num?)?.toDouble(),
      started: json['started'] as bool? ?? true,
      lobbyCountdownEndsAt: (json['lobbyCountdownEndsAt'] as num?)?.toDouble(),
      actionLogCount: json['actionLogCount'] as int,
      createdAt: (json['createdAt'] as num).toDouble(),
      expiresAt: (json['expiresAt'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OnlineSessionInvite {
  const OnlineSessionInvite({
    required this.sessionID,
    required this.openSeats,
    required this.occupiedSeats,
    required this.controllers,
    required this.playerProfiles,
    required this.hostProfile,
    this.ranked = false,
    this.browserJoinable = false,
    this.started = false,
    this.lobbyCountdownEndsAt,
    required this.createdAt,
    required this.expiresAt,
  });

  final String sessionID;
  final List<int> openSeats;
  final List<int> occupiedSeats;
  final List<KolkhozPlayerController> controllers;
  final List<OnlinePlayerProfile> playerProfiles;
  final OnlinePlayerProfile? hostProfile;
  final bool ranked;
  final bool browserJoinable;
  final bool started;
  final double? lobbyCountdownEndsAt;
  final double createdAt;
  final double expiresAt;

  String get hostDisplayName {
    final trimmed = hostProfile?.displayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return 'Comrade';
  }

  static OnlineSessionInvite fromJson(Map<String, Object?> json) {
    final hostProfileJson = json['hostProfile'];
    return OnlineSessionInvite(
      sessionID: json['sessionID'] as String,
      openSeats: _ints(json['openSeats']),
      occupiedSeats: _ints(json['occupiedSeats']),
      controllers: KolkhozPlayerController.normalized([
        for (final value in jsonList(json['controllers']))
          controllerFromJson(value),
      ]),
      playerProfiles: [
        for (final value in jsonList(json['playerProfiles'] ?? const []))
          OnlinePlayerProfile.fromJson(jsonObject(value)),
      ],
      hostProfile: hostProfileJson is Map
          ? OnlinePlayerProfile.fromJson(jsonObject(hostProfileJson))
          : null,
      ranked: json['ranked'] as bool? ?? false,
      browserJoinable: json['browserJoinable'] as bool? ?? false,
      started: json['started'] as bool? ?? false,
      lobbyCountdownEndsAt: (json['lobbyCountdownEndsAt'] as num?)?.toDouble(),
      createdAt: (json['createdAt'] as num).toDouble(),
      expiresAt: (json['expiresAt'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OnlineServerStatus {
  const OnlineServerStatus({required this.citizensOnline});

  final int citizensOnline;

  static OnlineServerStatus fromJson(Map<String, Object?> json) {
    final service = jsonObject(json['service']);
    return OnlineServerStatus(
      citizensOnline: _nonNegativeInt(
        service['citizensOnline'] ?? service['activeSeats'],
      ),
    );
  }
}

List<int> _ints(Object? value) {
  return [for (final entry in jsonList(value)) entry as int];
}

int _nonNegativeInt(Object? value) {
  return value is int && value >= 0 ? value : 0;
}
