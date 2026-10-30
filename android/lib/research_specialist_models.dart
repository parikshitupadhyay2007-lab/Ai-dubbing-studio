import 'dart:convert';
import 'dart:io';
import 'department01_inference.dart';

/// Installed specialist models must declare actual tensor contracts and provenance.
/// This validates interfaces, not model accuracy or licence ownership.
class ResearchSpecialistModels {
  const ResearchSpecialistModels({
    this.inference = const Department01Inference(),
  });
  final Department01Inference inference;

  static const roles = <String>{
    'visual_embedding', 'character_detector', 'character_reidentification',
    'active_speaker', 'emotion_performance', 'narrative_context',
  };
  static final _sha = RegExp(r'^[a-f0-9]{64}$');
  static final _name = RegExp(r'^[a-zA-Z0-9_-]{1,80}\.onnx$');

  Future<Map<String, dynamic>> inspectManifest(File manifestFile) async {
    if (!await manifestFile.exists() || await manifestFile.length() > 65536) {
      throw const FormatException('Missing or oversized model manifest');
    }
    final raw = jsonDecode(await manifestFile.readAsString());
    if (raw is! Map || raw['schema'] != 'otakudub_specialist_model_v1' ||
        !roles.contains(raw['role']) || raw['model_name'] is! String ||
        !_name.hasMatch(raw['model_name'] as String) ||
        raw['sha256'] is! String || !_sha.hasMatch(raw['sha256'] as String) ||
        raw['upstream_revision'] is! String ||
        (raw['upstream_revision'] as String).trim().isEmpty ||
        !{'original', 'licensed', 'public_domain', 'apache-2.0', 'mit', 'bsd-3-clause'}
            .contains(raw['rights_basis']) ||
        raw['rights_receipt'] is! String ||
        (raw['rights_receipt'] as String).trim().isEmpty ||
        raw['preprocessing_id'] is! String ||
        (raw['preprocessing_id'] as String).trim().isEmpty ||
        raw['inputs'] is! List || (raw['inputs'] as List).isEmpty ||
        raw['outputs'] is! List || (raw['outputs'] as List).isEmpty) {
      throw const FormatException('Invalid specialist model provenance or contract');
    }
    for (final field in ['inputs', 'outputs']) {
      final values = raw[field] as List;
      if (values.length > 16 || values.any((v) => v is! String ||
          !RegExp(r'^[a-zA-Z0-9_.:-]{1,128}$').hasMatch(v))) {
        throw const FormatException('Malformed tensor names');
      }
      if (values.toSet().length != values.length) {
        throw const FormatException('Duplicate tensor names');
      }
    }
    final name = raw['model_name'] as String;
    final sha = raw['sha256'] as String;
    final inspected = await inference.inspect(modelName: name, sha256: sha);
    final actualInputs = inspected['inputs'], actualOutputs = inspected['outputs'];
    if (actualInputs is! List || actualOutputs is! List ||
        actualInputs.toSet().difference((raw['inputs'] as List).toSet()).isNotEmpty ||
        (raw['inputs'] as List).toSet().difference(actualInputs.toSet()).isNotEmpty ||
        actualOutputs.toSet().difference((raw['outputs'] as List).toSet()).isNotEmpty ||
        (raw['outputs'] as List).toSet().difference(actualOutputs.toSet()).isNotEmpty) {
      throw const FormatException('Installed specialist tensor signature mismatch');
    }
    return {
      'role': raw['role'], 'model_name': name, 'model_sha256': sha,
      'upstream_revision': raw['upstream_revision'],
      'rights_basis': raw['rights_basis'], 'rights_receipt': raw['rights_receipt'],
      'preprocessing_id': raw['preprocessing_id'],
      'actual_inputs': actualInputs, 'actual_outputs': actualOutputs,
      'checksum_verified': true, 'installed': true,
      'real_inference_verified': false, 'professional_accuracy_verified': false,
    };
  }
}
