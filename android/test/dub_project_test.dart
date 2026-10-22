import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/models/dub_project.dart';

void main() {
  test('project round-trip retains character identity and timing', () {
    final project = DubProject(
      id: 'test-1',
      title: 'Offline sample',
      sourcePath: '/media/source.mp4',
      targetLanguage: 'hi',
      sourceLanguage: 'ja',
      stage: ProjectStage.translating,
      segments: [
        DubSegment(
          id: 7,
          start: 1.25,
          end: 3.5,
          original: 'Original dialogue',
          translation: 'Translated dialogue',
          speakerId: 'speaker_1',
          voiceId: 'hi_hero',
          speakerConfidence: 0.8,
        ),
      ],
      characterVoices: {'speaker_1': 'hi_hero'},
    );

    final restored = DubProject.decode(project.encode());
    expect(restored.stage, ProjectStage.translating);
    expect(restored.targetLanguage, 'hi');
    expect(restored.sourceLanguage, 'ja');
    expect(restored.segments.single.id, 7);
    expect(restored.segments.single.start, 1.25);
    expect(restored.segments.single.end, 3.5);
    expect(restored.segments.single.speakerId, 'speaker_1');
    expect(restored.segments.single.voiceId, 'hi_hero');
    expect(restored.segments.single.translation, 'Translated dialogue');
    expect(restored.characterVoices['speaker_1'], 'hi_hero');
  });

  test('unknown stage is safely interpreted as imported', () {
    final project = DubProject(
      id: 'test-2',
      title: 'Sample',
      sourcePath: '/source.mp4',
      targetLanguage: 'en',
    ).toJson();
    project['stage'] = 'future_stage';
    expect(DubProject.fromJson(project).stage, ProjectStage.imported);
  });
}
