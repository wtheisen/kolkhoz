import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/saved_game_store.dart';

const terminalGameRecordSchema = 'kolkhoz.terminal-game';
const terminalGameRecordVersion = 1;

class GameBuildIdentity {
  const GameBuildIdentity({
    required this.engine,
    required this.appVersion,
    required this.appBuild,
  });

  static const current = GameBuildIdentity(
    engine: 'KolkhozCEngine',
    appVersion: String.fromEnvironment(
      'KOLKHOZ_APP_VERSION',
      defaultValue: '1.0.0',
    ),
    appBuild: String.fromEnvironment('KOLKHOZ_APP_BUILD', defaultValue: '13'),
  );

  final String engine;
  final String appVersion;
  final String appBuild;

  Map<String, Object?> toJson() => {
    'engine': engine,
    'appVersion': appVersion,
    'appBuild': appBuild,
  };

  factory GameBuildIdentity.fromJson(Map<String, Object?> json) {
    return GameBuildIdentity(
      engine: json['engine'] as String,
      appVersion: json['appVersion'] as String,
      appBuild: json['appBuild'] as String,
    );
  }
}

class TerminalGameParticipant {
  const TerminalGameParticipant({
    required this.seatID,
    required this.name,
    required this.controller,
    this.userID,
  });

  final int seatID;
  final String name;
  final KolkhozPlayerController controller;
  final String? userID;

  Map<String, Object?> toJson() => {
    'seatID': seatID,
    'name': name,
    'controller': controller.name,
    if (userID != null) 'userID': userID,
  };

  factory TerminalGameParticipant.fromJson(Map<String, Object?> json) {
    return TerminalGameParticipant(
      seatID: json['seatID'] as int,
      name: json['name'] as String,
      controller: controllerFromJson(json['controller']),
      userID: json['userID'] as String?,
    );
  }
}

class TerminalGameScore {
  const TerminalGameScore({required this.seatID, required this.score});

  final int seatID;
  final int score;

  Map<String, Object?> toJson() => {'seatID': seatID, 'score': score};

  factory TerminalGameScore.fromJson(Map<String, Object?> json) {
    return TerminalGameScore(
      seatID: json['seatID'] as int,
      score: json['score'] as int,
    );
  }
}

class TerminalGameResult {
  TerminalGameResult({
    required this.winnerSeatID,
    required List<TerminalGameScore> scores,
  }) : scores = List.unmodifiable(scores);

  factory TerminalGameResult.fromTableResult(GameResult result) {
    return TerminalGameResult(
      winnerSeatID: result.winnerSeatID,
      scores: [
        for (final score in result.scores)
          TerminalGameScore(
            seatID: score.seatID,
            score: score.finalScore ?? score.visibleScore,
          ),
      ],
    );
  }

  final int winnerSeatID;
  final List<TerminalGameScore> scores;

  Map<String, Object?> toJson() => {
    'winnerSeatID': winnerSeatID,
    'scores': scores.map((score) => score.toJson()).toList(),
  };

  factory TerminalGameResult.fromJson(Map<String, Object?> json) {
    return TerminalGameResult(
      winnerSeatID: json['winnerSeatID'] as int,
      scores: [
        for (final value in jsonList(json['scores']))
          TerminalGameScore.fromJson(jsonObject(value)),
      ],
    );
  }
}

/// Portable, authoritative record captured before a match engine is disposed.
///
/// The action stream is the replay source of truth. The terminal result is
/// stored independently so a replay can be validated without reconstructing a
/// Flutter presentation model.
class TerminalGameRecord {
  TerminalGameRecord({
    this.schemaVersion = terminalGameRecordVersion,
    this.build = GameBuildIdentity.current,
    required this.seed,
    required this.variants,
    required List<KolkhozPlayerController> controllers,
    required List<TerminalGameParticipant> participants,
    required List<EngineAction> actions,
    required this.result,
  }) : controllers = List.unmodifiable(controllers),
       participants = List.unmodifiable(participants),
       actions = List.unmodifiable(actions) {
    if (schemaVersion != terminalGameRecordVersion) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    if (this.controllers.length != 4 || this.participants.length != 4) {
      throw ArgumentError('A terminal record must contain exactly four seats');
    }
    if (result.scores.length != 4) {
      throw ArgumentError('A terminal record must contain four final scores');
    }
    for (var seatID = 0; seatID < 4; seatID += 1) {
      final participant = this.participants.singleWhere(
        (participant) => participant.seatID == seatID,
        orElse: () => throw ArgumentError('Missing participant seat $seatID'),
      );
      if (participant.controller != this.controllers[seatID]) {
        throw ArgumentError('Controller mismatch for participant seat $seatID');
      }
      if (!result.scores.any((score) => score.seatID == seatID)) {
        throw ArgumentError('Missing final score for seat $seatID');
      }
    }
    if (result.winnerSeatID < 0 || result.winnerSeatID >= 4) {
      throw ArgumentError.value(result.winnerSeatID, 'winnerSeatID');
    }
  }

  final int schemaVersion;
  final GameBuildIdentity build;
  final int seed;
  final KolkhozGameVariants variants;
  final List<KolkhozPlayerController> controllers;
  final List<TerminalGameParticipant> participants;
  final List<EngineAction> actions;
  final TerminalGameResult result;

  Map<String, Object?> toJson() => {
    'schema': terminalGameRecordSchema,
    'schemaVersion': schemaVersion,
    'build': build.toJson(),
    'seed': seed,
    'variants': variantsToJson(variants),
    'controllers': controllers.map((controller) => controller.name).toList(),
    'participants': participants.map((player) => player.toJson()).toList(),
    'actions': actions.map(engineActionToJson).toList(),
    'result': result.toJson(),
  };

  factory TerminalGameRecord.fromJson(Map<String, Object?> json) {
    if (json['schema'] != terminalGameRecordSchema ||
        json['schemaVersion'] != terminalGameRecordVersion) {
      throw const FormatException('Unsupported terminal game record');
    }
    return TerminalGameRecord(
      schemaVersion: json['schemaVersion'] as int,
      build: GameBuildIdentity.fromJson(jsonObject(json['build'])),
      seed: json['seed'] as int,
      variants: variantsFromJson(jsonObject(json['variants'])),
      controllers: [
        for (final value in jsonList(json['controllers']))
          controllerFromJson(value),
      ],
      participants: [
        for (final value in jsonList(json['participants']))
          TerminalGameParticipant.fromJson(jsonObject(value)),
      ],
      actions: [
        for (final value in jsonList(json['actions']))
          engineActionFromJson(jsonObject(value)),
      ],
      result: TerminalGameResult.fromJson(jsonObject(json['result'])),
    );
  }
}
