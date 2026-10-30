import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/frame_signal_sampler.dart';
import 'package:ai_dubbing_studio/production_office.dart';
import 'package:ai_dubbing_studio/otakumind_research_director.dart';
import 'package:ai_dubbing_studio/research_visual_embedding_engine.dart';

class SceneOffice extends ProductionOffice {
  SceneOffice(Directory root) : super(root: root);
  bool valid = true;
  @override
  Future<Map<String, dynamic>> issueHandoff(IntakeRecord record) async =>
    {'project_id': record.id, 'source_sha256': record.data['sha256']};
  @override
  Future<bool> verifyHandoff(IntakeRecord record, Map<String, dynamic> receipt) async =>
    valid && receipt['project_id'] == record.id &&
    receipt['source_sha256'] == record.data['sha256'];
}

class SceneSampler extends FrameSignalSampler {
  const SceneSampler();
  @override
  Future<List<FrameSignal>> sample(String path, List<int> timestampsMs) async =>
    timestampsMs.map((t) => FrameSignal(t,
      List<int>.filled(64, t == 0 ? 0 : 255))).toList();
}

class SceneEncoder extends ResearchVisualEmbeddingEngine {
  const SceneEncoder();
  @override
  Future<Map<String, dynamic>> evaluateDinov2Frame({
    required String sourcePath, required int timestampMs,
    required String modelSha256,
    Map<String, List<double>> authorisedReferences = const {},
  }) async {
    final vector = List<double>.filled(384, 0);
    vector[timestampMs == 0 ? 0 : 1] = 1;
    return {'actual_onnx_execution': true, 'model_sha256': modelSha256,
      'embedding_dimension': 384, 'embedding': vector,
      'verified_anime': false, 'verified_character': false};
  }
}

void main() {
  test('director combines sampled native cuts with real-inference adapter output', () async {
    final root = await Directory.systemTemp.createTemp('scene_proposal_');
    try {
      final office = SceneOffice(root);
      final director = OtakuMindResearchDirector(office, onlineEnabled: false);
      final intake = IntakeRecord({'id': 'scene-test', 'sha256': 'a' * 64,
        'source_path': '${root.path}/source.media',
        'media': {'duration_ms': 6000}});
      final result = await director.proposeVisualScenes(intake: intake,
        modelSha256: 'b' * 64, sampleIntervalMs: 2000,
        sampler: const SceneSampler(), engine: const SceneEncoder());
      expect((result['scenes'] as List).length, 2);
      expect(result['semantic_scene_segmentation_verified'], false);
      expect(result['approved'], false);
      office.valid = false;
      await expectLater(director.proposeVisualScenes(intake: intake,
        modelSha256: 'b' * 64, sampleIntervalMs: 2000,
        sampler: const SceneSampler(), engine: const SceneEncoder()), throwsStateError);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
