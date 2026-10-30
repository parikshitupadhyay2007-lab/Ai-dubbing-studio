import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'production_office.dart';

/// Versioned continuity decisions. Contradictions remain unresolved, never
/// silently overwritten by a later detector or a guessed character name.
class ResearchContinuityMemory {
  const ResearchContinuityMemory(this.office);
  final ProductionOffice office;

  String _hash(Object value) =>
      crypto.sha256.convert(utf8.encode(jsonEncode(value))).toString();

  Future<Map<String, dynamic>> append({
    required IntakeRecord intake,
    required String entityId,
    required String attribute,
    required String value,
    required List<String> evidenceIds,
  }) async {
    final receipt = await office.issueHandoff(intake);
    final id = RegExp(r'^[a-zA-Z0-9_.:-]{1,100}$');
    if (!id.hasMatch(entityId) || !id.hasMatch(attribute) ||
        value.trim().isEmpty || value.length > 2000 ||
        evidenceIds.isEmpty || evidenceIds.any((v) => !id.hasMatch(v))) {
      throw const FormatException('Invalid continuity evidence');
    }
    final file = File('${(await office.root).path}/${intake.id}/continuity_memory.json');
    Map<String, dynamic> current = {
      'schema': 1, 'project_id': intake.id,
      'source_sha256': intake.data['sha256'],
      'revision': 0, 'decisions': <Object>[], 'unresolved_conflicts': <Object>[],
      'approved': false,
    };
    if (await file.exists()) {
      final parsed = jsonDecode(await file.readAsString());
      if (parsed is! Map) throw const FormatException('Invalid continuity memory');
      final persisted = Map<String, dynamic>.from(parsed);
      final checksum = persisted.remove('fingerprint_sha256');
      if (checksum != _hash(persisted) ||
          persisted['project_id'] != intake.id ||
          persisted['source_sha256'] != intake.data['sha256'] ||
          persisted['schema'] != 1 || persisted['revision'] is! int ||
          persisted['decisions'] is! List ||
          persisted['unresolved_conflicts'] is! List ||
          persisted['approved'] != false) {
        throw const FormatException('Tampered or stale continuity memory');
      }
      current = persisted;
    }
    final decisions = List<Map<String, dynamic>>.from(
      (current['decisions'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
    final conflicts = List<Map<String, dynamic>>.from(
      (current['unresolved_conflicts'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
    final prior = decisions.where((d) => d['entity_id'] == entityId &&
        d['attribute'] == attribute).toList();
    if (prior.any((d) => d['value'] != value)) {
      conflicts.add({
        'entity_id': entityId, 'attribute': attribute,
        'prior_evidence_ids': prior.expand((d) => d['evidence_ids'] as List).toSet().toList(),
        'new_evidence_ids': evidenceIds, 'candidate_value': value,
        'status': 'requires_independent_resolution',
      });
    } else if (!prior.any((d) => d['value'] == value &&
        jsonEncode(d['evidence_ids']) == jsonEncode(evidenceIds))) {
      decisions.add({'entity_id': entityId, 'attribute': attribute,
        'value': value, 'evidence_ids': evidenceIds,
        'status': 'provisional_requires_review'});
    }
    final next = <String, dynamic>{...current,
      'revision': (current['revision'] as int) + 1,
      'decisions': decisions, 'unresolved_conflicts': conflicts,
      'approved': false};
    final sealed = {...next, 'fingerprint_sha256': _hash(next)};
    final temp = File('${file.path}.part');
    try {
      if (!await office.verifyHandoff(intake, receipt)) throw StateError('Stale continuity source');
      await temp.writeAsString(jsonEncode(sealed), flush: true);
      if (!await office.verifyHandoff(intake, receipt)) throw StateError('Stale continuity source');
      await temp.rename(file.path);
      return sealed;
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }
}
