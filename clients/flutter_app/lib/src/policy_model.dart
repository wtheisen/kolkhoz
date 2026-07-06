import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import 'c_engine_bridge.dart';

const defaultNeuralPolicyAsset = 'assets/policies/current_best_policy.json';
const _maxHiddenLayers = 4;

class KolkhozNativePolicyModel {
  KolkhozNativePolicyModel._(this._buffer, this._allocations);

  final Pointer<KCPolicyModelBufferNative> _buffer;
  final List<Pointer<Void>> _allocations;
  bool _disposed = false;

  KCPolicyModelBufferNative get native => _buffer.ref;

  static Future<KolkhozNativePolicyModel> loadAsset(
    String assetPath, {
    AssetBundle? bundle,
  }) async {
    final source = await (bundle ?? rootBundle).loadString(assetPath);
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Policy model must be a JSON object');
    }
    return fromJson(decoded);
  }

  static KolkhozNativePolicyModel fromJson(Map<String, Object?> json) {
    final backend = json['backend'];
    if (backend != null && backend != 'c-mlp') {
      throw FormatException('Unsupported policy backend: $backend');
    }
    final hiddenLayers = _intList(json['hidden_layers'] ?? json['layerSizes']);
    if (hiddenLayers.isEmpty) {
      throw const FormatException('Policy model requires hidden_layers');
    }
    if (hiddenLayers.length > _maxHiddenLayers) {
      throw const FormatException('Policy model has too many hidden layers');
    }
    final hiddenWeights = _nestedDoubleList(
      json['hidden_weights'] ?? json['layerWeights'],
    );
    final hiddenBiases = _nestedDoubleList(
      json['hidden_biases'] ?? json['layerBiases'],
    );
    if (hiddenWeights.length < hiddenLayers.length ||
        hiddenBiases.length < hiddenLayers.length) {
      throw const FormatException('Policy model hidden layers are incomplete');
    }
    final outputWeights = _doubleList(
      json['output_weights'] ?? json['outputWeights'],
    );
    final b2s = _doubleList(json['b2s']);
    final inputSize = _intValue(json['input_size'] ?? json['inputSize'], 200);
    final headCount = _intValue(
      json['head_count'] ?? json['headCount'],
      b2s.isNotEmpty ? b2s.length : 1,
    );

    final allocations = <Pointer<Void>>[];
    final buffer = calloc<KCPolicyModelBufferNative>();
    allocations.add(buffer.cast<Void>());
    buffer.ref
      ..inputSize = inputSize
      ..hiddenSize = _intValue(
        json['hidden_size'] ?? json['hiddenSize'],
        hiddenLayers.first,
      )
      ..layerCount = hiddenLayers.length
      ..headCount = headCount;
    for (var index = 0; index < hiddenLayers.length; index += 1) {
      buffer.ref.layerSizes[index] = hiddenLayers[index];
      buffer.ref.layerWeights[index] = _nativeDoubles(
        hiddenWeights[index],
        allocations,
      );
      buffer.ref.layerBiases[index] = _nativeDoubles(
        hiddenBiases[index],
        allocations,
      );
    }
    buffer.ref.outputWeights = _nativeDoubles(outputWeights, allocations);
    buffer.ref.b2 = _nativeDoubles([_doubleValue(json['b2'], 0)], allocations);
    if (b2s.isNotEmpty) {
      buffer.ref.b2s = _nativeDoubles(b2s, allocations);
    }
    return KolkhozNativePolicyModel._(buffer, allocations);
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final allocation in _allocations.reversed) {
      calloc.free(allocation);
    }
    _allocations.clear();
  }
}

Pointer<Double> _nativeDoubles(
  List<double> values,
  List<Pointer<Void>> allocations,
) {
  if (values.isEmpty) {
    return nullptr;
  }
  final pointer = calloc<Double>(values.length);
  allocations.add(pointer.cast<Void>());
  for (var index = 0; index < values.length; index += 1) {
    pointer[index] = values[index];
  }
  return pointer;
}

int _intValue(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

double _doubleValue(Object? value, double fallback) {
  if (value is num) {
    return value.toDouble();
  }
  return fallback;
}

List<int> _intList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [for (final item in value) _intValue(item, 0)];
}

List<double> _doubleList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [for (final item in value) _doubleValue(item, 0)];
}

List<List<double>> _nestedDoubleList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final row in value)
      if (row is List) _doubleList(row),
  ];
}
