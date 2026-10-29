import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/department01_inference.dart';
import 'package:ai_dubbing_studio/research_visual_embedding_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/visual_embedding');
  const engine = ResearchVisualEmbeddingEngine(
    inference: Department01Inference(channel: channel));
  final hash = 'a' * 64;
  tearDown(() => TestDefaultBinaryMessengerBinding.instance
    .defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  test('model output reaches local ranker without asserting identity', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'inspectModel') return {
          'runtime': 'onnxruntime_android', 'checksum_verified': true,
          'inputs': ['image'], 'outputs': ['embedding']};
        if (call.method == 'runFloatModel') return {
          'executed': true, 'checksum_verified': true,
          'semantic_result_verified': false,
          'output_metadata': [{'name': 'embedding', 'type': 'float32',
            'shape': [1, 3], 'values': [1.0, 0.0, 0.0]}]};
        throw StateError('Unexpected native call');
      });
    final result = await engine.evaluate(modelName: 'encoder.onnx',
      modelSha256: hash, inputName: 'image', outputName: 'embedding',
      preprocessingId: 'model-specific-v1', inputShape: [1, 2],
      preprocessedPixels: [0, 1], authorisedReferences: {
        'known': [1, 0, 0], 'other': [0, 1, 0]});
    expect(result['actual_onnx_execution'], true);
    expect(result['verified_anime'], false);
    expect(result['verified_character'], false);
    expect((result['ranking'] as Map)['status'],
      'candidate_requires_independent_review');
    expect((result['input_sha256'] as String).length, 64);
  });

  test('rejects logits or spatial tensor presented as an embedding', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'inspectModel') return {
          'runtime': 'onnxruntime_android', 'checksum_verified': true,
          'inputs': ['image'], 'outputs': ['embedding']};
        return {'executed': true, 'checksum_verified': true,
          'semantic_result_verified': false,
          'output_metadata': [{'name': 'embedding', 'type': 'float32',
            'shape': [1, 1, 2], 'values': [1.0, 0.0]}]};
      });
    await expectLater(engine.evaluate(modelName: 'encoder.onnx',
      modelSha256: hash, inputName: 'image', outputName: 'embedding',
      preprocessingId: 'v1', inputShape: [1, 2],
      preprocessedPixels: [0, 1], authorisedReferences: {
        'known': [1, 0]}), throwsFormatException);
  });
}
