import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/design_tokens.dart';
import 'package:kolkhoz_app/src/player_identity.dart';

void main() {
  test('legacy Supabase session wins during one-time identity migration', () {
    expect(
      playerIdentityBootstrapToken(
        storedIdentityToken: 'khz_previous',
        legacyAccessToken: 'supabase_existing',
      ),
      'supabase_existing',
    );
    expect(
      playerIdentityBootstrapToken(
        storedIdentityToken: 'khz_returning',
        legacyAccessToken: null,
      ),
      'khz_returning',
    );
  });

  test('platform authentication retries are bounded', () {
    expect(shouldRetryPlatformAuthentication(1), isTrue);
    expect(shouldRetryPlatformAuthentication(2), isTrue);
    expect(shouldRetryPlatformAuthentication(3), isFalse);
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
      ),
    );
  });

  testWidgets('shows Game Center connected identity', (tester) async {
    runtime.setTestState(
      identity: const KolkhozPlayerIdentity(
        id: 'player-apple',
        displayName: 'Misha',
        guest: false,
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
      ),
      statusMessage: 'Guest progress may be lost if this app is deleted.',
    );
    await tester.pumpWidget(subject());
    expect(find.text('GUEST — LOCAL DEVICE ONLY'), findsOneWidget);
    expect(find.textContaining('may be lost'), findsOneWidget);
    expect(find.byKey(const Key('link-another-device')), findsOneWidget);
    expect(find.byKey(const Key('enter-device-link-code')), findsOneWidget);
  });

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
