import '../models/dub_project.dart';
import 'visual_speaker_evidence.dart';

/// Validates the output of an independently installed native active-speaker
/// model against immutable acoustic segments. Does not perform inference.
class ActiveSpeakerEvidenceGate {
  const ActiveSpeakerEvidenceGate();

  Map<int, VisualSpeakerEvidence> evaluate(DubProject project,
      Iterable<VisualSpeakerEvidence> candidates) {
    final bySegment = {for (final segment in project.segments) segment.id: segment};
    final accepted = <int, VisualSpeakerEvidence>{};
    final ambiguous = <int>{};
    for (final candidate in candidates) {
      final segment = bySegment[candidate.segmentId];
      if (segment == null || !candidate.unambiguousCandidate ||
          candidate.startSeconds > segment.start + 0.15 ||
          candidate.endSeconds < segment.end - 0.15 ||
          segment.speakerId.trim().isEmpty || segment.speakerId == 'unknown') {
        continue;
      }
      if (ambiguous.contains(candidate.segmentId)) continue;
      final old = accepted[candidate.segmentId];
      if (old == null) {
        accepted[candidate.segmentId] = candidate;
      } else if (old.trackId != candidate.trackId ||
          old.modelId != candidate.modelId || old.sourceHash != candidate.sourceHash) {
        accepted.remove(candidate.segmentId);
        ambiguous.add(candidate.segmentId);
      } else if (candidate.lipSyncScore > old.lipSyncScore) {
        accepted[candidate.segmentId] = candidate;
      }
    }
    return Map.unmodifiable(accepted);
  }
}
