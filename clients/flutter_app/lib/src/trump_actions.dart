import 'app_settings.dart';
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

List<TrumpActionOption> planningTrumpOptions(
  List<LegalAction> actions, {
  KolkhozLanguage? language,
}) {
  final bySuit = {
    for (final action in actions)
      if (action.kind == actionSetTrump && action.engineAction.suit != null)
        action.engineAction.suit!: action,
  };
  return displaySuitOrder
      .map(
        (suit) => TrumpActionOption(
          suit: suit,
          label: (language ?? KolkhozLanguage.en).suitName(suit),
          action: bySuit[suit],
        ),
      )
      .toList(growable: false);
}
