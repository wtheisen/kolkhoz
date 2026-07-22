import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_action_codec.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

class OnlineEngineCard {
  const OnlineEngineCard({
    required this.suit,
    required this.value,
    this.assignmentRound,
  });

  final int suit;
  final int value;
  final int? assignmentRound;

  bool get isValid =>
      (suit >= 0 && suit < 4 && value > 0) || (suit == 4 && value == 0);

  EngineCardValue get valueObject => EngineCardValue(suit: suit, value: value);

  Map<String, Object?> toJson() => {'suit': suit, 'value': value};

  static OnlineEngineCard fromJson(Map<String, Object?> json) {
    final suit = json['suit'] as int;
    final value = json['value'] as int;
    return OnlineEngineCard(
      suit: suit,
      value: suit == 4 && value == 14 ? 0 : value,
      assignmentRound: json['assignmentRound'] as int?,
    );
  }
}

class OnlineEngineAction {
  const OnlineEngineAction({
    required this.kind,
    required this.playerID,
    this.suit = -1,
    this.card = const OnlineEngineCard(suit: -1, value: 0),
    this.handCard = const OnlineEngineCard(suit: -1, value: 0),
    this.plotCard = const OnlineEngineCard(suit: -1, value: 0),
    this.plotZone = -1,
    this.targetSuit = -1,
  });

  final int kind;
  final int playerID;
  final int suit;
  final OnlineEngineCard card;
  final OnlineEngineCard handCard;
  final OnlineEngineCard plotCard;
  final int plotZone;
  final int targetSuit;

  CEngineActionValue get cValue {
    return CEngineActionValue(
      kind: kind,
      playerID: playerID,
      suit: suit,
      card: card.valueObject,
      handCard: handCard.valueObject,
      plotCard: plotCard.valueObject,
      plotZone: plotZone,
      targetSuit: targetSuit,
    );
  }

  EngineAction get engineAction {
    return engineActionFromCValue(cValue);
  }

  Map<String, Object?> toJson() {
    return {
      'kind': kind,
      'playerID': playerID,
      'suit': suit,
      'card': card.toJson(),
      'handCard': handCard.toJson(),
      'plotCard': plotCard.toJson(),
      'plotZone': plotZone,
      'targetSuit': targetSuit,
    };
  }

  static OnlineEngineAction fromJson(Map<String, Object?> json) {
    return OnlineEngineAction(
      kind: json['kind'] as int,
      playerID: json['playerID'] as int,
      suit: json['suit'] as int? ?? -1,
      card: OnlineEngineCard.fromJson(jsonObject(json['card'])),
      handCard: OnlineEngineCard.fromJson(jsonObject(json['handCard'])),
      plotCard: OnlineEngineCard.fromJson(jsonObject(json['plotCard'])),
      plotZone: json['plotZone'] as int? ?? -1,
      targetSuit: json['targetSuit'] as int? ?? -1,
    );
  }

  static OnlineEngineAction fromEngineAction(EngineAction action) {
    final cAction = cEngineAction(action);
    if (cAction == null) {
      throw const FormatException('Action cannot be sent online');
    }
    return OnlineEngineAction(
      kind: cAction.kind,
      playerID: cAction.playerID,
      suit: cAction.suit,
      card: OnlineEngineCard(
        suit: cAction.card.suit,
        value: cAction.card.value,
      ),
      handCard: OnlineEngineCard(
        suit: cAction.handCard.suit,
        value: cAction.handCard.value,
      ),
      plotCard: OnlineEngineCard(
        suit: cAction.plotCard.suit,
        value: cAction.plotCard.value,
      ),
      plotZone: cAction.plotZone,
      targetSuit: cAction.targetSuit,
    );
  }
}

class OnlinePlayerSnapshot {
  const OnlinePlayerSnapshot({
    required this.id,
    required this.hand,
    required this.revealedPlot,
    required this.hiddenPlot,
    this.hiddenPlotCount,
    required this.medals,
    required this.bankedMedals,
    required this.brigadeLeader,
    required this.wonTrickThisYear,
    required this.stacks,
  });

  final int id;
  final List<OnlineEngineCard> hand;
  final List<OnlineEngineCard> revealedPlot;
  final List<OnlineEngineCard> hiddenPlot;
  final int? hiddenPlotCount;

  int get effectiveHiddenPlotCount => hiddenPlotCount ?? hiddenPlot.length;
  final int medals;
  final int bankedMedals;
  final bool brigadeLeader;
  final bool wonTrickThisYear;
  final List<OnlinePlotStackSnapshot> stacks;

  static OnlinePlayerSnapshot fromJson(Map<String, Object?> json) {
    return OnlinePlayerSnapshot(
      id: json['id'] as int,
      hand: _cards(json['hand']),
      revealedPlot: _cards(json['revealedPlot']),
      hiddenPlot: _cards(json['hiddenPlot']),
      hiddenPlotCount:
          json['hiddenPlotCount'] as int? ?? _cards(json['hiddenPlot']).length,
      medals: json['medals'] as int,
      bankedMedals: json['bankedMedals'] as int,
      brigadeLeader: json['brigadeLeader'] as bool,
      wonTrickThisYear: json['wonTrickThisYear'] as bool,
      stacks: [
        for (final value in jsonList(json['stacks']))
          OnlinePlotStackSnapshot.fromJson(jsonObject(value)),
      ],
    );
  }
}

class OnlinePlotStackSnapshot {
  const OnlinePlotStackSnapshot({
    required this.revealed,
    required this.hidden,
    this.hiddenCount,
  });

  final List<OnlineEngineCard> revealed;
  final List<OnlineEngineCard> hidden;
  final int? hiddenCount;

  int get effectiveHiddenCount => hiddenCount ?? hidden.length;

  static OnlinePlotStackSnapshot fromJson(Map<String, Object?> json) {
    return OnlinePlotStackSnapshot(
      revealed: _cards(json['revealed']),
      hidden: _cards(json['hidden']),
      hiddenCount: json['hiddenCount'] as int? ?? _cards(json['hidden']).length,
    );
  }
}

class OnlineTrickPlaySnapshot {
  const OnlineTrickPlaySnapshot({required this.playerID, required this.card});

  final int playerID;
  final OnlineEngineCard card;

  static OnlineTrickPlaySnapshot fromJson(Map<String, Object?> json) {
    return OnlineTrickPlaySnapshot(
      playerID: json['playerID'] as int,
      card: OnlineEngineCard.fromJson(jsonObject(json['card'])),
    );
  }
}

class OnlineSuitCardsSnapshot {
  const OnlineSuitCardsSnapshot({required this.suit, required this.cards});

  final int suit;
  final List<OnlineEngineCard> cards;

  static OnlineSuitCardsSnapshot fromJson(Map<String, Object?> json) {
    return OnlineSuitCardsSnapshot(
      suit: json['suit'] as int,
      cards: _cards(json['cards']),
    );
  }
}

class OnlineSuitValueSnapshot {
  const OnlineSuitValueSnapshot({required this.suit, required this.value});

  final int suit;
  final int value;

  static OnlineSuitValueSnapshot fromJson(Map<String, Object?> json) {
    return OnlineSuitValueSnapshot(
      suit: json['suit'] as int,
      value: json['value'] as int,
    );
  }
}

class OnlineSuitPlayersSnapshot {
  const OnlineSuitPlayersSnapshot({required this.suit, required this.values});

  final int suit;
  final List<int> values;

  static OnlineSuitPlayersSnapshot fromJson(Map<String, Object?> json) {
    return OnlineSuitPlayersSnapshot(
      suit: json['suit'] as int,
      values: _ints(json['values']),
    );
  }
}

class OnlineAssignmentSnapshot {
  const OnlineAssignmentSnapshot({
    required this.card,
    required this.targetSuit,
  });

  final OnlineEngineCard card;
  final int targetSuit;

  static OnlineAssignmentSnapshot fromJson(Map<String, Object?> json) {
    return OnlineAssignmentSnapshot(
      card: OnlineEngineCard.fromJson(jsonObject(json['card'])),
      targetSuit: json['targetSuit'] as int,
    );
  }
}

class OnlineRequisitionSnapshot {
  const OnlineRequisitionSnapshot({
    required this.playerID,
    required this.suit,
    required this.card,
    required this.message,
  });

  final int playerID;
  final int suit;
  final OnlineEngineCard card;
  final String message;

  static OnlineRequisitionSnapshot fromJson(Map<String, Object?> json) {
    return OnlineRequisitionSnapshot(
      playerID: json['playerID'] as int,
      suit: json['suit'] as int,
      card: OnlineEngineCard.fromJson(jsonObject(json['card'])),
      message: json['message'] as String,
    );
  }
}

class OnlineScoreSnapshot {
  const OnlineScoreSnapshot({
    required this.playerID,
    required this.visibleScore,
    required this.finalScore,
  });

  final int playerID;
  final int visibleScore;
  final int finalScore;

  static OnlineScoreSnapshot fromJson(Map<String, Object?> json) {
    return OnlineScoreSnapshot(
      playerID: json['playerID'] as int,
      visibleScore: json['visibleScore'] as int,
      finalScore: json['finalScore'] as int,
    );
  }
}

class OnlineEngineSnapshot {
  const OnlineEngineSnapshot({
    required this.year,
    required this.phase,
    required this.currentPlayer,
    required this.waitingPlayer,
    required this.waitingForExternalAction,
    required this.lead,
    required this.trumpSelector,
    required this.trump,
    required this.trickCount,
    required this.isFamine,
    required this.players,
    required this.jobPiles,
    required this.revealedJobs,
    required this.claimedJobs,
    required this.workHours,
    required this.jobBuckets,
    required this.accumulatedJobCards,
    required this.currentTrick,
    required this.lastTrick,
    required this.lastWinner,
    required this.exiled,
    this.exiledPlayers = const [],
    required this.pendingAssignments,
    required this.requisitionEvents,
    required this.scores,
    required this.winnerID,
    required this.swapConfirmed,
    required this.swapCount,
    this.passConfirmed = const [],
    this.finalYearTrumpCard = const OnlineEngineCard(suit: -1, value: 0),
  });

  final int year;
  final int phase;
  final int currentPlayer;
  final int waitingPlayer;
  final bool waitingForExternalAction;
  final int lead;
  final int trumpSelector;
  final int trump;
  final int trickCount;
  final bool isFamine;
  final List<OnlinePlayerSnapshot> players;
  final List<OnlineSuitCardsSnapshot> jobPiles;
  final List<OnlineSuitCardsSnapshot> revealedJobs;
  final List<int> claimedJobs;
  final List<OnlineSuitValueSnapshot> workHours;
  final List<OnlineSuitCardsSnapshot> jobBuckets;
  final List<OnlineSuitCardsSnapshot> accumulatedJobCards;
  final List<OnlineTrickPlaySnapshot> currentTrick;
  final List<OnlineTrickPlaySnapshot> lastTrick;
  final int lastWinner;
  final List<OnlineSuitCardsSnapshot> exiled;
  final List<OnlineSuitPlayersSnapshot> exiledPlayers;
  final List<OnlineAssignmentSnapshot> pendingAssignments;
  final List<OnlineRequisitionSnapshot> requisitionEvents;
  final List<OnlineScoreSnapshot> scores;
  final int winnerID;
  final List<int> swapConfirmed;
  final List<int> swapCount;
  final List<int> passConfirmed;
  final OnlineEngineCard finalYearTrumpCard;

  static OnlineEngineSnapshot fromJson(Map<String, Object?> json) {
    return OnlineEngineSnapshot(
      year: json['year'] as int,
      phase: json['phase'] as int,
      currentPlayer: json['currentPlayer'] as int,
      waitingPlayer: json['waitingPlayer'] as int,
      waitingForExternalAction: json['waitingForExternalAction'] as bool,
      lead: json['lead'] as int,
      trumpSelector: json['trumpSelector'] as int,
      trump: json['trump'] as int,
      trickCount: json['trickCount'] as int,
      isFamine: json['isFamine'] as bool,
      players: [
        for (final value in jsonList(json['players']))
          OnlinePlayerSnapshot.fromJson(jsonObject(value)),
      ],
      jobPiles: _suitCards(json['jobPiles']),
      revealedJobs: _suitCards(json['revealedJobs']),
      claimedJobs: _ints(json['claimedJobs']),
      workHours: [
        for (final value in jsonList(json['workHours']))
          OnlineSuitValueSnapshot.fromJson(jsonObject(value)),
      ],
      jobBuckets: _suitCards(json['jobBuckets']),
      accumulatedJobCards: _suitCards(json['accumulatedJobCards']),
      currentTrick: [
        for (final value in jsonList(json['currentTrick']))
          OnlineTrickPlaySnapshot.fromJson(jsonObject(value)),
      ],
      lastTrick: [
        for (final value in jsonList(json['lastTrick']))
          OnlineTrickPlaySnapshot.fromJson(jsonObject(value)),
      ],
      lastWinner: json['lastWinner'] as int,
      exiled: _suitCards(json['exiled']),
      exiledPlayers: [
        for (final value in jsonList(json['exiledPlayers'] ?? const []))
          OnlineSuitPlayersSnapshot.fromJson(jsonObject(value)),
      ],
      pendingAssignments: [
        for (final value in jsonList(json['pendingAssignments']))
          OnlineAssignmentSnapshot.fromJson(jsonObject(value)),
      ],
      requisitionEvents: [
        for (final value in jsonList(json['requisitionEvents']))
          OnlineRequisitionSnapshot.fromJson(jsonObject(value)),
      ],
      scores: [
        for (final value in jsonList(json['scores']))
          OnlineScoreSnapshot.fromJson(jsonObject(value)),
      ],
      winnerID: json['winnerID'] as int,
      swapConfirmed: _ints(json['swapConfirmed']),
      swapCount: _ints(json['swapCount']),
      passConfirmed: _ints(json['passConfirmed'] ?? const []),
      finalYearTrumpCard: OnlineEngineCard.fromJson(
        jsonObject(
          json['finalYearTrumpCard'] ?? const {'suit': -1, 'value': 0},
        ),
      ),
    );
  }
}

List<OnlineEngineCard> _cards(Object? value) {
  return [
    for (final card in jsonList(value))
      OnlineEngineCard.fromJson(jsonObject(card)),
  ];
}

List<OnlineSuitCardsSnapshot> _suitCards(Object? value) {
  return [
    for (final entry in jsonList(value))
      OnlineSuitCardsSnapshot.fromJson(jsonObject(entry)),
  ];
}

List<int> _ints(Object? value) {
  return [for (final entry in jsonList(value)) entry as int];
}
