import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/research_multimodal_coordinator.dart';

void main() {
  test('integrates candidate identities, attributed dialogue, licensed retrieval and dramatic chronology', () {
    final result = const ResearchMultimodalCoordinator().evaluate(
      durationMs: 6000, sourceSha256: 'a' * 64,
      characterObservations: [
        {'timestamp_ms': 0, 'evidence_id': 'f0', 'detector_verified': true,
          'visual_embedding': [1.0, 0.0]},
        {'timestamp_ms': 2000, 'evidence_id': 'f1', 'detector_verified': true,
          'visual_embedding': [0.99, 0.01]},
      ],
      dialogueObservations: [
        {'start_ms': 100, 'end_ms': 1600, 'speaker_embedding_id': 'voice_0',
          'candidates': [
            {'track_id': 'local_track_0', 'evidence_id': 'av0',
              'mouth_sync_score': 0.9, 'audio_visual_score': 0.95},
          ]},
      ],
      episodeSamples: [[1.0, 0.0], [0.99, 0.01], [1.0, 0.0]],
      authorisedReferences: {'ref0': [1.0, 0.0], 'ref1': [0.0, 1.0]},
      referenceProvenance: {
        'ref0': {'episode_id': 'ep0', 'anime_id': 'anime0',
          'rights_basis': 'licensed', 'source_sha256': 'b' * 64},
        'ref1': {'episode_id': 'ep1', 'anime_id': 'anime0',
          'rights_basis': 'original', 'source_sha256': 'c' * 64},
      },
      sceneObservations: [
        {'scene_id': 'scene0', 'start_ms': 0, 'end_ms': 6000},
      ],
      timedDialogueEvidence: [
        {'start_ms': 100, 'end_ms': 1600, 'evidence_id': 'dialogue0',
          'speaker_track_id': 'local_track_0'},
      ],
    );
    expect(result['source_sha256'], 'a' * 64);
    expect((result['independent_consistency_review'] as Map)['passed'], true);
    expect(result['professional_acceptance'], false);
    expect(result['handoff_to_department02'], false);
  });
  test('rejects disconnected speaker identity instead of approving an invalid handoff', () {
    expect(() => const ResearchMultimodalCoordinator().evaluate(
      durationMs: 6000, sourceSha256: 'a' * 64,
      characterObservations: [
        {'timestamp_ms': 0, 'evidence_id': 'f0', 'detector_verified': true,
          'visual_embedding': [1.0, 0.0]},
      ],
      dialogueObservations: [
        {'start_ms': 100, 'end_ms': 1600, 'speaker_embedding_id': 'voice0',
          'candidates': [
            {'track_id': 'not_tracked', 'evidence_id': 'av0',
              'mouth_sync_score': 0.99, 'audio_visual_score': 0.99},
          ]},
      ],
      episodeSamples: [[1.0, 0.0], [1.0, 0.0], [1.0, 0.0]],
      authorisedReferences: {'ref0': [1.0, 0.0]},
      referenceProvenance: {'ref0': {'episode_id': 'ep0', 'anime_id': 'anime0',
        'rights_basis': 'licensed', 'source_sha256': 'b' * 64}},
      sceneObservations: [{'scene_id': 'scene0', 'start_ms': 0, 'end_ms': 6000}],
      timedDialogueEvidence: [],
    ), throwsFormatException);
  });
}
