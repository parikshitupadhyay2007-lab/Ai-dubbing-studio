import '../models/dub_project.dart';

/// Extends synthesis into proven adjacent silence only. The original Whisper
/// segment boundaries remain unchanged for identity and scene evidence.
class IntelligentTimingController {
  static const maxBorrowSeconds = 0.45;
  static const guardSeconds = 0.08;

  static double? extendIntoFollowingGap(DubProject project, DubSegment segment) {
    final ordered = [...project.segments]..sort((a, b) => a.start.compareTo(b.start));
    final index = ordered.indexWhere((s) => s.id == segment.id);
    if (index < 0 || !segment.end.isFinite || !segment.start.isFinite ||
        segment.end <= segment.start) return null;
    final nextStart = index + 1 < ordered.length
        ? ordered[index + 1].start : null;
    // Never assume silence after the final line: scene/video end is unknown.
    if (nextStart == null || !nextStart.isFinite) return null;
    final gap = nextStart - segment.end - guardSeconds;
    if (gap <= 0) return null;
    final proposed = segment.end + (gap < maxBorrowSeconds ? gap : maxBorrowSeconds);
    if (proposed <= segment.end || proposed >= nextStart) return null;
    return proposed;
  }
}
