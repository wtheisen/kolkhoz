import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/app.dart';

void main() {
  testWidgets('active-session overlay exposes only the sync action', (
    tester,
  ) async {
    var synced = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const Scaffold(body: Text('Underlying screen')),
            Positioned.fill(
              child: ActiveSessionSyncOverlay(
                tokens: defaultDesignTokens,
                busy: false,
                onSync: () => synced = true,
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.text('GAME ACTIVE ON ANOTHER DEVICE'), findsOneWidget);
    expect(find.text('SYNC VIEW'), findsOneWidget);
    await tester.tap(find.text('SYNC VIEW'));
    expect(synced, isTrue);
  });

  testWidgets('active-session overlay fits a phone-sized screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ActiveSessionSyncOverlay(
          tokens: defaultDesignTokens,
          busy: true,
          onSync: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('SYNCING…'), findsOneWidget);
  });
}
