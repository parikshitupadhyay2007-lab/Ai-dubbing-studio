import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/research_rgb_frame.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/rgb-frame');
  const sampler = ResearchRgbFrame(channel: channel);
  tearDown(() => TestDefaultBinaryMessengerBinding.instance
      .defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  test('real RGB byte contract and planar normalized channel ordering', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'sampleRgbFrame');
        return {'timestamp_ms': 100, 'width': 32, 'height': 32,
          'pixel_format': 'RGB_U8_INTERLEAVED',
          'rgb': Uint8List.fromList(List.generate(32 * 32 * 3,
            (i) => i % 3 == 0 ? 255 : 0))};
      });
    final frame = await sampler.sample(sourcePath: '/source.mp4',
      timestampMs: 100, size: 32);
    final tensor = sampler.toChwNormalized(frame, size: 32,
      mean: [0, 0, 0], std: [1, 1, 1]);
    expect(tensor.length, 3072);
    expect(tensor[0], 1);
    expect(tensor[1024], 0);
    expect(tensor[2048], 0);
  });

  test('rejects incomplete RGB payload', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (_) async => {
        'timestamp_ms': 0, 'width': 32, 'height': 32,
        'pixel_format': 'RGB_U8_INTERLEAVED', 'rgb': Uint8List(1)});
    await expectLater(sampler.sample(sourcePath: '/source.mp4',
      timestampMs: 0, size: 32), throwsFormatException);
  });

  test('rejects invalid normalization', () {
    expect(() => sampler.toChwNormalized(Uint8List(32 * 32 * 3),
      size: 32, mean: [0, 0, 0], std: [1, 0, 1]), throwsFormatException);
  });
}
