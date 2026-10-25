import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/models/dub_project.dart';
import 'package:ai_dubbing_studio/services/character_voice_caster.dart';
import 'package:ai_dubbing_studio/services/voice_catalog.dart';

DubSegment line(int id, String speaker) => DubSegment(
  id: id, start: id.toDouble(), end: id.toDouble() + 0.8,
  original: 'Original dialogue $id', speakerId: speaker,
  speakerConfidence: speaker == 'unknown' ? 0 : 0.9,
);

void main() {
  test('identified speakers are assigned before an unresolved line is reviewed', () {
    final project = DubProject(id: 'partial', title: 'test',
      sourcePath: 'source.mp4', targetLanguage: 'hi',
      segments: [line(1, 'speaker_1'), line(2, 'unknown'),
        line(3, 'speaker_2'), line(4, 'speaker_1')]);
    const CharacterVoiceCaster().assign(project);
    expect(project.characterVoices.keys.toSet(), {'speaker_1', 'speaker_2'});
    expect(project.segments[0].voiceId, isNotEmpty);
    expect(project.segments[3].voiceId, project.segments[0].voiceId);
    expect(project.segments[1].voiceId, isEmpty);
    expect(VoiceCatalog.supertonicStyle(project.segments[2].voiceId), isNotNull);
    final restored = DubProject.decode(project.encode());
    expect(restored.characterVoices, project.characterVoices);
  });

  test('resume preserves existing automatic speaker voice assignments', () {
    final project = DubProject(id: 'resume', title: 'test',
      sourcePath: 'source.mp4', targetLanguage: 'hi',
      segments: [line(1, 'speaker_1'), line(2, 'speaker_2')]);
    const CharacterVoiceCaster().assign(project);
    final first = Map<String, String>.of(project.characterVoices);
    const CharacterVoiceCaster().assign(project);
    expect(project.characterVoices, first);
  });

  test('provisional voices do not manufacture an identity for unknown audio', () {
    final project = DubProject(id: 'unknown', title: 'test',
      sourcePath: 'source.mp4', targetLanguage: 'en',
      segments: [line(1, 'unknown')]);
    const CharacterVoiceCaster().assign(project);
    expect(project.segments.single.speakerId, 'unknown');
    expect(project.characterVoices, isEmpty);
  });
}
