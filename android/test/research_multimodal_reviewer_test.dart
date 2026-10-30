import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/research_multimodal_reviewer.dart';

void main() {
  const reviewer = ResearchMultimodalReviewer();
  Map<String, dynamic> tracks() => {
    'identity_verified': false,
    'tracks': [{'track_id': 'local_track_0', 'sample_count': 2,
      'verified_character': false}],
    'assignments': [{'track_id': 'local_track_0',
      'status': 'provisional_track_match', 'verified_character': false}],
  };
  Map<String, dynamic> lines(String? track) => {
    'verified': false,
    'dialogue_attribution': [
      {'start_ms': 100, 'end_ms': 300, 'candidate_track_id': track,
        'verified_speaker': false},
    ],
  };
  Map<String, dynamic> scenes() => {
    'approved': false, 'narrative_inference_verified': false,
    'scenes': [
      {'start_ms': 0, 'end_ms': 400},
      {'start_ms': 400, 'end_ms': 1000},
    ],
  };
  test('reviews grounded cross-modal contracts without certifying quality', () {
    final result = reviewer.review(durationMs: 1000,
      characterTracks: tracks(), speakerAttribution: lines('local_track_0'),
      episodeMatching: {'verified_episode': false},
      dramaticEvidence: scenes());
    expect(result['passed'], true);
    expect(result['professional_acceptance'], false);
  });
  test('refuses speaker-to-unknown-track and fake certification', () {
    final bad = reviewer.review(durationMs: 1000,
      characterTracks: tracks(), speakerAttribution: lines('nonexistent'),
      episodeMatching: {'verified_episode': false},
      dramaticEvidence: scenes());
    expect(bad['passed'], false);
    final forged = reviewer.review(durationMs: 1000,
      characterTracks: {...tracks(), 'identity_verified': true},
      speakerAttribution: lines('local_track_0'),
      episodeMatching: {'verified_episode': true},
      dramaticEvidence: scenes());
    expect(forged['passed'], false);
  });
  test('refuses incomplete scene chronology', () {
    final result = reviewer.review(durationMs: 1000,
      characterTracks: tracks(), speakerAttribution: lines(null),
      episodeMatching: {'verified_episode': false},
      dramaticEvidence: {...scenes(), 'scenes': [
        {'start_ms': 0, 'end_ms': 400},
        {'start_ms': 500, 'end_ms': 1000},
      ]});
    expect(result['passed'], false);
  });
}
