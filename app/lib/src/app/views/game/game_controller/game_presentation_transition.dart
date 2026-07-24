import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';

class GamePresentationTransition {
  const GamePresentationTransition({
    required this.id,
    required this.before,
    required this.after,
    this.action,
    this.event,
    this.assignmentCardIDs = const [],
    this.assignmentTargets = const {},
    this.suppressedCardIDs = const {},
  });

  final int id;
  final TableViewModel before;
  final TableViewModel after;
  final EngineAction? action;
  final EngineTransitionEvent? event;
  final List<String> assignmentCardIDs;
  final Map<String, String> assignmentTargets;
  final Set<String> suppressedCardIDs;
}
