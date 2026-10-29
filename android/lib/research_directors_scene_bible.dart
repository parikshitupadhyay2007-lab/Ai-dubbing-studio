import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

/// A fail-closed dramatic-intelligence handoff. This is a contract and reviewer,
/// not a substitute for specialised inference or human-labelled benchmarks.
class ResearchDirectorsSceneBible {
  const ResearchDirectorsSceneBible();

  static const additionalCapabilities = <String>[
    'narrative_intelligence',
    'emotion_performance_intelligence',
    'audiovisual_dialogue_attribution',
    'scene_timing_constraints',
    'character_relationship_memory',
  ];

  Map<String, dynamic> draft({
    required String sourceSha256,
    required int durationMs,
  }) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sourceSha256) ||
        durationMs <= 0) {
      throw const FormatException('Invalid scene bible source');
    }
    return {
      'schema': 'otakudub_directors_scene_bible_v1',
      'source_sha256': sourceSha256,
      'duration_ms': durationMs,
      'capabilities': {
        for (final name in additionalCapabilities) name: {
          'state': 'unavailable', 'evidence_ids': <String>[],
          'independent_review': 'pending',
        },
      },
      'scenes': <Object>[],
      'approved': false,
    };
  }

  /// No empty, unattributed, out-of-range or contradictory scene can pass.
  /// A producer-set approved flag cannot bypass evidence/review requirements.
  Map<String, dynamic> review(Map<String, dynamic> bible) {
    final errors = <String>[];
    if (bible['schema'] != 'otakudub_directors_scene_bible_v1' ||
        bible['source_sha256'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(bible['source_sha256'] as String) ||
        bible['duration_ms'] is! int || (bible['duration_ms'] as int) <= 0) {
      return {'passed': false, 'errors': ['Invalid source-bound bible']};
    }
    final duration = bible['duration_ms'] as int;
    final capabilities = bible['capabilities'];
    if (capabilities is! Map || capabilities.length != additionalCapabilities.length) {
      errors.add('Missing or unexpected dramatic capability');
    } else {
      for (final name in additionalCapabilities) {
        final record = capabilities[name];
        if (record is! Map || record['state'] != 'verified' ||
            record['independent_review'] != 'passed' ||
            record['evidence_ids'] is! List ||
            (record['evidence_ids'] as List).isEmpty ||
            (record['evidence_ids'] as List).any((id) =>
                id is! String || id.trim().isEmpty)) {
          errors.add('Unverified dramatic capability: $name');
        }
      }
    }
    final scenes = bible['scenes'];
    if (scenes is! List || scenes.isEmpty) {
      errors.add('No scene bible records');
    } else {
      var previousEnd = 0;
      for (final scene in scenes) {
        if (scene is! Map) {
          errors.add('Invalid scene record');
          continue;
        }
        final start = scene['start_ms'], end = scene['end_ms'];
        if (start is! int || end is! int || start < previousEnd ||
            end <= start || end > duration) {
          errors.add('Overlapping or invalid scene interval');
          continue;
        }
        previousEnd = end;
        if (scene['scene_id'] is! String ||
            (scene['scene_id'] as String).trim().isEmpty) {
          errors.add('Invalid scene identifier');
        }
        for (final key in [
          'narrative_context', 'dramatic_intent',
          'emotion_performance', 'dialogue_attribution',
          'timing_constraints', 'character_relationships',
        ]) {
          final field = scene[key];
          if (field is! Map || field['status'] != 'verified' ||
              field['evidence_ids'] is! List ||
              (field['evidence_ids'] as List).isEmpty ||
              field['review'] != 'passed') {
            errors.add('Unverified $key in scene');
          }
        }
        if (scene['unresolved_conflicts'] is! List ||
            (scene['unresolved_conflicts'] as List).isNotEmpty) {
          errors.add('Unresolved scene conflicts');
        }
      }
    }
    if (bible['approved'] != true) errors.add('Director approval missing');
    return {'passed': errors.isEmpty, 'errors': errors.toSet().toList()};
  }

  String fingerprint(Map<String, dynamic> bible) =>
      crypto.sha256.convert(utf8.encode(jsonEncode(bible))).toString();
}
