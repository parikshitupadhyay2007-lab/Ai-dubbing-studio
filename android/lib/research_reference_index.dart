import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;

/// Validates a locally supplied, source-attributed embedding catalogue.
/// Does not download anime imagery or grant rights to any source.
class ResearchReferenceIndex {
  const ResearchReferenceIndex();

  Future<Map<String, List<double>>> load({
    required File file,
    required String expectedModelSha256,
    required String expectedPreprocessingId,
    required int dimension,
  }) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedModelSha256) ||
        expectedPreprocessingId.isEmpty || dimension < 1 || dimension > 4096) {
      throw const FormatException('Invalid reference index contract');
    }
    if (await file.length() > 16 * 1024 * 1024) {
      throw const FormatException('Reference index exceeds 16 MiB');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map || decoded['schema'] != 'otakudub_reference_v1' ||
        decoded['model_sha256'] != expectedModelSha256 ||
        decoded['preprocessing_id'] != expectedPreprocessingId ||
        decoded['dimension'] != dimension || decoded['entries'] is! List) {
      throw const FormatException('Incompatible or malformed reference index');
    }
    final entries = decoded['entries'] as List;
    if (entries.isEmpty || entries.length > 10000) {
      throw const FormatException('Invalid reference entry count');
    }
    final result = <String, List<double>>{};
    for (final raw in entries) {
      if (raw is! Map || raw['id'] is! String ||
          !RegExp(r'^[a-zA-Z0-9_.:-]{1,128}$').hasMatch(raw['id'] as String) ||
          raw['source'] is! String || (raw['source'] as String).trim().isEmpty ||
          raw['rights_basis'] is! String ||
          !['original', 'licensed', 'public_domain'].contains(raw['rights_basis']) ||
          raw['source_sha256'] is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(raw['source_sha256'] as String) ||
          raw['embedding'] is! List) {
        throw const FormatException('Missing reference identity or rights provenance');
      }
      final id = raw['id'] as String;
      if (result.containsKey(id)) {
        throw const FormatException('Duplicate reference ID');
      }
      final values = raw['embedding'] as List;
      if (values.length != dimension || values.any((v) => v is! num ||
          !(v as num).isFinite)) {
        throw const FormatException('Invalid reference embedding');
      }
      final vector = values.map((v) => (v as num).toDouble()).toList(growable: false);
      if (vector.every((v) => v == 0)) {
        throw const FormatException('Zero reference embedding');
      }
      result[id] = vector;
    }
    return Map.unmodifiable(result);
  }

  /// Generates a fingerprint for evidence manifests after rights validation.
  String fingerprint(Map<String, List<double>> references) =>
      crypto.sha256.convert(utf8.encode(jsonEncode(references))).toString();
}
