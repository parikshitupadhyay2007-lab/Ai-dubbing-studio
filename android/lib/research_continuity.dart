import 'dart:convert';
import 'dart:io';
import 'production_office.dart';

/// Evidence is not an identity claim. Every assertion has an explicit source.
class SceneEvidence {
  const SceneEvidence({required this.startMs, required this.endMs,
    required this.kind, required this.description, required this.source,
    required this.confidence});
  final int startMs, endMs;
  final String kind, description, source;
  final double confidence;
  Map<String, dynamic> toJson() => {
    'start_ms': startMs, 'end_ms': endMs, 'kind': kind,
    'description': description, 'source': source, 'confidence': confidence,
  };
}

/// Research & Continuity starts with an approved, immutable source contract.
/// Scene models are intentionally not represented as working until installed.
class ResearchContinuity {
  ResearchContinuity(this.office);
  final ProductionOffice office;

  Future<Map<String, dynamic>> createResearchManifest(
      IntakeRecord intake, List<SceneEvidence> evidence) async {
    final receipt = await office.issueHandoff(intake);
    final media = intake.data['media'];
    if (media is! Map || media['duration_ms'] is! num) {
      throw StateError('Invalid approved media manifest');
    }
    final duration = (media['duration_ms'] as num).toInt();
    final errors = <String>[];
    for (final item in evidence) {
      if (item.startMs < 0 || item.endMs <= item.startMs ||
          item.endMs > duration) errors.add('Evidence timestamps outside source');
      if (item.source.trim().isEmpty || item.description.trim().isEmpty ||
          item.kind.trim().isEmpty) errors.add('Unattributed or empty evidence');
      if (!item.confidence.isFinite || item.confidence < 0 ||
          item.confidence > 1) errors.add('Invalid confidence');
    }
    if (errors.isNotEmpty) throw FormatException(errors.toSet().join('; '));
    final manifest = <String, dynamic>{
      'schema': 1, 'department': '01', 'project_id': intake.id,
      'source_sha256': intake.data['sha256'],
      'upstream_handoff': receipt,
      'source_duration_ms': duration,
      'status': 'awaiting_models_and_review',
      'scene_evidence': evidence.map((e) => e.toJson()).toList(),
      'identity_claims': <Object>[],
      'continuity_review': 'pending',
      'approved': false,
    };
    if (!await office.verifyHandoff(intake, receipt)) {
      throw StateError('Department 00 source or approval changed during research');
    }
    final root = await office.root;
    final file = File('${root.path}/${intake.id}/research_manifest.json');
    final temp = File('${file.path}.part');
    await temp.writeAsString(jsonEncode(manifest), flush: true);
    if (!await office.verifyHandoff(intake, receipt)) {
      await temp.delete();
      throw StateError('Stale upstream approval: research output discarded');
    }
    await temp.rename(file.path);
    return manifest;
  }

  /// Independently reads the persisted artifact and rechecks its upstream receipt.
  Future<Map<String, dynamic>> review(IntakeRecord intake) async {
    final errors = <String>[];
    final file = File('${(await office.root).path}/${intake.id}/research_manifest.json');
    if (!await file.exists()) return {'passed': false, 'errors': ['Research manifest missing']};
    try {
      final data = Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map);
      final receipt = Map<String, dynamic>.from(data['upstream_handoff'] as Map);
      if (!await office.verifyHandoff(intake, receipt)) errors.add('Stale upstream approval');
      if (data['department'] != '01' || data['project_id'] != intake.id ||
          data['source_sha256'] != intake.data['sha256']) errors.add('Source binding mismatch');
      final duration = (intake.data['media'] as Map)['duration_ms'];
      if (data['source_duration_ms'] != duration) errors.add('Duration mismatch');
      final raw = data['scene_evidence'];
      if (raw is! List || raw.isEmpty) {
        errors.add('No scene evidence');
      } else {
        for (final entry in raw) {
          if (entry is! Map) { errors.add('Invalid evidence record'); continue; }
          final start = entry['start_ms'], end = entry['end_ms'], confidence = entry['confidence'];
          if (start is! int || end is! int || start < 0 || end <= start ||
              duration is! num || end > duration) errors.add('Invalid scene interval');
          if (confidence is! num || !confidence.isFinite ||
              confidence < 0 || confidence > 1) errors.add('Invalid confidence');
          for (final key in ['kind', 'description', 'source']) {
            if (entry[key] is! String || (entry[key] as String).trim().isEmpty) {
              errors.add('Missing evidence provenance or description');
            }
          }
        }
      }
      // Producer-declared flags are insufficient to certify inference.
      // Each component must be represented in the persisted model coverage.
      // Metadata-only lookup and schema validation are not inference.
      const required = [
        'anime_recognition', 'scene_segmentation', 'visual_understanding',
        'character_recognition', 'context_research', 'continuity_intelligence'
      ];
      final coverage = data['model_coverage'];
      if (coverage is! Map) {
        errors.add('Six-engine model coverage missing');
      } else {
        for (final engine in required) {
          if (coverage[engine] != 'verified') {
            errors.add('Engine not verified: $engine');
          }
        }
      }
      if (data['approved'] != true) errors.add('Research not approved');
      if (data['scene_segmentation_verified'] != true) errors.add('Scene segmentation unverified');
      if (data['visual_analysis_verified'] != true) errors.add('Visual analysis unverified');
      if (data['continuity_review'] != 'passed') errors.add('Continuity review pending');
    } catch (e) {
      errors.add('Research artifact cannot be independently parsed: $e');
    }
    return {'passed': errors.isEmpty, 'errors': errors.toSet().toList()};
  }

  Future<bool> canHandoff(IntakeRecord intake) async =>
      (await review(intake))['passed'] == true;
}
