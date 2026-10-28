/// Strict visual reference lookup performed before speech transcription.
/// Perceptual hashes are retrieval evidence, NOT proof of a byte-identical cut.
/// A match must not automatically replace recorded dialogue until a separate
/// timeline alignment/asset identity verifier is available.
class ReferenceFirstLookup {
  const ReferenceFirstLookup();

  Map<String, dynamic>? candidate(
    List<Map<String, dynamic>> corpus,
    List<String> observed,
  ) {
    if (observed.length < 3 ||
        observed.any((h) => !RegExp(r'^[0-9a-fA-F]{16}$').hasMatch(h))) {
      return null;
    }
    final hits = <Map<String, dynamic>>[];
    for (final entry in corpus) {
      final hashes = entry['frame_hashes'];
      final timeline = entry['timeline'];
      if (hashes is! List || timeline is! List || timeline.isEmpty ||
          hashes.length != observed.length || hashes.length < 3 ||
          entry['source_id'] is! String ||
          (entry['source_id'] as String).trim().isEmpty) continue;
      // All ordered samples must agree. No nearest-neighbour substitution.
      var agrees = true;
      for (var i = 0; i < observed.length; i++) {
        if (hashes[i] is! String ||
            (hashes[i] as String).toLowerCase() != observed[i].toLowerCase()) {
          agrees = false;
          break;
        }
      }
      if (agrees) hits.add(entry);
    }
    // Identical fingerprints for multiple records are ambiguous.
    if (hits.length != 1) return null;
    final hit = hits.single;
    return <String, dynamic>{
      'anime_id': hit['anime_id'],
      'title': hit['title'],
      'episode_id': hit['episode_id'],
      'source_id': hit['source_id'],
      'reference_start_seconds': hit['start_seconds'],
      'evidence': 'ordered_visual_hash_retrieval',
      'identity_status': 'candidate_pending_exact_timeline_verification',
      'reference_dialogue_status': 'not_applied',
      'matching_frames': observed.length,
    };
  }
}
