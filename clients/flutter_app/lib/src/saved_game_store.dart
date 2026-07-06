import 'dart:convert';
import 'dart:io';

import 'c_engine_bridge.dart';
import 'render_model.dart';

class KolkhozSavedGamePayload {
  const KolkhozSavedGamePayload({
    this.version = 1,
    required this.seed,
    required this.variants,
    required this.controllers,
    required this.actions,
  });

  final int version;
  final int seed;
  final KolkhozGameVariants variants;
  final List<KolkhozPlayerController> controllers;
  final List<EngineAction> actions;

  Map<String, Object?> toJson() {
    return {
      'version': version,
      'seed': seed,
      'variants': variantsToJson(variants),
      'controllers': controllers.map((controller) => controller.name).toList(),
      'actions': actions.map(engineActionToJson).toList(),
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
      variants: variantsFromJson(_objectMap(json['variants'])),
      controllers: KolkhozPlayerController.normalized([
        for (final value in _objectList(json['controllers']))
          controllerFromJson(value),
      ]),
      actions: [
        for (final value in _objectList(json['actions']))
          engineActionFromJson(_objectMap(value)),
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

Map<String, Object?> variantsToJson(KolkhozGameVariants variants) {
  return {
    'deckType': variants.deckType,
    'nomenclature': variants.nomenclature,
    'allowSwap': variants.allowSwap,
    'northernStyle': variants.northernStyle,
    'miceVariant': variants.miceVariant,
    'ordenNachalniku': variants.ordenNachalniku,
    'medalsCount': variants.medalsCount,
    'accumulateJobs': variants.accumulateJobs,
    'heroOfSovietUnion': variants.heroOfSovietUnion,
    'wrecker': variants.wreckerCard,
  };
}

KolkhozGameVariants variantsFromJson(Map<String, Object?> json) {
  return KolkhozGameVariants(
    deckType: json['deckType'] as int,
    nomenclature: json['nomenclature'] as bool,
    allowSwap: json['allowSwap'] as bool,
    northernStyle: json['northernStyle'] as bool,
    miceVariant: json['miceVariant'] as bool,
    ordenNachalniku: json['ordenNachalniku'] as bool,
    medalsCount: json['medalsCount'] as bool,
    accumulateJobs: json['accumulateJobs'] as bool,
    heroOfSovietUnion: json['heroOfSovietUnion'] as bool,
    wreckerCard: json['wrecker'] as bool? ?? false,
  );
}

KolkhozPlayerController controllerFromJson(Object? value) {
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

Map<String, Object?> engineActionToJson(EngineAction action) {
  return {
    'kind': action.kind,
    'playerID': action.playerID,
    if (action.suit != null) 'suit': action.suit,
    if (action.card != null) 'card': engineCardToJson(action.card!),
    if (action.handCard != null) 'handCard': engineCardToJson(action.handCard!),
    if (action.plotCard != null) 'plotCard': engineCardToJson(action.plotCard!),
    if (action.plotZone != null) 'plotZone': action.plotZone,
    if (action.targetSuit != null) 'targetSuit': action.targetSuit,
  };
}

EngineAction engineActionFromJson(Map<String, Object?> json) {
  return EngineAction(
    kind: json['kind'] as String,
    playerID: json['playerID'] as int,
    suit: json['suit'] as String?,
    card: optionalEngineCardFromJson(json['card']),
    handCard: optionalEngineCardFromJson(json['handCard']),
    plotCard: optionalEngineCardFromJson(json['plotCard']),
    plotZone: json['plotZone'] as String?,
    targetSuit: json['targetSuit'] as String?,
  );
}

Map<String, Object?> engineCardToJson(EngineCard card) {
  return {'suit': card.suit, 'value': card.value};
}

EngineCard? optionalEngineCardFromJson(Object? value) {
  if (value == null) {
    return null;
  }
  final json = _objectMap(value);
  return EngineCard(suit: json['suit'] as String, value: json['value'] as int);
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
