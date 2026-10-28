import '../models/dub_project.dart';

/// Deterministic post-synthesis alignment triage. This checks measured speech
/// duration against the source timeline; it does not claim visual lip accuracy.
/// A future validated audiovisual engine may supply independent mouth timings.
class DialogueAlignmentGate {
  const DialogueAlignmentGate();

  String? rejection({
    required DubSegment segment,
    required double speechSeconds,
    required List<DubSegment> timeline,
    double? measuredMouthStart,
    double? measuredMouthEnd,
  }) {
    final start = segment.start;
    final end = segment.synthesisEnd ?? segment.end;
    if (!start.isFinite || !end.isFinite || end <= start ||
        !speechSeconds.isFinite || speechSeconds <= 0) {
      return 'invalid_timing_or_measurement';
    }
    if (segment.synthesisEnd != null &&
        (segment.synthesisEnd! < segment.end ||
         segment.synthesisEnd! - segment.end > 0.451)) {
      return 'invalid_timing_extension';
    }
    final following = timeline.where((line) =>
        line.id != segment.id && line.start >= segment.end).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (following.isNotEmpty && end > following.first.start - 0.079) {
      return 'overlaps_next_dialogue';
    }
    // Native output may be time-compressed by WSOLA up to 1.5x. Longer
    // source speech is not automatically acceptable or silently truncated.
    if (speechSeconds > (end - start) * 1.50 + 0.01) {
      return 'speech_exceeds_safe_fit';
    }
    if ((measuredMouthStart == null) != (measuredMouthEnd == null)) {
      return 'incomplete_visual_measurement';
    }
    if (measuredMouthStart != null && measuredMouthEnd != null) {
      if (!measuredMouthStart.isFinite || !measuredMouthEnd.isFinite ||
          measuredMouthEnd <= measuredMouthStart ||
          (measuredMouthStart - start).abs() > 0.12 ||
          (measuredMouthEnd - segment.end).abs() > 0.18) {
        return 'visual_timing_mismatch';
      }
    }
    return null;
  }
}
