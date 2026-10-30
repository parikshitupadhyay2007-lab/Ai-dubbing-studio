/// Independently checks that the provisional Department 01 components are
/// internally consistent. Never upgrades model hypotheses to accepted dubbing.
class ResearchMultimodalReviewer {
  const ResearchMultimodalReviewer();

  Map<String, dynamic> review({
    required int durationMs,
    required Map<String, dynamic> characterTracks,
    required Map<String, dynamic> speakerAttribution,
    required Map<String, dynamic> episodeMatching,
    required Map<String, dynamic> dramaticEvidence,
  }) {
    final errors = <String>[];
    if (durationMs <= 0) errors.add('Invalid source duration');
    final assignments = characterTracks['assignments'];
    final tracks = characterTracks['tracks'];
    final lines = speakerAttribution['dialogue_attribution'];
    final scenes = dramaticEvidence['scenes'];
    if (assignments is! List || tracks is! List || lines is! List ||
        scenes is! List || scenes.isEmpty) {
      return {'passed': false, 'errors': ['Required multimodal artifacts absent'],
        'professional_acceptance': false};
    }
    final knownTracks = <String>{};
    for (final track in tracks) {
      if (track is! Map || track['track_id'] is! String ||
          !knownTracks.add(track['track_id'] as String) ||
          track['sample_count'] is! int || track['sample_count'] < 1 ||
          track['verified_character'] != false) {
        errors.add('Invalid provisional character track');
      }
    }
    for (final assignment in assignments) {
      if (assignment is! Map || assignment['status'] is! String ||
          assignment['verified_character'] != false ||
          (assignment['track_id'] != null && !knownTracks.contains(assignment['track_id']))) {
        errors.add('Unsupported identity assignment');
      }
    }
    for (final line in lines) {
      if (line is! Map || line['start_ms'] is! int || line['end_ms'] is! int ||
          line['start_ms'] < 0 || line['end_ms'] <= line['start_ms'] ||
          line['end_ms'] > durationMs || line['verified_speaker'] != false ||
          (line['candidate_track_id'] != null &&
            !knownTracks.contains(line['candidate_track_id']))) {
        errors.add('Unsupported audiovisual attribution');
      }
    }
    var cursor = 0;
    for (final scene in scenes) {
      if (scene is! Map || scene['start_ms'] != cursor ||
          scene['end_ms'] is! int || scene['end_ms'] <= cursor ||
          scene['end_ms'] > durationMs) {
        errors.add('Incomplete or overlapping dramatic chronology');
        break;
      }
      cursor = scene['end_ms'] as int;
    }
    if (cursor != durationMs) errors.add('Scene coverage does not reach source end');
    if (characterTracks['identity_verified'] != false ||
        speakerAttribution['verified'] != false ||
        episodeMatching['verified_episode'] != false ||
        dramaticEvidence['approved'] != false ||
        dramaticEvidence['narrative_inference_verified'] != false) {
      errors.add('Provisional output falsely asserts certification');
    }
    return {
      'passed': errors.isEmpty,
      'errors': errors.toSet().toList(),
      'review_scope': 'structural_and_cross_modal_consistency',
      'professional_acceptance': false,
      'pending': [
        'held_out_identity_accuracy', 'active_speaker_calibration',
        'licensed_episode_benchmark', 'narrative_model_validation',
        'physical_device_inference', 'human_director_acceptance',
      ],
    };
  }
}
