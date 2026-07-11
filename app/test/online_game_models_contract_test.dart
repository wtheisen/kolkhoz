import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/online_game_models.dart';

void main() {
  test('redacted plot counts remain visible without revealing cards', () {
    final player = OnlinePlayerSnapshot.fromJson({
      'id': 1,
      'hand': <Object?>[],
      'revealedPlot': <Object?>[],
      'hiddenPlot': <Object?>[],
      'hiddenPlotCount': 3,
      'medals': 0,
      'bankedMedals': 0,
      'brigadeLeader': false,
      'wonTrickThisYear': false,
      'stacks': [
        {'revealed': <Object?>[], 'hidden': <Object?>[], 'hiddenCount': 2},
      ],
    });

    expect(player.hiddenPlot, isEmpty);
    expect(player.effectiveHiddenPlotCount, 3);
    expect(player.stacks.single.hidden, isEmpty);
    expect(player.stacks.single.effectiveHiddenCount, 2);
  });

  test('unredacted plot counts fall back to card list lengths', () {
    final player = OnlinePlayerSnapshot.fromJson({
      'id': 0,
      'hand': <Object?>[],
      'revealedPlot': <Object?>[],
      'hiddenPlot': [
        {'suit': 0, 'value': 8},
      ],
      'medals': 0,
      'bankedMedals': 0,
      'brigadeLeader': true,
      'wonTrickThisYear': false,
      'stacks': [
        {
          'revealed': <Object?>[],
          'hidden': [
            {'suit': 1, 'value': 9},
          ],
        },
      ],
    });

    expect(player.effectiveHiddenPlotCount, 1);
    expect(player.stacks.single.effectiveHiddenCount, 1);
  });

  test('leaderboard and public-profile records preserve optional rank', () {
    final ranked = OnlineComradeProfile.fromJson({
      'userID': 'user-1',
      'displayName': 'Mira',
      'rank': 4,
      'stats': {'online_games': 9, 'online_wins': 5},
    });
    final unranked = OnlineComradeProfile.fromJson({
      'userID': 'user-2',
      'displayName': 'Lev',
      'stats': <String, Object?>{},
    });

    expect(ranked.rank, 4);
    expect(ranked.displayLabel, 'Mira');
    expect(unranked.rank, isNull);
  });

  test('North ownership parses and remains backward compatible', () {
    final owned = OnlineSuitPlayersSnapshot.fromJson({
      'suit': 2,
      'values': [3, 1],
    });

    expect(owned.suit, 2);
    expect(owned.values, [3, 1]);
  });
}
