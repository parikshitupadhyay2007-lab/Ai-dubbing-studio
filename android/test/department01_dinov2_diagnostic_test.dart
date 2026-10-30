import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/production_office.dart';
import 'package:ai_dubbing_studio/otakumind_research_director.dart';
import 'package:ai_dubbing_studio/research_continuity.dart';
import 'package:ai_dubbing_studio/research_visual_embedding_engine.dart';

class DiagnosticOffice extends ProductionOffice {
  DiagnosticOffice(Directory dir) : super(root: dir);
  bool current = true;
  @override
  Future<Map<String, dynamic>> issueHandoff(IntakeRecord record) async => {
    'schema': 1, 'project_id': record.id, 'source_sha256': record.data['sha256'],
  };
  @override
  Future<bool> verifyHandoff(IntakeRecord record, Map<String, dynamic> receipt) async =>
    current && receipt['project_id'] == record.id &&
    receipt['source_sha256'] == record.data['sha256'];
}

class DiagnosticEngine extends ResearchVisualEmbeddingEngine {
  const DiagnosticEngine();
  @override
  Future<Map<String, dynamic>> evaluateDinov2Frame({
    required String sourcePath, required int timestampMs,
    required String modelSha256,
    Map<String, List<double>> authorisedReferences = const {},
  }) async => {
    'actual_onnx_execution': true, 'model_sha256': modelSha256,
    'embedding_dimension': 384, 'verified_anime': false,
    'verified_character': false, 'input_sha256': 'a' * 64,
    'output_sha256': 'b' * 64,
  };
}

void main() {
  test('diagnostic writes source-bound, unapproved evidence and reviewer checks it', () async {
    final dir = await Directory.systemTemp.createTemp('dept01_diagnostic_');
    try {
      final project = await Directory('${dir.path}/test-id').create();
      final office = DiagnosticOffice(dir);
      final intake = IntakeRecord({
        'id': 'test-id', 'sha256': 'c' * 64,
        'source_path': '${project.path}/source.media',
        'media': {'duration_ms': 15697},
      });
      final director = OtakuMindResearchDirector(office, onlineEnabled: false);
      final result = await director.diagnoseDinov2(intake: intake,
        modelSha256: 'd' * 64, engine: const DiagnosticEngine());
      expect(result['sample_count'], 3);
      expect(result['approved'], false);
      final reviewer = ResearchContinuity(office);
      expect((await reviewer.reviewDinov2Diagnostic(intake,
        expectedModelSha256: 'd' * 64))['passed'], true);
      expect((await reviewer.reviewDinov2Diagnostic(intake,
        expectedModelSha256: 'e' * 64))['passed'], false);
      office.current = false;
      expect((await reviewer.reviewDinov2Diagnostic(intake,
        expectedModelSha256: 'd' * 64))['passed'], false);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
