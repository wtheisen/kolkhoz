import 'package:flutter/foundation.dart';

enum AppDestination { offline, rules, online, profile, game }

enum KolkhozGameLaunchOrigin {
  created,
  joined;

  bool get returnsToJoinGame => this == KolkhozGameLaunchOrigin.joined;
}

enum AppSettingsSection {
  profile,
  leaderboard,
  progress,
  comrades,
  admin,
  assist,
  display,
  rules,
}

class AppNavigationController extends ChangeNotifier {
  AppDestination _destination = AppDestination.offline;
  KolkhozGameLaunchOrigin _gameLaunchOrigin = KolkhozGameLaunchOrigin.created;
  AppSettingsSection _settingsSection = AppSettingsSection.profile;
  bool _showingTutorial = false;

  AppDestination get destination => _destination;
  KolkhozGameLaunchOrigin get gameLaunchOrigin => _gameLaunchOrigin;
  AppSettingsSection get settingsSection => _settingsSection;
  bool get showingTutorial => _showingTutorial;

  void showOffline({KolkhozGameLaunchOrigin? launchOrigin}) => _navigate(
    AppDestination.offline,
    launchOrigin: launchOrigin,
    showingTutorial: false,
  );

  void showRules() => _navigate(AppDestination.rules, showingTutorial: false);

  void showOnline({KolkhozGameLaunchOrigin? launchOrigin}) => _navigate(
    AppDestination.online,
    launchOrigin: launchOrigin,
    showingTutorial: false,
  );

  void showProfile({AppSettingsSection section = AppSettingsSection.profile}) =>
      _navigate(
        AppDestination.profile,
        settingsSection: section,
        showingTutorial: false,
      );

  void showGame({
    KolkhozGameLaunchOrigin? launchOrigin,
    bool tutorial = false,
  }) => _navigate(
    AppDestination.game,
    launchOrigin: launchOrigin,
    showingTutorial: tutorial,
  );

  void returnFromGame() {
    if (_gameLaunchOrigin.returnsToJoinGame) {
      showOnline();
    } else {
      showOffline();
    }
  }

  void closeTutorial() {
    if (!_showingTutorial) return;
    _showingTutorial = false;
    notifyListeners();
  }

  void _navigate(
    AppDestination destination, {
    KolkhozGameLaunchOrigin? launchOrigin,
    AppSettingsSection? settingsSection,
    bool? showingTutorial,
  }) {
    final nextLaunchOrigin = launchOrigin ?? _gameLaunchOrigin;
    final nextSettingsSection = settingsSection ?? _settingsSection;
    final nextTutorial = showingTutorial ?? _showingTutorial;
    if (_destination == destination &&
        _gameLaunchOrigin == nextLaunchOrigin &&
        _settingsSection == nextSettingsSection &&
        _showingTutorial == nextTutorial) {
      return;
    }
    _destination = destination;
    _gameLaunchOrigin = nextLaunchOrigin;
    _settingsSection = nextSettingsSection;
    _showingTutorial = nextTutorial;
    notifyListeners();
  }
}
