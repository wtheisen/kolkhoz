import 'package:flutter/widgets.dart';

enum MotionZoneKind {
  hand,
  plotHidden,
  plotRevealed,
  plotStackRevealed,
  trick,
  job,
  reward,
  finalTrump,
  exiled,
  northExile,
}

/// A semantic location in the card-motion graph.
///
/// Keeping this typed prevents animation behavior from depending on parsing
/// strings such as `plot:2:stack:0:revealed`.
@immutable
class MotionZone {
  const MotionZone._(
    this.kind, {
    this.seatID,
    this.stackIndex,
    this.year,
    this.suit,
  });

  const MotionZone.hand(int seatID)
    : this._(MotionZoneKind.hand, seatID: seatID);
  const MotionZone.plotHidden(int seatID)
    : this._(MotionZoneKind.plotHidden, seatID: seatID);
  const MotionZone.plotRevealed(int seatID)
    : this._(MotionZoneKind.plotRevealed, seatID: seatID);
  const MotionZone.plotStackRevealed(int seatID, int stackIndex)
    : this._(
        MotionZoneKind.plotStackRevealed,
        seatID: seatID,
        stackIndex: stackIndex,
      );
  const MotionZone.trick(int seatID)
    : this._(MotionZoneKind.trick, seatID: seatID);
  const MotionZone.job(String suit) : this._(MotionZoneKind.job, suit: suit);
  const MotionZone.reward(String suit)
    : this._(MotionZoneKind.reward, suit: suit);
  const MotionZone.finalTrump() : this._(MotionZoneKind.finalTrump);
  const MotionZone.exiled(int year) : this._(MotionZoneKind.exiled, year: year);
  const MotionZone.northExile() : this._(MotionZoneKind.northExile);

  final MotionZoneKind kind;
  final int? seatID;
  final int? stackIndex;
  final int? year;
  final String? suit;

  bool get isPlot => switch (kind) {
    MotionZoneKind.plotHidden ||
    MotionZoneKind.plotRevealed ||
    MotionZoneKind.plotStackRevealed => true,
    _ => false,
  };

  @override
  bool operator ==(Object other) =>
      other is MotionZone &&
      kind == other.kind &&
      seatID == other.seatID &&
      stackIndex == other.stackIndex &&
      year == other.year &&
      suit == other.suit;

  @override
  int get hashCode => Object.hash(kind, seatID, stackIndex, year, suit);
}

enum MotionAnchorKind {
  card,
  playerSource,
  plotSource,
  trickSource,
  jobGaugeTarget,
  jobFieldTarget,
  rewardPileSource,
  finalTrumpSource,
  northExileTarget,
}

/// A typed key for a measured piece of board geometry.
@immutable
class MotionAnchor {
  const MotionAnchor._(this.kind, {this.cardID, this.seatID, this.suit});

  const MotionAnchor.card(String cardID)
    : this._(MotionAnchorKind.card, cardID: cardID);
  const MotionAnchor.playerSource(int seatID)
    : this._(MotionAnchorKind.playerSource, seatID: seatID);
  const MotionAnchor.plotSource(int seatID)
    : this._(MotionAnchorKind.plotSource, seatID: seatID);
  const MotionAnchor.trickSource(String cardID)
    : this._(MotionAnchorKind.trickSource, cardID: cardID);
  const MotionAnchor.jobGaugeTarget(String suit)
    : this._(MotionAnchorKind.jobGaugeTarget, suit: suit);
  const MotionAnchor.jobFieldTarget(String suit)
    : this._(MotionAnchorKind.jobFieldTarget, suit: suit);
  const MotionAnchor.rewardPileSource(String suit)
    : this._(MotionAnchorKind.rewardPileSource, suit: suit);
  const MotionAnchor.finalTrumpSource()
    : this._(MotionAnchorKind.finalTrumpSource);
  const MotionAnchor.northExileTarget()
    : this._(MotionAnchorKind.northExileTarget);

  final MotionAnchorKind kind;
  final String? cardID;
  final int? seatID;
  final String? suit;

  @override
  bool operator ==(Object other) =>
      other is MotionAnchor &&
      kind == other.kind &&
      cardID == other.cardID &&
      seatID == other.seatID &&
      suit == other.suit;

  @override
  int get hashCode => Object.hash(kind, cardID, seatID, suit);
}

/// Immutable geometry snapshot consumed by the motion planner.
@immutable
class MotionGeometry {
  MotionGeometry(Map<MotionAnchor, Rect> rects)
    : _rects = Map.unmodifiable(rects);

  final Map<MotionAnchor, Rect> _rects;

  Rect? operator [](MotionAnchor anchor) => _rects[anchor];
  Map<MotionAnchor, Rect> toMap() => Map.of(_rects);
}

MotionAnchor playerCardMotionSourceKey(int seatID) =>
    MotionAnchor.playerSource(seatID);
MotionAnchor plotCardMotionSourceKey(int seatID) =>
    MotionAnchor.plotSource(seatID);
MotionAnchor trickCardMotionSourceKey(String cardID) =>
    MotionAnchor.trickSource(cardID);
MotionAnchor jobGaugeMotionTargetKey(String suit) =>
    MotionAnchor.jobGaugeTarget(suit);
MotionAnchor jobFieldMotionTargetKey(String suit) =>
    MotionAnchor.jobFieldTarget(suit);
MotionAnchor rewardPileMotionSourceKey(String suit) =>
    MotionAnchor.rewardPileSource(suit);
const finalTrumpMotionSourceKey = MotionAnchor.finalTrumpSource();
const northCardMotionTargetKey = MotionAnchor.northExileTarget();
const cardMotionNorthExileZone = MotionZone.northExile();
