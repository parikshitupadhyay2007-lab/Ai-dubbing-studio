import 'research_character_fusion.dart';
import 'research_speaker_attribution.dart';
import 'research_episode_matching.dart';
import 'research_dramatic_evidence.dart';
import 'research_multimodal_reviewer.dart';

/// Single fail-closed orchestration for measured, externally supplied signals.
/// Inputs must originate from real upstream detectors/embedders; no fabricated
/// visual identities, mouth motion, dialogue, or dramatic interpretations.
class ResearchMultimodalCoordinator {
  const ResearchMultimodalCoordinator();

  Map<String, dynamic> evaluate({
    required int durationMs,
    required String sourceSha256,
    required List<Map<String, dynamic>> characterObservations,
    required List<Map<String, dynamic>> dialogueObservations,
    required List<List<double>> episodeSamples,
    required Map<String, List<double>> authorisedReferences,
    required Map<String, Map<String, dynamic>> referenceProvenance,
    required List<Map<String, dynamic>> sceneObservations,
    required List<Map<String, dynamic>> timedDialogueEvidence,
  }) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sourceSha256)) {
      throw const FormatException('Unbound multimodal source');
    }
    final tracks = const ResearchCharacterFusion().track(
      observations: characterObservations);
    final attribution = const ResearchSpeakerAttribution().attribute(
      durationMs: durationMs, dialogue: dialogueObservations);
    final episode = const ResearchEpisodeMatching().compare(
      sampledEmbeddings: episodeSamples,
      authorisedReferences: authorisedReferences,
      provenance: referenceProvenance);
    final dramatic = const ResearchDramaticEvidence().assemble(
      durationMs: durationMs, scenes: sceneObservations,
      dialogue: timedDialogueEvidence);
    final review = const ResearchMultimodalReviewer().review(
      durationMs: durationMs, characterTracks: tracks,
      speakerAttribution: attribution, episodeMatching: episode,
      dramaticEvidence: dramatic);
    if (review['passed'] != true) {
      throw FormatException('Independent multimodal review failed: ${review['errors']}');
    }
    return {
      'schema': 'otakudub_multimodal_provisional_v1',
      'source_sha256': sourceSha256, 'duration_ms': durationMs,
      'character_tracking': tracks, 'speaker_attribution': attribution,
      'episode_matching': episode, 'dramatic_evidence': dramatic,
      'independent_consistency_review': review,
      'professional_acceptance': false, 'approved': false,
      'handoff_to_department02': false,
    };
  }
}
