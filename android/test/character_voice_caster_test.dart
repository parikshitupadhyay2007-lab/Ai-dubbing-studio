import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/models/dub_project.dart';
import 'package:ai_dubbing_studio/services/character_voice_caster.dart';
import 'package:ai_dubbing_studio/services/voice_catalog.dart';

void main() {
  late Directory directory;
  setUp(() async {
    VoiceCatalog.clearInstalled();
    directory = await Directory.systemTemp.createTemp('otakudub_cast_');
    for (final id in ['hi_hero', 'hi_heroine']) {
      final model = File('${directory.path}/$id.onnx');
      final config = File('${directory.path}/$id.onnx.json');
      await model.writeAsBytes([1, 2, 3]);
      await config.writeAsString(jsonEncode({
        'language': {'code': 'hi_IN'}, 'audio': {'sample_rate': 22050},
        'inference': {'noise_scale': 0.667, 'length_scale': 1, 'noise_w': 0.8},
        'phoneme_id_map': {'a': [1]}, 'num_speakers': 1,
      }));
      await VoiceCatalog.registerInstalled(
        profileId: id, modelId: id, modelPath: model.path,
        configPath: config.path,
      );
    }
  });
  tearDown(() async {
    VoiceCatalog.clearInstalled();
    await directory.delete(recursive: true);
  });

  DubSegment line(int id, String speaker) => DubSegment(
    id: id, start: id.toDouble(), end: id + 0.7,
    original: 'Original line', speakerId: speaker, speakerConfidence: 0.7,
  );

  test('automatic casting is stable for recurring speakers', () {
    final project = DubProject(
      id: 'test', title: 'test', sourcePath: 'source.mp4',
      targetLanguage: 'hi',
      segments: [line(1, 'speaker_1'), line(2, 'speaker_2'),
        line(3, 'speaker_1')],
    );
    const CharacterVoiceCaster().assign(project);
    expect(project.characterVoices.length, 2);
    expect(project.characterVoices.values.toSet().length, 2);
    expect(project.segments[0].voiceId, project.segments[2].voiceId);
    final before = Map<String, String>.from(project.characterVoices);
    const CharacterVoiceCaster().assign(project);
    expect(project.characterVoices, before);
  });

  test('saved casting is preserved rather than overwritten', () {
    final project = DubProject(
      id: 'test', title: 'test', sourcePath: 'source.mp4',
      targetLanguage: 'hi', segments: [line(1, 'speaker_1')],
      characterVoices: {'speaker_1': 'hi_heroine'},
    );
    const CharacterVoiceCaster().assign(project);
    expect(project.segments.single.voiceId, 'hi_heroine');
  });
}
