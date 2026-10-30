import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/production_office.dart';
import 'package:ai_dubbing_studio/research_continuity_memory.dart';

class MemoryOffice extends ProductionOffice {
  MemoryOffice(Directory root) : super(root: root);
  bool current = true;
  @override
  Future<Map<String, dynamic>> issueHandoff(IntakeRecord record) async =>
      {'source_sha256': record.data['sha256']};
  @override
  Future<bool> verifyHandoff(IntakeRecord record, Map<String, dynamic> receipt) async =>
      current && receipt['source_sha256'] == record.data['sha256'];
}

void main() {
  test('continuity persists decisions, retains contradictions and rejects tampering', () async {
    final root = await Directory.systemTemp.createTemp('continuity_memory_');
    try {
      final project = await Directory('${root.path}/p1').create();
      final office = MemoryOffice(root);
      final intake = IntakeRecord({'id': 'p1', 'sha256': 'a' * 64});
      final memory = ResearchContinuityMemory(office);
      final first = await memory.append(intake: intake,
        entityId: 'track_1', attribute: 'role', value: 'speaker_a',
        evidenceIds: ['frame_1']);
      expect((first['decisions'] as List).length, 1);
      final second = await memory.append(intake: intake,
        entityId: 'track_1', attribute: 'role', value: 'speaker_b',
        evidenceIds: ['frame_2']);
      expect((second['decisions'] as List).length, 1);
      expect((second['unresolved_conflicts'] as List).length, 1);
      expect(second['approved'], false);
      final file = File('${project.path}/continuity_memory.json');
      final corrupted = Map<String, dynamic>.from(
        jsonDecode(await file.readAsString()) as Map);
      corrupted['approved'] = true;
      await file.writeAsString(jsonEncode(corrupted));
      await expectLater(memory.append(intake: intake,
        entityId: 'track_1', attribute: 'role', value: 'speaker_a',
        evidenceIds: ['frame_3']), throwsFormatException);
      office.current = false;
      await expectLater(memory.append(intake: intake,
        entityId: 'track_2', attribute: 'role', value: 'speaker_c',
        evidenceIds: ['frame_4']), throwsStateError);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
