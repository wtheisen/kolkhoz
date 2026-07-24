import 'dart:collection';

import 'package:kolkhoz_app/src/app/views/game/game_controller/game_presentation_transition.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';

/// Owns the ordered, one-at-a-time presentation of authoritative game updates.
///
/// The engine may publish several updates while the UI is still animating an
/// earlier one. This queue keeps those updates ordered without making the game
/// controller manage transition IDs and list state itself.
class GamePresentationQueue {
  final Queue<GamePresentationTransition> _pending = Queue();
  GamePresentationTransition? _current;
  int _nextID = 0;

  GamePresentationTransition? get current => _current;
  bool get isBusy => _current != null || _pending.isNotEmpty;
  int get pendingCount => _pending.length;

  GamePresentationTransition enqueue({
    required TableViewModel before,
    required TableViewModel after,
    EngineAction? action,
    EngineTransitionEvent? event,
    List<String> assignmentCardIDs = const [],
    Map<String, String> assignmentTargets = const {},
    Set<String> suppressedCardIDs = const {},
  }) {
    final transition = GamePresentationTransition(
      id: ++_nextID,
      before: before,
      after: after,
      action: action,
      event: event,
      assignmentCardIDs: assignmentCardIDs,
      assignmentTargets: assignmentTargets,
      suppressedCardIDs: suppressedCardIDs,
    );
    if (_current == null) {
      _current = transition;
    } else {
      _pending.add(transition);
    }
    return transition;
  }

  bool complete(int transitionID) {
    if (_current?.id != transitionID) {
      return false;
    }
    _current = _pending.isEmpty ? null : _pending.removeFirst();
    return true;
  }

  void clear() {
    _current = null;
    _pending.clear();
  }
}
