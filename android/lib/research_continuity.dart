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
    if (!await office.canHandoff(intake)) {
      throw StateError('Department 00 fresh verification required');
    }
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
      'source_duration_ms': duration,
      'status': 'awaiting_models_and_review',
      'scene_evidence': evidence.map((e) => e.toJson()).toList(),
      'identity_claims': <Object>[],
      'continuity_review': 'pending',
      'approved': false,
    };
    final root = await office.root;
    final file = File('${root.path}/${intake.id}/research_manifest.json');
    final temp = File('${file.path}.part');
    await temp.writeAsString(jsonEncode(manifest), flush: true);
    await temp.rename(file.path);
    return manifest;
  }

  /// No approval by presence of a file or by a model's self-reported score.
  Future<bool> canHandoff(IntakeRecord intake) async => false;
}
