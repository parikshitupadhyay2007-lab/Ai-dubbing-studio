import 'dart:convert';
import 'dart:io';
import 'frame_signal_sampler.dart';

import 'otakumind_online_research.dart';
import 'continuity_evidence_verifier.dart';
import 'production_office.dart';
import 'research_continuity.dart';

/// Coordinates Department 01 without pretending reference metadata proves identity.
class OtakuMindResearchDirector {
  OtakuMindResearchDirector(this.office, {required this.onlineEnabled,
      OtakuMindOnlineResearch? online})
      : online = online ?? OtakuMindOnlineResearch(enabled: onlineEnabled);
  final ProductionOffice office;
  final bool onlineEnabled;
  final OtakuMindOnlineResearch online;

  /// Decode real frames locally and persist candidate visual transitions.
  /// This does not certify semantic scenes, identities or model coverage.
  Future<Map<String, dynamic>> runFromVideo({
    required IntakeRecord intake,
    String? userProvidedAnimeTitle,
    FrameSignalSampler sampler = const FrameSignalSampler(),
    int sampleIntervalMs = 1000,
  }) async {
    if (sampleIntervalMs < 250 || sampleIntervalMs > 60000) {
      throw const FormatException('Invalid sampling interval');
    }
    final duration = (intake.data['media'] as Map)['duration_ms'];
    final path = intake.data['source_path'];
    if (duration is! num || duration <= 0 || path is! String || path.isEmpty) {
      throw const FormatException('Invalid source metadata');
    }
    final length = duration.toInt();
    // Cover the entire source instead of silently analysing only its first
    // 240 seconds at the default sampling interval.
    final effectiveInterval = length > sampleIntervalMs * 239
        ? (length / 239).ceil()
        : sampleIntervalMs;
    final timestamps = <int>[];
    for (var t = 0; t < length && timestamps.length < 240; t += effectiveInterval) {
      timestamps.add(t);
    }
    if (timestamps.isNotEmpty && timestamps.last != length - 1 &&
        timestamps.length < 240) timestamps.add(length - 1);
    if (timestamps.length < 2) {
      throw StateError('Insufficient frames for visual transition analysis');
    }
    final samples = await sampler.sample(path, timestamps);
    final candidates = const ShotBoundaryCandidates().detect(samples);
    final observations = candidates.map((item) => SceneEvidence(
      startMs: item['start_ms'] as int,
      endMs: item['end_ms'] as int,
      kind: 'shot_boundary_candidate',
      description: 'Frame luminance discontinuity; not a verified scene boundary',
      source: 'native_decoded_frame_luma8x8',
      confidence: (item['difference'] as num).toDouble(),
    )).toList();
    final result = await run(intake: intake, observedEvidence: observations,
      userProvidedAnimeTitle: userProvidedAnimeTitle);
    final revised = <String, dynamic>{
      ...result,
      'visual_sampling': {
        'method': 'decoded_frame_luma8x8',
        'sample_count': samples.length,
        'candidate_count': candidates.length,
        'effective_sample_interval_ms': effectiveInterval,
        'last_sample_ms': timestamps.last,
        'source_duration_ms': length,
        'coverage_limited_to_240_samples': timestamps.length == 240,
        'verified_scene_segmentation': false,
      },
    };
    final receipt = Map<String, dynamic>.from(result['upstream_handoff'] as Map);
    if (!await office.verifyHandoff(intake, receipt)) {
      throw StateError('Source changed before visual sampling commit');
    }
    final file = File('${(await office.root).path}/${intake.id}/research_manifest.json');
    final temp = File('${file.path}.part');
    await temp.writeAsString(jsonEncode(revised), flush: true);
    if (!await office.verifyHandoff(intake, receipt)) {
      await temp.delete();
      throw StateError('Stale source during visual sampling commit');
    }
    await temp.rename(file.path);
    return revised;
  }

  /// Only a deliberately entered title is transmitted. No dialogue, frames,
  /// file paths, hashes, episode footage, or extracted user content is sent.
  Future<Map<String, dynamic>> run({
    required IntakeRecord intake,
    required List<SceneEvidence> observedEvidence,
    String? userProvidedAnimeTitle,
  }) async {
    final duration = (intake.data['media'] as Map)['duration_ms'];
    if (duration is! num) throw const FormatException('Missing media duration');
    final continuity = const ContinuityEvidenceVerifier().verify(
      durationMs: duration.toInt(), observations: observedEvidence,
      identityClaims: const []);
    if (continuity['passed'] != true) {
      throw FormatException('Continuity evidence rejected: ${continuity['errors']}');
    }
    final department = ResearchContinuity(office);
    final manifest = await department.createResearchManifest(intake, observedEvidence);
    Map<String, dynamic>? reference;
    String researchState = 'offline_no_reference';
    if (onlineEnabled && userProvidedAnimeTitle != null &&
        userProvidedAnimeTitle.trim().isNotEmpty) {
      try {
        reference = await online.searchAnime(userProvidedAnimeTitle);
        researchState = 'unverified_external_reference';
      } catch (error) {
        researchState = 'network_lookup_failed';
        // Failure remains visible, but does not corrupt the local artifact.
        reference = {'error': error.runtimeType.toString()};
      }
    }
    final receipt = Map<String, dynamic>.from(manifest['upstream_handoff'] as Map);
    if (!await office.verifyHandoff(intake, receipt)) {
      throw StateError('Upstream intake changed during research');
    }
    final revised = <String, dynamic>{
      ...manifest,
      'internet_enabled': onlineEnabled,
      'internet_research_status': researchState,
      if (reference != null) 'external_reference': reference,
      'identity_claims': <Object>[],
      'continuity_evidence_review': continuity,
      'model_coverage': {
        'anime_recognition': 'unavailable',
        'scene_segmentation': 'unavailable',
        'visual_understanding': 'unavailable',
        'character_recognition': 'unavailable',
        'context_research': reference != null && !reference.containsKey('error')
            ? 'metadata_only' : 'unavailable',
        'continuity_intelligence': 'validation_only',
      },
      'approved': false,
      'status': 'awaiting_models_and_review',
    };
    final file = File('${(await office.root).path}/${intake.id}/research_manifest.json');
    final temp = File('${file.path}.part');
    await temp.writeAsString(jsonEncode(revised), flush: true);
    if (!await office.verifyHandoff(intake, receipt)) {
      await temp.delete();
      throw StateError('Upstream intake changed before research commit');
    }
    await temp.rename(file.path);
    return revised;
  }
}
