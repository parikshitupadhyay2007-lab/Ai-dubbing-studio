import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/models/dub_project.dart';
import 'package:ai_dubbing_studio/services/segment_quality_control.dart';

void main() {
  DubSegment segment({
    double start = 0, double end = 2,
    String translation = 'मुझे घर जाना है।',
    String speaker = 'speaker_1', String voice = 'hi_hero',
    double confidence = 0.8,
  }) => DubSegment(
    id: 1, start: start, end: end, original: 'I must go home.',
    translation: translation, speakerId: speaker, voiceId: voice,
    speakerConfidence: confidence,
  );

  SegmentQualityReport check(DubSegment s, {SegmentAudioMeasurement? audio}) =>
      SegmentQualityControl.inspect(
        segment: s, sourceLanguage: 'en', targetLanguage: 'hi', audio: audio,
      );

  test('well formed segment passes deterministic gate', () {
    expect(check(segment()).passed, isTrue);
  });
  test('rejects invalid timing and unresolved casting', () {
    final report = check(segment(start: -1, speaker: 'unknown', voice: '', confidence: 0));
    expect(report.issues, containsAll([
      QualityIssue.invalidTiming, QualityIssue.unresolvedSpeaker, QualityIssue.missingVoice,
    ]));
    expect(report.needsManualReview, isTrue);
  });
  test('rejects unchanged language and bad generated text', () {
    expect(check(segment(translation: 'I must go home.')).issues,
        contains(QualityIssue.invalidTranslation));
  });
  test('rejects silence clipping and excessive duration', () {
    expect(check(segment(), audio: const SegmentAudioMeasurement(
      durationSeconds: 1, peakAbsolute: 0, rms: 0,
    )).issues, contains(QualityIssue.silence));
    expect(check(segment(), audio: const SegmentAudioMeasurement(
      durationSeconds: 1, peakAbsolute: 1, rms: 0.2,
    )).issues, contains(QualityIssue.clipping));
    expect(check(segment(), audio: const SegmentAudioMeasurement(
      durationSeconds: 2.5, peakAbsolute: 0.5, rms: 0.1,
    )).issues, contains(QualityIssue.durationMismatch));
  });
  test('retries are bounded and never bypass manual review', () {
    final report = check(segment(voice: ''), audio: const SegmentAudioMeasurement(
      durationSeconds: 1, peakAbsolute: 0, rms: 0,
    ));
    expect(QualityRetryPolicy.mayRetrySynthesis(report, 0), isFalse);
    expect(QualityRetryPolicy.mayRetrySynthesis(
      check(segment(), audio: const SegmentAudioMeasurement(
        durationSeconds: 1, peakAbsolute: 0, rms: 0,
      )), 2), isFalse);
  });
}
