import 'online_game_models.dart';

class GameEventQueue {
  final List<OnlineActionUpdate> _updates = [];

  int? awaitingPresentationRevision;
  final List<String> pendingAssignmentCardIDs = [];
  List<String> assignmentPresentationCardIDs = const [];
  List<OnlineEngineAction> pendingPresentationLegalActions = const [];
  OnlineSessionUpdate? deferredUpdate;

  bool get isEmpty => _updates.isEmpty;
  bool get isNotEmpty => _updates.isNotEmpty;

  int knownRevision(int presentedRevision) =>
      _updates.isEmpty ? presentedRevision : _updates.last.revision;

  void add(OnlineActionUpdate update) => _updates.add(update);

  void addAll(Iterable<OnlineActionUpdate> updates) => _updates.addAll(updates);

  OnlineActionUpdate? takeNext() =>
      _updates.isEmpty ? null : _updates.removeAt(0);

  void defer(OnlineSessionUpdate update) {
    final current = deferredUpdate;
    if (current == null || update.actionLogCount >= current.actionLogCount) {
      deferredUpdate = update;
    }
  }

  OnlineSessionUpdate? takeDeferred() {
    final update = deferredUpdate;
    deferredUpdate = null;
    return update;
  }

  void clear() {
    _updates.clear();
    awaitingPresentationRevision = null;
    pendingAssignmentCardIDs.clear();
    assignmentPresentationCardIDs = const [];
    pendingPresentationLegalActions = const [];
    deferredUpdate = null;
  }
}
