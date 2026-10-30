import 'dart:convert';
import 'dart:io';
import 'frame_signal_sampler.dart';
import 'research_visual_embedding_engine.dart';
import 'research_evidence_graph.dart';
import 'research_engine_coordinator.dart';
import 'research_directors_scene_bible.dart';

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

  /// Diagnostic only: executes pinned ONNX on frames from an approved intake.
  Future<Map<String, dynamic>> diagnoseDinov2({
    required IntakeRecord intake,
    required String modelSha256,
    ResearchVisualEmbeddingEngine engine = const ResearchVisualEmbeddingEngine(),
  }) async {
    final receipt = await office.issueHandoff(intake);
    final duration = (intake.data['media'] as Map)['duration_ms'];
    final source = intake.data['source_path'];
    final validHash = RegExp(r'^[a-f0-9]{64}$');
    if (duration is! num || duration <= 0 || source is! String ||
        source.isEmpty || !validHash.hasMatch(modelSha256)) {
      throw const FormatException('Invalid DINOv2 diagnostic source or model');
    }
    final length = duration.toInt();
    final positions = <int>{0, (length - 1) ~/ 2, length - 1}.toList()..sort();
    final samples = <Map<String, dynamic>>[];
    for (final timestamp in positions) {
      if (!await office.verifyHandoff(intake, receipt)) {
        throw StateError('Stale intake before DINOv2 execution');
      }
      final result = await engine.evaluateDinov2Frame(
        sourcePath: source, timestampMs: timestamp,
        modelSha256: modelSha256, authorisedReferences: const {});
      if (result['actual_onnx_execution'] != true ||
          result['model_sha256'] != modelSha256 ||
          result['embedding_dimension'] != 384 ||
          result['verified_anime'] != false ||
          result['verified_character'] != false ||
          result['input_sha256'] is! String ||
          result['output_sha256'] is! String ||
          !validHash.hasMatch(result['input_sha256'] as String) ||
          !validHash.hasMatch(result['output_sha256'] as String)) {
        throw const FormatException('DINOv2 diagnostic output rejected');
      }
      samples.add({
        'timestamp_ms': timestamp,
        'input_sha256': result['input_sha256'],
        'output_sha256': result['output_sha256'],
        'embedding_dimension': result['embedding_dimension'],
        'actual_onnx_execution': true,
      });
    }
    if (!await office.verifyHandoff(intake, receipt)) {
      throw StateError('Source changed during DINOv2 diagnostics');
    }
    final diagnostic = <String, dynamic>{
      'schema': 1, 'department': '01', 'kind': 'dinov2_diagnostic',
      'project_id': intake.id, 'source_sha256': intake.data['sha256'],
      'source_duration_ms': length, 'upstream_handoff': receipt,
      'model_name': 'dinov2_small_cls.onnx',
      'model_sha256': modelSha256,
      'preprocessing_id': 'dinov2_short256_crop224_v1',
      'sample_count': samples.length, 'samples': samples,
      'android_reference_parity_verified': false,
      'semantic_recognition_verified': false,
      'independent_review': 'pending', 'approved': false,
    };
    final file = File('${(await office.root).path}/${intake.id}/dinov2_diagnostic.json');
    final temp = File('${file.path}.part');
    try {
      await temp.writeAsString(jsonEncode(diagnostic), flush: true);
      if (!await office.verifyHandoff(intake, receipt)) {
        throw StateError('Stale intake before diagnostic commit');
      }
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
    return diagnostic;
  }

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
    // Decode every requested sample across the full source in bounded native
    // batches. Never silently degrade a 30-minute video to 240 sparse frames.
    final timestamps = <int>[];
    for (var t = 0; t < length; t += sampleIntervalMs) {
      timestamps.add(t);
    }
    if (timestamps.length < 2) {
      throw StateError('Insufficient frames for visual transition analysis');
    }
    final samples = <FrameSignal>[];
    for (var offset = 0; offset < timestamps.length; offset += 240) {
      final end = offset + 240 < timestamps.length ? offset + 240 : timestamps.length;
      samples.addAll(await sampler.sample(path, timestamps.sublist(offset, end)));
      // A source replacement during long-running analysis invalidates all evidence.
      if (!await office.canHandoff(intake)) {
        throw StateError('Source changed during visual frame sampling');
      }
    }
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
        'effective_sample_interval_ms': sampleIntervalMs,
        'last_sample_ms': timestamps.last,
        'source_duration_ms': length,
        'sampling_complete': samples.length == timestamps.length,
        'native_batch_limit': 240,
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
    final graph = const ResearchEvidenceGraph().build(
      sourceSha256: intake.data['sha256'] as String,
      durationMs: duration.toInt(),
      nodes: List.generate(observedEvidence.length, (i) {
        final item = observedEvidence[i];
        return <String, dynamic>{
          'id': 'observation_$i',
          'modality': item.kind == 'shot_boundary_candidate' ? 'visual' : 'context',
          'start_ms': item.startMs, 'end_ms': item.endMs,
          'confidence': item.confidence, 'provenance': item.source,
          'observation': item.description, 'verified': false,
        };
      }), links: const []);
    final revised = <String, dynamic>{
      ...manifest,
      'evidence_graph': graph,
      'directors_scene_bible': const ResearchDirectorsSceneBible().draft(
        sourceSha256: intake.data['sha256'] as String,
        durationMs: duration.toInt()),
      'coordination_ledger': const ResearchEngineCoordinator().initial(intake.data['sha256'] as String),
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
