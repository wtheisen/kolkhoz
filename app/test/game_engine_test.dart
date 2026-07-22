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
}
