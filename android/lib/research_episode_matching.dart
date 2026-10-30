import 'research_embedding_matcher.dart';

/// Episode-level hypothesis aggregation from rights-vetted reference vectors.
/// Does not infer anime titles from metadata alone.
class ResearchEpisodeMatching {
  const ResearchEpisodeMatching();

  Map<String, dynamic> compare({
    required List<List<double>> sampledEmbeddings,
    required Map<String, List<double>> authorisedReferences,
    required Map<String, Map<String, dynamic>> provenance,
    int minimumConsistentSamples = 3,
  }) {
    if (sampledEmbeddings.length < minimumConsistentSamples ||
        minimumConsistentSamples < 2 || authorisedReferences.isEmpty ||
        provenance.length != authorisedReferences.length) {
      throw const FormatException('Insufficient or unmatched episode evidence');
    }
    final votes = <String, int>{};
    final observations = <Map<String, dynamic>>[];
    for (final entry in authorisedReferences.entries) {
      final meta = provenance[entry.key];
      if (meta == null || meta['episode_id'] is! String ||
          meta['anime_id'] is! String || meta['rights_basis'] is! String ||
          !{'original', 'licensed', 'public_domain'}.contains(meta['rights_basis']) ||
          meta['source_sha256'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(meta['source_sha256'] as String)) {
        throw const FormatException('Reference missing episode or rights provenance');
      }
    }
    for (final sample in sampledEmbeddings) {
      final result = const ResearchEmbeddingMatcher().rank(
        query: sample, references: authorisedReferences);
      final candidates = result['candidates'] as List;
      final candidate = result['status'] == 'candidate_requires_independent_review'
          ? (candidates.first as Map)['reference_id'] as String : null;
      if (candidate != null) {
        final episode = provenance[candidate]!['episode_id'] as String;
        votes[episode] = (votes[episode] ?? 0) + 1;
      }
      observations.add({'candidate_reference_id': candidate,
        'status': result['status']});
    }
    final sorted = votes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final best = sorted.isEmpty ? null : sorted.first;
    final next = sorted.length > 1 ? sorted[1].value : 0;
    final unanimousEnough = best != null &&
        best.value >= minimumConsistentSamples &&
        best.value > next && best.value / sampledEmbeddings.length >= 0.75;
    return {'candidate_episode_id': unanimousEnough ? best.key : null,
      'status': unanimousEnough ? 'provisional_episode_requires_review' : 'unknown_or_ambiguous',
      'votes': votes, 'sample_results': observations,
      'verified_episode': false, 'requires_independent_review': true};
  }
}
