import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/models/dub_project.dart';
import 'package:ai_dubbing_studio/services/segment_quality_control.dart';

DubSegment segment({required String speaker, required double confidence,
  bool manuallyVerified = false, String voice = 'hi_hero'}) =>
    DubSegment(id: 1, start: 1, end: 3, original: 'こんにちは',
      translation: 'नमस्ते', speakerId: speaker, voiceId: voice,
      speakerConfidence: confidence,
      speakerManuallyVerified: manuallyVerified);

Set<QualityIssue> issues(DubSegment s) => SegmentQualityControl.inspect(
  segment: s, sourceLanguage: 'ja', targetLanguage: 'hi').issues;

void main() {
  test('explicitly verified existing speaker is not rejected for zero confidence', () {
    expect(issues(segment(speaker: 'speaker_1', confidence: 0,
      manuallyVerified: true)), isEmpty);
  });
  test('manual new speaker with assigned voice is accepted', () {
    expect(issues(segment(speaker: 'speaker_manual_1', confidence: 0,
      manuallyVerified: true)), isEmpty);
  });
  test('unverified zero confidence must still fail', () {
    expect(issues(segment(speaker: 'speaker_1', confidence: 0)),
      contains(QualityIssue.unresolvedSpeaker));
  });
  test('unknown speaker cannot be bypassed by manual flag', () {
    expect(issues(segment(speaker: 'unknown', confidence: 0,
      manuallyVerified: true)), contains(QualityIssue.unresolvedSpeaker));
  });
  test('manual verification still requires a voice', () {
    expect(issues(segment(speaker: 'speaker_1', confidence: 0,
      manuallyVerified: true, voice: '')), contains(QualityIssue.missingVoice));
  });
  test('manual verification survives project JSON checkpoint', () {
    final project = DubProject(id: 'fixture', title: 'fixture',
      sourcePath: 'source.mp4', targetLanguage: 'hi',
      segments: [segment(speaker: 'speaker_1', confidence: 0,
        manuallyVerified: true)]);
    final restored = DubProject.decode(project.encode());
    expect(restored.segments.single.speakerManuallyVerified, isTrue);
    expect(issues(restored.segments.single), isEmpty);
  });
}
