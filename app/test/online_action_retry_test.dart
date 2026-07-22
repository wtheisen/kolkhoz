import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_remote_commands.dart';
import 'package:kolkhoz_app/src/app/remote_connection/remote_error.dart';

void main() {
  test('online action errors identify stale revisions', () {
    final stale = RemoteRequestException(
      statusCode: HttpStatus.conflict,
      uri: Uri.parse('https://example.test/sessions/game/actions'),
      responseBody: '{"error":"stale action"}',
      sentAuthorization: true,
    );

    expect(isStaleOnlineActionError(stale), isTrue);
  });

  test('single-revision online action results are identified', () {
    expect(onlineActionResultIsSingleRevision(12, 13), isTrue);
    expect(onlineActionResultIsSingleRevision(12, 14), isFalse);
    expect(onlineActionResultIsSingleRevision(12, 12), isFalse);
  });
}
