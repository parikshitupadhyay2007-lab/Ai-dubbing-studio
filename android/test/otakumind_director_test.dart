import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/models/dub_project.dart';
import 'package:ai_dubbing_studio/services/otakumind_director.dart';
import 'package:ai_dubbing_studio/services/offline_engine.dart';
import 'package:ai_dubbing_studio/services/model_manager.dart';

void main() {
  final director = OtakuMindDirector(OfflineEngine(ModelManager()));
  DubProject project() => DubProject(
    id: 'director', title: 'director', sourcePath: 'scene.mp4',
    sourceLanguage: 'ja', targetLanguage: 'hi',
    characterVoices: {'speaker_1': 'hi_heroine'},
    segments: [DubSegment(
      id: 1, start: 0, end: 2.5, original: 'こんにちは',
      translation: 'नमस्ते।', speakerId: 'speaker_1', voiceId: 'hi_heroine',
      speakerConfidence: 0.8,
    )],
  );

  test('director accepts verified identity and dialogue', () {
    expect(() => director.verifyBeforeSynthesis(project()), returnsNormally);
  });
  test('director rejects unresolved speaker identity', () {
    final value = project();
    value.segments.single.speakerId = 'unknown';
    expect(() => director.verifyBeforeSynthesis(value), throwsA(isA<OfflineEngineException>()));
  });
  test('director rejects mismatched character voice', () {
    final value = project();
    value.segments.single.voiceId = 'hi_hero';
    expect(() => director.verifyBeforeSynthesis(value), throwsA(isA<OfflineEngineException>()));
  });
  test('director rejects duplicated dialogue ID', () {
    final value = project();
    value.segments.add(DubSegment(
      id: 1, start: 3, end: 4, original: 'さようなら',
      translation: 'अलविदा।', speakerId: 'speaker_1', voiceId: 'hi_heroine',
    ));
    expect(() => director.verifyBeforeSynthesis(value), throwsA(isA<OfflineEngineException>()));
  });
}
