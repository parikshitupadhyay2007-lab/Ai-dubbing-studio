import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/models/dub_project.dart';
import 'package:ai_dubbing_studio/services/identity_confidence_gate.dart';
import 'package:ai_dubbing_studio/services/character_voice_caster.dart';

DubSegment line(int id, String speaker, double confidence,
    {bool manual = false}) => DubSegment(
  id: id, start: id.toDouble(), end: id.toDouble() + 1,
  original: 'Dialogue', speakerId: speaker, speakerConfidence: confidence,
  speakerManuallyVerified: manual);

void main() {
  const gate = IdentityConfidenceGate();
  test('scene candidate cannot clear acoustic uncertainty', () {
    final project = DubProject(id: 'gate', title: 'gate',
      sourcePath: 'video.mp4', targetLanguage: 'hi',
      animeSceneContext: {'anime_id': 'example', 'possible_characters': ['a']},
      segments: [line(1, 'speaker_1', .9), line(2, 'unknown', 0)]);
    const CharacterVoiceCaster().assign(project);
    expect(gate.unresolved(project).map((s) => s.id), [2]);
    expect(gate.readyForSynthesis(project), isFalse);
    expect(gate.hasStableProvisionalVoice(project, 'speaker_1'), isTrue);
  });
  test('zero-confidence speaker requires explicit manual review', () {
    final project = DubProject(id: 'zero', title: 'zero',
      sourcePath: 'video.mp4', targetLanguage: 'en',
      segments: [line(1, 'speaker_1', 0)]);
    const CharacterVoiceCaster().assign(project);
    expect(gate.unresolved(project).length, 1);
    project.segments.single.speakerManuallyVerified = true;
    expect(gate.unresolved(project), isEmpty);
    expect(gate.readyForSynthesis(project), isTrue);
  });
  test('voice mapping mismatch cannot pass readiness', () {
    final project = DubProject(id: 'mismatch', title: 'mismatch',
      sourcePath: 'video.mp4', targetLanguage: 'hi',
      segments: [line(1, 'speaker_1', .9)]);
    const CharacterVoiceCaster().assign(project);
    expect(gate.readyForSynthesis(project), isTrue);
    project.segments.single.voiceId = 'hi_heroine';
    expect(gate.readyForSynthesis(project), isFalse);
  });
}
