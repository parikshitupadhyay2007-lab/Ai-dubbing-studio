import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/frame_signal_sampler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/frame_sampler');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        final timestamps = (call.arguments as Map)['timestamps_ms'] as List;
        return {'duration_ms': 1000, 'samples': timestamps.map((t) =>
          {'timestamp_ms': t, 'available': true, 'luma8x8': List.filled(64, t == 0 ? 0 : 255)}).toList()};
      });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('uses native observations and identifies uncertified shot candidates', () async {
    final samples = await const FrameSignalSampler(channel: channel)
        .sample('/private/source.media', [0, 500]);
    expect(calls.single.method, 'sampleFrames');
    final candidates = const ShotBoundaryCandidates().detect(samples);
    expect(candidates, hasLength(1));
    expect(candidates.single['difference'], 1);
    expect(candidates.single['verified_scene_boundary'], false);
  });

  test('invalid frame requests are blocked before native invocation', () async {
    final sampler = const FrameSignalSampler(channel: channel);
    await expectLater(sampler.sample('', [0]), throwsFormatException);
    await expectLater(sampler.sample('file', [-1]), throwsFormatException);
    await expectLater(sampler.sample('file', List.filled(241, 0)), throwsFormatException);
    expect(calls, isEmpty);
  });

  test('non-chronological observations are rejected', () {
    final frames = [FrameSignal(100, List.filled(64, 0)),
      FrameSignal(100, List.filled(64, 255))];
    expect(() => const ShotBoundaryCandidates().detect(frames), throwsFormatException);
  });
}
