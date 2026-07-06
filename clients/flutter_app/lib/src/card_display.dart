import 'game_constants.dart';
import 'render_model.dart';

TableCard cardWithSelection(
  TableCard card, {
  bool? selected,
  bool? highlighted,
}) {
  return TableCard(
    id: card.id,
    suit: card.suit,
    value: card.value,
    rank: card.rank,
    selected: selected ?? card.selected,
    highlighted: highlighted ?? card.highlighted,
    pending: card.pending,
    nomenclature: card.nomenclature,
  );
}

int compareCardsForHand(TableCard lhs, TableCard rhs) {
  final lhsSuit = suitSortIndex(lhs.suit);
  final rhsSuit = suitSortIndex(rhs.suit);
  if (lhsSuit != rhsSuit) {
    return lhsSuit.compareTo(rhsSuit);
  }
  return lhs.value.compareTo(rhs.value);
}

int suitSortIndex(String suit) {
  final index = displaySuitOrder.indexOf(suit);
  return index == -1 ? displaySuitOrder.length : index;
}
