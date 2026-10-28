import 'export_file_validator.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';

import '../models/dub_project.dart';
import 'package:flutter/services.dart';

import 'character_voice_caster.dart';
import 'character_identity_fusion.dart';
import 'identity_confidence_gate.dart';
import 'dialogue_quality_gate.dart';
import 'offline_engine.dart';
import 'otakumind_director.dart';
import 'lip_fit_agent.dart';
import 'intelligent_timing_controller.dart';
import 'anime_scene_matcher.dart';
import 'anime_reference_store.dart';
import 'reference_first_lookup.dart';
import 'active_speaker_evidence_gate.dart';
import 'visual_speaker_evidence.dart';
import 'character_evidence_matcher.dart';
import 'project_repository.dart';
import 'separation_installation.dart';
import 'segment_quality_control.dart';
import 'voice_catalog.dart';

typedef ProgressCallback = void Function(ProjectStage stage);

class DubbingPipeline {
  final OfflineEngine engine;
  final ProjectRepository repository;

  final CharacterVoiceCaster _caster =
      const CharacterVoiceCaster();

  DubbingPipeline(this.engine, this.repository);

  OtakuMindDirector get director => OtakuMindDirector(engine);

  Future<void> _stage(
    DubProject project,
    ProjectStage stage,
    ProgressCallback? progress,
  ) async {
    project.stage = stage;
    await repository.save(project);
    progress?.call(stage);
  }

  List<DubSegment> _parseSegments(dynamic value) {
    if (value is! List) {
      throw OfflineEngineException(
        'Native engine returned an invalid segment list.',
      );
    }

    return [
      for (final item in value)
        DubSegment.fromJson(
          Map<String, dynamic>.from(item as Map),
        ),
    ];
  }

  Future<void> _assignCharacterVoices(
    DubProject project,
  ) async {
    final available = VoiceCatalog.available(project.targetLanguage);
    if (available.isEmpty) {
      throw OfflineEngineException(
        'No bundled Supertonic voices support ${project.targetLanguage}.',
      );
    }

    // Keep automatic dubbing possible when ECAPA abstains. Each unresolved
    // line gets its own provisional voice identity: never falsely merge it
    // into a known character or claim that a scene lookup proves identity.
    final unresolved = const IdentityConfidenceGate().unresolved(project);
    for (final segment in unresolved) {
      segment.speakerId = 'unresolved_segment_${segment.id}';
      segment.speakerConfidence = 0.01; // Explicitly low confidence, not verified.
      segment.speakerManuallyVerified = false;
    }
    final roles = <String, VoiceRole>{};
    if (project.animeSceneContext?['identity_status'] == 'exact_registered_asset' &&
        project.animeSceneContext?['reference_dialogue_status'] ==
            'exact_asset_script_applied') {
      final referenceRoles = project.animeSceneContext?['speaker_roles'];
      if (referenceRoles is Map) {
        for (final entry in referenceRoles.entries) {
          if (entry.key is! String) continue;
          switch (entry.value) {
            case 'male': roles[entry.key as String] = VoiceRole.male; break;
            case 'female': roles[entry.key as String] = VoiceRole.female; break;
            case 'youthful': roles[entry.key as String] = VoiceRole.youthful; break;
          }
        }
      }
    }
    _caster.assign(project, preferredRoles: roles);
    const CharacterIdentityFusion().record(project);
    for (final segment in unresolved) {
      project.speakerIdentityEvidence[segment.speakerId] =
          <String, dynamic>{
        'identity': 'unresolved_acoustic_segment',
        'identity_status': 'automatic_provisional_fallback',
        'acoustic_speaker_id': segment.speakerId,
        'acoustic_confidence': 0.0,
        'segment_ids': [segment.id],
        'character_id': null,
        'visual_speaker_link_verified': false,
        'reference_speaker_link_verified': false,
        'voice_casting_status': 'assigned_provisionally',
      };
    }
    await repository.save(project);

    for (final segment in project.segments) {
      if (segment.speakerId.trim().isEmpty ||
          segment.speakerId == 'unknown') {
        throw OfflineEngineException(
          'Speaker identification is incomplete for '
          'segment ${segment.id}.',
        );
      }

      if (segment.voiceId.isEmpty) {
        throw OfflineEngineException(
          'No character voice was assigned to '
          'segment ${segment.id}.',
        );
      }

      if (VoiceCatalog.supertonicStyle(segment.voiceId) == null) {
        throw OfflineEngineException(
          'The assigned Supertonic style is unavailable for segment ${segment.id}.',
        );
      }
    }

    if (!const IdentityConfidenceGate().readyForSynthesis(project)) {
      throw OfflineEngineException('Casting confidence gate is incomplete.');
    }
    await repository.save(project);
  }

  Future<DubProject> process(
    DubProject project, {
    ProgressCallback? onProgress,
  }) async {
    try {
      project.error = null;
      project.outputPath = null;

      // Validate source before loading large models or resuming checkpoints.
      // A picker cache file may disappear after Android reclaims storage.
      final source = File(project.sourcePath);
      if (!await source.exists() || await source.length() == 0) {
        throw OfflineEngineException(
          'Source media is missing or empty. Re-import the video before resuming.',
        );
      }
      await engine.verifyRuntime();

      // Fail before expensive inference if soundtrack preservation is unavailable.
      final separation = await SeparationInstallation.load();

      // Existing v5 projects may have reached translation before Android killed
      // the process. Reuse only checkpoints whose data validates.
      final hasTranscript = project.segments.isNotEmpty &&
          project.segments.every((s) => s.original.trim().isNotEmpty &&
              s.start.isFinite && s.end.isFinite && s.end > s.start);
      final hasCasting = hasTranscript && project.characterVoices.isNotEmpty &&
          project.segments.every((s) => s.speakerId.isNotEmpty &&
              s.speakerId != 'unknown' && s.voiceId.isNotEmpty &&
              project.characterVoices[s.speakerId] == s.voiceId);
      if (!hasTranscript) {
        // A byte-identical licensed/local registered asset can use its
        // complete reference script without running Whisper. No visual
        // similarity score is sufficient to enter this path.
        final entries = await const AnimeReferenceStore().load();
        if (entries.any((entry) => entry['asset_sha256'] is String)) {
          final digest = (await sha256.bind(source.openRead()).first).toString();
          final exact = const ExactReferenceDialogue().match(entries, digest);
          if (exact != null) {
            project.sourceLanguage = exact['source_language'] as String;
            project.segments
              ..clear()
              ..addAll(exact['segments'] as List<DubSegment>);
            project.animeSceneContext =
                Map<String, dynamic>.from(exact['context'] as Map);
            await repository.save(project);
          }
        }
      }
      if (!(project.segments.isNotEmpty &&
          project.segments.every((line) => line.original.trim().isNotEmpty &&
              line.start.isFinite && line.end.isFinite && line.end > line.start))) {
        // Reference-first discovery runs before Whisper. Ordered visual
        // fingerprints are retrieval evidence only: an exact timeline/asset
        // verifier is still required before substituting catalog dialogue.
        // Preserve an earlier checkpoint if discovery is unavailable.
        if (project.animeSceneContext == null) {
          final entries = await const AnimeReferenceStore().load();
          if (entries.any((entry) => entry['frame_hashes'] is List &&
              (entry['frame_hashes'] as List).length >= 3 &&
              entry['timeline'] is List)) {
            try {
              final hashes = await engine.sampleSceneFrameHashes(project.sourcePath);
              final match = const ReferenceFirstLookup().candidate(entries, hashes);
              if (match != null) {
                project.animeSceneContext = match;
                await repository.save(project);
              }
            } catch (_) {
              // Missing native sampler or unsupported video: Whisper fallback.
            }
          }
        }
        await _stage(project, ProjectStage.transcribing, onProgress);
        final transcript = await engine.transcribe(project);
        final detectedLanguage = (transcript['language'] as String? ?? '')
            .trim().toLowerCase().split(RegExp('[-_]')).first;
        if (detectedLanguage.isEmpty || detectedLanguage == 'auto' ||
            detectedLanguage == 'unknown') {
          throw OfflineEngineException(
            'Whisper could not identify the source language reliably. '
            'Translation cannot proceed with an unknown language.',
          );
        }
        project.sourceLanguage = detectedLanguage;
      final transcribedSegments = _parseSegments(transcript['segments']);
      if (transcribedSegments.map((s) => s.id).toSet().length !=
              transcribedSegments.length ||
          transcribedSegments.any((s) =>
              !s.start.isFinite || !s.end.isFinite ||
              s.start < 0 || s.end <= s.start || s.original.trim().isEmpty)) {
        throw OfflineEngineException('Transcription returned invalid dialogue segments.');
      }
      project.segments
        ..clear()
        ..addAll(transcribedSegments);

      if (project.segments.isEmpty) {
        throw OfflineEngineException(
          'No dialogue was detected in the selected media.',
        );
      }

        await repository.save(project); // transcription checkpoint
      }

      // Resolve franchise/episode context only from a corroborated, explicitly
      // supplied reference corpus. An empty catalog leaves identity unknown
      // and never blocks acoustic diarization or alters speaker IDs.
      if (project.animeSceneContext == null && project.segments.isNotEmpty) {
        final entries = await const AnimeReferenceStore().load();
        final references = entries.map((entry) =>
            AnimeSceneReference.fromJson(Map<String, dynamic>.from(entry as Map)))
            .toList();
        // Visual evidence is optional: older/audio-only files and unsupported
        // codecs must still dub, but cannot claim multimodal corroboration.
        List<String> frameHashes = const [];
        if (references.any((reference) => reference.frameHashes.isNotEmpty)) {
          try {
            frameHashes = await engine.sampleSceneFrameHashes(project.sourcePath);
          } catch (_) {
            // No frame evidence: text-only retrieval remains explicitly marked.
          }
        }
        final candidate = director.identifyScene(project, references,
            observedFrameHashes: frameHashes);
        if (candidate != null) {
          project.animeSceneContext!['evidence'] =
              frameHashes.isEmpty ? 'dialogue_only' : 'dialogue_and_visual';
        }
        await repository.save(project);
      }

      if (!hasCasting) {
        await _stage(project, ProjectStage.casting, onProgress);
        // A failed casting attempt already persisted diarization. Reuse it
        // when the user supplies voice assignments; do not re-run clustering
        // and invalidate the selected speaker IDs on resume.
        final hasIdentifiedSpeakers = hasTranscript &&
            project.segments.any((s) =>
                s.speakerId.trim().isNotEmpty && s.speakerId != 'unknown') &&
            project.characterVoices.isNotEmpty;
        if (!hasIdentifiedSpeakers &&
            project.animeSceneContext?['identity_status'] !=
                'exact_registered_asset') {
        final casting = await engine.identifySpeakers(project);
      final beforeCasting = List<DubSegment>.from(project.segments);
      final identifiedSegments = _parseSegments(casting['segments']);
      if (identifiedSegments.map((segment) => segment.id).toSet().length !=
              identifiedSegments.length ||
          identifiedSegments.length != beforeCasting.length ||
          identifiedSegments.asMap().entries.any((entry) {
            final original = beforeCasting[entry.key];
            final identified = entry.value;
            return original.id != identified.id ||
                original.original != identified.original ||
                (original.start - identified.start).abs() > 0.001 ||
                (original.end - identified.end).abs() > 0.001 ||
                !identified.start.isFinite || !identified.end.isFinite ||
                identified.start < 0 || identified.end <= identified.start;
          })) {
        throw OfflineEngineException(
          'Speaker identification changed dialogue timing or identity.',
        );
      }

      project.segments
        ..clear()
        ..addAll(identifiedSegments);

      if (project.segments.isEmpty) {
        throw OfflineEngineException(
          'Speaker identification returned no dialogue.',
        );
      }

        await repository.save(project); // diarization checkpoint
        }
        // Visual inference is optional until verified native weights are shipped.
        // A missing native handler must not turn a scene hash into lip evidence.
        try {
          final visual = await engine.analyzeActiveSpeakers(project);
          final raw = visual['candidates'] as List;
          final candidates = raw.map((item) => VisualSpeakerEvidence.fromJson(
              Map<String, dynamic>.from(item as Map))).toList();
          final accepted = const ActiveSpeakerEvidenceGate()
              .evaluate(project, candidates);
          project.animeSceneContext ??= <String, dynamic>{};
          // Only annotations from the uniquely selected reference scene are
          // eligible. The native source hash must agree with the annotation.
          // These are proposals, never self-certified character identities.
          final scene = project.animeSceneContext!;
          final catalog = await const AnimeReferenceStore().load();
          final matching = catalog.where((e) => e['anime_id'] == scene['anime_id'] &&
              e['episode_id'] == scene['episode_id'] &&
              e['start_seconds'] == scene['reference_start_seconds']).toList();
          final annotations = <Map<String, dynamic>>[];
          for (final reference in matching) {
            final rows = reference['speaker_annotations'];
            if (rows is! List) continue;
            for (final rawRow in rows) {
              if (rawRow is! Map) continue;
              final row = Map<String, dynamic>.from(rawRow);
              final segment = row['segment_id'];
              final evidence = accepted[segment];
              if (evidence == null || row['source_hash'] != evidence.sourceHash ||
                  row['reference_id'] != reference['source_id']) continue;
              annotations.add(row);
            }
          }
          final proposals = const CharacterEvidenceMatcher()
              .propose(project, accepted, annotations);
          scene['character_match_candidates'] = [
            for (final proposal in proposals) <String, dynamic>{
              'speaker_id': proposal.speakerId,
              'segment_id': proposal.segmentId,
              'track_id': proposal.trackId,
              'character_id': proposal.characterId,
              'reference_id': proposal.referenceId,
              'visual_score': proposal.visualScore,
              'status': 'candidate_requires_independent_validation',
            },
          ];
          // Preserve measured timing as advisory evidence only. No expression
          // or mouth motion is inferred from a static scene hash or transcript.
          scene['measured_expression_candidates'] = [
            for (final entry in accepted.entries)
              if (entry.value.verifiedDelivery) <String, dynamic>{
                'segment_id': entry.key,
                'track_id': entry.value.trackId,
                'delivery': entry.value.delivery,
                'confidence': entry.value.deliveryConfidence,
                'model_id': entry.value.modelId,
                'source_hash': entry.value.sourceHash,
                'status': 'measured_candidate_not_automatically_applied',
              },
          ];
          scene['expression_inference_status'] =
              'native_model_output_requires_independent_validation';
                    scene['lip_timing_candidates'] = [
            for (final entry in accepted.entries) <String, dynamic>{
              'segment_id': entry.key,
              'track_id': entry.value.trackId,
              'start_seconds': entry.value.startSeconds,
              'end_seconds': entry.value.endSeconds,
              'score': entry.value.lipSyncScore,
              'model_id': entry.value.modelId,
              'source_hash': entry.value.sourceHash,
              'status': 'measured_candidate_not_output_lip_sync',
            },
          ];
          project.animeSceneContext!['active_speaker_evidence'] = [
            for (final entry in accepted.entries)
              <String, dynamic>{
                'segment_id': entry.key,
                'track_id': entry.value.trackId,
                'model_id': entry.value.modelId,
                'source_hash': entry.value.sourceHash,
                'lip_sync_score': entry.value.lipSyncScore,
                'status': 'visual_track_candidate_not_character_identity',
              },
          ];
        } on OfflineEngineException catch (error) {
          // Preserve acoustic-only operation, but make missing or failed
          // audiovisual inference visible in the durable project checkpoint.
          project.animeSceneContext ??= <String, dynamic>{};
          project.animeSceneContext!['visual_inference_status'] =
              'unavailable_or_failed';
          project.animeSceneContext!['visual_inference_diagnostic'] =
              error.message;
        } on FormatException {
          project.animeSceneContext ??= <String, dynamic>{};
          project.animeSceneContext!['visual_inference_status'] =
              'invalid_model_output';
        } on TypeError {
          project.animeSceneContext ??= <String, dynamic>{};
          project.animeSceneContext!['visual_inference_status'] =
              'invalid_model_output';
        }
        await _assignCharacterVoices(project); // casting checkpoint
      }

      // Legacy checkpoints may contain the literal request value "auto":
      // older native transcription echoed it instead of detected language.
      // Never infer Japanese from the filename or blindly pass "auto" to MT.
      if (project.sourceLanguage.trim().isEmpty ||
          const {'auto', 'unknown'}.contains(
            project.sourceLanguage.trim().toLowerCase())) {
        throw OfflineEngineException(
          'This project has no detected source language (legacy auto '
          'checkpoint). Re-import the video after installing an engine '
          'that reports Whisper detected language. Existing translations '
          'cannot be validated against an unknown source.',
        );
      }

      // Translate and commit each segment independently. A later malformed
      // response must not discard earlier valid dialogue in the same batch.
      await _stage(project, ProjectStage.translating, onProgress);
      const batchSize = 4; // Only refinement batches; translation is atomic per line.
      for (final segment in project.segments) {
        if (DialogueQualityGate.acceptableTranslation(
          segment.translation, segment.original, project.sourceLanguage,
          project.targetLanguage,
        )) continue;
        final candidate = await director.translateLine(project, segment);
        segment.translation = candidate;
        project.refinedSegmentIds.remove(segment.id);
        await repository.save(project); // durable successful-line checkpoint
      }

      // A completed translation checkpoint is persisted before refinement.
      await _stage(project, ProjectStage.refining, onProgress);
      // Refinement is optional for recovery safety: preserve the translated
      // dialogue until a complete validated refinement batch is available.
      for (var offset = 0; offset < project.segments.length; offset += batchSize) {
        final pending = project.segments.skip(offset).take(batchSize)
            .where((segment) => !project.refinedSegmentIds.contains(segment.id)).toList();
        if (pending.isEmpty) continue;
        // Refinement is optional: a model failure must not discard already
        // validated translations or force an entire project to restart.
        // Optional model proposal; invalid or failed output never overwrites
        // previously validated translation or changes acoustic identity.
        Map<int, String> accepted;
        try {
          accepted = await director.refineBatch(project, pending);
        } catch (_) {
          await repository.save(project);
          continue;
        }
        for (final segment in pending) {
          final candidate = accepted[segment.id];
          if (candidate != null) {
            segment.translation = candidate;
            project.refinedSegmentIds.add(segment.id);
          }
        }
        await repository.save(project);
      }

      // Restore the persistent speaker-to-voice mapping.
      for (final segment in project.segments) {
        final assigned = project.characterVoices[
          segment.speakerId
        ];

        if (assigned == null ||
            VoiceCatalog.supertonicStyle(assigned) == null) {
          throw OfflineEngineException(
            'A valid character voice is missing for '
            'segment ${segment.id}.',
          );
        }

        segment.voiceId = assigned;

        if (!DialogueQualityGate.acceptableTranslation(
          segment.translation, segment.original, project.sourceLanguage,
          project.targetLanguage)) {
          throw OfflineEngineException(
            'Translated dialogue is missing or invalid for '
            'segment ${segment.id}.',
          );
        }
      }

      director.verifyBeforeSynthesis(project);

      // Apply deterministic pre-synthesis quality triage to the actual pipeline.
      // Do not generate an MP4 with unresolved identities, malformed dialogue,
      // invalid timing or missing voice assignments.
      final failures = project.segments
          .map((segment) => SegmentQualityControl.inspect(
                segment: segment,
                sourceLanguage: project.sourceLanguage,
                targetLanguage: project.targetLanguage,
              ))
          .where((report) => !report.passed)
          .toList();
      if (failures.isNotEmpty) {
        final preview = failures.take(5).map((report) =>
            '${report.segmentId}: ${report.issues.map((i) => i.name).join(", ")}').join('; ');
        throw OfflineEngineException(
          'Pre-synthesis quality control rejected ${failures.length} '
          'dialogue segment(s). ${preview}',
        );
      }
      await repository.save(project);

      // STEP 6: Generate individual character voices
      await _stage(
        project,
        ProjectStage.synthesizing,
        onProgress,
      );

      // A failed duration fit must not force the entire project to restart.
      // Only the rejected line is eligible for a bounded, validated rewrite.
      Map<String, dynamic> synthesis;
      final timingRetries = <int, int>{};
      while (true) {
        try {
          synthesis = await engine.synthesize(project);
          break;
        } on OfflineEngineException catch (error) {
          final match = RegExp(
            r'Dialogue for segment (\d+) requires excessive duration compression',
          ).firstMatch(error.message);
          if (match == null) rethrow;
          final id = int.parse(match.group(1)!);
          final attempts = timingRetries[id] ?? 0;
          final matches = project.segments.where((s) => s.id == id).toList();
          if (matches.length != 1) rethrow;
          final segment = matches.single;
          // Try verified adjacent silence before sacrificing dialogue wording.
          // Persist separately from immutable acoustic timestamps.
          if (segment.synthesisEnd == null) {
            final extended = IntelligentTimingController.extendIntoFollowingGap(
              project, segment,
            );
            if (extended != null) {
              segment.synthesisEnd = extended;
              await repository.save(project);
              continue;
            }
          }
          final previous = segment.translation.trim();
          String? candidate;
          var attempted = attempts;
          final rejectionReasons = <String>[];
          final alternatives = <String>{};
          // Collect independent proposals; never commit the first merely
          // because it is shorter. Evaluate the candidates as a group.
          while (attempted < 4) {
            try {
              final proposal = await LipFitAgent(engine).propose(
                project, segment, attempt: attempted,
              );
              if (proposal != null && proposal != previous) {
                alternatives.add(proposal);
              } else {
                rejectionReasons.add('no usable alternative');
              }
            } catch (error) {
              final message = error.toString();
              rejectionReasons.add(message.contains('unchanged dialogue')
                  ? 'rewrite unchanged'
                  : message.contains('target-language validation')
                      ? 'rewrite failed target-language validation'
                      : message.contains('immutable')
                          ? 'model changed immutable metadata'
                          : message.contains('LipFit returned')
                              ? 'invalid model response shape'
                              : 'adaptation engine error');
            }
            attempted++;
          }
          final measured = <String, double>{};
          final window = (segment.synthesisEnd ?? segment.end) - segment.start;
          for (final alternative in alternatives) {
            try {
              measured[alternative] = await LipFitAgent(engine)
                  .measureSpokenSeconds(project, segment, alternative);
            } catch (_) {
              rejectionReasons.add('candidate duration measurement failed');
            }
          }
          if (measured.isNotEmpty) {
            final ranked = measured.entries.toList()
              ..sort((a, b) => a.value.compareTo(b.value));
            // Choose by actual generated speech length, never character count.
            // If no alternative fits the bounded 1.5x WSOLA limit, retain
            // the original translation and report the measured minimum.
            final fitting = ranked.where((entry) => entry.value <= window * 1.50);
            if (fitting.isNotEmpty) {
              candidate = fitting.first.key;
            } else {
              rejectionReasons.add(
                'shortest measured speech ${ranked.first.value.toStringAsFixed(2)}s '
                'exceeds safe fit for ${window.toStringAsFixed(2)}s window',
              );
            }
          }
          timingRetries[id] = attempted;
          if (candidate == null ||
              candidate.toLowerCase() == previous.toLowerCase() ||
              !DialogueQualityGate.acceptableTranslation(
                candidate, segment.original, project.sourceLanguage,
                project.targetLanguage)) {
            throw OfflineEngineException(
              'LipFit could not find dialogue fitting segment $id after '
              '$attempted adaptation attempt(s). Window: '
              '${((segment.synthesisEnd ?? segment.end) - segment.start).toStringAsFixed(2)}s; '
              'current text: ${previous.runes.length} characters. '
              'The original dialogue was preserved. '
              'Rejections: ${rejectionReasons.join('; ')}. '
              'Supertonic requires a shorter meaning-preserving line.',
            );
          }
          segment.translation = candidate;
          project.refinedSegmentIds.add(id);
          await repository.save(project);
        }
      }

      // Matches the native MainActivity synthesize response.
      final clips = synthesis['clips'];

      if (clips is! List || clips.isEmpty) {
        throw OfflineEngineException(
          'Voice synthesis produced no audio clips.',
        );
      }

      final expectedIds = project.segments.map((segment) => segment.id).toSet();
      final returnedIds = <int>{};
      // Index once: long videos can contain thousands of dialogue segments.
      final segmentsById = {for (final s in project.segments) s.id: s};
      if (segmentsById.length != project.segments.length) {
        throw OfflineEngineException('Project contains duplicate segment IDs.');
      }
      for (final item in clips) {
        if (item is! Map || item['segment_id'] is! int ||
            !returnedIds.add(item['segment_id'] as int)) {
          throw OfflineEngineException('Synthesis returned invalid or duplicate clip IDs.');
        }
        final segment = segmentsById[item['segment_id'] as int];
        if (segment == null) {
          throw OfflineEngineException('Synthesis returned an unknown segment.');
        }
        final clipPath = item['wav_path'];
        final sampleRate = item['sample_rate'];
        if (clipPath is! String || clipPath.trim().isEmpty ||
            sampleRate is! int || sampleRate <= 0 ||
            !await File(clipPath).exists() ||
            await File(clipPath).length() <= 44) {
          throw OfflineEngineException(
            'Synthesis returned missing or invalid audio for segment ${segment.id}.',
          );
        }
        if (item['speaker_id'] != segment.speakerId ||
            item['voice_id'] != segment.voiceId ||
            item['start'] is! num || item['end'] is! num ||
            !(item['start'] as num).toDouble().isFinite ||
            !(item['end'] as num).toDouble().isFinite ||
            (item['end'] as num).toDouble() <= (item['start'] as num).toDouble() ||
            ((item['start'] as num).toDouble() - segment.start).abs() > 0.001 ||
            ((item['end'] as num).toDouble() - (segment.synthesisEnd ?? segment.end)).abs() > 0.001) {
          throw OfflineEngineException('Synthesis changed character or timing for segment ${segment.id}.');
        }
      }
      if (returnedIds.length != expectedIds.length ||
          !returnedIds.containsAll(expectedIds)) {
        throw OfflineEngineException('Synthesis omitted dialogue segments.');
      }

      // STEP 7: Synchronize dialogue and export MP4
      await _stage(
        project,
        ProjectStage.exporting,
        onProgress,
      );

      final mixed = await engine.mixDialogue(
        project,
        clips,
      );

      final wavPath = mixed['wav_path'];

      if (wavPath is! String || wavPath.trim().isEmpty) {
        throw OfflineEngineException(
          'Dialogue mixing did not produce a WAV file.',
        );
      }

      if (!await File(wavPath).exists() || await File(wavPath).length() <= 44) {
        throw OfflineEngineException('Dialogue mixer returned a missing or empty WAV file.');
      }
      // Avoid running expensive separation after a failed dialogue mix.
      final stems = await engine.separateSoundtrack(
        sourcePath: project.sourcePath,
        modelPath: separation.modelPath,
        checkpointSha256: separation.sha256,
        inputName: separation.inputName,
        outputName: separation.outputName,
      );
      final accompaniment = stems['accompaniment_path'];
      if (accompaniment is! String || accompaniment.trim().isEmpty) {
        throw OfflineEngineException('Instrumental separation produced no accompaniment.');
      }
      if (!await File(accompaniment).exists() ||
          await File(accompaniment).length() <= 44) {
        throw OfflineEngineException('Separation returned a missing or empty accompaniment WAV.');
      }
      final finalMix = await engine.mixSoundtrack(
        dialogueWavPath: wavPath,
        accompanimentPath: accompaniment,
      );

      final exported = await engine.exportVideo(
        project,
        finalMix,
      );

      final output = exported['output_path'];

      if (output is! String || output.trim().isEmpty) {
        throw OfflineEngineException(
          'The media engine did not return an output file.',
        );
      }

      final exportedFile = File(output);
      if (!await ExportFileValidator.hasMp4Header(exportedFile)) {
        throw OfflineEngineException(
          'Export reported success but the output is missing or has an invalid MP4 header.',
        );
      }
      project.outputPath = output;
      // Preserve the private completed MP4 even if publishing to the gallery fails.
      await repository.save(project);
      try {
        await const MethodChannel('co.parikshit.otakudub/offline_engine')
            .invokeMethod<String>('saveCompletedVideo', {
          'path': output,
          'projectId': project.id,
        });
      } catch (error) {
        // A gallery error must not turn an already exported MP4 into a failed dub.
        project.error = 'Video exported in Projects, but Movies auto-save failed: $error';
      }

      // STEP 8: Save completed project
      await _stage(
        project,
        ProjectStage.completed,
        onProgress,
      );

      return project;
    } catch (error) {
      project.error = error.toString();
      project.stage = ProjectStage.failed;
      try {
        await repository.save(project);
      } catch (_) {
        // Preserve the original processing error when persistence also fails.
      }
      onProgress?.call(ProjectStage.failed);
      rethrow;
    }
  }
}
