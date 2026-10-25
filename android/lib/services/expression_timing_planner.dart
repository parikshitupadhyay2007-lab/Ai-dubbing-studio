import '../models/dub_project.dart';
import 'visual_speaker_evidence.dart';

/// Uses measured visual evidence without inventing an emotion label.
class ExpressionTimingPlanner {
  const ExpressionTimingPlanner();

  /// Returns the IDs with verified, unambiguous visual coverage and
  /// non-overlapping acoustic intervals. Original timing is never altered.
  List<int> eligibleSegmentIds(
    DubProject project,
    Map<int, VisualSpeakerEvidence> measured,
  ) {
    final ordered = List<DubSegment>.of(project.segments)
      ..sort((a, b) => a.start.compareTo(b.start));
    final eligible = <int>[];
    for (var i = 0; i < ordered.length; i++) {
      final segment = ordered[i];
      final visual = measured[segment.id];
      if (visual == null || !visual.unambiguousCandidate ||
          visual.startSeconds > segment.start + 0.15 ||
          visual.endSeconds < segment.end - 0.15) continue;
      if (i > 0 && ordered[i - 1].end > segment.start) continue;
      if (i + 1 < ordered.length &&
          ordered[i + 1].start < segment.end) continue;
      eligible.add(segment.id);
    }
    return List.unmodifiable(eligible);
  }
}
