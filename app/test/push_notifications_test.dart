import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/push_notifications.dart';

void main() {
  test('push payload carries routing metadata but no game state', () {
    final payload = KolkhozPushPayload.fromMessage(
      RemoteMessage(
        data: {
          'type': 'your_turn',
          'sessionID': '00000000-0000-4000-8000-000000000001',
        },
        notification: const RemoteNotification(
          title: 'Your turn',
          body: 'A human move is waiting for you.',
        ),
      ),
    );
    expect(payload.type, 'your_turn');
    expect(payload.sessionID, '00000000-0000-4000-8000-000000000001');
    expect(payload.body, 'A human move is waiting for you.');
  });
}
