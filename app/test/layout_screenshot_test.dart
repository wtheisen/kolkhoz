import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_view.dart';

import 'support/layout_scenarios.dart';

class _ScreenshotDevice {
  const _ScreenshotDevice(this.name, this.size, this.renderScale);

  final String name;
  final Size size;
  final double renderScale;
}

const _devices = [
  _ScreenshotDevice('phone_landscape_small', Size(667, 375), 2),
  _ScreenshotDevice('phone_landscape_standard', Size(852, 393), 3),
  _ScreenshotDevice('phone_landscape_large', Size(932, 430), 3),
];

void main() {
  testWidgets('phone landscape layout screenshots', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const SizedBox.shrink());

    for (final scenario in layoutScenarios) {
      for (final device in _devices) {
        final captureSize = Size(
          device.size.width * device.renderScale,
          device.size.height * device.renderScale,
        );
        await tester.binding.setSurfaceSize(captureSize);

        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(
              key: const Key('layout-screenshot'),
              child: Align(
                alignment: Alignment.topLeft,
                child: Transform.scale(
                  scale: device.renderScale,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: device.size.width,
                    height: device.size.height,
                    child: KolkhozBoard(
                      model: scenario.model,
                      tokens: KolkhozAppearance.dark.tokens,
                      language: KolkhozLanguage.en,
                      appearance: KolkhozAppearance.dark,
                      animationSpeed: GameAnimationSpeed.instant,
                      gameLogActions: scenario.gameLogActions,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await expectLater(
          find.byKey(const Key('layout-screenshot')),
          matchesGoldenFile(
            'layout_goldens/${scenario.name}__${device.name}.png',
          ),
        );
      }
    }
  });
}
