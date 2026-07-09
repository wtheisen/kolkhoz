import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'app_text.dart';
import 'c_engine_bridge.dart';

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
    int onlinePlays = 0,
    int onlineWins = 0,
    int? casualPlays,
    int? casualWins,
    int? rankedPlays,
    int? rankedWins,
    this.rating = 1000,
    this.totalWins = 0,
    this.totalLosses = 0,
  }) : casualPlays = casualPlays ?? onlinePlays,
       casualWins = casualWins ?? onlineWins,
       rankedPlays = rankedPlays ?? 0,
       rankedWins = rankedWins ?? 0;

  final int offlinePlays;
  final int offlineWins;
  final int casualPlays;
  final int casualWins;
  final int rankedPlays;
  final int rankedWins;
  final int rating;
  final int totalWins;
  final int totalLosses;

  int get gamesPlayed => totalWins + totalLosses;
  int get onlinePlays => casualPlays + rankedPlays;
  int get onlineWins => casualWins + rankedWins;

  KolkhozProfileStats copyWith({
    int? offlinePlays,
    int? offlineWins,
    int? casualPlays,
    int? casualWins,
    int? rankedPlays,
    int? rankedWins,
    int? rating,
    int? totalWins,
    int? totalLosses,
  }) {
    return KolkhozProfileStats(
      offlinePlays: offlinePlays ?? this.offlinePlays,
      offlineWins: offlineWins ?? this.offlineWins,
      casualPlays: casualPlays ?? this.casualPlays,
      casualWins: casualWins ?? this.casualWins,
      rankedPlays: rankedPlays ?? this.rankedPlays,
      rankedWins: rankedWins ?? this.rankedWins,
      rating: rating ?? this.rating,
      totalWins: totalWins ?? this.totalWins,
      totalLosses: totalLosses ?? this.totalLosses,
    );
  }

  KolkhozProfileStats recordResult({
    required bool online,
    required bool won,
    bool ranked = false,
  }) {
    final ratingDelta = won ? 16 : -16;
    final nextRating = online && ranked
        ? _clampInt(rating + ratingDelta, min: 100, max: 3000)
        : rating;
    return copyWith(
      offlinePlays: online ? offlinePlays : offlinePlays + 1,
      offlineWins: online ? offlineWins : offlineWins + (won ? 1 : 0),
      casualPlays: online && !ranked ? casualPlays + 1 : casualPlays,
      casualWins: online && !ranked ? casualWins + (won ? 1 : 0) : casualWins,
      rankedPlays: online && ranked ? rankedPlays + 1 : rankedPlays,
      rankedWins: online && ranked ? rankedWins + (won ? 1 : 0) : rankedWins,
      rating: nextRating,
      totalWins: totalWins + (won ? 1 : 0),
      totalLosses: totalLosses + (won ? 0 : 1),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'offline-plays': offlinePlays,
      'offline-wins': offlineWins,
      'casual-plays': casualPlays,
      'casual-wins': casualWins,
      'ranked-plays': rankedPlays,
      'ranked-wins': rankedWins,
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
      casualPlays: _nonNegativeInt(
        value['casual-plays'] ?? value['online-plays'],
      ),
      casualWins: _nonNegativeInt(value['casual-wins'] ?? value['online-wins']),
      rankedPlays: _nonNegativeInt(value['ranked-plays']),
      rankedWins: _nonNegativeInt(value['ranked-wins']),
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
  final onlineGames = _dbInt(value['online_games']);
  final onlineWins = _dbInt(value['online_wins']);
  final rankedGames = _dbInt(value['ranked_games'] ?? value['rating_games']);
  final rankedWins = value.containsKey('ranked_wins')
      ? _dbInt(value['ranked_wins'])
      : _clampInt(onlineWins, min: 0, max: rankedGames);
  final casualGames = value.containsKey('casual_games')
      ? _dbInt(value['casual_games'])
      : _clampInt(onlineGames - rankedGames, min: 0, max: onlineGames);
  final casualWins = value.containsKey('casual_wins')
      ? _dbInt(value['casual_wins'])
      : _clampInt(onlineWins - rankedWins, min: 0, max: casualGames);
  return KolkhozProfileStats(
    offlinePlays: _dbInt(value['offline_games']),
    offlineWins: _dbInt(value['offline_wins']),
    casualPlays: casualGames,
    casualWins: casualWins,
    rankedPlays: rankedGames,
    rankedWins: rankedWins,
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
    'casual_games': stats.casualPlays,
    'casual_wins': stats.casualWins,
    'ranked_games': stats.rankedPlays,
    'ranked_wins': stats.rankedWins,
    'online_games': stats.onlinePlays,
    'online_wins': stats.onlineWins,
    'rating': stats.rating,
    'peak_rating': stats.rating,
    'rating_games': stats.rankedPlays,
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

class KolkhozFavoriteSetup {
  const KolkhozFavoriteSetup({
    required this.variants,
    required this.controllers,
  });

  final KolkhozGameVariants variants;
  final List<KolkhozPlayerController> controllers;

  Map<String, Object?> toJson() {
    return {
      'variants': {
        'deckType': variants.deckType,
        'maxYears': variants.maxYears,
        'nomenclature': variants.nomenclature,
        'allowSwap': variants.allowSwap,
        'northernStyle': variants.northernStyle,
        'miceVariant': variants.miceVariant,
        'ordenNachalniku': variants.ordenNachalniku,
        'medalsCount': variants.medalsCount,
        'accumulateJobs': variants.accumulateJobs,
        'heroOfSovietUnion': variants.heroOfSovietUnion,
        'wrecker': variants.wreckerCard,
      },
      'controllers': controllers.map((controller) => controller.name).toList(),
    };
  }

  static KolkhozFavoriteSetup? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    try {
      final json = value.cast<String, Object?>();
      final variantsJson = _objectMap(json['variants']);
      return KolkhozFavoriteSetup(
        variants: KolkhozGameVariants(
          deckType: variantsJson['deckType'] as int,
          maxYears: variantsJson['maxYears'] as int? ?? 5,
          nomenclature: variantsJson['nomenclature'] as bool,
          allowSwap: variantsJson['allowSwap'] as bool,
          northernStyle: variantsJson['northernStyle'] as bool,
          miceVariant: variantsJson['miceVariant'] as bool,
          ordenNachalniku: variantsJson['ordenNachalniku'] as bool,
          medalsCount: variantsJson['medalsCount'] as bool,
          accumulateJobs: variantsJson['accumulateJobs'] as bool,
          heroOfSovietUnion: variantsJson['heroOfSovietUnion'] as bool,
          wreckerCard: variantsJson['wrecker'] as bool? ?? false,
        ),
        controllers: KolkhozPlayerController.normalized([
          for (final controller in _objectList(json['controllers']))
            _controllerFromJson(controller),
        ]),
      );
    } catch (_) {
      return null;
    }
  }
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  throw const FormatException('Expected object');
}

List<Object?> _objectList(Object? value) {
  if (value is List<Object?>) {
    return value;
  }
  if (value is List) {
    return value.cast<Object?>();
  }
  throw const FormatException('Expected list');
}

KolkhozPlayerController _controllerFromJson(Object? value) {
  if (value is! String) {
    throw const FormatException('Invalid player controller');
  }
  for (final controller in KolkhozPlayerController.values) {
    if (controller.name == value) {
      return controller;
    }
  }
  throw const FormatException('Unknown player controller');
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

enum KolkhozCardBack {
  classic(
    assetPath: 'ios_resources/Cards/card-back.png',
    iconAssetPath: 'ios_resources/Cards/card-back-icon.png',
  ),
  harvest(
    assetPath: 'ios_resources/Cards/card-back-harvest.png',
    iconAssetPath: 'ios_resources/Cards/card-back-harvest-icon.png',
  ),
  granary(
    assetPath: 'ios_resources/Cards/card-back-granary.png',
    iconAssetPath: 'ios_resources/Cards/card-back-granary-icon.png',
  ),
  winter(
    assetPath: 'ios_resources/Cards/card-back-winter.png',
    iconAssetPath: 'ios_resources/Cards/card-back-winter-icon.png',
  );

  const KolkhozCardBack({required this.assetPath, required this.iconAssetPath});

  final String assetPath;
  final String iconAssetPath;

  static KolkhozCardBack fromStoredValue(String? value) {
    return KolkhozCardBack.values.firstWhere(
      (cardBack) => cardBack.name == value,
      orElse: () => KolkhozCardBack.classic,
    );
  }

  String label(KolkhozLanguage language) {
    return switch (this) {
      KolkhozCardBack.classic => language.t(KolkhozText.appsettingsClassic),
      KolkhozCardBack.harvest => language.t(KolkhozText.appsettingsHarvest),
      KolkhozCardBack.granary => language.t(KolkhozText.appsettingsGranary),
      KolkhozCardBack.winter => language.t(KolkhozText.appsettingsWinter),
    };
  }
}

class KolkhozCardBackScope extends InheritedWidget {
  const KolkhozCardBackScope({
    required this.cardBack,
    required super.child,
    super.key,
  });

  final KolkhozCardBack cardBack;

  static KolkhozCardBack of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<KolkhozCardBackScope>();
    return scope?.cardBack ?? KolkhozCardBack.classic;
  }

  @override
  bool updateShouldNotify(KolkhozCardBackScope oldWidget) {
    return cardBack != oldWidget.cardBack;
  }
}

class KolkhozAppSettings {
  const KolkhozAppSettings({
    this.language = KolkhozLanguage.ru,
    this.appearance = KolkhozAppearance.dark,
    this.cardBack = KolkhozCardBack.classic,
    this.confirmNewGame = true,
    this.confirmMainMenu = true,
    this.showInvalidTapHints = true,
    this.displayName = defaultProfileDisplayName,
    this.portraitAsset = defaultProfilePortraitAsset,
    this.profileStats = defaultProfileStats,
    this.favoriteSetup,
  });

  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final KolkhozCardBack cardBack;
  final bool confirmNewGame;
  final bool confirmMainMenu;
  final bool showInvalidTapHints;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final KolkhozFavoriteSetup? favoriteSetup;

  KolkhozAppSettings copyWith({
    KolkhozLanguage? language,
    KolkhozAppearance? appearance,
    KolkhozCardBack? cardBack,
    bool? confirmNewGame,
    bool? confirmMainMenu,
    bool? showInvalidTapHints,
    String? displayName,
    String? portraitAsset,
    KolkhozProfileStats? profileStats,
    KolkhozFavoriteSetup? favoriteSetup,
  }) {
    return KolkhozAppSettings(
      language: language ?? this.language,
      appearance: appearance ?? this.appearance,
      cardBack: cardBack ?? this.cardBack,
      confirmNewGame: confirmNewGame ?? this.confirmNewGame,
      confirmMainMenu: confirmMainMenu ?? this.confirmMainMenu,
      showInvalidTapHints: showInvalidTapHints ?? this.showInvalidTapHints,
      displayName: displayName ?? this.displayName,
      portraitAsset: portraitAsset ?? this.portraitAsset,
      profileStats: profileStats ?? this.profileStats,
      favoriteSetup: favoriteSetup ?? this.favoriteSetup,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'kolkhoz-lang': language.name,
      'kolkhoz-appearance': appearance.name,
      'card-back': cardBack.name,
      'confirm-new-game': confirmNewGame,
      'confirm-main-menu': confirmMainMenu,
      'show-invalid-tap-hints': showInvalidTapHints,
      'display-name': displayName,
      'portrait-asset': portraitAsset,
      'profile-stats': profileStats.toJson(),
      if (favoriteSetup != null) 'favorite-setup': favoriteSetup!.toJson(),
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
      cardBack: KolkhozCardBack.fromStoredValue(json['card-back'] as String?),
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
      favoriteSetup: KolkhozFavoriteSetup.fromJson(json['favorite-setup']),
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
