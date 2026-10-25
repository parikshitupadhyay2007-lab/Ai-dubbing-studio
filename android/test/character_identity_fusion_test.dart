import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/models/dub_project.dart';
import 'package:ai_dubbing_studio/services/character_identity_fusion.dart';
import 'package:ai_dubbing_studio/services/character_voice_caster.dart';

void main() {
  test('scene candidate never becomes an asserted speaker-to-character link', () {
    final project = DubProject(id: 'evidence', title: 'test',
      sourcePath: 'video.mp4', targetLanguage: 'hi',
      segments: [
        DubSegment(id: 1, start: 0, end: 1, original: 'First',
          speakerId: 'speaker_1', speakerConfidence: 0.88),
        DubSegment(id: 2, start: 2, end: 3, original: 'Unknown',
          speakerId: 'unknown'),
      ],
      animeSceneContext: {'anime_id': 'reference-a', 'episode_id': '1',
        'evidence': 'dialogue_and_visual',
        'possible_characters': [{'name': 'Candidate A'}]});
    const CharacterVoiceCaster().assign(project);
    const CharacterIdentityFusion().record(project);
    expect(project.speakerIdentityEvidence.keys.toList(), ['speaker_1']);
    final evidence = project.speakerIdentityEvidence['speaker_1'] as Map;
    expect(evidence['identity'], 'provisional_speaker');
    expect(evidence['character_id'], isNull);
    expect(evidence['voice_casting_status'], 'assigned');
    expect(evidence['scene_candidate'], 'reference-a');
    expect(evidence['visual_speaker_link_verified'], isFalse);
    expect(project.segments.last.speakerId, 'unknown');
    final restored = DubProject.decode(project.encode());
    expect(restored.speakerIdentityEvidence, project.speakerIdentityEvidence);
  });

  test('manual acoustic resolution does not generate model confidence', () {
    final project = DubProject(id: 'manual', title: 'test',
      sourcePath: 'video.mp4', targetLanguage: 'en',
      segments: [DubSegment(id: 3, start: 0, end: 1, original: 'Line',
        speakerId: 'speaker_manual_1', speakerManuallyVerified: true)]);
    const CharacterIdentityFusion().record(project);
    final evidence = project.speakerIdentityEvidence['speaker_manual_1'] as Map;
    expect(evidence['manually_reviewed'], isTrue);
    expect(evidence['acoustic_confidence'], isNull);
  });
  test('multimodal link rejects unrelated segments and preserves speaker IDs', () {
    final project = DubProject(id: 'fusion', title: 'fixture',
      sourcePath: 'video.mp4', targetLanguage: 'hi',
      segments: [
        DubSegment(id: 1, start: 0, end: 1, original: 'One',
          speakerId: 'speaker_1', speakerConfidence: 0.9),
        DubSegment(id: 2, start: 1, end: 2, original: 'Two',
          speakerId: 'speaker_2', speakerConfidence: 0.9),
      ]);
    const fusion = CharacterIdentityFusion();
    fusion.record(project);
    expect(fusion.applyVerifiedLink(project, speakerId: 'speaker_1',
      characterId: 'character-a', segmentIds: [1, 2],
      referenceId: 'ref', visualEvidenceId: 'visual',
      acousticEvidenceId: 'acoustic'), isFalse);
    expect(fusion.applyVerifiedLink(project, speakerId: 'speaker_1',
      characterId: 'character-a', segmentIds: [1],
      referenceId: '', visualEvidenceId: 'visual',
      acousticEvidenceId: 'acoustic'), isFalse);
    expect(fusion.applyVerifiedLink(project, speakerId: 'speaker_1',
      characterId: 'character-a', segmentIds: [1],
      referenceId: 'ref', visualEvidenceId: 'visual',
      acousticEvidenceId: 'acoustic'), isTrue);
    fusion.record(project);
    final evidence = project.speakerIdentityEvidence['speaker_1'] as Map;
    expect(evidence['character_id'], 'character-a');
    expect(evidence['identity'], 'verified_character');
    expect(project.segments.first.speakerId, 'speaker_1');
    project.segments.first.speakerId = 'speaker_2';
    fusion.record(project);
    expect(project.speakerIdentityEvidence.containsKey('speaker_1'), isFalse);
  });

}
