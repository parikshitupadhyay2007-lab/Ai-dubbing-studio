import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/models/dub_project.dart';
import 'package:ai_dubbing_studio/services/active_speaker_evidence_gate.dart';
import 'package:ai_dubbing_studio/services/visual_speaker_evidence.dart';

void main() {
  final project = DubProject(id: 'visual', title: 'fixture',
    sourcePath: 'source.mp4', targetLanguage: 'hi',
    segments: [DubSegment(id: 1, start: 1, end: 2,
      original: 'line', speakerId: 'speaker_1', speakerConfidence: .9)]);
  VisualSpeakerEvidence sample(String track, {double start = 1, double end = 2}) =>
      VisualSpeakerEvidence(segmentId: 1, trackId: track,
        startSeconds: start, endSeconds: end, lipSyncScore: .95,
        competingTrackScore: .50, modelId: 'native-model',
        sourceHash: 'measured-source');

  test('aligned native candidate is admitted without naming a character', () {
    final result = const ActiveSpeakerEvidenceGate().evaluate(project, [sample('a')]);
    expect(result[1]?.trackId, 'a');
    expect(project.segments.single.speakerId, 'speaker_1');
  });
  test('two conflicting eligible visual tracks are withheld', () {
    final result = const ActiveSpeakerEvidenceGate().evaluate(
      project, [sample('a'), sample('b')]);
    expect(result, isEmpty);
  });
  test('non-covering time range is withheld', () {
    final result = const ActiveSpeakerEvidenceGate().evaluate(
      project, [sample('a', start: 1.4)]);
    expect(result, isEmpty);
  });
}
