import 'dart:convert';
import 'dart:io';

import 'app_text.dart';

import 'design_tokens.dart';
import 'game_constants.dart';

const defaultProfileDisplayName = 'Player';
const defaultProfilePortraitAsset = 'worker1';
const profilePortraitAssets = ['worker1', 'worker2', 'worker3', 'worker4'];
const defaultProfileStats = KolkhozProfileStats();

class KolkhozProfileStats {
  const KolkhozProfileStats({
    this.offlinePlays = 0,
    this.offlineWins = 0,
    this.onlinePlays = 0,
    this.onlineWins = 0,
    this.rating = 1000,
    this.totalWins = 0,
    this.totalLosses = 0,
  });

  final int offlinePlays;
  final int offlineWins;
  final int onlinePlays;
  final int onlineWins;
  final int rating;
  final int totalWins;
  final int totalLosses;

  int get gamesPlayed => totalWins + totalLosses;

  KolkhozProfileStats copyWith({
    int? offlinePlays,
    int? offlineWins,
    int? onlinePlays,
    int? onlineWins,
    int? rating,
    int? totalWins,
    int? totalLosses,
  }) {
    return KolkhozProfileStats(
      offlinePlays: offlinePlays ?? this.offlinePlays,
      offlineWins: offlineWins ?? this.offlineWins,
      onlinePlays: onlinePlays ?? this.onlinePlays,
      onlineWins: onlineWins ?? this.onlineWins,
      rating: rating ?? this.rating,
      totalWins: totalWins ?? this.totalWins,
      totalLosses: totalLosses ?? this.totalLosses,
    );
  }

  KolkhozProfileStats recordResult({required bool online, required bool won}) {
    final ratingDelta = won ? 16 : -16;
    final nextRating = online
        ? _clampInt(rating + ratingDelta, min: 100, max: 3000)
        : rating;
    return copyWith(
      offlinePlays: online ? offlinePlays : offlinePlays + 1,
      offlineWins: online ? offlineWins : offlineWins + (won ? 1 : 0),
      onlinePlays: online ? onlinePlays + 1 : onlinePlays,
      onlineWins: online ? onlineWins + (won ? 1 : 0) : onlineWins,
      rating: nextRating,
      totalWins: totalWins + (won ? 1 : 0),
      totalLosses: totalLosses + (won ? 0 : 1),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'offline-plays': offlinePlays,
      'offline-wins': offlineWins,
      'online-plays': onlinePlays,
      'online-wins': onlineWins,
      'rating': rating,
      'total-wins': totalWins,
      'total-losses': totalLosses,
    };
  }

  static KolkhozProfileStats fromJson(Object? value) {
    if (value is! Map) {
      return defaultProfileStats;
    }
    return KolkhozProfileStats(
      offlinePlays: _nonNegativeInt(value['offline-plays']),
      offlineWins: _nonNegativeInt(value['offline-wins']),
      onlinePlays: _nonNegativeInt(value['online-plays']),
      onlineWins: _nonNegativeInt(value['online-wins']),
      rating: _positiveInt(value['rating'], fallback: 1000),
      totalWins: _nonNegativeInt(value['total-wins']),
      totalLosses: _nonNegativeInt(value['total-losses']),
    );
  }

  static int _nonNegativeInt(Object? value) {
    return value is int && value >= 0 ? value : 0;
  }

  static int _positiveInt(Object? value, {required int fallback}) {
    return value is int && value > 0 ? value : fallback;
  }
}

KolkhozProfileStats profileStatsFromSupabaseJson(Object? value) {
  if (value is! Map) {
    return defaultProfileStats;
  }
  final gamesPlayed = _dbInt(value['games_played']);
  final winsTotal = _dbInt(value['wins_total']);
  final lossesTotal = _clampInt(
    gamesPlayed - winsTotal,
    min: 0,
    max: gamesPlayed,
  );
  return KolkhozProfileStats(
    offlinePlays: _dbInt(value['offline_games']),
    offlineWins: _dbInt(value['offline_wins']),
    onlinePlays: _dbInt(value['online_games']),
    onlineWins: _dbInt(value['online_wins']),
    rating: _dbPositiveInt(value['rating'], fallback: 1000),
    totalWins: winsTotal,
    totalLosses: lossesTotal,
  );
}

Map<String, Object?> profileStatsToSupabaseJson(KolkhozProfileStats stats) {
  return {
    'games_played': stats.gamesPlayed,
    'wins_total': stats.totalWins,
    'offline_games': stats.offlinePlays,
    'offline_wins': stats.offlineWins,
    'online_games': stats.onlinePlays,
    'online_wins': stats.onlineWins,
    'rating': stats.rating,
    'peak_rating': stats.rating,
    'rating_games': stats.onlinePlays,
  };
}

int _dbInt(Object? value) {
  if (value is int && value >= 0) {
    return value;
  }
  if (value is num && value >= 0) {
    return value.toInt();
  }
  return 0;
}

int _dbPositiveInt(Object? value, {required int fallback}) {
  final parsed = _dbInt(value);
  return parsed > 0 ? parsed : fallback;
}

int _clampInt(int value, {required int min, required int max}) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

enum KolkhozLanguage {
  ru,
  en;

  static KolkhozLanguage fromStoredValue(String? value) {
    return KolkhozLanguage.values.firstWhere(
      (language) => language.name == value,
      orElse: () => KolkhozLanguage.ru,
    );
  }

  KolkhozLanguage get next {
    return this == KolkhozLanguage.ru ? KolkhozLanguage.en : KolkhozLanguage.ru;
  }

  String t(KolkhozText key, [Map<String, Object?> args = const {}]) {
    return lookupKolkhozText(
      key,
      russian: this == KolkhozLanguage.ru,
      args: args,
    );
  }

  String suitName(String suit) {
    return switch (suit) {
      'wheat' => t(KolkhozText.suitWheat),
      'sunflower' => t(KolkhozText.suitSunflower),
      'potato' => t(KolkhozText.suitPotatoes),
      'beet' => t(KolkhozText.suitBeets),
      _ => suit,
    };
  }

  String phaseName(String phase) {
    return switch (phase) {
      phasePlanning => t(KolkhozText.phasePlanning),
      phaseSwap => t(KolkhozText.phaseSwap),
      phaseTrick => t(KolkhozText.phaseTrick),
      phaseAssignment => t(KolkhozText.phaseAssignment),
      phaseRequisition => t(KolkhozText.phaseRequisition),
      phaseGameOver => t(KolkhozText.phaseGameOver),
      _ => phase,
    };
  }

  String get toggleTitle {
    return t(KolkhozText.languageSwitchTitle);
  }

  String get toggleIconAsset {
    return next == KolkhozLanguage.en
        ? 'icon-language-en.png'
        : 'icon-language-ru.png';
  }

  String get footerLabel {
    return this == KolkhozLanguage.ru ? 'RU' : 'EN';
  }
}

enum KolkhozAppearance {
  dark,
  light;

  static KolkhozAppearance fromStoredValue(String? value) {
    return KolkhozAppearance.values.firstWhere(
      (appearance) => appearance.name == value,
      orElse: () => KolkhozAppearance.dark,
    );
  }

  KolkhozAppearance get next {
    return this == KolkhozAppearance.dark
        ? KolkhozAppearance.light
        : KolkhozAppearance.dark;
  }

  DesignTokens get tokens {
    return this == KolkhozAppearance.dark
        ? defaultDesignTokens
        : lightDesignTokens;
  }

  String label(KolkhozLanguage language) {
    return this == KolkhozAppearance.dark
        ? language.t(KolkhozText.appsettingsDark)
        : language.t(KolkhozText.appsettingsLight);
  }

  String toggleTitle(KolkhozLanguage language) {
    return this == KolkhozAppearance.dark
        ? language.t(KolkhozText.appsettingsSwitchToLightMode)
        : language.t(KolkhozText.appsettingsSwitchToDarkMode);
  }

  String get toggleIconAsset {
    return next == KolkhozAppearance.light
        ? 'icon-appearance-light.png'
        : 'icon-appearance-dark.png';
  }
}

class KolkhozAppSettings {
  const KolkhozAppSettings({
    this.language = KolkhozLanguage.ru,
    this.appearance = KolkhozAppearance.dark,
    this.confirmNewGame = true,
    this.confirmMainMenu = true,
    this.showInvalidTapHints = true,
    this.displayName = defaultProfileDisplayName,
    this.portraitAsset = defaultProfilePortraitAsset,
    this.profileStats = defaultProfileStats,
  });

  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final bool confirmNewGame;
  final bool confirmMainMenu;
  final bool showInvalidTapHints;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;

  KolkhozAppSettings copyWith({
    KolkhozLanguage? language,
    KolkhozAppearance? appearance,
    bool? confirmNewGame,
    bool? confirmMainMenu,
    bool? showInvalidTapHints,
    String? displayName,
    String? portraitAsset,
    KolkhozProfileStats? profileStats,
  }) {
    return KolkhozAppSettings(
      language: language ?? this.language,
      appearance: appearance ?? this.appearance,
      confirmNewGame: confirmNewGame ?? this.confirmNewGame,
      confirmMainMenu: confirmMainMenu ?? this.confirmMainMenu,
      showInvalidTapHints: showInvalidTapHints ?? this.showInvalidTapHints,
      displayName: displayName ?? this.displayName,
      portraitAsset: portraitAsset ?? this.portraitAsset,
      profileStats: profileStats ?? this.profileStats,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'kolkhoz-lang': language.name,
      'kolkhoz-appearance': appearance.name,
      'confirm-new-game': confirmNewGame,
      'confirm-main-menu': confirmMainMenu,
      'show-invalid-tap-hints': showInvalidTapHints,
      'display-name': displayName,
      'portrait-asset': portraitAsset,
      'profile-stats': profileStats.toJson(),
    };
  }

  static KolkhozAppSettings fromJson(Map<String, Object?> json) {
    final displayName = json['display-name'] as String?;
    final portraitAsset = json['portrait-asset'] as String?;
    return KolkhozAppSettings(
      language: KolkhozLanguage.fromStoredValue(
        json['kolkhoz-lang'] as String?,
      ),
      appearance: KolkhozAppearance.fromStoredValue(
        json['kolkhoz-appearance'] as String?,
      ),
      confirmNewGame: json['confirm-new-game'] as bool? ?? true,
      confirmMainMenu: json['confirm-main-menu'] as bool? ?? true,
      showInvalidTapHints: json['show-invalid-tap-hints'] as bool? ?? true,
      displayName: displayName == null || displayName.isEmpty
          ? defaultProfileDisplayName
          : displayName,
      portraitAsset: profilePortraitAssets.contains(portraitAsset)
          ? portraitAsset!
          : defaultProfilePortraitAsset,
      profileStats: KolkhozProfileStats.fromJson(json['profile-stats']),
    );
  }
}

class KolkhozAppSettingsStore {
  const KolkhozAppSettingsStore(this.file);

  final File file;

  static KolkhozAppSettingsStore defaultStore() {
    return KolkhozAppSettingsStore(defaultFile());
  }

  static File defaultFile() {
    final override = Platform.environment['KOLKHOZ_FLUTTER_SETTINGS'];
    if (override != null && override.isNotEmpty) {
      return File(override);
    }
    final home = Platform.environment['HOME'];
    if ((Platform.isMacOS || Platform.isIOS) &&
        home != null &&
        home.isNotEmpty) {
      return File(
        '$home/Library/Application Support/Kolkhoz/settings_flutter.json',
      );
    }
    if (Platform.isLinux) {
      final dataHome = Platform.environment['XDG_DATA_HOME'];
      if (dataHome != null && dataHome.isNotEmpty) {
        return File('$dataHome/kolkhoz/settings_flutter.json');
      }
      if (home != null && home.isNotEmpty) {
        return File('$home/.local/share/kolkhoz/settings_flutter.json');
      }
    }
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return File('$appData\\Kolkhoz\\settings_flutter.json');
      }
    }
    return File('${Directory.systemTemp.path}/kolkhoz_flutter_settings.json');
  }

  KolkhozAppSettings load() {
    try {
      if (!file.existsSync()) {
        return const KolkhozAppSettings();
      }
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?>) {
        return const KolkhozAppSettings();
      }
      return KolkhozAppSettings.fromJson(decoded);
    } catch (_) {
      return const KolkhozAppSettings();
    }
  }

  void save(KolkhozAppSettings settings) {
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(settings.toJson()), flush: true);
    } catch (_) {
      // Settings should never block launching or playing.
    }
  }
}
