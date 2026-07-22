import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/profile_remote_connection.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/profile_controller.dart';
import 'package:kolkhoz_app/src/app/remote_connection/remote_connection.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_connection.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/main_menu_controller.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/app.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/shared/pixel_text.dart';

class _ScreenshotDevice {
  const _ScreenshotDevice(this.name, this.size, this.renderScale);

  final String name;
  final Size size;
  final double renderScale;
}

class _LobbyScenario {
  const _LobbyScenario(
    this.name, {
    this.showingRules = false,
    this.showingOnline = false,
    this.showingProfile = false,
    this.settingsTab = KolkhozSettingsTab.profile,
    this.openPlayerSetup = false,
  });

  final String name;
  final bool showingRules;
  final bool showingOnline;
  final bool showingProfile;
  final KolkhozSettingsTab settingsTab;
  final bool openPlayerSetup;
}

const _devices = [
  _ScreenshotDevice('phone_landscape_small', Size(667, 375), 2),
  _ScreenshotDevice('phone_landscape_standard', Size(852, 393), 3),
  _ScreenshotDevice('phone_landscape_large', Size(932, 430), 3),
];

const _scenarios = [
  _LobbyScenario('lobby_create_game'),
  _LobbyScenario('lobby_add_players', openPlayerSetup: true),
  _LobbyScenario('lobby_online', showingOnline: true),
  _LobbyScenario('lobby_how_to_play', showingRules: true),
  _LobbyScenario(
    'lobby_profile',
    showingProfile: true,
    settingsTab: KolkhozSettingsTab.profile,
  ),
  _LobbyScenario(
    'lobby_comrades',
    showingProfile: true,
    settingsTab: KolkhozSettingsTab.comrades,
  ),
  _LobbyScenario(
    'lobby_progress',
    showingProfile: true,
    settingsTab: KolkhozSettingsTab.progress,
  ),
  _LobbyScenario(
    'lobby_assist_settings',
    showingProfile: true,
    settingsTab: KolkhozSettingsTab.assist,
  ),
  _LobbyScenario(
    'lobby_display_settings',
    showingProfile: true,
    settingsTab: KolkhozSettingsTab.display,
  ),
  _LobbyScenario(
    'lobby_rules_settings',
    showingProfile: true,
    settingsTab: KolkhozSettingsTab.rules,
  ),
];

const _comrades = OnlineComradesResponse(
  userID: 'nadia',
  comradeCode: 'NADIA',
  comrades: [
    OnlineComradeProfile(
      userID: 'boris',
      displayName: 'Boris',
      avatarURL: 'worker2',
      comradeCode: 'BORIS',
      isOnline: true,
      inLobby: true,
    ),
    OnlineComradeProfile(
      userID: 'irina',
      displayName: 'Irina',
      avatarURL: 'worker3',
      comradeCode: 'IRINA',
      isOnline: true,
      inGame: true,
    ),
  ],
  incomingRequests: [
    OnlineComradeProfile(
      userID: 'mikhail',
      displayName: 'Mikhail',
      avatarURL: 'worker4',
      comradeCode: 'MIKHA',
    ),
  ],
);

void main() {
  testWidgets('phone landscape lobby screenshots', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PixelFontAtlasCache.instance.resetForTesting();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      final handjet = FontLoader('Handjet')
        ..addFont(rootBundle.load('assets/ui/Fonts/Handjet.ttf'));
      await Future.wait([
        handjet.load(),
        for (final variant in PixelTextVariant.values)
          for (final size in PixelTextSize.values)
            PixelFontAtlasCache.instance.load(variant: variant, size: size),
      ]);
    });

    for (final scenario in _scenarios) {
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
            theme: ThemeData(
              fontFamily: 'Handjet',
              textTheme: ThemeData.dark().textTheme.apply(
                fontFamily: 'Handjet',
              ),
            ),
            home: RepaintBoundary(
              key: const Key('lobby-layout-screenshot'),
              child: Align(
                alignment: Alignment.topLeft,
                child: Transform.scale(
                  scale: device.renderScale,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: device.size.width,
                    height: device.size.height,
                    child: _lobby(scenario),
                  ),
                ),
              ),
            ),
          ),
        );

        if (scenario.openPlayerSetup) {
          await tester.tap(find.bySemanticsLabel('ADD PLAYERS'));
          await tester.pump(const Duration(milliseconds: 300));
        }

        await tester.pump();

        await expectLater(
          find.byKey(const Key('lobby-layout-screenshot')),
          matchesGoldenFile(
            'layout_goldens/${scenario.name}__${device.name}.png',
          ),
        );
      }
    }
  });
}

Widget _lobby(_LobbyScenario scenario) {
  return StandaloneLobby(
    tokens: KolkhozAppearance.dark.tokens,
    language: KolkhozLanguage.en,
    appearance: KolkhozAppearance.dark,
    onStart: () {},
    selectedPreset: KolkhozGamePreset.kolkhoz,
    customVariants: KolkhozGameVariants.kolkhoz,
    playerControllers: KolkhozPlayerController.defaultControllers,
    showingRules: scenario.showingRules,
    showingOnline: scenario.showingOnline,
    showingProfile: scenario.showingProfile,
    initialSettingsTab: scenario.settingsTab,
    displayName: 'Nadia',
    portraitAsset: 'worker1',
    profileStats: const KolkhozProfileStats(
      offlinePlays: 12,
      offlineWins: 8,
      onlinePlays: 7,
      onlineWins: 4,
      casualRating: 1084,
      rating: 1142,
      totalWins: 12,
      totalLosses: 7,
    ),
    comradesSummary: _comrades,
    cloudConfigured: true,
    cloudReady: true,
    cloudSignedIn: true,
    cloudEmail: 'nadia@example.com',
    cloudAuthMessage: 'Profile loaded.',
    onHostOnline: (_, _, _, _, _) async => 'ABCDE',
    onJoinOnline: (_, _, _) async {},
    onMatchmakeOnline: (_, _, _) async => 'ABCDE',
    onEnterOnlineGame: () {},
    onPresetChanged: (_) {},
    onCustomVariantsChanged: (_) {},
    onPlayerControllersChanged: (_) {},
    onRulesPressed: () {},
    onOfflinePressed: () {},
    onOnlinePressed: () {},
    onTutorialPressed: () {},
    onLanguageToggle: () {},
    onAppearanceToggle: () {},
    menuRemoteConnection: _ScreenshotMenuRemoteConnection(),
    mainMenuController: MainMenuController(
      _ScreenshotMenuRemoteConnection(),
      () => true,
      () => null,
    ),
    profileController: ProfileController(
      connection: _screenshotRemoteConnection(),
      remoteConnection: _ScreenshotProfileRemoteConnection(),
    ),
  );
}

RemoteConnection _screenshotRemoteConnection() => RemoteConnection(
  baseURL: Uri.parse('http://screenshot.invalid'),
  accessTokenProvider: () async => null,
  deviceID: '',
  activeSessionID: () => null,
);

class _ScreenshotMenuRemoteConnection extends MenuRemoteConnection {
  _ScreenshotMenuRemoteConnection() : super(_screenshotRemoteConnection());

  @override
  Future<List<OnlineSessionListing>> fetchSessions() async => const [
    OnlineSessionListing(
      sessionID: 'session-one',
      openSeats: [2, 3],
      occupiedSeats: [0, 1],
      controllers: KolkhozPlayerController.defaultControllers,
      playerProfiles: [
        OnlinePlayerProfile(
          playerID: 0,
          userID: 'mira',
          displayName: 'Mira',
          avatarURL: 'worker3',
        ),
        OnlinePlayerProfile(
          playerID: 1,
          userID: 'boris',
          displayName: 'Boris',
          avatarURL: 'worker2',
        ),
      ],
      ranked: false,
      actionLogCount: 18,
      createdAt: 1,
      expiresAt: 9999999999,
    ),
  ];

  @override
  Future<OnlineServerStatus> fetchServerStatus() async =>
      const OnlineServerStatus(citizensOnline: 16);
}

class _ScreenshotProfileRemoteConnection extends ProfileRemoteConnection {
  _ScreenshotProfileRemoteConnection() : super(_screenshotRemoteConnection());

  @override
  Future<OnlineComradesResponse> fetchComrades() async => _comrades;
}
