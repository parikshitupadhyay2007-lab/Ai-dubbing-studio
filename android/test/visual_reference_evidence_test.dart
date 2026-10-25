import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/services/verified_anime_catalog.dart';
import 'package:ai_dubbing_studio/services/visual_speaker_evidence.dart';

void main() {
  test('empty licensed catalog is valid but contains no invented matches', () {
    expect(const VerifiedAnimeCatalog().parse('[]'), isEmpty);
  });
  test('a reference with no licence or provenance cannot enter retrieval', () {
    expect(() => const VerifiedAnimeCatalog().parse(
      '[{"anime_id":"a","episode_id":"1","title":"Example",'
      '"start_seconds":0,"dialogue":["one","two","three"]}]'),
      throwsFormatException);
  });
  test('visual evidence must beat competing visible track', () {
    const strong = VisualSpeakerEvidence(segmentId: 1, trackId: 'track-1',
      startSeconds: 1, endSeconds: 2, lipSyncScore: .93,
      competingTrackScore: .60, modelId: 'validated-model',
      sourceHash: 'source-checksum');
    const ambiguous = VisualSpeakerEvidence(segmentId: 1, trackId: 'track-2',
      startSeconds: 1, endSeconds: 2, lipSyncScore: .88,
      competingTrackScore: .81, modelId: 'validated-model',
      sourceHash: 'source-checksum');
    expect(strong.unambiguousCandidate, isTrue);
    expect(ambiguous.unambiguousCandidate, isFalse);
  });
}
