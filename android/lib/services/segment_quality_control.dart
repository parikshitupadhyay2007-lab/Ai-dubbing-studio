import '../models/dub_project.dart';
import 'dialogue_quality_gate.dart';

/// Deterministic pre-export triage. These checks are not perceptual MOS or ASR
/// measurements: audio quality requires measured waveform and listening data.
enum QualityIssue {
  invalidTiming,
  invalidTranslation,
  unresolvedSpeaker,
  missingVoice,
  invalidAudioMeasurement,
  silence,
  clipping,
  durationMismatch,
}

class SegmentAudioMeasurement {
  final double durationSeconds;
  final double peakAbsolute;
  final double rms;
  const SegmentAudioMeasurement({
    required this.durationSeconds,
    required this.peakAbsolute,
    required this.rms,
  });
}

class SegmentQualityReport {
  final int segmentId;
  final Set<QualityIssue> issues;
  const SegmentQualityReport(this.segmentId, this.issues);
  bool get passed => issues.isEmpty;
  bool get needsTranslationRetry => issues.contains(QualityIssue.invalidTranslation);
  bool get needsSynthesisRetry => issues.any((issue) => {
    QualityIssue.silence, QualityIssue.clipping,
    QualityIssue.durationMismatch, QualityIssue.invalidAudioMeasurement,
  }.contains(issue));
  bool get needsManualReview => issues.any((issue) => {
    QualityIssue.invalidTiming, QualityIssue.unresolvedSpeaker,
    QualityIssue.missingVoice,
  }.contains(issue));
}

/// Does not invent a speaker identity or declare perceptual quality from text.
class SegmentQualityControl {
  static SegmentQualityReport inspect({
    required DubSegment segment,
    required String sourceLanguage,
    required String targetLanguage,
    SegmentAudioMeasurement? audio,
  }) {
    final issues = <QualityIssue>{};
    final window = segment.end - segment.start;
    if (!segment.start.isFinite || !segment.end.isFinite ||
        segment.start < 0 || window <= 0) {
      issues.add(QualityIssue.invalidTiming);
    }
    if (!DialogueQualityGate.acceptableTranslation(
      segment.translation, segment.original, sourceLanguage, targetLanguage,
    )) {
      issues.add(QualityIssue.invalidTranslation);
    }
    // A manually reviewed identity is explicitly persisted with confidence 0
    // (not a fabricated model score), even when linked to an existing speaker.
    // It is accepted only after an explicit voice assignment below.
    final manuallyResolved = segment.speakerManuallyVerified &&
        segment.speakerConfidence == 0;
    if (segment.speakerId.trim().isEmpty || segment.speakerId == 'unknown' ||
        !segment.speakerConfidence.isFinite ||
        (!manuallyResolved && segment.speakerConfidence <= 0)) {
      issues.add(QualityIssue.unresolvedSpeaker);
    }
    if (segment.voiceId.trim().isEmpty) issues.add(QualityIssue.missingVoice);
    if (audio != null) {
      if (!audio.durationSeconds.isFinite || !audio.peakAbsolute.isFinite ||
          !audio.rms.isFinite || audio.durationSeconds <= 0 ||
          audio.peakAbsolute < 0 || audio.rms < 0 ||
          audio.peakAbsolute > 1.0 || audio.rms > 1.0) {
        issues.add(QualityIssue.invalidAudioMeasurement);
      } else {
        if (audio.rms < 0.0001) issues.add(QualityIssue.silence);
        if (audio.peakAbsolute >= 32767 / 32768) issues.add(QualityIssue.clipping);
        if (window > 0 && audio.durationSeconds > window * 1.12) {
          issues.add(QualityIssue.durationMismatch);
        }
      }
    }
    return SegmentQualityReport(segment.id, Set.unmodifiable(issues));
  }
}

/// Bounded retries per segment. Persist attempt counts with project checkpoints
/// before integrating into the export pipeline; never loop on an unresolved issue.
class QualityRetryPolicy {
  static const maxTranslationAttempts = 2;
  static const maxSynthesisAttempts = 2;
  static bool mayRetryTranslation(SegmentQualityReport report, int attempts) =>
      attempts >= 0 && attempts < maxTranslationAttempts &&
      report.needsTranslationRetry;
  static bool mayRetrySynthesis(SegmentQualityReport report, int attempts) =>
      attempts >= 0 && attempts < maxSynthesisAttempts &&
      report.needsSynthesisRetry && !report.needsManualReview;
}
