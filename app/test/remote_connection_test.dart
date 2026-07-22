import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/remote_connection/remote_connection.dart';
import 'package:kolkhoz_app/src/app/remote_connection/remote_status.dart';

void main() {
  test('heartbeat publishes app-owned remote status', () async {
    String? receivedSessionID;
    final connection = RemoteConnection(
      baseURL: Uri.parse('https://example.invalid'),
      accessTokenProvider: () async => 'token',
      deviceID: 'device-1',
      activeSessionID: () => 'session-1',
      requestHandler: (method, path, query, headers, body) async {
        receivedSessionID =
            (body! as Map<String, Object?>)['sessionID'] as String?;
        return {
          'service': {'citizensOnline': 7},
          'activeSession': {
            'sessionID': 'session-1',
            'inviteCode': 'invite-1',
            'playerID': 2,
            'started': true,
            'requiresSync': false,
          },
        };
      },
    );
    addTearDown(connection.dispose);

    await connection.refreshHeartbeat();

    expect(receivedSessionID, 'session-1');
    expect(connection.status.availability, RemoteAvailability.reachable);
    expect(connection.status.citizensOnline, 7);
    expect(connection.status.activeGame?.sessionID, 'session-1');
    expect(connection.status.activeGame?.playerID, 2);
    expect(connection.status.lastHeartbeatAt, isNotNull);
  });

  test(
    'failed heartbeat marks connection unreachable and preserves context',
    () async {
      var fail = false;
      final connection = RemoteConnection(
        baseURL: Uri.parse('https://example.invalid'),
        accessTokenProvider: () async => 'token',
        deviceID: 'device-1',
        activeSessionID: () => null,
        requestHandler: (method, path, query, headers, body) async {
          if (fail) {
            throw StateError('offline');
          }
          return {
            'service': {'citizensOnline': 4},
            'activeSession': {
              'sessionID': 'session-2',
              'inviteCode': 'invite-2',
              'playerID': 1,
              'started': false,
              'requiresSync': true,
            },
          };
        },
      );
      addTearDown(connection.dispose);

      await connection.refreshHeartbeat();
      fail = true;
      await connection.refreshHeartbeat();

      expect(connection.status.availability, RemoteAvailability.unreachable);
      expect(connection.status.citizensOnline, 4);
      expect(connection.status.activeGame?.sessionID, 'session-2');
    },
  );

  test('heartbeat lifecycle is idempotent', () {
    final connection = RemoteConnection(
      baseURL: Uri.parse('https://example.invalid'),
      accessTokenProvider: () async => 'token',
      deviceID: 'device-1',
      activeSessionID: () => null,
      requestHandler: (method, path, query, headers, body) async => {
        'service': {'citizensOnline': 0},
      },
      heartbeatInterval: const Duration(hours: 1),
    );
    addTearDown(connection.dispose);

    connection.startHeartbeat();
    connection.startHeartbeat();
    expect(connection.heartbeatRunning, isTrue);

    connection.stopHeartbeat();
    connection.stopHeartbeat();
    expect(connection.heartbeatRunning, isFalse);
  });
}
