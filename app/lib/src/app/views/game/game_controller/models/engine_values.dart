class EngineCardValue {
  const EngineCardValue({required this.suit, required this.value});

  final int suit;
  final int value;

  bool get isValid =>
      (suit >= 0 && suit < 4 && value > 0) || (suit == 4 && value == 0);
}

class EngineTransitionEvent {
  const EngineTransitionEvent({
    required this.kind,
    required this.playerID,
    required this.card,
    required this.fromZone,
    required this.toZone,
    required this.fromOwner,
    required this.toOwner,
    required this.targetSuit,
    this.trickWinnerID = -1,
  });

  final int kind;
  final int playerID;
  final EngineCardValue card;
  final int fromZone;
  final int toZone;
  final int fromOwner;
  final int toOwner;
  final int targetSuit;
  final int trickWinnerID;

  factory EngineTransitionEvent.fromJson(Map<String, Object?> json) {
    final card = json['card'] as Map<String, Object?>?;
    return EngineTransitionEvent(
      kind: json['kind'] as int,
      playerID: json['playerID'] as int? ?? -1,
      card: EngineCardValue(
        suit: card?['suit'] as int? ?? -1,
        value: card?['value'] as int? ?? 0,
      ),
      fromZone: json['fromZone'] as int? ?? kcObjectZoneNone,
      toZone: json['toZone'] as int? ?? kcObjectZoneNone,
      fromOwner: json['fromOwner'] as int? ?? -1,
      toOwner: json['toOwner'] as int? ?? -1,
      targetSuit: json['targetSuit'] as int? ?? -1,
      trickWinnerID: json['trickWinnerID'] as int? ?? -1,
    );
  }
}

class CEngineActionValue {
  const CEngineActionValue({
    required this.kind,
    required this.playerID,
    required this.suit,
    required this.card,
    required this.handCard,
    required this.plotCard,
    required this.plotZone,
    required this.targetSuit,
  });

  final int kind;
  final int playerID;
  final int suit;
  final EngineCardValue card;
  final EngineCardValue handCard;
  final EngineCardValue plotCard;
  final int plotZone;
  final int targetSuit;
}

class KolkhozGameVariants {
  const KolkhozGameVariants({
    this.deckType = 52,
    this.maxYears = 5,
    this.nomenclature = true,
    this.allowSwap = true,
    this.northernStyle = false,
    this.miceVariant = false,
    this.ordenNachalniku = false,
    this.medalsCount = false,
    this.accumulateJobs = false,
    this.heroOfSovietUnion = true,
    this.wreckerCard = false,
    this.finalYearTrump = false,
    this.passCards = false,
    this.highestCardsRequisition = false,
    this.lottoRewards = false,
  });

  final int deckType;
  final int maxYears;
  final bool nomenclature;
  final bool allowSwap;
  final bool northernStyle;
  final bool miceVariant;
  final bool ordenNachalniku;
  final bool medalsCount;
  final bool accumulateJobs;
  final bool heroOfSovietUnion;
  final bool wreckerCard;
  final bool finalYearTrump;
  final bool passCards;
  final bool highestCardsRequisition;
  final bool lottoRewards;

  KolkhozGameVariants copyWith({
    int? deckType,
    int? maxYears,
    bool? nomenclature,
    bool? allowSwap,
    bool? northernStyle,
    bool? miceVariant,
    bool? ordenNachalniku,
    bool? medalsCount,
    bool? accumulateJobs,
    bool? heroOfSovietUnion,
    bool? wreckerCard,
    bool? finalYearTrump,
    bool? passCards,
    bool? highestCardsRequisition,
    bool? lottoRewards,
  }) {
    return KolkhozGameVariants(
      deckType: deckType ?? this.deckType,
      maxYears: maxYears ?? this.maxYears,
      nomenclature: nomenclature ?? this.nomenclature,
      allowSwap: allowSwap ?? this.allowSwap,
      northernStyle: northernStyle ?? this.northernStyle,
      miceVariant: miceVariant ?? this.miceVariant,
      ordenNachalniku: ordenNachalniku ?? this.ordenNachalniku,
      medalsCount: medalsCount ?? this.medalsCount,
      accumulateJobs: accumulateJobs ?? this.accumulateJobs,
      heroOfSovietUnion: heroOfSovietUnion ?? this.heroOfSovietUnion,
      wreckerCard: wreckerCard ?? this.wreckerCard,
      finalYearTrump: finalYearTrump ?? this.finalYearTrump,
      passCards: passCards ?? this.passCards,
      highestCardsRequisition:
          highestCardsRequisition ?? this.highestCardsRequisition,
      lottoRewards: lottoRewards ?? this.lottoRewards,
    );
  }

  static const kolkhoz = KolkhozGameVariants(
    nomenclature: false,
    wreckerCard: true,
    finalYearTrump: true,
    highestCardsRequisition: true,
    lottoRewards: true,
  );
  static const demoKolkhoz = kolkhoz;
  static const littleKolkhoz = KolkhozGameVariants(
    deckType: 36,
    nomenclature: true,
    allowSwap: true,
    ordenNachalniku: true,
    heroOfSovietUnion: false,
  );
  static const campStyle = KolkhozGameVariants(
    deckType: 36,
    nomenclature: true,
    allowSwap: true,
    northernStyle: true,
    miceVariant: true,
    heroOfSovietUnion: true,
  );
}

enum KolkhozPlayerController {
  human,
  heuristicAI,
  mediumAI,
  neuralAI;

  static const defaultControllers = [human, neuralAI, neuralAI, neuralAI];
  static const demoControllers = [human, heuristicAI, heuristicAI, heuristicAI];

  static List<KolkhozPlayerController> normalized(
    List<KolkhozPlayerController> controllers,
  ) {
    final normalized = List<KolkhozPlayerController>.generate(
      4,
      (index) => index < controllers.length
          ? controllers[index]
          : defaultControllers[index],
    );
    if (!normalized.contains(KolkhozPlayerController.human)) {
      normalized[0] = KolkhozPlayerController.human;
    }
    return normalized;
  }
}

const kcActionSetTrump = 1;
const kcActionSwap = 2;
const kcActionConfirmSwap = 3;
const kcActionPlayCard = 4;
const kcActionAssign = 5;
const kcActionSubmitAssignments = 6;
const kcActionContinueAfterRequisition = 7;
const kcActionUndoSwap = 8;
const kcActionPassCard = 9;
const kcActionRevealReward = 10;
const kcActionRevealTrump = 11;

const kcPhasePlanning = 0;
const kcPhaseSwap = 1;
const kcPhaseTrick = 2;
const kcPhaseAssignment = 3;
const kcPhaseRequisition = 4;
const kcPhaseGameOver = 5;
const kcPhasePass = 6;

const kcTransitionCardMoved = 1;
const kcTransitionTrickResolved = 2;
const kcTransitionAssignmentOpened = 3;
const kcTransitionAssignmentTargeted = 4;

const kcObjectZoneNone = 0;
const kcObjectZoneHand = 1;
const kcObjectZonePlotRevealed = 2;
const kcObjectZonePlotHidden = 3;
const kcObjectZoneStackRevealed = 4;
const kcObjectZoneStackHidden = 5;
const kcObjectZoneJobPile = 6;
const kcObjectZoneRevealedJob = 7;
const kcObjectZoneJobBucket = 8;
const kcObjectZoneCurrentTrick = 9;
const kcObjectZoneLastTrick = 10;
const kcObjectZoneExiled = 11;
const kcObjectZonePendingAssignment = 15;

String? engineSuitName(int suit) => switch (suit) {
  0 => 'wheat',
  1 => 'sunflower',
  2 => 'potato',
  3 => 'beet',
  4 => 'wrecker',
  _ => null,
};

const kcControllerExternal = 0;
const kcControllerHeuristicAI = 1;
const kcControllerPolicyAI = 2;
