import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kolkhoz_app/src/app/views/shared/world_depth_camera.dart';

const defaultFigmaFileKey = 'MQdTuEmeZVkWS79EJcLEOF';
const defaultFigmaFrameNodeId = '103:2';
const defaultExportWidth = 1672;
const worldDepthAssetDirectory = 'assets/art/field_plan/world_depth';

const requiredBaseLayerIds = <String>{
  'U00',
  'M10',
  'M20',
  'M30',
  'M40',
  'R10',
  'T20',
  'T30',
  'T40',
  'N00',
  'N10',
  'N20',
  'B20',
  'B30',
  'B40',
};

final _layerNamePattern = RegExp(
  r'^([A-Z][A-Z0-9_-]*)\s*·\s*Z\s+(-?\d+(?:\.\d+)?)\s*·\s*(.+)$',
);

Future<void> main(List<String> arguments) async {
  final options = SyncOptions.parse(arguments);
  if (options.showHelp) {
    stdout.write(SyncOptions.usage);
    return;
  }

  final auth = FigmaAuth.fromEnvironment(Platform.environment);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final response = await _getJson(
      client,
      Uri.https('api.figma.com', '/v1/files/${options.fileKey}/nodes', {
        'ids': options.frameNodeId,
      }),
      auth.headers,
    );
    final plan = parseFigmaWorldDepthFrame(
      response,
      frameNodeId: options.frameNodeId,
    );
    final exportUrls = await _requestExportUrls(client, auth, options, plan);
    await _writeSyncOutput(client, options, plan, exportUrls);
    stdout.writeln(
      'Synced ${plan.layers.length} Figma depth plates to '
      '${options.outputDirectory.path}.',
    );
  } finally {
    client.close(force: true);
  }
}

class SyncOptions {
  const SyncOptions({
    required this.fileKey,
    required this.frameNodeId,
    required this.outputDirectory,
    required this.exportWidth,
    required this.showHelp,
  });

  final String fileKey;
  final String frameNodeId;
  final Directory outputDirectory;
  final int exportWidth;
  final bool showHelp;

  static SyncOptions parse(List<String> arguments) {
    final appRoot = File.fromUri(Platform.script).parent.parent;
    var fileKey = defaultFigmaFileKey;
    var frameNodeId = defaultFigmaFrameNodeId;
    var output = Directory('${appRoot.path}/$worldDepthAssetDirectory');
    var exportWidth = defaultExportWidth;
    var showHelp = false;

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      String value() {
        if (++index >= arguments.length) {
          throw FormatException('Missing value after $argument.');
        }
        return arguments[index];
      }

      switch (argument) {
        case '--file-key':
          fileKey = value();
        case '--frame-node-id':
          frameNodeId = value();
        case '--output':
          output = Directory(value()).absolute;
        case '--export-width':
          exportWidth = int.parse(value());
        case '--help' || '-h':
          showHelp = true;
        default:
          throw FormatException('Unknown option: $argument');
      }
    }
    if (exportWidth <= 0) {
      throw const FormatException('--export-width must be positive.');
    }
    return SyncOptions(
      fileKey: fileKey,
      frameNodeId: frameNodeId,
      outputDirectory: output,
      exportWidth: exportWidth,
      showHelp: showHelp,
    );
  }

  static const usage = '''
Pull the Figma world depth stack into Flutter assets.

Authentication:
  FIGMA_ACCESS_TOKEN  Personal access token with file_content:read
  FIGMA_OAUTH_TOKEN   OAuth access token with file_content:read

Usage:
  dart run tool/sync_world_depth_plates.dart [options]

Options:
  --file-key KEY         Figma file key (defaults to the Kolkhoz world file)
  --frame-node-id ID     Composite camera frame (default: 103:2)
  --output DIRECTORY     Flutter asset output directory
  --export-width PIXELS  Registered PNG width (default: 1672)
  -h, --help             Show this help
''';
}

class FigmaAuth {
  const FigmaAuth(this.headers);

  final Map<String, String> headers;

  factory FigmaAuth.fromEnvironment(Map<String, String> environment) {
    final personalToken = environment['FIGMA_ACCESS_TOKEN'];
    if (personalToken != null && personalToken.isNotEmpty) {
      return FigmaAuth({'X-Figma-Token': personalToken});
    }
    final oauthToken = environment['FIGMA_OAUTH_TOKEN'];
    if (oauthToken != null && oauthToken.isNotEmpty) {
      return FigmaAuth({'Authorization': 'Bearer $oauthToken'});
    }
    throw StateError(
      'Set FIGMA_ACCESS_TOKEN or FIGMA_OAUTH_TOKEN. The token needs the '
      'file_content:read scope.',
    );
  }
}

class FigmaWorldDepthLayer {
  const FigmaWorldDepthLayer({
    required this.id,
    required this.name,
    required this.nodeId,
    required this.worldZ,
    required this.bounds,
    required this.initialRect,
  });

  final String id;
  final String name;
  final String nodeId;
  final double worldZ;
  final FigmaRect bounds;
  final List<double> initialRect;

  String get fileName => '${id.toLowerCase()}.png';
}

class FigmaWorldDepthPlan {
  const FigmaWorldDepthPlan({
    required this.fileName,
    required this.lastModified,
    required this.version,
    required this.frameName,
    required this.frameBounds,
    required this.layers,
  });

  final String fileName;
  final String lastModified;
  final String version;
  final String frameName;
  final FigmaRect frameBounds;
  final List<FigmaWorldDepthLayer> layers;

  Map<String, Object?> manifestJson(SyncOptions options) => {
    'schemaVersion': 1,
    'source': {
      'fileKey': options.fileKey,
      'nodeId': options.frameNodeId,
      'fileName': fileName,
      'frameName': frameName,
      'lastModified': lastModified,
      'version': version,
      'transport': 'figma-rest',
    },
    'viewport': {'width': frameBounds.width, 'height': frameBounds.height},
    'camera': worldDepthCameraCalibration.toManifestJson(),
    'layers': [
      for (final layer in layers)
        {
          'id': layer.id,
          'name': layer.name,
          'nodeId': layer.nodeId,
          'worldZ': layer.worldZ,
          'assetPath': '$worldDepthAssetDirectory/${layer.fileName}',
          'initialRect': layer.initialRect,
        },
    ],
  };
}

class FigmaRect {
  const FigmaRect(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;

  factory FigmaRect.fromJson(Map<String, Object?> json) => FigmaRect(
    _number(json, 'x'),
    _number(json, 'y'),
    _number(json, 'width'),
    _number(json, 'height'),
  );
}

FigmaWorldDepthPlan parseFigmaWorldDepthFrame(
  Map<String, Object?> response, {
  required String frameNodeId,
}) {
  final nodes = _map(response, 'nodes');
  final nodeEntry = nodes[frameNodeId];
  if (nodeEntry is! Map<String, Object?>) {
    throw FormatException('Figma did not return frame $frameNodeId.');
  }
  final frame = _map(nodeEntry, 'document');
  final frameBounds = FigmaRect.fromJson(_map(frame, 'absoluteBoundingBox'));
  if (frameBounds.width <= 0 || frameBounds.height <= 0) {
    throw const FormatException('The Figma camera frame has no dimensions.');
  }
  final rawChildren = frame['children'];
  if (rawChildren is! List) {
    throw const FormatException('The Figma camera frame has no child layers.');
  }

  final layers = <FigmaWorldDepthLayer>[];
  final ids = <String>{};
  for (final rawChild in rawChildren) {
    if (rawChild is! Map<String, Object?>) {
      throw const FormatException('A Figma camera child is not an object.');
    }
    if (rawChild['visible'] == false) continue;
    final name = _string(rawChild, 'name');
    final match = _layerNamePattern.firstMatch(name);
    if (match == null) {
      throw FormatException(
        'Visible camera child "$name" must use "ID · Z 0.00 · Name".',
      );
    }
    final id = match.group(1)!;
    if (!ids.add(id)) {
      throw FormatException('Duplicate Figma depth layer ID $id.');
    }
    final bounds = FigmaRect.fromJson(_map(rawChild, 'absoluteBoundingBox'));
    if (bounds.width <= 0 || bounds.height <= 0) {
      throw FormatException('Figma depth layer $id has no dimensions.');
    }
    layers.add(
      FigmaWorldDepthLayer(
        id: id,
        name: match.group(3)!,
        nodeId: _string(rawChild, 'id'),
        worldZ: double.parse(match.group(2)!),
        bounds: bounds,
        initialRect: [
          (bounds.x - frameBounds.x) / frameBounds.width,
          (bounds.y - frameBounds.y) / frameBounds.height,
          bounds.width / frameBounds.width,
          bounds.height / frameBounds.height,
        ],
      ),
    );
  }

  final missing = requiredBaseLayerIds.difference(ids).toList()..sort();
  if (missing.isNotEmpty) {
    throw FormatException(
      'Figma camera frame is missing base layers: ${missing.join(', ')}.',
    );
  }
  // Child order is the painter order. The continuous railway intentionally
  // projects from a distant Z while painting above the landscape underlay, so
  // numerical Z order is not a valid substitute for explicit Figma stacking.

  return FigmaWorldDepthPlan(
    fileName: _optionalString(response, 'name'),
    lastModified: _optionalString(response, 'lastModified'),
    version: _optionalString(response, 'version'),
    frameName: _string(frame, 'name'),
    frameBounds: frameBounds,
    layers: layers,
  );
}

Future<Map<String, Uri>> _requestExportUrls(
  HttpClient client,
  FigmaAuth auth,
  SyncOptions options,
  FigmaWorldDepthPlan plan,
) async {
  final groups = <String, List<FigmaWorldDepthLayer>>{};
  for (final layer in plan.layers) {
    final scale = options.exportWidth / layer.bounds.width;
    if (scale < 0.01 || scale > 4) {
      throw StateError(
        '${layer.id} needs Figma export scale ${scale.toStringAsFixed(2)}, '
        'outside the supported 0.01–4 range.',
      );
    }
    final key = scale.toStringAsFixed(4);
    groups.putIfAbsent(key, () => []).add(layer);
  }

  final result = <String, Uri>{};
  for (final entry in groups.entries) {
    final ids = entry.value.map((layer) => layer.nodeId).join(',');
    final response = await _getJson(
      client,
      Uri.https('api.figma.com', '/v1/images/${options.fileKey}', {
        'ids': ids,
        'format': 'png',
        'scale': entry.key,
        'contents_only': 'true',
        'use_absolute_bounds': 'true',
      }),
      auth.headers,
    );
    final images = _map(response, 'images');
    for (final layer in entry.value) {
      final url = images[layer.nodeId];
      if (url is! String || url.isEmpty) {
        throw StateError('Figma could not render depth layer ${layer.id}.');
      }
      result[layer.id] = Uri.parse(url);
    }
  }
  return result;
}

Future<void> _writeSyncOutput(
  HttpClient client,
  SyncOptions options,
  FigmaWorldDepthPlan plan,
  Map<String, Uri> exportUrls,
) async {
  final output = options.outputDirectory.absolute;
  await output.parent.create(recursive: true);
  final suffix = '$pid-${DateTime.now().microsecondsSinceEpoch}';
  final temporary = Directory('${output.path}.tmp-$suffix');
  final backup = Directory('${output.path}.backup-$suffix');
  await temporary.create();

  try {
    for (final layer in plan.layers) {
      final bytes = await _getBytes(client, exportUrls[layer.id]!);
      final png = PngInfo.read(bytes);
      if ((png.width - options.exportWidth).abs() > 2) {
        throw StateError(
          '${layer.id} exported at ${png.width}px, expected '
          '${options.exportWidth}px.',
        );
      }
      if (!png.hasAlpha) {
        throw StateError(
          '${layer.id} is opaque. Depth plates must export with transparency.',
        );
      }
      await File('${temporary.path}/${layer.fileName}').writeAsBytes(bytes);
    }
    final encoder = const JsonEncoder.withIndent('  ');
    await File(
      '${temporary.path}/manifest.json',
    ).writeAsString('${encoder.convert(plan.manifestJson(options))}\n');

    if (await output.exists()) await output.rename(backup.path);
    try {
      await temporary.rename(output.path);
    } catch (_) {
      if (await backup.exists()) await backup.rename(output.path);
      rethrow;
    }
    if (await backup.exists()) await backup.delete(recursive: true);
  } finally {
    if (await temporary.exists()) await temporary.delete(recursive: true);
  }
}

class PngInfo {
  const PngInfo({
    required this.width,
    required this.height,
    required this.hasAlpha,
  });

  final int width;
  final int height;
  final bool hasAlpha;

  static PngInfo read(Uint8List bytes) {
    const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < 26) {
      throw const FormatException('Figma export is not a PNG.');
    }
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) {
        throw const FormatException('Figma export is not a PNG.');
      }
    }
    final data = ByteData.sublistView(bytes);
    final colorType = bytes[25];
    final hasTransparencyChunk = ascii
        .decode(bytes, allowInvalid: true)
        .contains('tRNS');
    return PngInfo(
      width: data.getUint32(16),
      height: data.getUint32(20),
      hasAlpha: colorType == 4 || colorType == 6 || hasTransparencyChunk,
    );
  }
}

Future<Map<String, Object?>> _getJson(
  HttpClient client,
  Uri uri,
  Map<String, String> headers,
) async {
  final request = await client.getUrl(uri);
  headers.forEach(request.headers.set);
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  final response = await request.close();
  final body = await utf8.decoder.bind(response).join();
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
      'Figma ${response.statusCode}: ${body.length > 500 ? body.substring(0, 500) : body}',
      uri: uri,
    );
  }
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Figma returned a non-object JSON response.');
  }
  return decoded;
}

Future<Uint8List> _getBytes(HttpClient client, Uri uri) async {
  final request = await client.getUrl(uri);
  final response = await request.close();
  if (response.statusCode < 200 || response.statusCode >= 300) {
    await response.drain<void>();
    throw HttpException(
      'Image download failed with HTTP ${response.statusCode}.',
      uri: uri,
    );
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

Map<String, Object?> _map(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map<String, Object?>) {
    throw FormatException('Expected "$key" to be an object.');
  }
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Expected "$key" to be a non-empty string.');
  }
  return value;
}

String _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String ? value : '';
}

double _number(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw FormatException('Expected "$key" to be a number.');
  }
  return value.toDouble();
}
