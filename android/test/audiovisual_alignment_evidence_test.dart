import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/services/audiovisual_alignment_evidence.dart';

void main() {
  const source = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const clip = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const model = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  Map<String, dynamic> row() => {
    'segment_id': 1, 'source_sha256': source, 'clip_sha256': clip,
    'model_id': 'validated-onnx', 'model_sha256': model,
    'mouth_start_seconds': 1.0, 'mouth_end_seconds': 2.0,
    'sync_score': 0.95, 'model_verified': true,
  };
  test('only properly bound measured evidence is eligible', () {
    expect(AudiovisualAlignmentEvidence.fromJson(row()).validFor(
      id: 1, sourceSha256: source, clipSha256: clip), isTrue);
  });
  test('refuses fabricated or stale media and model evidence', () {
    for (final invalid in [
      {...row(), 'model_verified': false},
      {...row(), 'model_sha256': 'unknown'},
      {...row(), 'source_sha256': clip},
      {...row(), 'clip_sha256': source},
      {...row(), 'mouth_end_seconds': 0.5},
      {...row(), 'sync_score': double.nan},
    ]) {
      expect(AudiovisualAlignmentEvidence.fromJson(invalid).validFor(
          id: 1, sourceSha256: source, clipSha256: clip), isFalse);
    }
  });
}
