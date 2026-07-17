import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app_settings.dart';
import 'package:kolkhoz_app/src/kolkhoz_app.dart';

void main() {
  test('completed local game returns to the standalone lobby', () {
    expect(
      shouldShowStandaloneLobby(
        hasModel: true,
        showingLobby: true,
        isOnlineGame: false,
        onlineStarted: false,
      ),
      isTrue,
    );
    expect(
      shouldShowStandaloneLobby(
        hasModel: true,
        showingLobby: false,
        isOnlineGame: false,
        onlineStarted: false,
      ),
      isFalse,
    );
  });

  testWidgets('notification offer follows selected appearance tokens', (
    tester,
  ) async {
    for (final appearance in KolkhozAppearance.values) {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showPushNotificationOffer(
                  context: context,
                  tokens: appearance.tokens,
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, appearance.tokens.colors.panel);
      expect(dialog.titleTextStyle?.color, appearance.tokens.colors.gold);
      expect(dialog.contentTextStyle?.color, appearance.tokens.colors.cream);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    }
  });
}
