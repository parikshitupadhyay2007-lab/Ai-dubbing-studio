import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/production_office.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  const media = {'duration_ms': 2000, 'width': 1280, 'height': 720,
    'has_video': true, 'has_audio': true, 'streams': [
      {'index': 0, 'mime': 'video/avc'}, {'index': 1, 'mime': 'audio/aac'}
    ]};
  setUp(() async { root = await Directory.systemTemp.createTemp('otakudub-intake-'); });
  tearDown(() async { if (await root.exists()) await root.delete(recursive: true); });

  test('valid intake is persisted and independently reverified', () async {
    final source = File('${root.path}/sample.mp4')..writeAsStringSync('fixture bytes');
    final office = ProductionOffice(root: Directory('${root.path}/projects'), inspectOverride: (_) async => media);
    final record = await office.import(source.path, 'sample.mp4', 'hi');
    expect(record.approved, true);
    expect((await office.all()).single.id, record.id);
    expect(await office.canHandoff(record), true);
    await File(record.data['source_path'] as String).writeAsString('tampered');
    expect(await office.canHandoff(record), false);
  });
  test('missing audio is rejected and never handed off', () async {
    final source = File('${root.path}/sample.mp4')..writeAsStringSync('fixture bytes');
    final office = ProductionOffice(root: Directory('${root.path}/projects'),
      inspectOverride: (_) async => {...media, 'has_audio': false});
    final record = await office.import(source.path, 'sample.mp4', 'en');
    expect(record.approved, false);
    expect(await office.canHandoff(record), false);
  });
  test('empty source and unsupported language fail closed', () async {
    final source = File('${root.path}/empty.mp4')..createSync();
    final office = ProductionOffice(root: Directory('${root.path}/projects'), inspectOverride: (_) async => media);
    expect(() => office.import(source.path, 'empty.mp4', 'hi'), throwsFormatException);
    expect(() => office.import(source.path, 'empty.mp4', 'xx'), throwsFormatException);
  });
}
