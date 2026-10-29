import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/continuity_evidence_verifier.dart';
import 'package:ai_dubbing_studio/research_continuity.dart';

void main() {
  const verifier = ContinuityEvidenceVerifier();
  const evidence = [
    SceneEvidence(startMs: 0, endMs: 1000, kind: 'visual',
      description: 'frame observation', source: 'decoded frame', confidence: .9),
    SceneEvidence(startMs: 1000, endMs: 2000, kind: 'visual',
      description: 'second frame observation', source: 'decoded frame', confidence: .8),
  ];
  test('accepts structurally supported track without certifying identity', () {
    final result = verifier.verify(durationMs: 2000, observations: evidence,
      identityClaims: [
        {'identity': 'candidate A', 'track_id': 'track1',
          'start_ms': 0, 'end_ms': 1000, 'evidence_indices': [0]},
        {'identity': 'candidate A', 'track_id': 'track1',
          'start_ms': 1000, 'end_ms': 2000, 'evidence_indices': [1]},
      ]);
    expect(result['passed'], true);
    expect(result['verified_identity'], false);
    expect(result['requires_model_review'], true);
  });
  test('rejects contradictory identity assigned to same recurring track', () {
    final result = verifier.verify(durationMs: 2000, observations: evidence,
      identityClaims: [
        {'identity': 'A', 'track_id': 'track1',
          'start_ms': 0, 'end_ms': 1000, 'evidence_indices': [0]},
        {'identity': 'B', 'track_id': 'track1',
          'start_ms': 1000, 'end_ms': 2000, 'evidence_indices': [1]},
      ]);
    expect(result['passed'], false);
    expect((result['errors'] as List).join(' '), contains('Contradictory identity'));
  });
  test('rejects unsupported identity and out-of-bounds timestamps', () {
    final result = verifier.verify(durationMs: 2000, observations: evidence,
      identityClaims: [
        {'identity': 'A', 'track_id': 'track1',
          'start_ms': 1900, 'end_ms': 2100, 'evidence_indices': [1]},
        {'identity': 'B', 'track_id': 'track2',
          'start_ms': 0, 'end_ms': 1000, 'evidence_indices': []},
      ]);
    expect(result['passed'], false);
  });
}
