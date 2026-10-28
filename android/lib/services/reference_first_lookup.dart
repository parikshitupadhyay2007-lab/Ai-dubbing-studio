import '../models/dub_project.dart';

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

/// Only a byte-identical registered media asset may bypass transcription.
/// Visual/perceptual candidates above must never supply definitive dialogue.
class ExactReferenceDialogue {
  const ExactReferenceDialogue();

  Map<String, dynamic>? match(
      List<Map<String, dynamic>> corpus, String mediaSha256) {
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(mediaSha256)) return null;
    final hits = corpus.where((entry) =>
        entry['asset_sha256'] is String &&
        (entry['asset_sha256'] as String).toLowerCase() ==
            mediaSha256.toLowerCase()).toList();
    if (hits.length != 1) return null;
    final row = hits.single;
    if (row['start_seconds'] != 0 || row['end_seconds'] is! num ||
        row['source_language'] is! String ||
        !RegExp(r'^[a-z]{2,3}$').hasMatch(row['source_language'] as String) ||
        row['timeline'] is! List) return null;
    final timeline = row['timeline'] as List;
    if (timeline.isEmpty) return null;
    final segments = <DubSegment>[];
    final speakerRoles = <String, String>{};
    var lastEnd = 0.0;
    for (var i = 0; i < timeline.length; i++) {
      final raw = timeline[i];
      if (raw is! Map) return null;
      final line = Map<String, dynamic>.from(raw);
      final start = line['start_seconds'];
      final end = line['end_seconds'];
      final dialogue = line['dialogue'];
      final speaker = line['speaker_id'];
      if (start is! num || end is! num ||
          !start.toDouble().isFinite || !end.toDouble().isFinite ||
          start < lastEnd || end <= start ||
          end > (row['end_seconds'] as num) ||
          dialogue is! String || dialogue.trim().isEmpty ||
          speaker is! String || speaker.trim().isEmpty ||
          line['source_id'] != row['source_id']) return null;
      final role = line['voice_role'];
      if (role != null) {
        if (role is! String || !const {'male', 'female', 'youthful'}.contains(role) ||
            (speakerRoles.containsKey(speaker) && speakerRoles[speaker] != role)) return null;
        speakerRoles[speaker] = role;
      }
      segments.add(DubSegment(
        id: i + 1,
        start: start.toDouble(),
        end: end.toDouble(),
        original: dialogue,
        speakerId: speaker,
        speakerConfidence: 1.0, // Exact registered-script attribution, not an acoustic score.
      ));
      lastEnd = end.toDouble();
    }
    return <String, dynamic>{
      'segments': segments,
      'source_language': row['source_language'],
      'context': <String, dynamic>{
        'anime_id': row['anime_id'],
        'title': row['title'],
        'episode_id': row['episode_id'],
        'source_id': row['source_id'],
        'reference_start_seconds': 0.0,
        'evidence': 'exact_registered_media_sha256',
        'identity_status': 'exact_registered_asset',
        'reference_dialogue_status': 'exact_asset_script_applied',
        'matching_lines': segments.length,
        'speaker_roles': speakerRoles,
        'casting_evidence': 'registered_exact_asset_timeline',
      },
    };
  }
}
