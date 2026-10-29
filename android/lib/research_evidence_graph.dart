import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Immutable, source-bound cross-modal evidence contract. Evidence is not proof
/// of an anime title or character identity until independently corroborated.
class ResearchEvidenceGraph {
  const ResearchEvidenceGraph();

  Map<String, dynamic> build({
    required String sourceSha256,
    required int durationMs,
    required List<Map<String, dynamic>> nodes,
    required List<Map<String, dynamic>> links,
  }) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sourceSha256) || durationMs <= 0) {
      throw const FormatException('Invalid source binding');
    }
    final ids = <String>{};
    const modalities = {'visual', 'audio', 'reference', 'context', 'temporal'};
    for (final node in nodes) {
      final id = node['id'], modality = node['modality'];
      final start = node['start_ms'], end = node['end_ms'];
      final confidence = node['confidence'];
      if (id is! String || !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id) ||
          !ids.add(id) || !modalities.contains(modality) ||
          start is! int || end is! int || start < 0 || end <= start ||
          end > durationMs || confidence is! num || !confidence.isFinite ||
          confidence < 0 || confidence > 1 ||
          node['provenance'] is! String ||
          (node['provenance'] as String).trim().isEmpty ||
          node['observation'] is! String ||
          (node['observation'] as String).trim().isEmpty ||
          node['verified'] != false) {
        throw const FormatException('Invalid or prematurely verified evidence node');
      }
    }
    const relations = {'supports', 'conflicts', 'precedes', 'same_track', 'co_occurs'};
    final seen = <String>{};
    for (final link in links) {
      final from = link['from'], to = link['to'], relation = link['relation'];
      if (from is! String || to is! String || from == to ||
          !ids.contains(from) || !ids.contains(to) ||
          !relations.contains(relation) ||
          !seen.add('$from:$relation:$to')) {
        throw const FormatException('Invalid evidence relation');
      }
    }
    final payload = <String, dynamic>{
      'schema': 1,
      'source_sha256': sourceSha256,
      'source_duration_ms': durationMs,
      'nodes': nodes,
      'links': links,
      'verified_identity': false,
      'verified_episode': false,
      'independent_model_review': 'pending',
    };
    return {...payload, 'fingerprint_sha256': sha256.convert(utf8.encode(jsonEncode(payload))).toString()};
  }

  bool validate(Map<String, dynamic> graph) {
    try {
      final rebuilt = build(
        sourceSha256: graph['source_sha256'] as String,
        durationMs: graph['source_duration_ms'] as int,
        nodes: (graph['nodes'] as List).map((n) => Map<String, dynamic>.from(n as Map)).toList(),
        links: (graph['links'] as List).map((n) => Map<String, dynamic>.from(n as Map)).toList(),
      );
      return jsonEncode(rebuilt) == jsonEncode(graph);
    } catch (_) { return false; }
  }
}
