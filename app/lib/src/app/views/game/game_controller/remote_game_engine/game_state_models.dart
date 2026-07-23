import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_action_codec.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

part 'game_state_models.freezed.dart';
part 'game_state_models.g.dart';

@Freezed(fromJson: false, toJson: false)
abstract class OnlineEngineCard with _$OnlineEngineCard {
  const OnlineEngineCard._();

  const factory OnlineEngineCard({
    required int suit,
    required int value,
    int? assignmentRound,
  }) = _OnlineEngineCard;

  bool get isValid =>
      (suit >= 0 && suit < 4 && value > 0) || (suit == 4 && value == 0);

  EngineCardValue get valueObject => EngineCardValue(suit: suit, value: value);

  Map<String, Object?> toJson() => {'suit': suit, 'value': value};

  factory OnlineEngineCard.fromJson(Map<String, Object?> json) {
    final suit = json['suit'] as int;
    final value = json['value'] as int;
    return OnlineEngineCard(
      suit: suit,
      value: suit == 4 && value == 14 ? 0 : value,
      assignmentRound: json['assignmentRound'] as int?,
    );
  }
}

@Freezed(fromJson: false, toJson: false)
abstract class OnlineEngineAction with _$OnlineEngineAction {
  const OnlineEngineAction._();

  const factory OnlineEngineAction({
    required int kind,
    required int playerID,
    @Default(-1) int suit,
    @Default(OnlineEngineCard(suit: -1, value: 0)) OnlineEngineCard card,
    @Default(OnlineEngineCard(suit: -1, value: 0)) OnlineEngineCard handCard,
    @Default(OnlineEngineCard(suit: -1, value: 0)) OnlineEngineCard plotCard,
    @Default(-1) int plotZone,
    @Default(-1) int targetSuit,
  }) = _OnlineEngineAction;

  CEngineActionValue get cValue => CEngineActionValue(
    kind: kind,
    playerID: playerID,
    suit: suit,
    card: card.valueObject,
    handCard: handCard.valueObject,
    plotCard: plotCard.valueObject,
    plotZone: plotZone,
    targetSuit: targetSuit,
  );

  EngineAction get engineAction => engineActionFromCValue(cValue);

  Map<String, Object?> toJson() => {
    'kind': kind,
    'playerID': playerID,
    'suit': suit,
    'card': card.toJson(),
    'handCard': handCard.toJson(),
    'plotCard': plotCard.toJson(),
    'plotZone': plotZone,
    'targetSuit': targetSuit,
  };

  factory OnlineEngineAction.fromJson(Map<String, Object?> json) =>
      OnlineEngineAction(
        kind: json['kind'] as int,
        playerID: json['playerID'] as int,
        suit: json['suit'] as int? ?? -1,
        card: OnlineEngineCard.fromJson(jsonObject(json['card'])),
        handCard: OnlineEngineCard.fromJson(jsonObject(json['handCard'])),
        plotCard: OnlineEngineCard.fromJson(jsonObject(json['plotCard'])),
        plotZone: json['plotZone'] as int? ?? -1,
        targetSuit: json['targetSuit'] as int? ?? -1,
      );

  factory OnlineEngineAction.fromEngineAction(EngineAction action) {
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

@Freezed(toJson: false)
abstract class OnlinePlayerSnapshot with _$OnlinePlayerSnapshot {
  const OnlinePlayerSnapshot._();

  const factory OnlinePlayerSnapshot({
    required int id,
    required List<OnlineEngineCard> hand,
    required List<OnlineEngineCard> revealedPlot,
    required List<OnlineEngineCard> hiddenPlot,
    @JsonKey(readValue: _hiddenPlotCountFromJson) int? hiddenPlotCount,
    required int medals,
    required int bankedMedals,
    required bool brigadeLeader,
    required bool wonTrickThisYear,
    required List<OnlinePlotStackSnapshot> stacks,
  }) = _OnlinePlayerSnapshot;

  factory OnlinePlayerSnapshot.fromJson(Map<String, Object?> json) =>
      _$OnlinePlayerSnapshotFromJson(json);

  int get effectiveHiddenPlotCount => hiddenPlotCount ?? hiddenPlot.length;
}

@Freezed(toJson: false)
abstract class OnlinePlotStackSnapshot with _$OnlinePlotStackSnapshot {
  const OnlinePlotStackSnapshot._();

  const factory OnlinePlotStackSnapshot({
    required List<OnlineEngineCard> revealed,
    required List<OnlineEngineCard> hidden,
    @JsonKey(readValue: _hiddenCountFromJson) int? hiddenCount,
  }) = _OnlinePlotStackSnapshot;

  factory OnlinePlotStackSnapshot.fromJson(Map<String, Object?> json) =>
      _$OnlinePlotStackSnapshotFromJson(json);

  int get effectiveHiddenCount => hiddenCount ?? hidden.length;
}

@Freezed(toJson: false)
abstract class OnlineTrickPlaySnapshot with _$OnlineTrickPlaySnapshot {
  const factory OnlineTrickPlaySnapshot({
    required int playerID,
    required OnlineEngineCard card,
  }) = _OnlineTrickPlaySnapshot;

  factory OnlineTrickPlaySnapshot.fromJson(Map<String, Object?> json) =>
      _$OnlineTrickPlaySnapshotFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineSuitCardsSnapshot with _$OnlineSuitCardsSnapshot {
  const factory OnlineSuitCardsSnapshot({
    required int suit,
    required List<OnlineEngineCard> cards,
  }) = _OnlineSuitCardsSnapshot;

  factory OnlineSuitCardsSnapshot.fromJson(Map<String, Object?> json) =>
      _$OnlineSuitCardsSnapshotFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineSuitValueSnapshot with _$OnlineSuitValueSnapshot {
  const factory OnlineSuitValueSnapshot({
    required int suit,
    required int value,
  }) = _OnlineSuitValueSnapshot;

  factory OnlineSuitValueSnapshot.fromJson(Map<String, Object?> json) =>
      _$OnlineSuitValueSnapshotFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineSuitPlayersSnapshot with _$OnlineSuitPlayersSnapshot {
  const factory OnlineSuitPlayersSnapshot({
    required int suit,
    required List<int> values,
  }) = _OnlineSuitPlayersSnapshot;

  factory OnlineSuitPlayersSnapshot.fromJson(Map<String, Object?> json) =>
      _$OnlineSuitPlayersSnapshotFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineAssignmentSnapshot with _$OnlineAssignmentSnapshot {
  const factory OnlineAssignmentSnapshot({
    required OnlineEngineCard card,
    required int targetSuit,
  }) = _OnlineAssignmentSnapshot;

  factory OnlineAssignmentSnapshot.fromJson(Map<String, Object?> json) =>
      _$OnlineAssignmentSnapshotFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineRequisitionSnapshot with _$OnlineRequisitionSnapshot {
  const factory OnlineRequisitionSnapshot({
    required int playerID,
    required int suit,
    required OnlineEngineCard card,
    required String message,
  }) = _OnlineRequisitionSnapshot;

  factory OnlineRequisitionSnapshot.fromJson(Map<String, Object?> json) =>
      _$OnlineRequisitionSnapshotFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineScoreSnapshot with _$OnlineScoreSnapshot {
  const factory OnlineScoreSnapshot({
    required int playerID,
    required int visibleScore,
    required int finalScore,
  }) = _OnlineScoreSnapshot;

  factory OnlineScoreSnapshot.fromJson(Map<String, Object?> json) =>
      _$OnlineScoreSnapshotFromJson(json);
}

@Freezed(toJson: false)
abstract class OnlineEngineSnapshot with _$OnlineEngineSnapshot {
  const factory OnlineEngineSnapshot({
    required int year,
    required int phase,
    required int currentPlayer,
    required int waitingPlayer,
    required bool waitingForExternalAction,
    required int lead,
    required int trumpSelector,
    required int trump,
    required int trickCount,
    required bool isFamine,
    required List<OnlinePlayerSnapshot> players,
    required List<OnlineSuitCardsSnapshot> jobPiles,
    required List<OnlineSuitCardsSnapshot> revealedJobs,
    required List<int> claimedJobs,
    required List<OnlineSuitValueSnapshot> workHours,
    required List<OnlineSuitCardsSnapshot> jobBuckets,
    required List<OnlineSuitCardsSnapshot> accumulatedJobCards,
    required List<OnlineTrickPlaySnapshot> currentTrick,
    required List<OnlineTrickPlaySnapshot> lastTrick,
    required int lastWinner,
    required List<OnlineSuitCardsSnapshot> exiled,
    @Default([]) List<OnlineSuitPlayersSnapshot> exiledPlayers,
    required List<OnlineAssignmentSnapshot> pendingAssignments,
    required List<OnlineRequisitionSnapshot> requisitionEvents,
    required List<OnlineScoreSnapshot> scores,
    required int winnerID,
    required List<int> swapConfirmed,
    required List<int> swapCount,
    @Default([]) List<int> passConfirmed,
    @Default(OnlineEngineCard(suit: -1, value: 0))
    OnlineEngineCard finalYearTrumpCard,
  }) = _OnlineEngineSnapshot;

  factory OnlineEngineSnapshot.fromJson(Map<String, Object?> json) =>
      _$OnlineEngineSnapshotFromJson(json);
}

Object? _hiddenPlotCountFromJson(Map<dynamic, dynamic> json, String key) =>
    json[key] ?? (json['hiddenPlot'] as List<dynamic>).length;

Object? _hiddenCountFromJson(Map<dynamic, dynamic> json, String key) =>
    json[key] ?? (json['hidden'] as List<dynamic>).length;
