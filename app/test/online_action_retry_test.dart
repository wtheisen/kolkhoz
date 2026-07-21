import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/game_channel_online.dart';
import 'package:kolkhoz_app/src/game_constants.dart';
import 'package:kolkhoz_app/src/online_game_models.dart';
import 'package:kolkhoz_app/src/online_game_client.dart';
import 'package:kolkhoz_app/src/render_model.dart';

void main() {
  test('online action retry helpers identify stale matching plays', () {
    const action = EngineAction(
      kind: actionPlayCard,
      playerID: 2,
      card: EngineCard(suit: 'potato', value: 9),
    );
    final stale = OnlineRequestException(
      statusCode: HttpStatus.conflict,
      uri: Uri.parse('https://example.test/sessions/game/actions'),
      responseBody: '{"error":"stale action"}',
      sentAuthorization: true,
    );

    expect(isStaleOnlineActionError(stale), isTrue);
    expect(
      onlineActionMatches(OnlineEngineAction.fromEngineAction(action), action),
      isTrue,
    );
    expect(
      onlineActionMatches(
        OnlineEngineAction.fromEngineAction(
          const EngineAction(
            kind: actionPlayCard,
            playerID: 2,
            card: EngineCard(suit: 'potato', value: 10),
          ),
        ),
        action,
      ),
      isFalse,
    );
  });

  test('single-revision online action results are identified', () {
    expect(onlineActionResultIsSingleRevision(12, 13), isTrue);
    expect(onlineActionResultIsSingleRevision(12, 14), isFalse);
    expect(onlineActionResultIsSingleRevision(12, 12), isFalse);
  });
}
