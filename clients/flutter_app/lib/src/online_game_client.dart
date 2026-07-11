import 'dart:convert';
import 'dart:io';

import 'c_engine_bridge.dart';
import 'online_game_models.dart';
import 'render_model.dart';
import 'saved_game_store.dart';

class KolkhozOnlineClient {
  KolkhozOnlineClient(
    this.baseURL, {
    HttpClient? httpClient,
    this.accessTokenProvider,
    this.deviceID,
  }) : _httpClient = httpClient ?? HttpClient();

  final Uri baseURL;
  final Future<String?> Function()? accessTokenProvider;
  final String? deviceID;
  final HttpClient _httpClient;

  Future<List<OnlineSessionListing>> fetchSessions() async {
    final decoded = await _send(method: 'GET', path: 'sessions');
    return [
      for (final value in onlineObjectList(decoded))
        OnlineSessionListing.fromJson(onlineObjectMap(value)),
    ];
  }

  Future<OnlineSessionListing> fetchSession(String sessionID) async {
    final decoded = await _send(method: 'GET', path: 'sessions/$sessionID');
    return OnlineSessionListing.fromJson(onlineObjectMap(decoded));
  }

  Future<List<OnlineSessionInvite>> fetchSessionInvites() async {
    final decoded = await _send(method: 'GET', path: 'sessions/invites');
    return [
      for (final value in onlineObjectList(decoded))
        OnlineSessionInvite.fromJson(onlineObjectMap(value)),
    ];
  }

  Future<OnlineServerStatus> fetchServerStatus() async {
    final decoded = await _send(method: 'GET', path: 'metrics');
    return OnlineServerStatus.fromJson(onlineObjectMap(decoded));
  }

  Future<OnlinePresenceHeartbeat> sendPresenceHeartbeat({
    String? sessionID,
  }) async {
    final decoded = await _send(
      method: 'POST',
      path: 'presence',
      body: {'sessionID': ?sessionID},
    );
    return OnlinePresenceHeartbeat.fromJson(onlineObjectMap(decoded));
  }

  Future<OnlineSessionResponse> syncActiveSession() async {
    final decoded = await _send(method: 'POST', path: 'active-session/sync');
    return OnlineSessionResponse.fromJson(onlineObjectMap(decoded));
  }

  Future<OnlineComradesResponse> fetchComrades() async {
    final decoded = await _send(method: 'GET', path: 'comrades');
    return OnlineComradesResponse.fromJson(onlineObjectMap(decoded));
  }

  Future<OnlineComradeProfile> sendComradeRequest(String comradeCode) async {
    final json = await _sendJson(
      method: 'POST',
      path: 'comrades',
      body: {'comradeCode': comradeCode},
    );
    return OnlineComradeProfile.fromJson(
      onlineObjectMap(json['request'] ?? json['comrade']),
    );
  }

  Future<OnlineComradeProfile> sendComradeRequestToUser(String userID) async {
    final json = await _sendJson(
      method: 'POST',
      path: 'comrades',
      body: {'userID': userID},
    );
    return OnlineComradeProfile.fromJson(
      onlineObjectMap(json['request'] ?? json['comrade']),
    );
  }

  Future<OnlineComradeProfile> addComrade(String comradeCode) {
    return sendComradeRequest(comradeCode);
  }

  Future<void> respondToComradeRequest({
    required String userID,
    required bool accept,
  }) async {
    await _sendJson(
      method: 'POST',
      path: 'comrades/respond',
      body: {'userID': userID, 'accept': accept},
    );
  }

  Future<void> removeComrade(String userID) async {
    await _sendJson(
      method: 'POST',
      path: 'comrades/remove',
      body: {'userID': userID},
    );
  }

  Future<OnlineSessionResponse> createSession({
    int? seed,
    required KolkhozGameVariants variants,
    required List<KolkhozPlayerController> controllers,
    bool ranked = false,
    bool browserJoinable = true,
  }) async {
    final body = <String, Object?>{
      'variants': variantsToJson(variants),
      'controllers': controllers.map((controller) => controller.name).toList(),
      'ranked': ranked,
      'browserJoinable': browserJoinable,
    };
    if (seed != null) {
      body['seed'] = seed;
    }
    final json = await _sendJson(method: 'POST', path: 'sessions', body: body);
    return OnlineSessionResponse.fromJson(json);
  }

  Future<void> inviteSessionComrades({
    required String sessionID,
    required List<String> userIDs,
  }) async {
    await _sendJson(
      method: 'POST',
      path: 'sessions/$sessionID/invites',
      body: {'userIDs': userIDs},
    );
  }

  Future<void> declineSessionInvite(String sessionID) async {
    await _sendJson(
      method: 'POST',
      path: 'sessions/$sessionID/invites/decline',
      body: {'sessionID': sessionID},
    );
  }

  Future<OnlineSessionResponse> joinSession({
    required String sessionID,
    int? preferredPlayerID,
  }) async {
    final body = <String, Object?>{'sessionID': sessionID};
    if (preferredPlayerID != null) {
      body['preferredPlayerID'] = preferredPlayerID;
    }
    final json = await _sendJson(
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
    final json = await _sendJson(
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
    final json = await _sendJson(
      method: 'POST',
      path: 'sessions/$sessionID/players/$targetPlayerID/kick',
      headers: {_seatTokenHeader: seatToken},
      body: {'hostPlayerID': hostPlayerID},
    );
    return OnlineSessionUpdate.fromJson(onlineObjectMap(json['update']));
  }

  Future<OnlineSessionUpdate> fetchUpdate({
    required String sessionID,
    required int playerID,
    required String seatToken,
  }) async {
    final json = await _sendJson(
      method: 'GET',
      path: 'sessions/$sessionID/state',
      query: {'viewerID': '$playerID'},
      headers: {_seatTokenHeader: seatToken},
    );
    return OnlineSessionUpdate.fromJson(json);
  }

  Future<OnlineActionUpdatesResponse> fetchActionUpdates({
    required String sessionID,
    required int playerID,
    required String seatToken,
    required int afterRevision,
  }) async {
    final json = await _sendJson(
      method: 'GET',
      path: 'sessions/$sessionID/actions',
      query: {'viewerID': '$playerID', 'afterRevision': '$afterRevision'},
      headers: {_seatTokenHeader: seatToken},
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
      headers: {_seatTokenHeader: seatToken},
    );
    return [
      for (final value in onlineObjectList(decoded))
        OnlineEngineAction.fromJson(onlineObjectMap(value)),
    ];
  }

  Future<OnlineSessionUpdate> submitAction({
    required String sessionID,
    required int playerID,
    required String seatToken,
    required int actionLogCount,
    required EngineAction action,
  }) async {
    final json = await _sendJson(
      method: 'POST',
      path: 'sessions/$sessionID/actions',
      headers: {_seatTokenHeader: seatToken},
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
    final json = await _sendJson(
      method: 'POST',
      path: 'sessions/$sessionID/reactions',
      headers: {_seatTokenHeader: seatToken},
      body: {'playerID': playerID, 'reactionID': reactionID},
    );
    return OnlineSessionUpdate.fromJson(json);
  }

  Future<OnlineSessionUpdate> leaveSession({
    required String sessionID,
    required int playerID,
    required String seatToken,
  }) async {
    final json = await _sendJson(
      method: 'POST',
      path: 'sessions/$sessionID/players/$playerID/leave',
      headers: {_seatTokenHeader: seatToken},
      body: {'sessionID': sessionID, 'playerID': playerID},
    );
    return OnlineSessionUpdate.fromJson(onlineObjectMap(json['update']));
  }

  Future<Map<String, Object?>> _sendJson({
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
    return onlineObjectMap(decoded);
  }

  Future<Object?> _send({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    final uri = _resolve(path, query);
    final request = await _httpClient.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (deviceID != null && deviceID!.isNotEmpty) {
      request.headers.set('X-Kolkhoz-Device-ID', deviceID!);
    }
    final accessToken = await accessTokenProvider?.call();
    if (accessToken != null && accessToken.isNotEmpty) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
    }
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    if (body != null) {
      final encodedBody = utf8.encode(jsonEncode(body));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.contentLength = encodedBody.length;
      request.add(encodedBody);
    }
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OnlineRequestException(
        statusCode: response.statusCode,
        uri: uri,
        responseBody: responseBody,
        sentAuthorization: accessToken != null && accessToken.isNotEmpty,
      );
    }
    return responseBody.isEmpty ? null : jsonDecode(responseBody);
  }

  Uri _resolve(String path, Map<String, String> query) {
    final normalizedBase = baseURL.path.endsWith('/')
        ? baseURL
        : baseURL.replace(path: '${baseURL.path}/');
    final resolved = normalizedBase.resolve(path);
    if (query.isEmpty) {
      return resolved;
    }
    return resolved.replace(queryParameters: query);
  }
}

class OnlineRequestException implements Exception {
  const OnlineRequestException({
    required this.statusCode,
    required this.uri,
    required this.responseBody,
    required this.sentAuthorization,
  });

  final int statusCode;
  final Uri uri;
  final String responseBody;
  final bool sentAuthorization;

  String get message {
    final parsed = _serverError(responseBody);
    if (parsed.isNotEmpty) {
      return parsed;
    }
    return responseBody.isEmpty ? 'Online request failed' : responseBody;
  }

  @override
  String toString() {
    final auth = sentAuthorization ? 'sent' : 'missing';
    return 'OnlineRequestException: $message '
        '(status $statusCode, auth $auth), uri = $uri';
  }
}

const _seatTokenHeader = 'X-Kolkhoz-Seat-Token';

String _serverError(String responseBody) {
  if (responseBody.isEmpty) {
    return '';
  }
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is Map<String, Object?>) {
      final error = decoded['error'];
      if (error is String) {
        return error;
      }
    }
  } catch (_) {
    return '';
  }
  return '';
}
