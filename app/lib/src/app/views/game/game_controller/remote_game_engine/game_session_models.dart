import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_serialization.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_state_models.dart';

class OnlineTournamentGameStatus {
  const OnlineTournamentGameStatus({
    required this.tournamentID,
    required this.roundNumber,
    required this.tableNumber,
    required this.totalRounds,
    required this.status,
  });

  final String tournamentID;
  final int roundNumber;
  final int tableNumber;
  final int totalRounds;
  final String status;

  factory OnlineTournamentGameStatus.fromJson(Map<String, Object?> json) =>
      OnlineTournamentGameStatus(
        tournamentID: json['tournamentID'] as String,
        roundNumber: json['roundNumber'] as int,
        tableNumber: json['tableNumber'] as int,
        totalRounds: json['totalRounds'] as int? ?? 4,
        status: json['status'] as String,
      );
}

class OnlineSessionUpdate {
  const OnlineSessionUpdate({
    required this.sessionID,
    this.seed,
    required this.inviteCode,
    required this.viewerID,
    required this.actionLogCount,
    required this.isViewerTurn,
    required this.legalActions,
    required this.variants,
    required this.controllers,
    required this.playerProfiles,
    this.ranked = true,
    this.browserJoinable = true,
    this.seatPresence = const [],
    this.turnPlayerID,
    this.turnDeadlineAt,
    this.started = true,
    this.lobbyCountdownEndsAt,
    this.gameLogActions = const [],
    this.reactions = const [],
    this.series,
    this.tournament,
    required this.snapshot,
  });

  final String sessionID;
  final int? seed;
  final String inviteCode;
  final int? viewerID;
  final int actionLogCount;
  final bool isViewerTurn;
  final List<OnlineEngineAction> legalActions;
  final KolkhozGameVariants variants;
  final List<KolkhozPlayerController> controllers;
  final List<OnlinePlayerProfile> playerProfiles;
  final bool ranked;
  final bool browserJoinable;
  final List<OnlineSeatPresence> seatPresence;
  final int? turnPlayerID;
  final double? turnDeadlineAt;
  final bool started;
  final double? lobbyCountdownEndsAt;
  final List<OnlineEngineAction> gameLogActions;
  final List<OnlineReaction> reactions;
  final OnlineSeriesStatus? series;
  final OnlineTournamentGameStatus? tournament;
  final OnlineEngineSnapshot snapshot;

  int? get lobbyCountdownSeconds {
    final deadline = lobbyCountdownEndsAt;
    if (deadline == null || started) {
      return null;
    }
    final remaining = deadline - DateTime.now().millisecondsSinceEpoch / 1000;
    return remaining.ceil().clamp(0, 30).toInt();
  }

  static OnlineSessionUpdate fromJson(Map<String, Object?> json) {
    return OnlineSessionUpdate(
      sessionID: json['sessionID'] as String,
      seed: json['seed'] as int?,
      inviteCode: json['inviteCode'] as String? ?? json['sessionID'] as String,
      viewerID: json['viewerID'] as int?,
      actionLogCount: json['actionLogCount'] as int,
      isViewerTurn: json['isViewerTurn'] as bool? ?? false,
      legalActions: [
        for (final value in jsonList(json['legalActions'] ?? const []))
          OnlineEngineAction.fromJson(jsonObject(value)),
      ],
      variants: variantsFromJson(jsonObject(json['variants'])),
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
      gameLogActions: [
        for (final value in jsonList(json['gameLogActions'] ?? const []))
          OnlineEngineAction.fromJson(jsonObject(value)),
      ],
      reactions: [
        for (final value in jsonList(json['reactions'] ?? const []))
          OnlineReaction.fromJson(jsonObject(value)),
      ],
      series: json['series'] is Map
          ? OnlineSeriesStatus.fromJson(jsonObject(json['series']))
          : null,
      tournament: json['tournament'] is Map
          ? OnlineTournamentGameStatus.fromJson(jsonObject(json['tournament']))
          : null,
      snapshot: OnlineEngineSnapshot.fromJson(jsonObject(json['snapshot'])),
    );
  }

  OnlineSessionUpdate copyWith({List<OnlineEngineAction>? legalActions}) {
    return OnlineSessionUpdate(
      sessionID: sessionID,
      seed: seed,
      inviteCode: inviteCode,
      viewerID: viewerID,
      actionLogCount: actionLogCount,
      isViewerTurn: isViewerTurn,
      legalActions: legalActions ?? this.legalActions,
      variants: variants,
      controllers: controllers,
      playerProfiles: playerProfiles,
      ranked: ranked,
      browserJoinable: browserJoinable,
      seatPresence: seatPresence,
      turnPlayerID: turnPlayerID,
      turnDeadlineAt: turnDeadlineAt,
      started: started,
      lobbyCountdownEndsAt: lobbyCountdownEndsAt,
      gameLogActions: gameLogActions,
      reactions: reactions,
      series: series,
      tournament: tournament,
      snapshot: snapshot,
    );
  }
}

class OnlineSeriesStatus {
  const OnlineSeriesStatus({
    required this.seriesID,
    required this.bestOf,
    required this.roundNumber,
    required this.completed,
    required this.winnerPlayerID,
    required this.wins,
  });
  final String seriesID;
  final int bestOf;
  final int roundNumber;
  final bool completed;
  final int? winnerPlayerID;
  final Map<int, int> wins;

  int winsFor(int playerID) => wins[playerID] ?? 0;

  factory OnlineSeriesStatus.fromJson(Map<String, Object?> json) {
    final rawWins = jsonObject(json['wins'] ?? const <String, Object?>{});
    return OnlineSeriesStatus(
      seriesID: json['seriesID'] as String,
      bestOf: json['bestOf'] as int,
      roundNumber: json['roundNumber'] as int,
      completed: json['completed'] as bool? ?? false,
      winnerPlayerID: json['winnerPlayerID'] as int?,
      wins: {
        for (final entry in rawWins.entries)
          ?int.tryParse(entry.key): entry.value as int,
      },
    );
  }
}

class OnlineReaction {
  const OnlineReaction({
    required this.revision,
    required this.playerID,
    required this.reactionID,
    required this.year,
    required this.phase,
    required this.createdAt,
  });

  final int revision;
  final int playerID;
  final String reactionID;
  final int year;
  final int phase;
  final double createdAt;

  static OnlineReaction fromJson(Map<String, Object?> json) {
    return OnlineReaction(
      revision: json['revision'] as int,
      playerID: json['playerID'] as int,
      reactionID: json['reactionID'] as String,
      year: json['year'] as int,
      phase: json['phase'] as int,
      createdAt: (json['createdAt'] as num).toDouble(),
    );
  }
}

class OnlineSeatPresence {
  const OnlineSeatPresence({
    required this.playerID,
    required this.connected,
    required this.lastSeenAt,
    required this.timeouts,
    required this.autopilot,
    required this.abandoned,
  });

  final int playerID;
  final bool connected;
  final double? lastSeenAt;
  final int timeouts;
  final bool autopilot;
  final bool abandoned;

  static OnlineSeatPresence fromJson(Map<String, Object?> json) {
    return OnlineSeatPresence(
      playerID: json['playerID'] as int,
      connected: json['connected'] as bool? ?? false,
      lastSeenAt: (json['lastSeenAt'] as num?)?.toDouble(),
      timeouts: json['timeouts'] as int? ?? 0,
      autopilot: json['autopilot'] as bool? ?? false,
      abandoned: json['abandoned'] as bool? ?? false,
    );
  }
}

class OnlineSessionResponse {
  const OnlineSessionResponse({
    required this.sessionID,
    required this.inviteCode,
    required this.playerID,
    required this.seatToken,
    required this.update,
  });

  final String sessionID;
  final String inviteCode;
  final int playerID;
  final String seatToken;
  final OnlineSessionUpdate update;

  static OnlineSessionResponse fromJson(Map<String, Object?> json) {
    return OnlineSessionResponse(
      sessionID: json['sessionID'] as String,
      inviteCode: json['inviteCode'] as String? ?? json['sessionID'] as String,
      playerID: json['playerID'] as int,
      seatToken: json['seatToken'] as String,
      update: OnlineSessionUpdate.fromJson(jsonObject(json['update'])),
    );
  }
}

class OnlineActionUpdate {
  const OnlineActionUpdate({
    required this.revision,
    required this.action,
    required this.update,
  });

  final int revision;
  final OnlineEngineAction action;
  final OnlineSessionUpdate update;

  static OnlineActionUpdate fromJson(Map<String, Object?> json) {
    return OnlineActionUpdate(
      revision: json['revision'] as int,
      action: OnlineEngineAction.fromJson(jsonObject(json['action'])),
      update: OnlineSessionUpdate.fromJson(jsonObject(json['update'])),
    );
  }
}

class OnlineActionUpdatesResponse {
  const OnlineActionUpdatesResponse({
    required this.sessionID,
    required this.actionLogCount,
    required this.updates,
    this.resyncUpdate,
  });

  final String sessionID;
  final int actionLogCount;
  final List<OnlineActionUpdate> updates;
  final OnlineSessionUpdate? resyncUpdate;

  static OnlineActionUpdatesResponse fromJson(Map<String, Object?> json) {
    return OnlineActionUpdatesResponse(
      sessionID: json['sessionID'] as String,
      actionLogCount: json['actionLogCount'] as int,
      updates: [
        for (final value in jsonList(json['updates'] ?? const []))
          OnlineActionUpdate.fromJson(jsonObject(value)),
      ],
      resyncUpdate: json['resyncUpdate'] == null
          ? null
          : OnlineSessionUpdate.fromJson(jsonObject(json['resyncUpdate'])),
    );
  }
}
