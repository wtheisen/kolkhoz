import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/player_identity.dart';

void main() {
  test('legacy Supabase session migrates exactly once', () {
    expect(
      shouldMigrateLegacySession(
        storedIdentityToken: null,
        legacyAccessToken: 'legacy-token',
        migrationCompleted: false,
      ),
      isTrue,
    );
    expect(
      shouldMigrateLegacySession(
        storedIdentityToken: 'khz-current',
        legacyAccessToken: 'legacy-token',
        migrationCompleted: true,
      ),
      isFalse,
    );
  });

  test('legacy migration retries when its Kolkhoz token is missing', () {
    expect(
      shouldMigrateLegacySession(
        storedIdentityToken: null,
        legacyAccessToken: 'legacy-token',
        migrationCompleted: true,
      ),
      isTrue,
    );
  });

  test('platform authentication retries are bounded', () {
    expect(shouldRetryPlatformAuthentication(1), isTrue);
    expect(shouldRetryPlatformAuthentication(2), isTrue);
    expect(shouldRetryPlatformAuthentication(3), isFalse);
    expect(
      shouldRetryPlatformAuthenticationError(1, 'game_center_timeout'),
      isFalse,
    );
    expect(
      shouldRetryPlatformAuthenticationError(1, 'game_center_authentication'),
      isTrue,
    );
  });

  final runtime = KolkhozIdentityRuntime.instance;

  Widget subject() => MaterialApp(
    home: Scaffold(
      body: PlayerIdentityPanel(
        tokens: defaultDesignTokens,
        displayName: 'Comrade',
        onDeleteAccount: () async {},
      ),
    ),
  );

  tearDown(() {
    runtime.setTestState(
      identity: const KolkhozPlayerIdentity(
        id: 'guest',
        displayName: 'Comrade',
        guest: true,
        portable: false,
      ),
      busyState: false,
    );
  });

  testWidgets('shows Game Center connected identity', (tester) async {
    runtime.setTestState(
      identity: const KolkhozPlayerIdentity(
        id: 'player-apple',
        displayName: 'Misha',
        guest: false,
        portable: true,
        provider: 'game_center',
      ),
    );
    await tester.pumpWidget(subject());
    expect(find.text('GAME CENTER — CONNECTED'), findsOneWidget);
    expect(find.textContaining('player-apple'), findsOneWidget);
  });

  testWidgets('shows Play Games connected identity', (tester) async {
    runtime.setTestState(
      identity: const KolkhozPlayerIdentity(
        id: 'player-android',
        displayName: 'Nadia',
        guest: false,
        portable: true,
        provider: 'play_games',
      ),
    );
    await tester.pumpWidget(subject());
    expect(find.text('GOOGLE PLAY GAMES — CONNECTED'), findsOneWidget);
  });

  testWidgets('shows guest recovery warning and link actions', (tester) async {
    runtime.setTestState(
      identity: const KolkhozPlayerIdentity(
        id: 'guest-player',
        displayName: 'Guest',
        guest: true,
        portable: false,
      ),
      statusMessage: 'Guest progress may be lost if this app is deleted.',
    );
    await tester.pumpWidget(subject());
    expect(find.text('DEVICE-ONLY GUEST'), findsOneWidget);
    expect(find.textContaining('may be lost'), findsOneWidget);
    expect(find.byKey(const Key('link-another-device')), findsOneWidget);
    expect(find.byKey(const Key('enter-device-link-code')), findsOneWidget);
  });

  testWidgets(
    'link code dialog remains available while authentication is busy',
    (tester) async {
      runtime.setTestState(
        identity: null,
        statusMessage: 'Connecting…',
        busyState: true,
      );
      await tester.pumpWidget(subject());

      await tester.tap(find.byKey(const Key('enter-device-link-code')));
      await tester.pump();

      expect(find.text('ENTER OR SCAN LINK CODE'), findsOneWidget);
      expect(find.byKey(const Key('device-link-code-field')), findsOneWidget);
    },
  );

  test('maps every link UI state', () {
    for (final state in const {
      PlayerIdentityLinkState.pending,
      PlayerIdentityLinkState.expired,
      PlayerIdentityLinkState.conflict,
      PlayerIdentityLinkState.approved,
      PlayerIdentityLinkState.error,
      PlayerIdentityLinkState.cancelled,
    }) {
      runtime.setTestState(state: state);
      expect(runtime.linkState, state);
    }
  });
}
