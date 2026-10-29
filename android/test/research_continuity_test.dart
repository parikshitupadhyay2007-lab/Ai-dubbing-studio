import 'dart:io';
import 'dart:convert';
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
  test('forged completion flags cannot bypass missing AI engines', () async {
    final file = File('${root.path}/source.mp4')..writeAsStringSync('fixture');
    final office = ProductionOffice(root: Directory('${root.path}/projects'),
      inspectOverride: (_) async => metadata);
    final intake = await office.import(file.path, 'source', 'en');
    final research = ResearchContinuity(office);
    final manifest = await research.createResearchManifest(intake, [
      const SceneEvidence(startMs: 0, endMs: 2000, kind: 'visual',
        description: 'fixture observation', source: 'fixture', confidence: 1),
    ]);
    final forged = <String, dynamic>{
      ...manifest,
      'approved': true,
      'scene_segmentation_verified': true,
      'visual_analysis_verified': true,
      'continuity_review': 'passed',
    };
    final saved = File('${(await office.root).path}/${intake.id}/research_manifest.json');
    await saved.writeAsString(jsonEncode(forged));
    final review = await research.review(intake);
    expect(review['passed'], false);
    expect((review['errors'] as List).join(' '), contains('Six-engine model coverage missing'));
  });

}
