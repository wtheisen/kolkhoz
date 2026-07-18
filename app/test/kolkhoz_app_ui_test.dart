import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app_settings.dart';
import 'package:kolkhoz_app/src/kolkhoz_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('account email normalization preserves plus-address tags', () {
    expect(
      normalizeAccountEmail('  tester+tag@example.com  '),
      'tester+tag@example.com',
    );
    expect(maxAccountEmailLength, 254);
  });

  test('account auth errors are actionable without exposing the email', () {
    const enteredEmail = 'tester+tag@example.com';
    const exception = AuthApiException(
      'Invalid email: $enteredEmail',
      statusCode: '400',
      code: 'validation_failed',
    );

    final message = safeAccountErrorMessage(exception, KolkhozLanguage.en);

    expect(message, 'Enter a valid email address, including any + tag.');
    expect(message, isNot(contains(enteredEmail)));
  });

  test('account auth errors explain common recovery actions', () {
    expect(
      safeAccountErrorMessage(
        const AuthApiException(
          'User already registered',
          statusCode: '422',
          code: 'user_already_exists',
        ),
        KolkhozLanguage.en,
      ),
      contains('Sign in or reset the password'),
    );
    expect(
      safeAccountErrorMessage(
        const AuthApiException(
          'Too many requests',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
        KolkhozLanguage.en,
      ),
      contains('Wait a few minutes'),
    );
  });

  test('online play requires both full-game access and an account', () {
    expect(
      canAccessOnlinePlay(fullGameUnlocked: true, signedIn: false),
      isFalse,
    );
    expect(
      canAccessOnlinePlay(fullGameUnlocked: false, signedIn: true),
      isFalse,
    );
    expect(canAccessOnlinePlay(fullGameUnlocked: true, signedIn: true), isTrue);
  });

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
