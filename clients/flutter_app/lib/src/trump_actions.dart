import 'game_constants.dart';
import 'render_model.dart';

class TrumpActionOption {
  const TrumpActionOption({
    required this.suit,
    required this.label,
    required this.action,
  });

  final String suit;
  final String label;
  final LegalAction? action;

  bool get enabled => action != null;
}

List<LegalAction> legalTrumpActions(List<LegalAction> actions) {
  return actions
      .where((action) => action.kind == actionSetTrump)
      .toList(growable: false);
}

List<LegalAction> orderedTrumpActions(List<LegalAction> actions) {
  final bySuit = {
    for (final action in actions)
      if (action.engineAction.suit != null) action.engineAction.suit!: action,
  };
  return displaySuitOrder
      .map((suit) => bySuit[suit])
      .whereType<LegalAction>()
      .toList(growable: false);
}

List<TrumpActionOption> planningTrumpOptions(List<LegalAction> actions) {
  final bySuit = {
    for (final action in actions)
      if (action.engineAction.suit != null) action.engineAction.suit!: action,
  };
  return displaySuitOrder
      .map((suit) => trumpActionOption(suit, bySuit[suit]))
      .toList(growable: false);
}

TrumpActionOption trumpActionOption(String suit, LegalAction? action) {
  return TrumpActionOption(
    suit: suit,
    label: action?.label ?? trumpActionLabel(suit),
    action: action,
  );
}

String trumpActionLabel(String suit) {
  return switch (suit) {
    'wheat' => 'Wheat',
    'sunflower' => 'Sunflower',
    'potato' => 'Potato',
    'beet' => 'Beet',
    _ => suit,
  };
}
