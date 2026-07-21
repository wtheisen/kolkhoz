import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/online_game_models.dart';

void main() {
  test('legacy online saboteur wire value maps to zero', () {
    final card = OnlineEngineCard.fromJson({'suit': 4, 'value': 14});

    expect(card.isValid, isTrue);
    expect(card.value, 0);
  });

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

  test('replay contract preserves ordered actions for future playback', () {
    final replay = OnlineGameReplay.fromJson({
      'sessionID': 'finished-1',
      'seed': 42,
      'variants': {
        'deckType': 40,
        'maxYears': 5,
        'nomenclature': true,
        'allowSwap': true,
        'northernStyle': false,
        'miceVariant': false,
        'ordenNachalniku': false,
        'medalsCount': true,
        'accumulateJobs': false,
        'heroOfSovietUnion': false,
        'wrecker': true,
      },
      'controllers': ['human', 'mediumAI', 'mediumAI', 'mediumAI'],
      'ranked': false,
      'results': [
        {'playerID': 0, 'score': 120, 'rank': 1, 'displayName': 'Mira'},
      ],
      'events': [
        {
          'revision': 1,
          'kind': 'action',
          'createdAt': 10.0,
          'action': {
            'kind': 1,
            'playerID': 0,
            'card': {'suit': 0, 'value': 8},
            'handCard': {'suit': -1, 'value': 0},
            'plotCard': {'suit': -1, 'value': 0},
          },
        },
      ],
    });

    expect(replay.seed, 42);
    expect(replay.events.single.revision, 1);
    expect(replay.events.single.action.card.value, 8);
    expect(replay.results.single.displayName, 'Mira');
  });

  test('daily challenge exposes personal best and best-score leaders', () {
    final challenge = OnlineDailyChallenge.fromJson({
      'date': '2026-07-12',
      'seed': 99,
      'attempt': {'score': 150},
      'leaders': [
        {'displayName': 'Lev', 'score': 175},
      ],
    });

    expect(challenge.bestScore, 150);
    expect(challenge.leaders.single.score, 175);
  });

  test('online series status preserves round and seat wins', () {
    final series = OnlineSeriesStatus.fromJson({
      'seriesID': 'series-1',
      'bestOf': 5,
      'roundNumber': 3,
      'completed': false,
      'winnerPlayerID': null,
      'wins': {'0': 2, '2': 1},
    });

    expect(series.bestOf, 5);
    expect(series.roundNumber, 3);
    expect(series.winsFor(0), 2);
    expect(series.winsFor(1), 0);
  });

  test('weekly tournament preserves enrollment, table, and standings', () {
    final tournament = OnlineWeeklyTournament.fromJson({
      'available': true,
      'tournamentID': 'weekly-1',
      'startsAt': 1000,
      'joinOpensAt': 900,
      'joinClosesAt': 1000,
      'status': 'playing',
      'roundNumber': 2,
      'totalRounds': 4,
      'joined': true,
      'forfeited': false,
      'entrantCount': 8,
      'standings': [
        {
          'rank': 1,
          'userID': 'player-1',
          'displayName': 'Mira',
          'points': 8.0,
          'wins': 1,
          'gameScore': 230,
          'isBot': false,
          'forfeited': false,
        },
      ],
      'table': {
        'tableID': 'table-1',
        'sessionID': 'session-1',
        'roundNumber': 2,
        'tableNumber': 1,
        'status': 'active',
        'playerID': 3,
      },
    });

    expect(tournament.roundNumber, 2);
    expect(tournament.standings.single.displayName, 'Mira');
    expect(tournament.table?.sessionID, 'session-1');
    expect(tournament.table?.playerID, 3);
  });
}
