import 'c_engine_bridge.dart';
import 'render_model.dart';
import 'saved_game_store.dart';

/// Portable, immutable state captured before a native engine is disposed.
class GameStateSnapshot {
  GameStateSnapshot({
    required this.seed,
    required this.variants,
    required List<KolkhozPlayerController> controllers,
    required this.model,
  }) : controllers = List.unmodifiable(controllers);

  final int seed;
  final KolkhozGameVariants variants;
  final List<KolkhozPlayerController> controllers;
  final TableViewModel model;

  Map<String, Object?> toJson() => {
    'version': 1,
    'seed': seed,
    'variants': variantsToJson(variants),
    'controllers': controllers.map((controller) => controller.name).toList(),
    'state': _tableToJson(model.table),
  };
}

Map<String, Object?> _tableToJson(TableState table) => {
  'year': table.year,
  'phase': table.phase,
  'currentPlayerID': table.currentPlayerID,
  'trump': table.trump,
  'isFamine': table.isFamine,
  'maxTricks': table.maxTricks,
  'seats': table.seats.map(_seatToJson).toList(),
  'jobs': table.jobs.map(_jobToJson).toList(),
  'trick': _trickToJson(table.trick),
  'lastTrick': _trickToJson(table.lastTrick),
  'requisitionEvents': table.requisitionEvents
      .map(
        (event) => {
          'seatID': event.seatID,
          'suit': event.suit,
          'card': _optionalCardToJson(event.card),
          'message': event.message,
        },
      )
      .toList(),
  'exiledByYear': {
    for (final entry in table.exiledByYear.entries)
      entry.key.toString(): entry.value.map(_cardToJson).toList(),
  },
  'scoreboard': table.scoreboard.map(_scoreToJson).toList(),
  'gameResult': table.gameResult == null
      ? null
      : {
          'winnerSeatID': table.gameResult!.winnerSeatID,
          'scores': table.gameResult!.scores.map(_scoreToJson).toList(),
        },
  'finalYearTrumpCard': _optionalCardToJson(table.finalYearTrumpCard),
};

Map<String, Object?> _seatToJson(Seat seat) => {
  'id': seat.id,
  'name': seat.name,
  'controller': seat.controller,
  'isBrigadeLeader': seat.isBrigadeLeader,
  'hand': seat.hand.map(_cardToJson).toList(),
  'plot': {
    'revealed': seat.plot.revealed.map(_cardToJson).toList(),
    'hidden': seat.plot.hidden.map(_cardToJson).toList(),
    'stacks': seat.plot.stacks
        .map(
          (stack) => {
            'revealed': stack.revealed.map(_cardToJson).toList(),
            'hidden': stack.hidden.map(_cardToJson).toList(),
          },
        )
        .toList(),
  },
  'medals': seat.medals,
  'visibleScore': seat.visibleScore,
};

Map<String, Object?> _jobToJson(Job job) => {
  'suit': job.suit,
  'hours': job.hours,
  'requiredHours': job.requiredHours,
  'claimed': job.claimed,
  'reward': _optionalCardToJson(job.reward),
  'assignedCards': job.assignedCards.map(_cardToJson).toList(),
};

Map<String, Object?> _trickToJson(Trick trick) => {
  'plays': trick.plays
      .map((play) => {'seatID': play.seatID, 'card': _cardToJson(play.card)})
      .toList(),
  'winnerSeatID': trick.winnerSeatID,
};

Map<String, Object?> _scoreToJson(Score score) => {
  'seatID': score.seatID,
  'visibleScore': score.visibleScore,
  'finalScore': score.finalScore,
};

Map<String, Object?>? _optionalCardToJson(TableCard? card) =>
    card == null ? null : _cardToJson(card);

Map<String, Object?> _cardToJson(TableCard card) => {
  'suit': card.suit,
  'value': card.value,
  if (card.assignmentRound != null) 'assignmentRound': card.assignmentRound,
  if (card.ownerSeatID != null) 'ownerSeatID': card.ownerSeatID,
};
