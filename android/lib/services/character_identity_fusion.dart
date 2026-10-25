import '../models/dub_project.dart';

/// Records independent evidence without allowing a scene-level match to
/// overwrite acoustic speaker identity or fabricate a character name.
class CharacterIdentityFusion {
  const CharacterIdentityFusion();

  void record(DubProject project) {
    final scene = project.animeSceneContext;
    final sceneEvidence = scene?['evidence'];
    final sceneMatched = scene != null &&
        scene['anime_id'] is String && scene['episode_id'] is String;
    final speakers = project.segments.map((s) => s.speakerId.trim())
        .where((id) => id.isNotEmpty && id != 'unknown').toSet();
    final result = <String, dynamic>{};
    for (final speaker in speakers) {
      final lines = project.segments.where((s) => s.speakerId == speaker).toList();
      final manual = lines.any((s) => s.speakerManuallyVerified);
      result[speaker] = <String, dynamic>{
        'identity': 'provisional_speaker',
        'character_id': null,
        'acoustic_speaker_id': speaker,
        'acoustic_confidence': manual ? null :
            lines.map((s) => s.speakerConfidence).where((v) => v.isFinite && v > 0)
                .fold<double>(0, (a, v) => v > a ? v : a),
        'manually_reviewed': manual,
        'segment_ids': lines.map((s) => s.id).toList()..sort(),
        'scene_candidate': sceneMatched ? scene['anime_id'] : null,
        'scene_evidence': sceneMatched ? sceneEvidence : null,
        'visual_speaker_link_verified': false,
        'reference_speaker_link_verified': false,
      };
    }
    project.speakerIdentityEvidence = result;
  }
}
