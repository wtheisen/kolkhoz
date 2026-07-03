import 'c_engine_bridge.dart';
import 'engine_action_projection.dart';
import 'render_model.dart';

CEngineActionValue? cEngineAction(EngineAction action) {
  final kind = actionKindCode(action.kind);
  if (kind == null) {
    return null;
  }
  return CEngineActionValue(
    kind: kind,
    playerID: action.playerID,
    suit: suitCode(action.suit) ?? -1,
    card: cEngineCard(action.card),
    handCard: cEngineCard(action.handCard),
    plotCard: cEngineCard(action.plotCard),
    plotZone: plotZoneCode(action.plotZone) ?? -1,
    targetSuit: suitCode(action.targetSuit) ?? -1,
  );
}

EngineCardValue cEngineCard(EngineCard? card) {
  if (card == null) {
    return const EngineCardValue(suit: -1, value: 0);
  }
  return EngineCardValue(suit: suitCode(card.suit) ?? -1, value: card.value);
}
