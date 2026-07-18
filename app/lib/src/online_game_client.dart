import 'dart:convert';
import 'dart:io';

import 'c_engine_bridge.dart';
import 'online_game_models.dart';
import 'render_model.dart';
import 'saved_game_store.dart';

typedef OnlineWebSocketConnector =
    Future<WebSocket> Function(Uri uri, Map<String, dynamic> headers);

class KolkhozOnlineClient {
  KolkhozOnlineClient(
    this.baseURL, {
    HttpClient? httpClient,
    OnlineWebSocketConnector? webSocketConnector,
    this.accessTokenProvider,
    this.deviceID,
  }) : _httpClient = httpClient ?? HttpClient(),
       _webSocketConnector = webSocketConnector ?? _connectWebSocket;

  final Uri baseURL;
  final Future<String?> Function()? accessTokenProvider;
  final String? deviceID;
  final HttpClient _httpClient;
  final OnlineWebSocketConnector _webSocketConnector;

  static Future<WebSocket> _connectWebSocket(
    Uri uri,
    Map<String, dynamic> headers,
  ) => WebSocket.connect(uri.toString(), headers: headers);

  Future<List<OnlineSessionListing>> fetchSessions() async {
    final decoded = await _send(method: 'GET', path: 'sessions');
    return [
      for (final value in onlineObjectList(decoded))
        OnlineSessionListing.fromJson(onlineObjectMap(value)),
    ];
  }

  Future<List<OnlineSessionListing>> fetchWatchableSessions() async {
    final decoded = await _send(method: 'GET', path: 'sessions/watchable');
    return [
      for (final value in onlineObjectList(decoded))
        OnlineSessionListing.fromJson(onlineObjectMap(value)),
    ];
  }

  Future<OnlineSessionUpdate> fetchSpectatorUpdate(String sessionID) async {
    final json = await _sendJson(
      method: 'GET',
      path: 'sessions/$sessionID/spectate',
    );
    return OnlineSessionUpdate.fromJson(json);
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

  Future<Map<String, Object?>> fetchAdminOperations() async {
    return _sendJson(method: 'GET', path: 'admin/operations');
  }

  Future<void> restartProductionServer() async {
    await _sendJson(
      method: 'POST',
      path: 'admin/control/restart',
      headers: {'X-Kolkhoz-Restart-Confirm': 'restart'},
    );
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

  Future<void> registerInstallation({
    required String installationID,
    required String platform,
    required String token,
  }) async {
    await _sendJson(
      method: 'PUT',
      path: 'installations/$installationID',
      body: {
        'platform': platform,
        'token': token,
        'preferences': {
          'social': true,
          'invites': true,
          'turns': true,
          'results': true,
        },
      },
    );
  }

  Future<void> deleteInstallation(String installationID) async {
    await _send(method: 'DELETE', path: 'installations/$installationID');
  }

  Future<void> deleteAccount() async {
    await _send(method: 'DELETE', path: 'account');
  }

  Future<bool> fetchFullGameEntitlement() async {
    final json = await _sendJson(method: 'GET', path: 'commerce/entitlements');
    return json['fullGame'] as bool? ?? false;
  }

  Future<bool> claimFullGamePurchase({
    required String provider,
    required String verificationData,
  }) async {
    final json = await _sendJson(
      method: 'POST',
      path: 'commerce/purchases/claim',
      body: {'provider': provider, 'verificationData': verificationData},
    );
    return json['fullGame'] as bool? ?? false;
  }

  Future<OnlineSessionResponse> syncActiveSession() async {
    final decoded = await _send(method: 'POST', path: 'active-session/sync');
    return OnlineSessionResponse.fromJson(onlineObjectMap(decoded));
  }

  Future<OnlineComradesResponse> fetchComrades() async {
    final decoded = await _send(method: 'GET', path: 'comrades');
    return OnlineComradesResponse.fromJson(onlineObjectMap(decoded));
  }

  Future<List<OnlineComradeProfile>> fetchLeaderboard() async {
    final json = await _sendJson(method: 'GET', path: 'leaderboard');
    return [
      for (final value in onlineObjectList(json['players'] ?? const []))
        OnlineComradeProfile.fromJson(onlineObjectMap(value)),
    ];
  }

  Future<List<OnlineRecentGame>> fetchRecentGames() async {
    final json = await _sendJson(method: 'GET', path: 'results/recent');
    return [
      for (final value in onlineObjectList(json['games'] ?? const []))
        OnlineRecentGame.fromJson(onlineObjectMap(value)),
    ];
  }

  Future<OnlineGameReplay> fetchReplay(String sessionID) async {
    final json = await _sendJson(
      method: 'GET',
      path: 'results/$sessionID/replay',
    );
    return OnlineGameReplay.fromJson(json);
  }

  Future<OnlineSessionResponse> createRematch(String sessionID) async {
    final json = await _sendJson(
      method: 'POST',
      path: 'results/$sessionID/rematch',
    );
    return OnlineSessionResponse.fromJson(json);
  }

  Future<OnlineDailyChallenge> fetchDailyChallenge() async {
    final json = await _sendJson(method: 'GET', path: 'challenges/daily');
    return OnlineDailyChallenge.fromJson(json);
  }

  Future<OnlineSessionResponse> startDailyChallenge() async {
    final json = await _sendJson(
      method: 'POST',
      path: 'challenges/daily/start',
    );
    return OnlineSessionResponse.fromJson(json);
  }

  Future<OnlineWeeklyTournament> fetchWeeklyTournament() async {
    final json = await _sendJson(method: 'GET', path: 'tournaments/weekly');
    return OnlineWeeklyTournament.fromJson(json);
  }

  Future<OnlineWeeklyTournament> joinWeeklyTournament() async {
    final json = await _sendJson(
      method: 'POST',
      path: 'tournaments/weekly/join',
    );
    return OnlineWeeklyTournament.fromJson(json);
  }

  Future<OnlineWeeklyTournament> leaveWeeklyTournament() async {
    final json = await _sendJson(
      method: 'POST',
      path: 'tournaments/weekly/leave',
    );
    return OnlineWeeklyTournament.fromJson(json);
  }

  Future<OnlineComradeProfile> fetchPublicProfile(String userID) async {
    final decoded = await _send(method: 'GET', path: 'profiles/$userID');
    return OnlineComradeProfile.fromJson(onlineObjectMap(decoded));
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

  Uri realtimeURI({
    required String sessionID,
    required int playerID,
    required int afterRevision,
  }) {
    final uri = _resolve('sessions/$sessionID/realtime', {
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
    final accessToken = await accessTokenProvider?.call();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Online realtime requires an access token');
    }
    return _webSocketConnector(
      realtimeURI(
        sessionID: sessionID,
        playerID: playerID,
        afterRevision: afterRevision,
      ),
      {
        HttpHeaders.authorizationHeader: 'Bearer $accessToken',
        _seatTokenHeader: seatToken,
      },
    );
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
          ? OnlineSessionUpdate.fromJson(onlineObjectMap(json['update']))
          : null,
      updates: type == 'catchUp' || type == 'committed'
          ? OnlineActionUpdatesResponse.fromJson(
              onlineObjectMap(json['updates']),
            )
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
    return fromJson(onlineObjectMap(jsonDecode(text)));
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
