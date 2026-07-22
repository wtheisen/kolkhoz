import 'dart:convert';
import 'dart:io';

import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_serialization.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

export 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_serialization.dart';

class KolkhozSavedGamePayload {
  const KolkhozSavedGamePayload({
    this.version = 1,
    required this.seed,
    required this.variants,
    required this.controllers,
    required this.actions,
    this.gameLogActions = const [],
  });

  final int version;
  final int seed;
  final KolkhozGameVariants variants;
  final List<KolkhozPlayerController> controllers;
  final List<EngineAction> actions;
  final List<EngineAction> gameLogActions;

  Map<String, Object?> toJson() {
    return {
      'version': version,
      'seed': seed,
      'variants': variantsToJson(variants),
      'controllers': controllers.map((controller) => controller.name).toList(),
      'actions': actions.map(engineActionToJson).toList(),
      'gameLogActions': gameLogActions.map(engineActionToJson).toList(),
    };
  }

  static KolkhozSavedGamePayload fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version != 1) {
      throw const FormatException('Unsupported saved game version');
    }
    return KolkhozSavedGamePayload(
      version: version as int,
      seed: json['seed'] as int,
      variants: variantsFromJson(jsonObject(json['variants'])),
      controllers: KolkhozPlayerController.normalized([
        for (final value in jsonList(json['controllers']))
          controllerFromJson(value),
      ]),
      actions: [
        for (final value in jsonList(json['actions']))
          engineActionFromJson(jsonObject(value)),
      ],
      gameLogActions: [
        for (final value in jsonList(json['gameLogActions'] ?? const []))
          engineActionFromJson(jsonObject(value)),
      ],
    );
  }
}

class KolkhozAutosaveStore {
  const KolkhozAutosaveStore(this.file);

  final File file;

  static KolkhozAutosaveStore defaultStore() {
    return KolkhozAutosaveStore(defaultFile());
  }

  static File defaultFile() {
    final override = Platform.environment['KOLKHOZ_FLUTTER_AUTOSAVE'];
    if (override != null && override.isNotEmpty) {
      return File(override);
    }
    final home = Platform.environment['HOME'];
    if (Platform.isMacOS || Platform.isIOS) {
      if (home != null && home.isNotEmpty) {
        return File(
          '$home/Library/Application Support/Kolkhoz/autosave_flutter.json',
        );
      }
    }
    if (Platform.isLinux) {
      final dataHome = Platform.environment['XDG_DATA_HOME'];
      if (dataHome != null && dataHome.isNotEmpty) {
        return File('$dataHome/kolkhoz/autosave_flutter.json');
      }
      if (home != null && home.isNotEmpty) {
        return File('$home/.local/share/kolkhoz/autosave_flutter.json');
      }
    }
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return File('$appData\\Kolkhoz\\autosave_flutter.json');
      }
    }
    return File('${Directory.systemTemp.path}/kolkhoz_flutter_autosave.json');
  }

  KolkhozSavedGamePayload? load() {
    try {
      if (!file.existsSync()) {
        return null;
      }
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      return KolkhozSavedGamePayload.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  void save(KolkhozSavedGamePayload payload) {
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(payload.toJson()), flush: true);
    } catch (_) {
      // Autosave should never block play.
    }
  }

  void clear() {
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {
      // Autosave should never block play.
    }
  }
}
