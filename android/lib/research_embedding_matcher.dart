import 'dart:math' as math;

/// Scores actual model embeddings against a source-authorised local reference
/// index. Never converts an uncalibrated similarity into an identity claim.
class ResearchEmbeddingMatcher {
  const ResearchEmbeddingMatcher();

  Map<String, dynamic> rank({
    required List<double> query,
    required Map<String, List<double>> references,
    int limit = 5,
    double minimumSimilarity = 0.65,
    double minimumMargin = 0.08,
  }) {
    if (query.isEmpty || query.length > 4096 || references.isEmpty ||
        limit < 1 || limit > 20 ||
        !minimumSimilarity.isFinite || minimumSimilarity < -1 ||
        minimumSimilarity > 1 ||
        !minimumMargin.isFinite || minimumMargin < 0 || minimumMargin > 2) {
      throw const FormatException('Invalid embedding search configuration');
    }
    double norm(List<double> vector) {
      if (vector.length != query.length ||
          vector.any((value) => !value.isFinite)) {
        throw const FormatException('Invalid embedding dimensions or values');
      }
      final result = math.sqrt(vector.fold<double>(0, (s, v) => s + v * v));
      if (!result.isFinite || result <= 1e-12) {
        throw const FormatException('Degenerate embedding');
      }
      return result;
    }
    final queryNorm = norm(query);
    final results = <Map<String, dynamic>>[];
    for (final entry in references.entries) {
      if (entry.key.trim().isEmpty) {
        throw const FormatException('Unidentified reference');
      }
      final referenceNorm = norm(entry.value);
      var dot = 0.0;
      for (var i = 0; i < query.length; i++) {
        dot += query[i] * entry.value[i];
      }
      results.add({'reference_id': entry.key,
        'similarity': (dot / (queryNorm * referenceNorm)).clamp(-1.0, 1.0)});
    }
    results.sort((a, b) {
      final byScore = (b['similarity'] as double).compareTo(a['similarity'] as double);
      return byScore != 0 ? byScore :
        (a['reference_id'] as String).compareTo(b['reference_id'] as String);
    });
    final first = results.first['similarity'] as double;
    final second = results.length > 1 ? results[1]['similarity'] as double : -1.0;
    return {
      'candidates': results.take(limit).toList(),
      'status': first >= minimumSimilarity && first - second >= minimumMargin
          ? 'candidate_requires_independent_review' : 'ambiguous_or_unknown',
      'metric': 'cosine_similarity',
      'calibrated_confidence': false,
      'verified_identity': false,
    };
  }
}
