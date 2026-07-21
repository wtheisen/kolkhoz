import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/game_engine.dart';

void main() {
  test('GameEngine exclusively owns native lifecycle and clones', () {
    final bridge = KolkhozCEngineBridge();
    final engine = GameEngine(
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
}
