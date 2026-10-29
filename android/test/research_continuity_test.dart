import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/production_office.dart';
import 'package:ai_dubbing_studio/research_continuity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async => root = await Directory.systemTemp.createTemp('otakudub-research-'));
  tearDown(() async { if (await root.exists()) await root.delete(recursive: true); });
  const metadata = <String, dynamic>{'duration_ms': 2000, 'width': 640,
    'height': 480, 'has_video': true, 'has_audio': true, 'streams': []};

  test('rejects unapproved intake and does not claim downstream approval', () async {
    final file = File('${root.path}/source.mp4')..writeAsStringSync('fixture');
    final office = ProductionOffice(root: Directory('${root.path}/projects'),
      inspectOverride: (_) async => {...metadata, 'has_audio': false});
    final intake = await office.import(file.path, 'source', 'hi');
    final research = ResearchContinuity(office);
    await expectLater(research.createResearchManifest(intake, []), throwsStateError);
    expect(await research.canHandoff(intake), false);
  });
  test('rejects ungrounded evidence and preserves explicit pending status', () async {
    final file = File('${root.path}/source.mp4')..writeAsStringSync('fixture');
    final office = ProductionOffice(root: Directory('${root.path}/projects'),
      inspectOverride: (_) async => metadata);
    final intake = await office.import(file.path, 'source', 'en');
    final research = ResearchContinuity(office);
    await expectLater(research.createResearchManifest(intake, [
      const SceneEvidence(startMs: 100, endMs: 2500, kind: 'visual',
        description: 'scene', source: 'frame', confidence: .8),
    ]), throwsFormatException);
    final manifest = await research.createResearchManifest(intake, []);
    expect(manifest['approved'], false);
    final receipt = Map<String, dynamic>.from(manifest['upstream_handoff'] as Map);
    expect(await office.verifyHandoff(intake, receipt), true);
    final altered = {...receipt, 'source_sha256': 'incorrect'};
    expect(await office.verifyHandoff(intake, altered), false);
    await File(intake.data['source_path'] as String).writeAsString('changed source');
    expect(await office.verifyHandoff(intake, receipt), false);
    expect(manifest['status'], 'awaiting_models_and_review');
    expect(await research.canHandoff(intake), false);
  });
}
