import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/research_reference_index.dart';

void main() {
  const index = ResearchReferenceIndex();
  final sha = List.filled(64, 'a').join();
  late Directory dir;
  setUp(() async { dir = await Directory.systemTemp.createTemp('reference_test_'); });
  tearDown(() async { await dir.delete(recursive: true); });
  Future<File> write(Map<String, dynamic> document) async =>
      File('${dir.path}/index.json').writeAsString(jsonEncode(document));
  Map<String, dynamic> valid() => {
    'schema': 'otakudub_reference_v1', 'model_sha256': sha,
    'preprocessing_id': 'dinov2_256_center224_v1', 'dimension': 3,
    'entries': [
      {'id': 'original:test:1', 'source': 'locally authored reference',
        'rights_basis': 'original', 'source_sha256': List.filled(64, 'b').join(),
        'embedding': [1, 0, 0]}
    ],
  };
  test('loads model-pinned original reference and fingerprints it', () async {
    final values = await index.load(file: await write(valid()),
      expectedModelSha256: sha,
      expectedPreprocessingId: 'dinov2_256_center224_v1', dimension: 3);
    expect(values['original:test:1'], [1, 0, 0]);
    expect(index.fingerprint(values).length, 64);
  });
  test('rejects unlicensed entries', () async {
    final doc = valid();
    (doc['entries'] as List).first['rights_basis'] = 'unknown';
    await expectLater(index.load(file: await write(doc),
      expectedModelSha256: sha,
      expectedPreprocessingId: 'dinov2_256_center224_v1', dimension: 3),
      throwsFormatException);
  });
  test('rejects incompatible model hash', () async {
    await expectLater(index.load(file: await write(valid()),
      expectedModelSha256: List.filled(64, 'c').join(),
      expectedPreprocessingId: 'dinov2_256_center224_v1', dimension: 3),
      throwsFormatException);
  });
}
