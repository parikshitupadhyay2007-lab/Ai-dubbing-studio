import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/department01_inference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/dept01_onnx');
  const inference = Department01Inference(channel: channel);
  final hash = 'a' * 64;
  tearDown(() => TestDefaultBinaryMessengerBinding.instance
    .defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  test('local install checks the native receipt and rejects bad paths', () async {
    expect(() => inference.installLocal(sourcePath: '',
      modelName: 'scene.onnx', sha256: hash), throwsFormatException);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'installLocalModel');
        return {'installed': true, 'model_name': 'scene.onnx',
          'sha256': hash, 'size_bytes': 1024};
      });
    final receipt = await inference.installLocal(sourcePath: '/local/scene.onnx',
      modelName: 'scene.onnx', sha256: hash);
    expect(receipt['installed'], true);
  });

  test('bundled model provisioning requires a verified native installation receipt', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'installBundledModel');
        expect((call.arguments as Map)['sha256'], hash);
        return {'installed': true, 'model_name': 'dinov2_small_cls.onnx',
          'sha256': hash, 'size_bytes': 82000000};
      });
    final receipt = await inference.installBundled(
      modelName: 'dinov2_small_cls.onnx', sha256: hash);
    expect(receipt['installed'], true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (_) async =>
        {'installed': true, 'model_name': 'dinov2_small_cls.onnx',
          'sha256': 'b' * 64, 'size_bytes': 82000000});
    await expectLater(inference.installBundled(
      modelName: 'dinov2_small_cls.onnx', sha256: hash), throwsFormatException);
  });

  test('rejects native installation with mismatched digest', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (_) async =>
        {'installed': true, 'model_name': 'scene.onnx',
          'sha256': 'b' * 64, 'size_bytes': 1024});
    await expectLater(inference.installLocal(sourcePath: '/local/scene.onnx',
      modelName: 'scene.onnx', sha256: hash), throwsFormatException);
  });

  test('rejects unpinned models before native invocation', () async {
    expect(() => inference.inspect(modelName: '../unsafe.onnx', sha256: hash),
      throwsFormatException);
    expect(() => inference.inspect(modelName: 'scene.onnx', sha256: 'unverified'),
      throwsFormatException);
  });

  test('rejects missing local model or checksum mismatch', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'LOCAL_INFERENCE_FAILED',
          message: 'Local model weights not installed');
      });
    await expectLater(inference.inspect(modelName: 'scene.onnx', sha256: hash),
      throwsA(isA<PlatformException>()));
  });

  test('inspects verified model metadata without claiming inference', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'inspectModel');
        return {'runtime': 'onnxruntime_android',
          'checksum_verified': true, 'inputs': ['image'], 'outputs': ['features']};
      });
    final result = await inference.inspect(modelName: 'scene.onnx', sha256: hash);
    expect(result['checksum_verified'], true);
  });

  test('bounded execution requires actual native acknowledgment', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'runFloatModel');
        expect((call.arguments as Map)['shape'], [1, 2]);
        return {'executed': true, 'checksum_verified': true,
          'semantic_result_verified': false, 'output_metadata': [
            {'name': 'features', 'type': 'float32', 'shape': [1, 2],
              'values': [0.25, 0.75]}
          ]};
      });
    final result = await inference.runFloat(modelName: 'scene.onnx', sha256: hash,
      inputName: 'image', shape: [1, 2], values: [0.0, 1.0]);
    expect(result['semantic_result_verified'], false);
    expect(((result['output_metadata'] as List).first as Map)['values'], [0.25, 0.75]);
    await expectLater(inference.runFloat(modelName: 'scene.onnx', sha256: hash,
      inputName: 'image', shape: [1, 2], values: [0.0]),
      throwsFormatException);
  });
}
