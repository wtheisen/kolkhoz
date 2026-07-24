import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/native_game_engine.dart';

void main() {
  test('NativeGameEngine exclusively owns native lifecycle and clones', () {
    final bridge = KolkhozCEngineBridge();
    final engine = NativeGameEngine(
      bridge: bridge,
      seed: 20260721,
      variants: KolkhozGameVariants.kolkhoz,
      controllers: const [
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
      ],
    );
    final clone = engine.clone();
    final phase = engine.phase;

    expect(engine.seed, 20260721);
    expect(engine.variants, KolkhozGameVariants.kolkhoz);
    expect(engine.controllers, hasLength(4));
    expect(
      () => engine.controllers[0] = KolkhozPlayerController.neuralAI,
      throwsUnsupportedError,
    );

    engine.dispose();
    engine.dispose();

    expect(() => engine.phase, throwsStateError);
    expect(clone.phase, phase);
    clone.dispose();
  });

  test('final trick card returns ordered rule transitions in one dispatch', () {
    final bridge = KolkhozCEngineBridge();
    final engine = NativeGameEngine(
      bridge: bridge,
      seed: 20260723,
      variants: KolkhozGameVariants.kolkhoz,
      controllers: const [
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
      ],
    );
    addTearDown(engine.dispose);

    while (engine.phase != kcPhaseTrick) {
      final actions = engine.legalActions;
      expect(actions, isNotEmpty);
      expect(engine.applyManual(actions.first), 0);
    }

    for (var play = 0; play < 4; play++) {
      final actions = engine.legalActions
          .where((action) => action.kind == kcActionPlayCard)
          .toList();
      expect(actions, isNotEmpty);
      expect(engine.applyManual(actions.first), 0);
      if (play < 3) {
        final currentWinner = engine.readNative(
          (bridge, pointer) => bridge.currentTrickWinner(pointer),
        );
        expect(
          currentWinner,
          isNot(-1),
          reason: 'the in-progress trick needs a visible leader',
        );
        expect(engine.transitionEvents.single.trickWinnerID, currentWinner);
      }
    }

    expect(
      engine.transitionEvents.map((event) => event.kind),
      containsAllInOrder([
        kcTransitionCardMoved,
        kcTransitionTrickResolved,
        kcTransitionAssignmentOpened,
      ]),
    );
    expect(engine.transitionEvents.first.fromZone, kcObjectZoneHand);
    expect(engine.transitionEvents.first.toZone, kcObjectZoneCurrentTrick);
  });
}
