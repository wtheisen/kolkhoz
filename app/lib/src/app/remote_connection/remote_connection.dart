import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'remote_error.dart';
import 'remote_status.dart';

const defaultRemoteHeartbeatInterval = Duration(seconds: 15);
const remoteSeatTokenHeader = 'X-Kolkhoz-Seat-Token';

typedef RemoteWebSocketConnector =
    Future<WebSocket> Function(Uri uri, Map<String, dynamic> headers);
typedef RemoteRequestHandler =
    Future<Object?> Function(
      String method,
      String path,
      Map<String, String> query,
      Map<String, String> headers,
      Object? body,
    );

class RemoteConnection extends ChangeNotifier {
  RemoteConnection({
    required this.baseURL,
    required this.accessTokenProvider,
    required this.deviceID,
    required this.activeSessionID,
    HttpClient? httpClient,
    RemoteWebSocketConnector? webSocketConnector,
    this.requestHandler,
    this.heartbeatInterval = defaultRemoteHeartbeatInterval,
  }) : _ownsHttpClient = httpClient == null,
       _httpClient = httpClient ?? HttpClient(),
       _webSocketConnector = webSocketConnector ?? _connectWebSocket;

  final Duration heartbeatInterval;
  final String? Function() activeSessionID;
  final Uri baseURL;
  final Future<String?> Function() accessTokenProvider;
  final String deviceID;
  final RemoteRequestHandler? requestHandler;
  final bool _ownsHttpClient;
  final HttpClient _httpClient;
  final RemoteWebSocketConnector _webSocketConnector;

  RemoteStatus _status = const RemoteStatus();
  RemoteStatus get status => _status;

  Timer? _heartbeatTimer;
  bool _heartbeatInFlight = false;
  bool _disposed = false;

  bool get heartbeatRunning => _heartbeatTimer != null;

  static Future<WebSocket> _connectWebSocket(
    Uri uri,
    Map<String, dynamic> headers,
  ) => WebSocket.connect(uri.toString(), headers: headers);

  Future<Object?> request({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    final handler = requestHandler;
    if (handler != null) {
      return handler(method, path, query, headers, body);
    }
    final uri = resolve(path, query);
    final request = await _httpClient.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (deviceID.isNotEmpty) {
      request.headers.set('X-Kolkhoz-Device-ID', deviceID);
    }
    final accessToken = await accessTokenProvider();
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
      throw RemoteRequestException(
        statusCode: response.statusCode,
        uri: uri,
        responseBody: responseBody,
        sentAuthorization: accessToken != null && accessToken.isNotEmpty,
      );
    }
    return responseBody.isEmpty ? null : jsonDecode(responseBody);
  }

  Future<Map<String, Object?>> requestJson({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    final value = await request(
      method: method,
      path: path,
      query: query,
      headers: headers,
      body: body,
    );
    if (value is! Map) {
      throw const FormatException('Remote response must be a JSON object');
    }
    return value.cast<String, Object?>();
  }

  Uri resolve(String path, [Map<String, String> query = const {}]) {
    final normalizedBase = baseURL.path.endsWith('/')
        ? baseURL
        : baseURL.replace(path: '${baseURL.path}/');
    final resolved = normalizedBase.resolve(path);
    return query.isEmpty ? resolved : resolved.replace(queryParameters: query);
  }

  Future<WebSocket> openSocket({
    required String path,
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
  }) async {
    final accessToken = await accessTokenProvider();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Remote realtime requires an access token');
    }
    final uri = resolve(path, query);
    return _webSocketConnector(
      uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws'),
      {HttpHeaders.authorizationHeader: 'Bearer $accessToken', ...headers},
    );
  }

  void startHeartbeat() {
    if (_disposed || _heartbeatTimer != null) {
      return;
    }
    unawaited(refreshHeartbeat());
    _heartbeatTimer = Timer.periodic(
      heartbeatInterval,
      (_) => unawaited(refreshHeartbeat()),
    );
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> refreshHeartbeat() async {
    if (_disposed || _heartbeatInFlight) {
      return;
    }
    _heartbeatInFlight = true;
    try {
      final heartbeat = await requestJson(
        method: 'POST',
        path: 'presence',
        body: {'sessionID': ?activeSessionID()},
      );
      if (_disposed) {
        return;
      }
      _status = RemoteStatus.fromHeartbeatJson(heartbeat);
      notifyListeners();
    } catch (_) {
      if (_disposed) {
        return;
      }
      _status = RemoteStatus(
        availability: RemoteAvailability.unreachable,
        citizensOnline: _status.citizensOnline,
        activeGame: _status.activeGame,
        lastHeartbeatAt: _status.lastHeartbeatAt,
      );
      notifyListeners();
    } finally {
      _heartbeatInFlight = false;
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    stopHeartbeat();
    if (_ownsHttpClient) {
      _httpClient.close(force: true);
    }
    super.dispose();
  }
}
