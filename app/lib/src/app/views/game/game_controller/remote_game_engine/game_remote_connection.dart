import 'dart:convert';
import 'dart:io';

import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_state_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_serialization.dart';
import '../../../../remote_connection/remote_connection.dart';

class GameRemoteConnection {
  const GameRemoteConnection(this._remote);

  final RemoteConnection _remote;

  Future<OnlineSessionUpdate> fetchSpectatorUpdate(String sessionID) async {
    final json = await _requestJson(
      method: 'GET',
      path: 'sessions/$sessionID/spectate',
    );
    return OnlineSessionUpdate.fromJson(json);
  }

  Future<OnlineSessionResponse> syncActiveSession() async {
    final decoded = await _send(method: 'POST', path: 'active-session/sync');
    return OnlineSessionResponse.fromJson(jsonObject(decoded));
  }

  Future<OnlineSessionResponse> createRematch(String sessionID) async {
    final json = await _requestJson(
      method: 'POST',
      path: 'results/$sessionID/rematch',
    );
    return OnlineSessionResponse.fromJson(json);
  }

  Future<OnlineSessionResponse> startDailyChallenge() async {
    final json = await _requestJson(
      method: 'POST',
      path: 'challenges/daily/start',
    );
    return OnlineSessionResponse.fromJson(json);
  }

  Future<OnlineSessionResponse> createSession({
    int? seed,
    required KolkhozGameVariants variants,
    required List<KolkhozPlayerController> controllers,
    bool ranked = false,
    bool browserJoinable = true,
    int bestOf = 1,
  }) async {
    final body = <String, Object?>{
      'variants': variantsToJson(variants),
      'controllers': controllers.map((controller) => controller.name).toList(),
      'ranked': ranked,
      'browserJoinable': browserJoinable,
      'bestOf': bestOf,
    };
    if (seed != null) {
      body['seed'] = seed;
    }
    final json = await _requestJson(
      method: 'POST',
      path: 'sessions',
      body: body,
    );
    return OnlineSessionResponse.fromJson(json);
  }

  Future<OnlineSessionResponse> joinSession({
    required String sessionID,
    int? preferredPlayerID,
  }) async {
    final body = <String, Object?>{'sessionID': sessionID};
    if (preferredPlayerID != null) {
      body['preferredPlayerID'] = preferredPlayerID;
    }
    final json = await _requestJson(
      method: 'POST',
      path: 'sessions/$sessionID/join',
      body: body,
    );
    return OnlineSessionResponse.fromJson(json);
  }

  Future<OnlineSessionResponse> matchmakeSession({
    bool rankedOnly = false,
    bool comradesOnly = false,
  }) async {
    final json = await _requestJson(
      method: 'POST',
      path: 'sessions/matchmake',
      body: {'rankedOnly': rankedOnly, 'comradesOnly': comradesOnly},
    );
    return OnlineSessionResponse.fromJson(json);
  }

  Future<OnlineSessionUpdate> kickSessionPlayer({
    required String sessionID,
    required int hostPlayerID,
    required int targetPlayerID,
    required String seatToken,
  }) async {
    final json = await _requestJson(
      method: 'POST',
      path: 'sessions/$sessionID/players/$targetPlayerID/kick',
      headers: {remoteSeatTokenHeader: seatToken},
      body: {'hostPlayerID': hostPlayerID},
    );
    return OnlineSessionUpdate.fromJson(jsonObject(json['update']));
  }

  Future<OnlineSessionUpdate> fetchUpdate({
    required String sessionID,
    required int playerID,
    required String seatToken,
  }) async {
    final json = await _requestJson(
      method: 'GET',
      path: 'sessions/$sessionID/state',
      query: {'viewerID': '$playerID'},
      headers: {remoteSeatTokenHeader: seatToken},
    );
    return OnlineSessionUpdate.fromJson(json);
  }

  Future<OnlineActionUpdatesResponse> fetchActionUpdates({
    required String sessionID,
    required int playerID,
    required String seatToken,
    required int afterRevision,
  }) async {
    final json = await _requestJson(
      method: 'GET',
      path: 'sessions/$sessionID/actions',
      query: {'viewerID': '$playerID', 'afterRevision': '$afterRevision'},
      headers: {remoteSeatTokenHeader: seatToken},
    );
    return OnlineActionUpdatesResponse.fromJson(json);
  }

  Future<List<OnlineEngineAction>> fetchLegalActions({
    required String sessionID,
    required int playerID,
    required String seatToken,
  }) async {
    final decoded = await _send(
      method: 'GET',
      path: 'sessions/$sessionID/players/$playerID/actions',
      headers: {remoteSeatTokenHeader: seatToken},
    );
    return [
      for (final value in jsonList(decoded))
        OnlineEngineAction.fromJson(jsonObject(value)),
    ];
  }

  Future<OnlineSessionUpdate> submitAction({
    required String sessionID,
    required int playerID,
    required String seatToken,
    required int actionLogCount,
    required EngineAction action,
  }) async {
    final json = await _requestJson(
      method: 'POST',
      path: 'sessions/$sessionID/actions',
      headers: {remoteSeatTokenHeader: seatToken},
      body: {
        'sessionID': sessionID,
        'playerID': playerID,
        'actionLogCount': actionLogCount,
        'action': OnlineEngineAction.fromEngineAction(action).toJson(),
      },
    );
    return OnlineSessionUpdate.fromJson(json);
  }

  Future<OnlineSessionUpdate> submitReaction({
    required String sessionID,
    required int playerID,
    required String seatToken,
    required String reactionID,
  }) async {
    final json = await _requestJson(
      method: 'POST',
      path: 'sessions/$sessionID/reactions',
      headers: {remoteSeatTokenHeader: seatToken},
      body: {'playerID': playerID, 'reactionID': reactionID},
    );
    return OnlineSessionUpdate.fromJson(json);
  }

  Future<OnlineSessionUpdate> leaveSession({
    required String sessionID,
    required int playerID,
    required String seatToken,
  }) async {
    final json = await _requestJson(
      method: 'POST',
      path: 'sessions/$sessionID/players/$playerID/leave',
      headers: {remoteSeatTokenHeader: seatToken},
      body: {'sessionID': sessionID, 'playerID': playerID},
    );
    return OnlineSessionUpdate.fromJson(jsonObject(json['update']));
  }

  Uri realtimeURI({
    required String sessionID,
    required int playerID,
    required int afterRevision,
  }) {
    final uri = _remote.resolve('sessions/$sessionID/realtime', {
      'viewerID': '$playerID',
      'afterRevision': '$afterRevision',
    });
    return uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws');
  }

  Future<WebSocket> connectRealtime({
    required String sessionID,
    required int playerID,
    required String seatToken,
    required int afterRevision,
  }) async {
    return _remote.openSocket(
      path: 'sessions/$sessionID/realtime',
      query: {'viewerID': '$playerID', 'afterRevision': '$afterRevision'},
      headers: {remoteSeatTokenHeader: seatToken},
    );
  }

  Future<Map<String, Object?>> _requestJson({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    final decoded = await _send(
      method: method,
      path: path,
      query: query,
      headers: headers,
      body: body,
    );
    return jsonObject(decoded);
  }

  Future<Object?> _send({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    return _remote.request(
      method: method,
      path: path,
      query: query,
      headers: headers,
      body: body,
    );
  }
}

class OnlineRealtimeFrame {
  const OnlineRealtimeFrame({
    required this.type,
    this.revision,
    this.update,
    this.updates,
  });

  final String type;
  final int? revision;
  final OnlineSessionUpdate? update;
  final OnlineActionUpdatesResponse? updates;

  static OnlineRealtimeFrame fromJson(Map<String, Object?> json) {
    final type = json['type'] as String;
    return OnlineRealtimeFrame(
      type: type,
      revision: (json['revision'] as num?)?.toInt(),
      update: type == 'state'
          ? OnlineSessionUpdate.fromJson(jsonObject(json['update']))
          : null,
      updates: type == 'catchUp' || type == 'committed'
          ? OnlineActionUpdatesResponse.fromJson(jsonObject(json['updates']))
          : null,
    );
  }

  static OnlineRealtimeFrame decode(Object? data) {
    final text = switch (data) {
      String value => value,
      List<int> value => utf8.decode(value),
      _ => null,
    };
    if (text == null) {
      throw const FormatException('Online realtime frame must be text');
    }
    return fromJson(jsonObject(jsonDecode(text)));
  }
}
