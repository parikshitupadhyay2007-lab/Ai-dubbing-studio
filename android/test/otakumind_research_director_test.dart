import 'dart:io';
import 'package:flutter/services.dart';
import 'package:ai_dubbing_studio/frame_signal_sampler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/otakumind_online_research.dart';
import 'package:ai_dubbing_studio/otakumind_research_director.dart';
import 'package:ai_dubbing_studio/production_office.dart';
import 'package:ai_dubbing_studio/research_continuity.dart';

class FakeReference extends OtakuMindOnlineResearch {
  FakeReference() : super(enabled: true);
  String? received;
  @override
  Future<Map<String, dynamic>> searchAnime(String title) async {
    received = title;
    return {'provider': 'test', 'metadata': {'title': title},
      'verification': 'unverified_reference_only'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async => root = await Directory.systemTemp.createTemp('research-director-'));
  tearDown(() async { if (await root.exists()) await root.delete(recursive: true); });

  test('only explicit title reaches metadata provider; no premature approval', () async {
    final source = File('${root.path}/fixture.mp4')..writeAsStringSync('sample bytes');
    final office = ProductionOffice(root: Directory('${root.path}/projects'),
      inspectOverride: (_) async => {'duration_ms': 3000, 'width': 640,
        'height': 480, 'has_video': true, 'has_audio': true, 'streams': []});
    final intake = await office.import(source.path, 'Private video title', 'hi');
    final fake = FakeReference();
    final director = OtakuMindResearchDirector(office, onlineEnabled: true, online: fake);
    final output = await director.run(intake: intake, observedEvidence: [
      const SceneEvidence(startMs: 0, endMs: 3000, kind: 'observation',
        description: 'Verified fixture interval', source: 'test fixture', confidence: 1),
    ], userProvidedAnimeTitle: 'Explicit query');
    expect(fake.received, 'Explicit query');
    expect(output['internet_research_status'], 'unverified_external_reference');
    expect(output['approved'], false);
    expect(await ResearchContinuity(office).canHandoff(intake), false);
    expect(output['identity_claims'], isEmpty);
  });

  test('enabled internet without explicit title never initiates search', () async {
    final source = File('${root.path}/fixture.mp4')..writeAsStringSync('sample bytes');
    final office = ProductionOffice(root: Directory('${root.path}/projects'),
      inspectOverride: (_) async => {'duration_ms': 3000, 'width': 640,
        'height': 480, 'has_video': true, 'has_audio': true, 'streams': []});
    final intake = await office.import(source.path, 'Private video title', 'hi');
    final fake = FakeReference();
    final output = await OtakuMindResearchDirector(office,
      onlineEnabled: true, online: fake).run(intake: intake, observedEvidence: []);
    expect(fake.received, isNull);
    expect(output['internet_research_status'], 'offline_no_reference');
  });
  test('native frame observations reach research without claiming verified scenes', () async {
    const channel = MethodChannel('test/research_frames');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final times = (call.arguments as Map)['timestamps_ms'] as List;
      return {'duration_ms': 3000, 'samples': times.map((time) =>
        {'timestamp_ms': time, 'available': true,
          'luma8x8': List.filled(64, time == 0 ? 0 : 255)}).toList()};
    });
    try {
      final source = File('${root.path}/fixture.mp4')..writeAsStringSync('sample bytes');
      final office = ProductionOffice(root: Directory('${root.path}/projects'),
        inspectOverride: (_) async => {'duration_ms': 3000, 'width': 640,
          'height': 480, 'has_video': true, 'has_audio': true, 'streams': []});
      final intake = await office.import(source.path, 'Private title', 'en');
      final output = await OtakuMindResearchDirector(office, onlineEnabled: false)
          .runFromVideo(intake: intake,
            sampler: const FrameSignalSampler(channel: channel));
      expect((output['visual_sampling'] as Map)['sample_count'], 3);
      expect((output['visual_sampling'] as Map)['candidate_count'], 1);
      expect((output['visual_sampling'] as Map)['verified_scene_segmentation'], false);
      expect(await ResearchContinuity(office).canHandoff(intake), false);
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  test('long video uses multiple bounded frame batches without losing coverage', () async {
    const channel = MethodChannel('test/research_long_video');
    final batchSizes = <int>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final times = (call.arguments as Map)['timestamps_ms'] as List;
      batchSizes.add(times.length);
      return {'duration_ms': 241000, 'samples': times.map((time) =>
        {'timestamp_ms': time, 'available': true,
          'luma8x8': List.filled(64, time == 240000 ? 255 : 0)}).toList()};
    });
    try {
      final source = File('${root.path}/long-fixture.mp4')..writeAsStringSync('source bytes');
      final office = ProductionOffice(root: Directory('${root.path}/long-projects'),
        inspectOverride: (_) async => {'duration_ms': 241000, 'width': 640,
          'height': 480, 'has_video': true, 'has_audio': true, 'streams': []});
      final intake = await office.import(source.path, 'Long test', 'en');
      final output = await OtakuMindResearchDirector(office, onlineEnabled: false)
          .runFromVideo(intake: intake, sampler: const FrameSignalSampler(channel: channel));
      expect(batchSizes, [240, 1]);
      expect((output['visual_sampling'] as Map)['sample_count'], 241);
      expect((output['visual_sampling'] as Map)['sampling_complete'], true);
      expect((output['visual_sampling'] as Map)['candidate_count'], 1);
      expect(output['approved'], false);
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

}
