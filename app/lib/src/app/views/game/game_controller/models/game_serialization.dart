import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

Map<String, Object?> variantsToJson(KolkhozGameVariants variants) {
  return {
    'deckType': variants.deckType,
    'maxYears': variants.maxYears,
    'nomenclature': variants.nomenclature,
    'allowSwap': variants.allowSwap,
    'northernStyle': variants.northernStyle,
    'miceVariant': variants.miceVariant,
    'ordenNachalniku': variants.ordenNachalniku,
    'medalsCount': variants.medalsCount,
    'accumulateJobs': variants.accumulateJobs,
    'heroOfSovietUnion': variants.heroOfSovietUnion,
    'wrecker': variants.wreckerCard,
    'finalYearTrump': variants.finalYearTrump,
    'passCards': variants.passCards,
    'highestCardsRequisition': variants.highestCardsRequisition,
    'lottoRewards': variants.lottoRewards,
  };
}

KolkhozGameVariants variantsFromJson(Map<String, Object?> json) {
  return KolkhozGameVariants(
    deckType: json['deckType'] as int,
    maxYears: json['maxYears'] as int? ?? 5,
    nomenclature: json['nomenclature'] as bool,
    allowSwap: json['allowSwap'] as bool,
    northernStyle: json['northernStyle'] as bool,
    miceVariant: json['miceVariant'] as bool,
    ordenNachalniku: json['ordenNachalniku'] as bool,
    medalsCount: json['medalsCount'] as bool,
    accumulateJobs: json['accumulateJobs'] as bool,
    heroOfSovietUnion: json['heroOfSovietUnion'] as bool,
    wreckerCard: json['wrecker'] as bool? ?? false,
    finalYearTrump: json['finalYearTrump'] as bool? ?? false,
    passCards: json['passCards'] as bool? ?? false,
    highestCardsRequisition: json['highestCardsRequisition'] as bool? ?? false,
    lottoRewards: json['lottoRewards'] as bool? ?? false,
  );
}

KolkhozPlayerController controllerFromJson(Object? value) {
  if (value is! String) {
    throw const FormatException('Invalid player controller');
  }
  for (final controller in KolkhozPlayerController.values) {
    if (controller.name == value) {
      return controller;
    }
  }
  throw const FormatException('Unknown player controller');
}

Map<String, Object?> engineActionToJson(EngineAction action) {
  return {
    'kind': action.kind,
    'playerID': action.playerID,
    if (action.suit != null) 'suit': action.suit,
    if (action.card != null) 'card': engineCardToJson(action.card!),
    if (action.handCard != null) 'handCard': engineCardToJson(action.handCard!),
    if (action.plotCard != null) 'plotCard': engineCardToJson(action.plotCard!),
    if (action.plotZone != null) 'plotZone': action.plotZone,
    if (action.targetSuit != null) 'targetSuit': action.targetSuit,
    if (action.requisitionKind != null)
      'requisitionKind': action.requisitionKind,
  };
}

EngineAction engineActionFromJson(Map<String, Object?> json) {
  return EngineAction(
    kind: json['kind'] as String,
    playerID: json['playerID'] as int,
    suit: json['suit'] as String?,
    card: optionalEngineCardFromJson(json['card']),
    handCard: optionalEngineCardFromJson(json['handCard']),
    plotCard: optionalEngineCardFromJson(json['plotCard']),
    plotZone: json['plotZone'] as String?,
    targetSuit: json['targetSuit'] as String?,
    requisitionKind: json['requisitionKind'] as int?,
  );
}

Map<String, Object?> engineCardToJson(EngineCard card) {
  return {'suit': card.suit, 'value': card.value};
}

EngineCard? optionalEngineCardFromJson(Object? value) {
  if (value == null) {
    return null;
  }
  final json = jsonObject(value);
  final suit = json['suit'] as String;
  final cardValue = json['value'] as int;
  return EngineCard(
    suit: suit,
    value: suit == 'wrecker' && cardValue == 14 ? 0 : cardValue,
  );
}
