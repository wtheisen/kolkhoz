import 'dart:convert';
import 'dart:io';

import 'design_tokens.dart';
import 'game_constants.dart';

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

  String text({required String en, required String ru}) {
    return this == KolkhozLanguage.ru ? ru : en;
  }

  String suitName(String suit) {
    return switch (suit) {
      'wheat' => text(en: 'Wheat', ru: 'Пшеница'),
      'sunflower' => text(en: 'Sunflower', ru: 'Подсолнух'),
      'potato' => text(en: 'Potatoes', ru: 'Картофель'),
      'beet' => text(en: 'Beets', ru: 'Свёкла'),
      _ => suit,
    };
  }

  String phaseName(String phase) {
    return switch (phase) {
      phasePlanning => text(en: 'Planning', ru: 'План'),
      phaseSwap => text(en: 'Swap', ru: 'Обмен'),
      phaseTrick => text(en: 'Trick', ru: 'Взятка'),
      phaseAssignment => text(en: 'Assignment', ru: 'Работы'),
      phaseRequisition => text(en: 'Requisition', ru: 'Реквизиция'),
      phaseGameOver => text(en: 'Game Over', ru: 'Итог'),
      _ => phase,
    };
  }

  String get toggleTitle {
    return text(en: 'Switch to Russian', ru: 'Switch to English');
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
        ? language.text(en: 'DARK', ru: 'ТЬМА')
        : language.text(en: 'LIGHT', ru: 'СВЕТ');
  }

  String toggleTitle(KolkhozLanguage language) {
    return this == KolkhozAppearance.dark
        ? language.text(en: 'Switch to light mode', ru: 'Включить светлую тему')
        : language.text(en: 'Switch to dark mode', ru: 'Включить тёмную тему');
  }
}

class KolkhozAppSettings {
  const KolkhozAppSettings({
    this.language = KolkhozLanguage.ru,
    this.appearance = KolkhozAppearance.dark,
  });

  final KolkhozLanguage language;
  final KolkhozAppearance appearance;

  KolkhozAppSettings copyWith({
    KolkhozLanguage? language,
    KolkhozAppearance? appearance,
  }) {
    return KolkhozAppSettings(
      language: language ?? this.language,
      appearance: appearance ?? this.appearance,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'kolkhoz-lang': language.name,
      'kolkhoz-appearance': appearance.name,
    };
  }

  static KolkhozAppSettings fromJson(Map<String, Object?> json) {
    return KolkhozAppSettings(
      language: KolkhozLanguage.fromStoredValue(
        json['kolkhoz-lang'] as String?,
      ),
      appearance: KolkhozAppearance.fromStoredValue(
        json['kolkhoz-appearance'] as String?,
      ),
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
