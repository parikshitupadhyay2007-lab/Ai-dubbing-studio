import 'dart:math' as math;

/// Cross-frame identity hypotheses; accepts measured embeddings only.
/// A hypothesis is never a verified character, name, or voice assignment.
class ResearchCharacterFusion {
  const ResearchCharacterFusion();

  Map<String, dynamic> track({
    required List<Map<String, dynamic>> observations,
    double similarityThreshold = 0.83,
    double ambiguityMargin = 0.08,
  }) {
    if (observations.isEmpty || observations.length > 20000 ||
        !similarityThreshold.isFinite || similarityThreshold < -1 || similarityThreshold > 1 ||
        !ambiguityMargin.isFinite || ambiguityMargin < 0 || ambiguityMargin > 2) {
      throw const FormatException('Invalid identity tracking contract');
    }
    final tracks = <Map<String, dynamic>>[];
    final assignments = <Map<String, dynamic>>[];
    int previousTime = -1;
    int? dimension;
    List<double> normalize(Object? raw) {
      if (raw is! List || raw.isEmpty || raw.length > 4096 ||
          (dimension != null && raw.length != dimension) ||
          raw.any((v) => v is! num || !v.isFinite)) {
        throw const FormatException('Invalid visual embedding');
      }
      final values = raw.cast<num>().map((v) => v.toDouble()).toList();
      final length = math.sqrt(values.fold<double>(0, (s, v) => s + v * v));
      if (!length.isFinite || length < 1e-12) {
        throw const FormatException('Degenerate character observation');
      }
      dimension = values.length;
      return values.map((v) => v / length).toList();
    }
    double similarity(List<double> a, List<double> b) {
      var dot = 0.0;
      for (var i = 0; i < a.length; i++) { dot += a[i] * b[i]; }
      return dot.clamp(-1.0, 1.0).toDouble();
    }
    for (final observation in observations) {
      final timestamp = observation['timestamp_ms'];
      final evidence = observation['evidence_id'];
      if (timestamp is! int || timestamp < 0 || timestamp < previousTime ||
          evidence is! String || !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(evidence) ||
          observation['detector_verified'] != true) {
        throw const FormatException('Unvalidated character observation');
      }
      final vector = normalize(observation['visual_embedding']);
      previousTime = timestamp;
      final scored = tracks.map((t) => (
        track: t,
        score: similarity(vector, t['centroid'] as List<double>),
      )).toList()..sort((a, b) => b.score.compareTo(a.score));
      String? assigned;
      var status = 'unknown';
      if (scored.isEmpty) {
        assigned = 'local_track_0';
        status = 'new_local_track';
      } else {
        final top = scored.first;
        final second = scored.length > 1 ? scored[1].score : -1.0;
        if (top.score >= similarityThreshold &&
            top.score - second >= ambiguityMargin) {
          assigned = top.track['track_id'] as String;
          status = 'provisional_track_match';
        } else if (top.score < similarityThreshold - ambiguityMargin) {
          assigned = 'local_track_${tracks.length}';
          status = 'new_local_track';
        } else {
          status = 'ambiguous_abstain';
        }
      }
      if (assigned != null) {
        final found = tracks.where((t) => t['track_id'] == assigned).toList();
        if (found.isEmpty) {
          tracks.add({'track_id': assigned, 'centroid': vector,
            'count': 1, 'evidence_ids': <String>[evidence]});
        } else {
          final t = found.single;
          final count = t['count'] as int;
          final old = t['centroid'] as List<double>;
          final blended = List<double>.generate(vector.length,
            (i) => (old[i] * count + vector[i]) / (count + 1));
          final norm = math.sqrt(blended.fold<double>(0, (s, v) => s + v * v));
          t['centroid'] = blended.map((v) => v / norm).toList();
          t['count'] = count + 1;
          (t['evidence_ids'] as List<String>).add(evidence);
        }
      }
      assignments.add({'timestamp_ms': timestamp, 'evidence_id': evidence,
        'track_id': assigned, 'status': status, 'verified_character': false});
    }
    return {'assignments': assignments,
      'tracks': tracks.map((t) => {
        'track_id': t['track_id'], 'sample_count': t['count'],
        'evidence_ids': t['evidence_ids'], 'verified_character': false,
      }).toList(), 'identity_verified': false,
      'requires_independent_review': true};
  }
}
