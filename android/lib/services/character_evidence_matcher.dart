import '../models/dub_project.dart';
import 'visual_speaker_evidence.dart';

/// Produces *candidates* from explicitly annotated reference lines and
/// measured speaking tracks. It cannot authenticate a corpus or model.
class CharacterMatchCandidate {
  final String speakerId;
  final String characterId;
  final int segmentId;
  final String trackId;
  final String referenceId;
  final double visualScore;
  const CharacterMatchCandidate(this.speakerId, this.characterId,
      this.segmentId, this.trackId, this.referenceId, this.visualScore);
}

class CharacterEvidenceMatcher {
  const CharacterEvidenceMatcher();

  /// Reference annotations must contain immutable dialogue segment ID,
  /// visual track ID and character ID. Never infer character identity from
  /// appearing in a scene or dialog semantics.
  List<CharacterMatchCandidate> propose(
    DubProject project,
    Map<int, VisualSpeakerEvidence> measured,
    List<Map<String, dynamic>> referenceAnnotations,
  ) {
    final segments = {for (final s in project.segments) s.id: s};
    final results = <CharacterMatchCandidate>[];
    final conflicts = <int>{};
    for (final row in referenceAnnotations) {
      final segmentId = row['segment_id'];
      final trackId = row['track_id'];
      final character = row['character_id'];
      final reference = row['reference_id'];
      if (segmentId is! int || trackId is! String || character is! String ||
          reference is! String || trackId.trim().isEmpty ||
          character.trim().isEmpty || reference.trim().isEmpty) continue;
      final segment = segments[segmentId];
      final visual = measured[segmentId];
      if (segment == null || visual == null || visual.trackId != trackId ||
          segment.speakerId.isEmpty || segment.speakerId == 'unknown' ||
          !visual.unambiguousCandidate) continue;
      if (conflicts.contains(segmentId)) continue;
      final candidate = CharacterMatchCandidate(segment.speakerId, character,
          segmentId, trackId, reference, visual.lipSyncScore);
      final existing = results.where((c) => c.segmentId == segmentId).toList();
      if (existing.any((c) => c.characterId != character ||
          c.trackId != trackId || c.referenceId != reference)) {
        results.removeWhere((c) => c.segmentId == segmentId);
        conflicts.add(segmentId);
      } else if (existing.isEmpty) {
        results.add(candidate);
      }
    }
    return List.unmodifiable(results);
  }
}
