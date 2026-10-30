import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/research_character_fusion.dart';
import 'package:ai_dubbing_studio/research_speaker_attribution.dart';
import 'package:ai_dubbing_studio/research_episode_matching.dart';
import 'package:ai_dubbing_studio/research_dramatic_evidence.dart';

void main() {
  test('recurring observation retains local track and ambiguous identity abstains', () {
    final result = const ResearchCharacterFusion().track(observations: [
      {'timestamp_ms': 0, 'evidence_id': 'frame_0', 'detector_verified': true,
        'visual_embedding': [1.0, 0.0]},
      {'timestamp_ms': 1000, 'evidence_id': 'frame_1', 'detector_verified': true,
        'visual_embedding': [0.99, 0.01]},
      {'timestamp_ms': 2000, 'evidence_id': 'frame_2', 'detector_verified': true,
        'visual_embedding': [0.0, 1.0]},
      {'timestamp_ms': 3000, 'evidence_id': 'frame_3', 'detector_verified': true,
        'visual_embedding': [0.85, 0.53]},
    ]);
    final assignments = result['assignments'] as List;
    expect((assignments[0] as Map)['track_id'], 'local_track_0');
    expect((assignments[1] as Map)['track_id'], 'local_track_0');
    expect((assignments[3] as Map)['track_id'], isNull);
    expect((assignments[3] as Map)['status'], 'ambiguous_abstain');
    expect(result['identity_verified'], false);
  });
  test('unverified detections are rejected, not assigned a track', () {
    expect(() => const ResearchCharacterFusion().track(observations: [
      {'timestamp_ms': 0, 'evidence_id': 'frame_0',
        'detector_verified': false, 'visual_embedding': [1.0, 0.0]},
    ]), throwsFormatException);
  });
  test('audio and mouth synchrony only generate independently reviewed candidates', () {
    final result = const ResearchSpeakerAttribution().attribute(
      durationMs: 6000, dialogue: [
      {'start_ms': 0, 'end_ms': 2000, 'speaker_embedding_id': 'speaker_a',
        'candidates': [
          {'track_id': 'local_track_0', 'evidence_id': 'av_0',
            'mouth_sync_score': 0.95, 'audio_visual_score': 0.93},
          {'track_id': 'local_track_1', 'evidence_id': 'av_1',
            'mouth_sync_score': 0.3, 'audio_visual_score': 0.4},
        ]},
      {'start_ms': 2000, 'end_ms': 4000, 'speaker_embedding_id': 'speaker_b',
        'candidates': []},
    ]);
    final lines = result['dialogue_attribution'] as List;
    expect((lines.first as Map)['candidate_track_id'], 'local_track_0');
    expect((lines.last as Map)['candidate_track_id'], isNull);
    expect((lines.first as Map)['verified_speaker'], false);
  });
  test('episode matching requires consistent licensed references', () {
    final references = {'frame_a': [1.0, 0.0], 'frame_b': [0.0, 1.0]};
    final provenance = {
      'frame_a': {'episode_id': 'episode_1', 'anime_id': 'work_a',
        'rights_basis': 'licensed', 'source_sha256': 'a' * 64},
      'frame_b': {'episode_id': 'episode_2', 'anime_id': 'work_a',
        'rights_basis': 'original', 'source_sha256': 'b' * 64},
    };
    final result = const ResearchEpisodeMatching().compare(
      sampledEmbeddings: [[1.0, 0.0], [0.99, 0.01], [1.0, 0.0]],
      authorisedReferences: references, provenance: provenance);
    expect(result['candidate_episode_id'], 'episode_1');
    expect(result['verified_episode'], false);
    expect(() => const ResearchEpisodeMatching().compare(
      sampledEmbeddings: [[1.0, 0.0], [1.0, 0.0], [1.0, 0.0]],
      authorisedReferences: references, provenance: {
        ...provenance, 'frame_a': {...provenance['frame_a']!, 'rights_basis': 'unknown'},
      }), throwsFormatException);
  });
  test('dramatic evidence preserves timing but does not hallucinate direction', () {
    final output = const ResearchDramaticEvidence().assemble(durationMs: 6000,
      scenes: [
        {'scene_id': 'scene_0', 'start_ms': 0, 'end_ms': 3000},
        {'scene_id': 'scene_1', 'start_ms': 3000, 'end_ms': 6000},
      ], dialogue: [
        {'start_ms': 500, 'end_ms': 1800, 'evidence_id': 'speech_0',
          'speaker_track_id': 'local_track_0'},
      ]);
    final scenes = output['scenes'] as List;
    expect(((scenes.first as Map)['narrative_context'] as Map)['status'], 'pending_inference');
    expect(output['approved'], false);
    expect(() => const ResearchDramaticEvidence().assemble(durationMs: 6000,
      scenes: [
        {'scene_id': 'scene_0', 'start_ms': 0, 'end_ms': 3000},
        {'scene_id': 'scene_1', 'start_ms': 3000, 'end_ms': 6000},
      ], dialogue: [
        {'start_ms': 2500, 'end_ms': 3200, 'evidence_id': 'speech_cross'},
      ]), throwsFormatException);
  });
}
