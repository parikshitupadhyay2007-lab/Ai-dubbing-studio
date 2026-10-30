import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/production_office.dart';
import 'package:ai_dubbing_studio/research_production_archive.dart';

class ArchiveOffice extends ProductionOffice {
  ArchiveOffice(Directory root) : super(root: root);
  bool current = true;
  @override
  Future<Map<String, dynamic>> issueHandoff(IntakeRecord record) async => {
    'project_id': record.id, 'source_sha256': record.data['sha256'],
  };
  @override
  Future<bool> verifyHandoff(IntakeRecord record, Map<String, dynamic> receipt) async =>
      current && receipt['project_id'] == record.id &&
      receipt['source_sha256'] == record.data['sha256'];
}

void main() {
  test('persisted multimodal Scene Bible is source bound and rejects tampering and stale input', () async {
    final root = await Directory.systemTemp.createTemp('research_archive_');
    try {
      final project = await Directory('${root.path}/archive-test').create();
      final office = ArchiveOffice(root);
      final intake = IntakeRecord({'id': 'archive-test', 'sha256': 'a' * 64,
        'media': {'duration_ms': 6000}});
      final archive = ResearchProductionArchive(office);
      final written = await archive.produce(intake: intake,
        characterObservations: [
          {'timestamp_ms': 0, 'evidence_id': 'f0', 'detector_verified': true,
            'visual_embedding': [1.0, 0.0]},
        ],
        dialogueObservations: [
          {'start_ms': 100, 'end_ms': 1600, 'speaker_embedding_id': 'voice0',
            'candidates': [
              {'track_id': 'local_track_0', 'evidence_id': 'av0',
                'mouth_sync_score': 0.95, 'audio_visual_score': 0.95},
            ]},
        ],
        episodeSamples: [[1.0, 0.0], [1.0, 0.0], [1.0, 0.0]],
        authorisedReferences: {'ref0': [1.0, 0.0]},
        referenceProvenance: {'ref0': {
          'episode_id': 'ep0', 'anime_id': 'anime0',
          'rights_basis': 'licensed', 'source_sha256': 'b' * 64}},
        sceneObservations: [{'scene_id': 'scene0',
          'start_ms': 0, 'end_ms': 6000}],
        timedDialogueEvidence: [
          {'start_ms': 100, 'end_ms': 1600,
            'evidence_id': 'speech0', 'speaker_track_id': 'local_track_0'},
        ]);
      expect(written['approved'], isNull);
      expect(written['department02_unlocked'], false);
      expect((await archive.review(intake))['passed'], true);
      final file = File('${project.path}/research_archive.json');
      final altered = Map<String, dynamic>.from(
        jsonDecode(await file.readAsString()) as Map);
      altered['department02_unlocked'] = true;
      await file.writeAsString(jsonEncode(altered));
      expect((await archive.review(intake))['passed'], false);
      office.current = false;
      expect((await archive.review(intake))['passed'], false);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
