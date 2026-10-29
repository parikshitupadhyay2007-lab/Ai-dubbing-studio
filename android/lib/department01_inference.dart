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

  /// Installs a locally obtained, authorised ONNX file into private storage.
  /// The native layer independently checks SHA256 and opens the session.
  Future<Map<String, dynamic>> installLocal({
    required String sourcePath, required String modelName,
    required String sha256,
  }) async {
    if (sourcePath.trim().isEmpty) {
      throw const FormatException('Missing local source path');
    }
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'installLocalModel', {
        ..._binding(modelName, sha256), 'source_path': sourcePath,
      });
    if (raw == null || raw['installed'] != true ||
        raw['model_name'] != modelName || raw['sha256'] != sha256 ||
        raw['size_bytes'] is! int || (raw['size_bytes'] as int) <= 0) {
      throw const FormatException('Native model installation unverified');
    }
    return raw;
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
    final outputs = raw['output_metadata'];
    if (outputs is! List || outputs.isEmpty) {
      throw const FormatException('No native inference outputs');
    }
    for (final output in outputs) {
      if (output is! Map || output['name'] is! String ||
          output['type'] != 'float32' ||
          output['shape'] is! List || output['values'] is! List) {
        throw const FormatException('Unsupported model output');
      }
      final shape = output['shape'] as List;
      final values = output['values'] as List;
      if (shape.isEmpty || shape.any((v) => v is! int || v <= 0) ||
          shape.fold<int>(1, (a, b) => a * (b as int)) != values.length ||
          values.length > 262144 ||
          values.any((v) => v is! num || !v.isFinite)) {
        throw const FormatException('Invalid native model tensor');
      }
    }
    return raw;
  }
}
