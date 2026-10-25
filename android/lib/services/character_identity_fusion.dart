import '../models/dub_project.dart';

/// Records independent evidence without allowing a scene-level match to
/// overwrite acoustic speaker identity or fabricate a character name.
class CharacterIdentityFusion {
  const CharacterIdentityFusion();

  /// Apply independently verified, segment-scoped links only. The producer of
  /// these links must provide acoustic, visual and licensed-reference proof;
  /// a scene candidate or language-model suggestion is never sufficient.
  /// Every linked line must belong to the same existing acoustic speaker.
  bool applyVerifiedLink(DubProject project, {
    required String speakerId,
    required String characterId,
    required List<int> segmentIds,
    required String referenceId,
    required String visualEvidenceId,
    required String acousticEvidenceId,
  }) {
    if (speakerId.trim().isEmpty || speakerId == 'unknown' ||
        characterId.trim().isEmpty || referenceId.trim().isEmpty ||
        visualEvidenceId.trim().isEmpty || acousticEvidenceId.trim().isEmpty ||
        segmentIds.isEmpty || segmentIds.toSet().length != segmentIds.length) {
      return false;
    }
    final owned = project.segments.where((s) => s.speakerId == speakerId)
        .map((s) => s.id).toSet();
    if (!owned.containsAll(segmentIds)) return false;
    final existing = project.speakerIdentityEvidence[speakerId];
    if (existing is! Map || existing['acoustic_speaker_id'] != speakerId) {
      return false;
    }
    final previous = existing['character_id'];
    if (previous != null && previous != characterId) return false;
    project.speakerIdentityEvidence[speakerId] = <String, dynamic>{
      ...Map<String, dynamic>.from(existing),
      'identity': 'verified_character',
      'identity_status': 'verified_multimodal',
      'character_id': characterId,
      'linked_segment_ids': List<int>.of(segmentIds)..sort(),
      'reference_evidence_id': referenceId,
      'visual_evidence_id': visualEvidenceId,
      'acoustic_evidence_id': acousticEvidenceId,
      'visual_speaker_link_verified': true,
      'reference_speaker_link_verified': true,
    };
    return true;
  }

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
        'identity_status': manual ? 'manual_acoustic_review' :
            'acoustic_provisional',
        'voice_casting_status': project.characterVoices.containsKey(speaker)
            ? 'assigned' : 'pending',
        'visual_speaker_link_verified': false,
        'reference_speaker_link_verified': false,
      };
    }
    // Preserve earlier verified links only while every linked line still
    // belongs to the same acoustic speaker; do not retain stale evidence.
    for (final entry in result.entries) {
      final previous = project.speakerIdentityEvidence[entry.key];
      if (previous is! Map || previous['identity'] != 'verified_character' ||
          previous['linked_segment_ids'] is! List) continue;
      final linked = previous['linked_segment_ids'] as List;
      final current = (entry.value as Map)['segment_ids'] as List;
      if (linked.isNotEmpty && linked.every((id) => current.contains(id))) {
        result[entry.key] = <String, dynamic>{
          ...Map<String, dynamic>.from(entry.value as Map),
          ...Map<String, dynamic>.from(previous),
          'voice_casting_status': project.characterVoices.containsKey(entry.key)
              ? 'assigned' : 'pending',
        };
      }
    }
    project.speakerIdentityEvidence = result;
  }
}
