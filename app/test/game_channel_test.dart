import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/c_engine_action_codec.dart';
import 'package:kolkhoz_app/src/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/game_channel.dart';
import 'package:kolkhoz_app/src/game_channel_local.dart';
import 'package:kolkhoz_app/src/game_engine.dart';

void main() {
  test(
    'local channel applies portable commands and publishes results',
    () async {
      final channel = LocalGameChannel(
        GameEngine(
          bridge: KolkhozCEngineBridge(),
          seed: 20260721,
          variants: KolkhozGameVariants.kolkhoz,
          controllers: const [
            KolkhozPlayerController.human,
            KolkhozPlayerController.human,
            KolkhozPlayerController.human,
            KolkhozPlayerController.human,
          ],
        ),
      );
      addTearDown(channel.dispose);
      final events = <GameEvent>[];
      final subscription = channel.events.listen(events.add);
      addTearDown(subscription.cancel);

      final action = engineActionFromCValue(channel.legalActions.single);
      await channel.send(
        SubmitGameAction(
          action: action,
          source: GameActionSource.centralPlanner,
        ),
      );

      expect(events, hasLength(1));
      final result = events.single as LocalGameCommandResult;
      expect(result.command, isA<SubmitGameAction>());
      expect(result.accepted, isTrue);
      expect(result.stateChanged, isTrue);
    },
  );
}
