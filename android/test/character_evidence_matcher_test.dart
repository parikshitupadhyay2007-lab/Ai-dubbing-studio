import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/models/dub_project.dart';
import 'package:ai_dubbing_studio/services/visual_speaker_evidence.dart';
import 'package:ai_dubbing_studio/services/character_evidence_matcher.dart';

void main() {
  final project = DubProject(id: 'reference', title: 'reference',
    sourcePath: 'video.mp4', targetLanguage: 'hi',
    segments: [DubSegment(id: 1, start: 1, end: 2, original: 'line',
      speakerId: 'speaker_1', speakerConfidence: .9)]);
  const visual = VisualSpeakerEvidence(segmentId: 1, trackId: 'track-a',
    startSeconds: 1, endSeconds: 2, lipSyncScore: .94,
    competingTrackScore: .50, modelId: 'tested-native-model',
    sourceHash: 'source-asset-hash');
  test('matching actual measured track yields provisional character candidate', () {
    final matches = const CharacterEvidenceMatcher().propose(project,
      {1: visual}, [{'segment_id': 1, 'track_id': 'track-a',
        'character_id': 'character-a', 'reference_id': 'licensed-record-a'}]);
    expect(matches.single.characterId, 'character-a');
    expect(project.segments.single.speakerId, 'speaker_1');
  });
  test('scene-only name or mismatched visual track cannot identify a speaker', () {
    final matches = const CharacterEvidenceMatcher().propose(project,
      {1: visual}, [{'segment_id': 1, 'track_id': 'track-b',
        'character_id': 'character-a', 'reference_id': 'licensed-record-a'}]);
    expect(matches, isEmpty);
  });
  test('conflicting character labels are withheld', () {
    final matches = const CharacterEvidenceMatcher().propose(project,
      {1: visual}, [
        {'segment_id': 1, 'track_id': 'track-a',
          'character_id': 'character-a', 'reference_id': 'licensed-record-a'},
        {'segment_id': 1, 'track_id': 'track-a',
          'character_id': 'character-b', 'reference_id': 'licensed-record-a'},
      ]);
    expect(matches, isEmpty);
  });
}
