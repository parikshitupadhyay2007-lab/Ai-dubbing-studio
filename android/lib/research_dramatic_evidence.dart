/// Translates already measured and source-attributed observations into a
/// provisional director's record, without inventing intent or emotions.
class ResearchDramaticEvidence {
  const ResearchDramaticEvidence();

  Map<String, dynamic> assemble({
    required int durationMs,
    required List<Map<String, dynamic>> scenes,
    required List<Map<String, dynamic>> dialogue,
  }) {
    if (durationMs <= 0 || scenes.isEmpty) {
      throw const FormatException('Missing dramatic source');
    }
    final records = <Map<String, dynamic>>[];
    var previous = 0;
    for (final scene in scenes) {
      final start = scene['start_ms'], end = scene['end_ms'];
      final id = scene['scene_id'];
      if (start is! int || end is! int || start != previous || end <= start ||
          end > durationMs || id is! String || id.isEmpty) {
        throw const FormatException('Scene chronology or coverage incomplete');
      }
      final lines = <Map<String, dynamic>>[];
      for (final d in dialogue) {
        final a = d['start_ms'], b = d['end_ms'];
        if (a is! int || b is! int || a < 0 || b <= a || b > durationMs ||
            d['evidence_id'] is! String || (d['evidence_id'] as String).isEmpty) {
          throw const FormatException('Invalid dialogue timing evidence');
        }
        if (a >= start && b <= end) {
          lines.add({'start_ms': a, 'end_ms': b,
            'evidence_id': d['evidence_id'], 'speaker_track_id': d['speaker_track_id'],
            'emotion': d['measured_emotion'] ?? 'unknown',
            'performance_review': 'pending'});
        } else if (a < end && b > start) {
          throw const FormatException('Dialogue crosses unreviewed scene boundary');
        }
      }
      records.add({'scene_id': id, 'start_ms': start, 'end_ms': end,
        'timed_dialogue': lines,
        'narrative_context': {'status': 'pending_inference', 'evidence_ids': []},
        'dramatic_intent': {'status': 'pending_inference', 'evidence_ids': []},
        'emotion_performance': {'status': 'pending_review',
          'evidence_ids': lines.map((l) => l['evidence_id']).toList()},
        'dialogue_attribution': {'status': 'pending_review',
          'evidence_ids': lines.map((l) => l['evidence_id']).toList()},
        'timing_constraints': {'status': 'provisional',
          'evidence_ids': lines.map((l) => l['evidence_id']).toList()},
        'character_relationships': {'status': 'pending_inference', 'evidence_ids': []},
        'unresolved_conflicts': <String>[],
      });
      previous = end;
    }
    if (previous != durationMs) {
      throw const FormatException('Dramatic scenes do not cover source duration');
    }
    return {'scenes': records, 'approved': false,
      'narrative_inference_verified': false,
      'emotion_inference_verified': false,
      'requires_independent_review': true};
  }
}
