import 'package:flutter/services.dart';

/// Calls the real local Android ONNX executor. Model weights are mandatory;
/// this adapter never substitutes mocked or metadata-only inference.
class Department01Inference {
  const Department01Inference({
    MethodChannel channel = const MethodChannel(
      'co.parikshit.otakudub/department01_inference'),
  }) : _channel = channel;

  final MethodChannel _channel;
  static final _name = RegExp(r'^[a-zA-Z0-9_-]{1,80}\.onnx$');
  static final _hash = RegExp(r'^[0-9a-f]{64}$');

  Map<String, dynamic> _binding(String modelName, String sha256) {
    if (!_name.hasMatch(modelName) || !_hash.hasMatch(sha256)) {
      throw const FormatException('Invalid model name or pinned SHA256');
    }
    return {'model_name': modelName, 'sha256': sha256};
  }

  Future<Map<String, dynamic>> inspect({
    required String modelName, required String sha256,
  }) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'inspectModel', _binding(modelName, sha256));
    if (raw == null || raw['checksum_verified'] != true ||
        raw['runtime'] != 'onnxruntime_android') {
      throw const FormatException('Native model inspection failed');
    }
    return raw;
  }

  Future<Map<String, dynamic>> runFloat({
    required String modelName, required String sha256,
    required String inputName, required List<int> shape,
    required List<double> values,
  }) async {
    if (shape.isEmpty || shape.length > 5 ||
        shape.any((n) => n < 1 || n > 4096)) {
      throw const FormatException('Invalid tensor dimensions');
    }
    final length = shape.fold<int>(1, (a, b) => a * b);
    if (length > 4194304 || values.length != length ||
        values.any((v) => !v.isFinite)) {
      throw const FormatException('Invalid tensor payload');
    }
    final raw = await _channel.invokeMapMethod<String, dynamic>('runFloatModel', {
      ..._binding(modelName, sha256),
      'input_name': inputName, 'shape': shape, 'values': values,
    });
    if (raw == null || raw['executed'] != true ||
        raw['checksum_verified'] != true ||
        raw['semantic_result_verified'] != false) {
      throw const FormatException('Native ONNX execution not confirmed');
    }
    return raw;
  }
}
