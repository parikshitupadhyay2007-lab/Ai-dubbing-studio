/// Fuses timestamp-aligned independently measured audio and mouth-motion
/// scores. Absence, conflict or weak separation must abstain.
class ResearchSpeakerAttribution {
  const ResearchSpeakerAttribution();

  Map<String, dynamic> attribute({
    required int durationMs,
    required List<Map<String, dynamic>> dialogue,
    double minimumScore = 0.72,
    double minimumMargin = 0.12,
  }) {
    if (durationMs <= 0 || dialogue.length > 10000 ||
        !minimumScore.isFinite || minimumScore < 0 || minimumScore > 1 ||
        !minimumMargin.isFinite || minimumMargin < 0 || minimumMargin > 1) {
      throw const FormatException('Invalid attribution contract');
    }
    final output = <Map<String, dynamic>>[];
    for (final segment in dialogue) {
      final start = segment['start_ms'], end = segment['end_ms'];
      final audioId = segment['speaker_embedding_id'];
      final candidates = segment['candidates'];
      if (start is! int || end is! int || start < 0 || end <= start ||
          end > durationMs || audioId is! String || audioId.isEmpty ||
          candidates is! List || candidates.length > 100) {
        throw const FormatException('Invalid dialogue observation');
      }
      final scored = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final item in candidates) {
        if (item is! Map || item['track_id'] is! String ||
            !seen.add(item['track_id'] as String) ||
            item['mouth_sync_score'] is! num ||
            item['audio_visual_score'] is! num ||
            item['evidence_id'] is! String ||
            (item['evidence_id'] as String).isEmpty) {
          throw const FormatException('Malformed attribution candidate');
        }
        final mouth = item['mouth_sync_score'] as num;
        final fusion = item['audio_visual_score'] as num;
        if (!mouth.isFinite || !fusion.isFinite ||
            mouth < 0 || mouth > 1 || fusion < 0 || fusion > 1) {
          throw const FormatException('Invalid measured synchrony score');
        }
        scored.add({'track_id': item['track_id'], 'evidence_id': item['evidence_id'],
          'score': mouth.toDouble() * 0.5 + fusion.toDouble() * 0.5});
      }
      scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
      final best = scored.isEmpty ? 0.0 : scored.first['score'] as double;
      final runner = scored.length < 2 ? 0.0 : scored[1]['score'] as double;
      final eligible = scored.isNotEmpty &&
          best >= minimumScore && best - runner >= minimumMargin;
      output.add({'start_ms': start, 'end_ms': end,
        'speaker_embedding_id': audioId,
        'candidate_track_id': eligible ? scored.first['track_id'] : null,
        'status': eligible ? 'provisional_requires_review' : 'unattributed',
        'candidate_scores': scored, 'verified_speaker': false});
    }
    return {'dialogue_attribution': output, 'verified': false,
      'requires_independent_review': true};
  }
}
