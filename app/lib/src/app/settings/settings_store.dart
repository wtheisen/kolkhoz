import 'dart:convert';
import 'dart:io';

import 'settings.dart';

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
