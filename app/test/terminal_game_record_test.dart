import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/terminal_game_record.dart';

void main() {
  const actions = [
    EngineAction(kind: 'revealReward', playerID: 0, suit: 'wheat'),
    EngineAction(
      kind: 'playCard',
      playerID: 1,
      card: EngineCard(suit: 'beet', value: 9),
    ),
  ];
  final record = TerminalGameRecord(
    seed: 2718,
    variants: KolkhozGameVariants.kolkhoz,
    controllers: KolkhozPlayerController.defaultControllers,
    participants: const [
      TerminalGameParticipant(
        seatID: 0,
        name: 'Local player',
        controller: KolkhozPlayerController.human,
        userID: 'user-1',
      ),
      TerminalGameParticipant(
        seatID: 1,
        name: 'AI 1',
        controller: KolkhozPlayerController.neuralAI,
      ),
      TerminalGameParticipant(
        seatID: 2,
        name: 'AI 2',
        controller: KolkhozPlayerController.neuralAI,
      ),
      TerminalGameParticipant(
        seatID: 3,
        name: 'AI 3',
        controller: KolkhozPlayerController.neuralAI,
      ),
    ],
    actions: actions,
    result: TerminalGameResult(
      winnerSeatID: 2,
      scores: const [
        TerminalGameScore(seatID: 0, score: 18),
        TerminalGameScore(seatID: 1, score: 22),
        TerminalGameScore(seatID: 2, score: 31),
        TerminalGameScore(seatID: 3, score: 24),
      ],
    ),
  );

  test('terminal record has stable versioned JSON round trip', () {
    final encoded = jsonEncode(record.toJson());
    final decoded = TerminalGameRecord.fromJson(
      jsonDecode(encoded) as Map<String, Object?>,
    );

    expect(jsonEncode(decoded.toJson()), encoded);
    expect(decoded.build.engine, 'KolkhozCEngine');
    expect(decoded.participants.first.userID, 'user-1');
    expect(decoded.actions.last.card?.value, 9);
    expect(decoded.result.scores.last.score, 24);
  });

  test('terminal record rejects unknown schemas', () {
    final json = record.toJson()..['schemaVersion'] = 2;

    expect(
      () => TerminalGameRecord.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });
}
