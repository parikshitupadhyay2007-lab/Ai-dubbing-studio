import 'dart:io';

import '../models/dub_project.dart';
import 'package:flutter/services.dart';

import 'character_voice_caster.dart';
import 'character_identity_fusion.dart';
import 'identity_confidence_gate.dart';
import 'dialogue_quality_gate.dart';
import 'offline_engine.dart';
import 'otakumind_director.dart';
import 'anime_scene_matcher.dart';
import 'anime_reference_store.dart';
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

    final unresolved = const IdentityConfidenceGate().unresolved(project);
    // Cast every acoustically identified speaker before handling exceptions.
    // Scene metadata is advisory, never an invented acoustic identity or role.
    _caster.assign(project);
    const CharacterIdentityFusion().record(project);
    await repository.save(project); // preserve partial automatic casting and evidence

    if (unresolved.isNotEmpty) {
      final preview = unresolved.take(8).map((s) =>
          '#${s.id} (${(s.end - s.start).toStringAsFixed(2)}s)').join(', ');
      throw OfflineEngineException(
        'ECAPA could not establish an acoustic identity for '
        '${unresolved.length} of ${project.segments.length} lines: $preview. '
        'The transcript and successful speaker matches are saved. '
        'Verified speakers have already received provisional, consistent '
        'voices. Review only unresolved lines in Assign Character Voices; '
        'Resume preserves confirmed assignments. An anime scene match cannot '
        'safely identify an audible speaker.',
      );
    }

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
        if (!hasIdentifiedSpeakers) {
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
        } on OfflineEngineException {
          // Provisional acoustic casting remains available offline.
        } on FormatException {
          // Invalid output cannot become character-identification evidence.
        } on TypeError {
          // Reject malformed native maps without corrupting the checkpoint.
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
            r'Dialogue for segment (\\d+) requires excessive duration compression',
          ).firstMatch(error.message);
          if (match == null) rethrow;
          final id = int.parse(match.group(1)!);
          final attempts = timingRetries[id] ?? 0;
          if (attempts >= 2) rethrow;
          final matches = project.segments.where((s) => s.id == id).toList();
          if (matches.length != 1) rethrow;
          final segment = matches.single;
          final previous = segment.translation.trim();
          Map<int, String> proposals;
          try {
            proposals = await director.refineBatch(project, [segment]);
          } catch (_) {
            rethrow;
          }
          final candidate = proposals[id]?.trim();
          if (candidate == null || candidate.length >= previous.length ||
              !DialogueQualityGate.acceptableTranslation(
                candidate, segment.original, project.sourceLanguage,
                project.targetLanguage)) {
            rethrow;
          }
          segment.translation = candidate;
          timingRetries[id] = attempts + 1;
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
        if (item['speaker_id'] != segment.speakerId ||
            item['voice_id'] != segment.voiceId ||
            item['start'] is! num || item['end'] is! num ||
            ((item['start'] as num).toDouble() - segment.start).abs() > 0.001 ||
            ((item['end'] as num).toDouble() - segment.end).abs() > 0.001) {
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

      final stems = await engine.separateSoundtrack(
        sourcePath: project.sourcePath,
        modelPath: separation.modelPath,
        checkpointSha256: separation.sha256,
        inputName: separation.inputName,
        outputName: separation.outputName,
      );
      if (!await File(wavPath).exists() || await File(wavPath).length() <= 44) {
        throw OfflineEngineException('Dialogue mixer returned a missing or empty WAV file.');
      }
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
      if (!await exportedFile.exists() || await exportedFile.length() == 0) {
        throw OfflineEngineException(
          'Export reported success but the output MP4 is missing or empty.',
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
