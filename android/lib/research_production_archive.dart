import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'production_office.dart';
import 'research_multimodal_coordinator.dart';
import 'research_directors_scene_bible.dart';

/// Source-bound persisted research. A successful structural review is NOT a
/// professional approval; records and their upstream receipts remain inspectable.
class ResearchProductionArchive {
  const ResearchProductionArchive(this.office);
  final ProductionOffice office;

  String fingerprint(Object value) =>
      crypto.sha256.convert(utf8.encode(jsonEncode(value))).toString();

  Future<Map<String, dynamic>> produce({
    required IntakeRecord intake,
    required List<Map<String, dynamic>> characterObservations,
    required List<Map<String, dynamic>> dialogueObservations,
    required List<List<double>> episodeSamples,
    required Map<String, List<double>> authorisedReferences,
    required Map<String, Map<String, dynamic>> referenceProvenance,
    required List<Map<String, dynamic>> sceneObservations,
    required List<Map<String, dynamic>> timedDialogueEvidence,
  }) async {
    final receipt = await office.issueHandoff(intake);
    final duration = (intake.data['media'] as Map)['duration_ms'];
    final source = intake.data['sha256'];
    if (duration is! int || duration <= 0 || source is! String) {
      throw const FormatException('Invalid approved research source');
    }
    final research = const ResearchMultimodalCoordinator().evaluate(
      durationMs: duration, sourceSha256: source,
      characterObservations: characterObservations,
      dialogueObservations: dialogueObservations,
      episodeSamples: episodeSamples,
      authorisedReferences: authorisedReferences,
      referenceProvenance: referenceProvenance,
      sceneObservations: sceneObservations,
      timedDialogueEvidence: timedDialogueEvidence);
    final bible = const ResearchDirectorsSceneBible().draft(
      sourceSha256: source, durationMs: duration);
    final dramatic = research['dramatic_evidence'] as Map;
    final populatedBible = <String, dynamic>{
      ...bible, 'scenes': dramatic['scenes'],
      'status': 'provisional_pending_specialist_inference',
      'approved': false,
    };
    final output = <String, dynamic>{
      'schema': 'otakudub_research_archive_v1',
      'project_id': intake.id,
      'source_sha256': source, 'duration_ms': duration,
      'upstream_handoff': receipt,
      'multimodal': research,
      'directors_scene_bible': populatedBible,
      'independent_consistency_review': research['independent_consistency_review'],
      'professional_acceptance': false,
      'department02_unlocked': false,
    };
    final digest = fingerprint(output);
    final sealed = {...output, 'fingerprint_sha256': digest};
    final project = Directory('${(await office.root).path}/${intake.id}');
    final target = File('${project.path}/research_archive.json');
    final temp = File('${target.path}.part');
    try {
      if (!await office.verifyHandoff(intake, receipt)) {
        throw StateError('Stale intake before research archive write');
      }
      await temp.writeAsString(jsonEncode(sealed), flush: true);
      if (!await office.verifyHandoff(intake, receipt)) {
        throw StateError('Stale intake before research archive commit');
      }
      await temp.rename(target.path);
      return sealed;
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  /// Re-reads stored bytes, checks tampering and revalidates intake independently.
  Future<Map<String, dynamic>> review(IntakeRecord intake) async {
    final errors = <String>[];
    final file = File('${(await office.root).path}/${intake.id}/research_archive.json');
    if (!await file.exists()) {
      return {'passed': false, 'errors': ['Research archive missing']};
    }
    try {
      final data = Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map);
      final fingerprintValue = data.remove('fingerprint_sha256');
      if (fingerprintValue != fingerprint(data)) errors.add('Archive fingerprint mismatch');
      final receipt = Map<String, dynamic>.from(data['upstream_handoff'] as Map);
      if (!await office.verifyHandoff(intake, receipt)) errors.add('Stale upstream receipt');
      if (data['project_id'] != intake.id ||
          data['source_sha256'] != intake.data['sha256'] ||
          data['duration_ms'] != (intake.data['media'] as Map)['duration_ms'] ||
          data['schema'] != 'otakudub_research_archive_v1') {
        errors.add('Archive source binding mismatch');
      }
      final multimodal = Map<String, dynamic>.from(data['multimodal'] as Map);
      if (multimodal['source_sha256'] != data['source_sha256'] ||
          multimodal['duration_ms'] != data['duration_ms'] ||
          (multimodal['independent_consistency_review'] as Map)['passed'] != true ||
          multimodal['professional_acceptance'] != false ||
          multimodal['handoff_to_department02'] != false) {
        errors.add('Invalid research consistency review');
      }
      final bible = Map<String, dynamic>.from(data['directors_scene_bible'] as Map);
      if (bible['source_sha256'] != data['source_sha256'] ||
          bible['duration_ms'] != data['duration_ms'] ||
          bible['approved'] != false ||
          (bible['scenes'] as List).isEmpty) {
        errors.add('Invalid provisional Scene Bible');
      }
      if (data['professional_acceptance'] != false ||
          data['department02_unlocked'] != false) {
        errors.add('Unverified archive claims professional acceptance');
      }
    } catch (_) {
      errors.add('Invalid persisted research archive');
    }
    return {'passed': errors.isEmpty, 'errors': errors.toSet().toList(),
      'professional_acceptance': false, 'department02_unlocked': false};
  }
}
