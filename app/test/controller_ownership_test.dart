import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/navigation/app_navigation_controller.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/player_identity.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/profile_controller.dart';
import 'package:kolkhoz_app/src/app/remote_connection/remote_connection.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/main_menu_controller.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_connection.dart';

RemoteConnection testConnection(RemoteRequestHandler handler) =>
    RemoteConnection(
      baseURL: Uri.parse('https://example.invalid'),
      accessTokenProvider: () async => 'token',
      deviceID: 'test-device',
      activeSessionID: () => null,
      requestHandler: handler,
    );

void main() {
  test('application navigation owns destinations and return routing', () {
    final navigation = AppNavigationController();
    addTearDown(navigation.dispose);

    navigation.showProfile(section: AppSettingsSection.display);
    expect(navigation.destination, AppDestination.profile);
    expect(navigation.settingsSection, AppSettingsSection.display);

    navigation.showGame(
      launchOrigin: KolkhozGameLaunchOrigin.joined,
      tutorial: true,
    );
    expect(navigation.destination, AppDestination.game);
    expect(navigation.showingTutorial, isTrue);

    navigation.closeTutorial();
    navigation.returnFromGame();
    expect(navigation.destination, AppDestination.online);
    expect(navigation.showingTutorial, isFalse);
  });

  test('main menu controller owns invitation polling and dismissal', () async {
    var declines = 0;
    final remote = testConnection((method, path, query, headers, body) async {
      if (method == 'GET' && path == 'sessions/invites') {
        return [
          {
            'sessionID': 'session-1',
            'openSeats': [1, 2, 3],
            'occupiedSeats': [0],
            'controllers': ['human', 'human', 'human', 'human'],
            'createdAt': 1.0,
            'expiresAt': 2.0,
          },
        ];
      }
      if (method == 'POST' && path.endsWith('/invites/decline')) {
        declines += 1;
        return <String, Object?>{};
      }
      throw StateError('Unexpected request: $method $path');
    });
    final controller = MainMenuController(
      remoteMenu(remote),
      () => true,
      () => null,
    );
    addTearDown(controller.dispose);
    addTearDown(remote.dispose);

    await controller.pollInvites();
    expect(controller.pendingInvite?.sessionID, 'session-1');

    controller.dismissPendingInvite('session-1');
    await Future<void>.delayed(Duration.zero);
    expect(controller.pendingInvite, isNull);
    expect(declines, 1);

    await controller.pollInvites();
    expect(controller.pendingInvite, isNull);
  });

  test('main menu controller owns browser and population state', () async {
    final remote = testConnection((method, path, query, headers, body) async {
      if (method == 'GET' && path == 'sessions') {
        return [
          {
            'sessionID': 'session-1',
            'inviteCode': 'ABCDE',
            'openSeats': [1, 2, 3],
            'occupiedSeats': [0],
            'controllers': ['human', 'human', 'human', 'human'],
            'actionLogCount': 0,
            'createdAt': 1.0,
            'expiresAt': 2.0,
          },
        ];
      }
      if (method == 'GET' && path == 'sessions/watchable') return [];
      if (method == 'GET' && path == 'metrics') {
        return {
          'service': {'citizensOnline': 9},
        };
      }
      throw StateError('Optional endpoint unavailable: $method $path');
    });
    final controller = MainMenuController(
      remoteMenu(remote),
      () => true,
      () => null,
    );
    addTearDown(controller.dispose);
    addTearDown(remote.dispose);

    await controller.refreshBrowser();

    expect(controller.openSessions.single.sessionID, 'session-1');
    expect(controller.citizensOnline, 9);
    expect(controller.browserError, isNull);
  });

  test('profile controller owns scheduled saves and comrades state', () async {
    Map<String, Object?>? savedProfile;
    final remote = testConnection((method, path, query, headers, body) async {
      if (method == 'PATCH' && path == 'profile') {
        savedProfile = (body! as Map).cast<String, Object?>();
        return {
          'userID': 'user-1',
          'displayName': savedProfile!['displayName'],
          'avatarURL': savedProfile!['portraitAsset'],
        };
      }
      if (method == 'GET' && path == 'comrades') {
        return {
          'userID': 'user-1',
          'comradeCode': 'ABCDE',
          'comrades': [
            {'userID': 'user-2', 'displayName': 'Mira'},
          ],
        };
      }
      if (method == 'GET' && path == 'results/recent') {
        return {
          'games': [
            {
              'sessionID': 'game-1',
              'playerID': 0,
              'score': 42,
              'rank': 1,
              'won': true,
              'ranked': false,
              'completedAt': 10.0,
            },
          ],
        };
      }
      throw StateError('Unexpected request: $method $path');
    });
    final identity = KolkhozIdentityRuntime.instance
      ..setTestState(
        identity: const KolkhozPlayerIdentity(
          id: 'user-1',
          displayName: 'Old Name',
          guest: false,
          portable: true,
        ),
      );
    final controller = ProfileController(
      connection: remote,
      identityRuntime: identity,
    );
    addTearDown(() {
      controller.dispose();
      remote.dispose();
      identity.setTestState(identity: null);
    });

    controller.scheduleCurrentProfileSave(
      displayName: 'New Name',
      portraitAsset: 'worker2',
      loadingMessage: 'Saving',
      successMessage: 'Saved',
      errorMessage: 'Failed',
      delay: Duration.zero,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(savedProfile?['displayName'], 'New Name');
    expect(controller.message, 'Saved');

    await controller.refreshComrades();
    expect(controller.comrades.userID, 'user-1');
    expect(controller.comrades.comrades.single.userID, 'user-2');

    await controller.loadRecentGames();
    expect(controller.recentGames.single.sessionID, 'game-1');
    expect(controller.recentGamesError, isNull);
  });
}

MenuRemoteConnection remoteMenu(RemoteConnection remote) =>
    MenuRemoteConnection(remote);
