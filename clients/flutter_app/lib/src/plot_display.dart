import 'card_display.dart';
import 'game_constants.dart';
import 'render_model.dart';

Set<String> requisitionExiledCardIDs(TableViewModel model) {
  if (model.table.phase != phaseRequisition) {
    return const {};
  }
  return currentYearExiledCardIDs(model);
}

Set<String> hiddenExiledPlotCardIDs(TableViewModel model) {
  if (model.table.phase != phaseRequisition) {
    return const {};
  }
  return currentYearExiledCardIDs(model);
}

Set<String> currentYearExiledCardIDs(TableViewModel model) {
  return {
    for (final card in model.table.exiledByYear[model.table.year] ?? const [])
      card.id,
  };
}

List<TableCard> visiblePlotCards(
  List<TableCard> cards,
  Set<String> hiddenExiledCardIDs,
) {
  return cards
      .where((card) => !hiddenExiledCardIDs.contains(card.id))
      .toList(growable: false);
}

int visiblePlotScore(Seat seat, Set<String> hiddenExiledCardIDs) {
  final hiddenValue = seat.plot.revealed
      .where((card) => hiddenExiledCardIDs.contains(card.id))
      .fold<int>(0, (sum, card) => sum + card.value);
  return seat.visibleScore - hiddenValue;
}

TableCard selectedPlotCard(TableCard card, String? selectedCardID) {
  if (selectedCardID == null || card.id != selectedCardID) {
    return card;
  }
  return cardWithSelection(card, selected: true);
}
