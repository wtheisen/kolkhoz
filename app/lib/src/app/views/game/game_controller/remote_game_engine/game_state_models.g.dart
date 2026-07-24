// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_state_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OnlinePlayerSnapshot _$OnlinePlayerSnapshotFromJson(
  Map<String, dynamic> json,
) => _OnlinePlayerSnapshot(
  id: (json['id'] as num).toInt(),
  hand: (json['hand'] as List<dynamic>)
      .map((e) => OnlineEngineCard.fromJson(e as Map<String, dynamic>))
      .toList(),
  revealedPlot: (json['revealedPlot'] as List<dynamic>)
      .map((e) => OnlineEngineCard.fromJson(e as Map<String, dynamic>))
      .toList(),
  hiddenPlot: (json['hiddenPlot'] as List<dynamic>)
      .map((e) => OnlineEngineCard.fromJson(e as Map<String, dynamic>))
      .toList(),
  hiddenPlotCount: (_hiddenPlotCountFromJson(json, 'hiddenPlotCount') as num?)
      ?.toInt(),
  medals: (json['medals'] as num).toInt(),
  bankedMedals: (json['bankedMedals'] as num).toInt(),
  brigadeLeader: json['brigadeLeader'] as bool,
  wonTrickThisYear: json['wonTrickThisYear'] as bool,
  stacks: (json['stacks'] as List<dynamic>)
      .map((e) => OnlinePlotStackSnapshot.fromJson(e as Map<String, dynamic>))
      .toList(),
);

_OnlinePlotStackSnapshot _$OnlinePlotStackSnapshotFromJson(
  Map<String, dynamic> json,
) => _OnlinePlotStackSnapshot(
  revealed: (json['revealed'] as List<dynamic>)
      .map((e) => OnlineEngineCard.fromJson(e as Map<String, dynamic>))
      .toList(),
  hidden: (json['hidden'] as List<dynamic>)
      .map((e) => OnlineEngineCard.fromJson(e as Map<String, dynamic>))
      .toList(),
  hiddenCount: (_hiddenCountFromJson(json, 'hiddenCount') as num?)?.toInt(),
);

_OnlineTrickPlaySnapshot _$OnlineTrickPlaySnapshotFromJson(
  Map<String, dynamic> json,
) => _OnlineTrickPlaySnapshot(
  playerID: (json['playerID'] as num).toInt(),
  card: OnlineEngineCard.fromJson(json['card'] as Map<String, dynamic>),
);

_OnlineSuitCardsSnapshot _$OnlineSuitCardsSnapshotFromJson(
  Map<String, dynamic> json,
) => _OnlineSuitCardsSnapshot(
  suit: (json['suit'] as num).toInt(),
  cards: (json['cards'] as List<dynamic>)
      .map((e) => OnlineEngineCard.fromJson(e as Map<String, dynamic>))
      .toList(),
);

_OnlineSuitValueSnapshot _$OnlineSuitValueSnapshotFromJson(
  Map<String, dynamic> json,
) => _OnlineSuitValueSnapshot(
  suit: (json['suit'] as num).toInt(),
  value: (json['value'] as num).toInt(),
);

_OnlineSuitPlayersSnapshot _$OnlineSuitPlayersSnapshotFromJson(
  Map<String, dynamic> json,
) => _OnlineSuitPlayersSnapshot(
  suit: (json['suit'] as num).toInt(),
  values: (json['values'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
);

_OnlineAssignmentSnapshot _$OnlineAssignmentSnapshotFromJson(
  Map<String, dynamic> json,
) => _OnlineAssignmentSnapshot(
  card: OnlineEngineCard.fromJson(json['card'] as Map<String, dynamic>),
  targetSuit: (json['targetSuit'] as num).toInt(),
);

_OnlineRequisitionSnapshot _$OnlineRequisitionSnapshotFromJson(
  Map<String, dynamic> json,
) => _OnlineRequisitionSnapshot(
  playerID: (json['playerID'] as num).toInt(),
  suit: (json['suit'] as num).toInt(),
  card: OnlineEngineCard.fromJson(json['card'] as Map<String, dynamic>),
  message: json['message'] as String,
);

_OnlineScoreSnapshot _$OnlineScoreSnapshotFromJson(Map<String, dynamic> json) =>
    _OnlineScoreSnapshot(
      playerID: (json['playerID'] as num).toInt(),
      visibleScore: (json['visibleScore'] as num).toInt(),
      finalScore: (json['finalScore'] as num).toInt(),
    );

_OnlineEngineSnapshot _$OnlineEngineSnapshotFromJson(
  Map<String, dynamic> json,
) => _OnlineEngineSnapshot(
  year: (json['year'] as num).toInt(),
  phase: (json['phase'] as num).toInt(),
  currentPlayer: (json['currentPlayer'] as num).toInt(),
  waitingPlayer: (json['waitingPlayer'] as num).toInt(),
  waitingForExternalAction: json['waitingForExternalAction'] as bool,
  lead: (json['lead'] as num).toInt(),
  trumpSelector: (json['trumpSelector'] as num).toInt(),
  trump: (json['trump'] as num).toInt(),
  trickCount: (json['trickCount'] as num).toInt(),
  isFamine: json['isFamine'] as bool,
  players: (json['players'] as List<dynamic>)
      .map((e) => OnlinePlayerSnapshot.fromJson(e as Map<String, dynamic>))
      .toList(),
  jobPiles: (json['jobPiles'] as List<dynamic>)
      .map((e) => OnlineSuitCardsSnapshot.fromJson(e as Map<String, dynamic>))
      .toList(),
  revealedJobs: (json['revealedJobs'] as List<dynamic>)
      .map((e) => OnlineSuitCardsSnapshot.fromJson(e as Map<String, dynamic>))
      .toList(),
  claimedJobs: (json['claimedJobs'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  workHours: (json['workHours'] as List<dynamic>)
      .map((e) => OnlineSuitValueSnapshot.fromJson(e as Map<String, dynamic>))
      .toList(),
  jobBuckets: (json['jobBuckets'] as List<dynamic>)
      .map((e) => OnlineSuitCardsSnapshot.fromJson(e as Map<String, dynamic>))
      .toList(),
  accumulatedJobCards: (json['accumulatedJobCards'] as List<dynamic>)
      .map((e) => OnlineSuitCardsSnapshot.fromJson(e as Map<String, dynamic>))
      .toList(),
  currentTrick: (json['currentTrick'] as List<dynamic>)
      .map((e) => OnlineTrickPlaySnapshot.fromJson(e as Map<String, dynamic>))
      .toList(),
  currentTrickWinner: (json['currentTrickWinner'] as num?)?.toInt() ?? -1,
  lastTrick: (json['lastTrick'] as List<dynamic>)
      .map((e) => OnlineTrickPlaySnapshot.fromJson(e as Map<String, dynamic>))
      .toList(),
  lastWinner: (json['lastWinner'] as num).toInt(),
  exiled: (json['exiled'] as List<dynamic>)
      .map((e) => OnlineSuitCardsSnapshot.fromJson(e as Map<String, dynamic>))
      .toList(),
  exiledPlayers:
      (json['exiledPlayers'] as List<dynamic>?)
          ?.map(
            (e) =>
                OnlineSuitPlayersSnapshot.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  pendingAssignments: (json['pendingAssignments'] as List<dynamic>)
      .map((e) => OnlineAssignmentSnapshot.fromJson(e as Map<String, dynamic>))
      .toList(),
  requisitionEvents: (json['requisitionEvents'] as List<dynamic>)
      .map((e) => OnlineRequisitionSnapshot.fromJson(e as Map<String, dynamic>))
      .toList(),
  transitionEvents: json['transitionEvents'] == null
      ? const []
      : _transitionEventsFromJson(json['transitionEvents']),
  scores: (json['scores'] as List<dynamic>)
      .map((e) => OnlineScoreSnapshot.fromJson(e as Map<String, dynamic>))
      .toList(),
  winnerID: (json['winnerID'] as num).toInt(),
  swapConfirmed: (json['swapConfirmed'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  swapCount: (json['swapCount'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  passConfirmed:
      (json['passConfirmed'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  finalYearTrumpCard: json['finalYearTrumpCard'] == null
      ? const OnlineEngineCard(suit: -1, value: 0)
      : OnlineEngineCard.fromJson(
          json['finalYearTrumpCard'] as Map<String, dynamic>,
        ),
);
