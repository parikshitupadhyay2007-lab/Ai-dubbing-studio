import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/department01_inference.dart';
import 'package:ai_dubbing_studio/research_specialist_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/specialist_models');
  const registry = ResearchSpecialistModels(
    inference: Department01Inference(channel: channel));
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('specialist_models_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => {
        'runtime': 'onnxruntime_android', 'checksum_verified': true,
        'inputs': ['image'], 'outputs': ['detections'],
      });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });
  Map<String, dynamic> valid() => {
    'schema': 'otakudub_specialist_model_v1',
    'role': 'character_detector', 'model_name': 'detector.onnx',
    'sha256': 'a' * 64, 'upstream_revision': 'pinned-revision',
    'rights_basis': 'apache-2.0', 'rights_receipt': 'licence-record',
    'preprocessing_id': 'detector_rgb_v1',
    'inputs': ['image'], 'outputs': ['detections'],
  };
  test('inspects pinned real-native tensors without marking accuracy verified', () async {
    final file = File('${root.path}/model.json');
    await file.writeAsString(jsonEncode(valid()));
    final result = await registry.inspectManifest(file);
    expect(result['installed'], true);
    expect(result['real_inference_verified'], false);
    expect(result['professional_accuracy_verified'], false);
  });
  test('rejects missing licensing or incompatible tensor signatures', () async {
    final file = File('${root.path}/model.json');
    await file.writeAsString(jsonEncode({...valid(), 'rights_receipt': ''}));
    await expectLater(registry.inspectManifest(file), throwsFormatException);
    await file.writeAsString(jsonEncode({...valid(), 'outputs': ['wrong']}));
    await expectLater(registry.inspectManifest(file), throwsFormatException);
  });
}
