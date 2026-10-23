import '../models/dub_project.dart';
import 'package:flutter/services.dart';

import 'character_voice_caster.dart';
import 'dialogue_quality_gate.dart';
import 'offline_engine.dart';
import 'project_repository.dart';
import 'separation_installation.dart';
import 'voice_catalog.dart';
import 'voice_installation_registry.dart';

typedef ProgressCallback = void Function(ProjectStage stage);

class DubbingPipeline {
  final OfflineEngine engine;
  final ProjectRepository repository;

  final CharacterVoiceCaster _caster =
      const CharacterVoiceCaster();

  final VoiceInstallationRegistry _voiceRegistry =
      const VoiceInstallationRegistry();

  DubbingPipeline(this.engine, this.repository);

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

  // Native stages must preserve the original timeline and segment identity.
  // Otherwise dialogue can silently be dubbed with the wrong character voice.
  List<DubSegment> _checkedSegments(
    dynamic response,
    List<DubSegment> previous,
    String stage,
  ) {
    final next = _parseSegments(response);
    if (next.length != previous.length) {
      throw OfflineEngineException(
        '$stage changed the number of dialogue segments.',
      );
    }
    if (next.map((segment) => segment.id).toSet().length != next.length) {
      throw OfflineEngineException('$stage returned duplicate segment IDs.');
    }
    for (var i = 0; i < next.length; i++) {
      final before = previous[i];
      final after = next[i];
      if (after.id != before.id ||
          after.original != before.original ||
          after.speakerId != before.speakerId ||
          (after.start - before.start).abs() > 0.001 ||
          (after.end - before.end).abs() > 0.001 ||
          !after.start.isFinite || !after.end.isFinite ||
          after.start < 0 || after.end <= after.start) {
        throw OfflineEngineException(
          '$stage changed speaker identity or timing for segment ${before.id}.',
        );
      }
    }
    return next;
  }

  Future<void> _assignCharacterVoices(
    DubProject project,
  ) async {
    await _voiceRegistry.refresh();

    final available = VoiceCatalog.available(
      project.targetLanguage,
    );

    if (available.isEmpty) {
      throw OfflineEngineException(
        'No compatible character voices are installed for '
        '${project.targetLanguage.toUpperCase()}. '
        'Install a valid voice model and configuration first.',
      );
    }

    final installedIds = available
        .map((profile) => profile.modelId)
        .whereType<String>()
        .toSet();

    _caster.assign(
      project,
      installedModelIds: installedIds,
    );

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

      final installed = VoiceCatalog.installedModel(
        segment.voiceId,
      );

      if (installed == null) {
        throw OfflineEngineException(
          'The voice assigned to segment ${segment.id} '
          'is no longer installed.',
        );
      }
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
        project.sourceLanguage = transcript['language'] as String? ?? 'unknown';
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

      if (!hasCasting) {
        await _stage(project, ProjectStage.casting, onProgress);
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

        await _assignCharacterVoices(project); // casting checkpoint
      }

      // Translate small batches, persist each completed batch, and skip
      // already translated segments when reopening an interrupted project.
      await _stage(project, ProjectStage.translating, onProgress);
      const batchSize = 4;
      for (var offset = 0; offset < project.segments.length; offset += batchSize) {
        final pending = project.segments
            .skip(offset).take(batchSize)
            .where((s) => !DialogueQualityGate.acceptable(
              s.translation, project.targetLanguage)).toList();
        if (pending.isEmpty) continue;
        final batch = DubProject(
          id: project.id, title: project.title, sourcePath: project.sourcePath,
          targetLanguage: project.targetLanguage, sourceLanguage: project.sourceLanguage,
          segments: pending, characterVoices: project.characterVoices,
        );
        // Retry transient or malformed model output once. A failed batch is
        // retried per segment so one bad line cannot discard valid dialogue.
        Future<List<DubSegment>> translateChecked(DubProject request) async {
          final response = await engine.translate(request);
          final checked = _checkedSegments(
            response['segments'], request.segments, 'Translation',
          );
          if (checked.any((s) => !DialogueQualityGate.acceptable(
                s.translation, project.targetLanguage,
              ))) {
            throw OfflineEngineException(
              'Translation returned invalid spoken dialogue.',
            );
          }
          return checked;
        }

        List<DubSegment>? translated;
        try {
          translated = await translateChecked(batch);
        } catch (_) {
          // Retry each line independently; do not persist a partial batch.
          final recovered = <DubSegment>[];
          for (final segment in pending) {
            final single = DubProject(
              id: project.id, title: project.title,
              sourcePath: project.sourcePath,
              targetLanguage: project.targetLanguage,
              sourceLanguage: project.sourceLanguage,
              segments: [segment],
              characterVoices: project.characterVoices,
            );
            recovered.add((await translateChecked(single)).single);
          }
          translated = recovered;
        }
        for (var i = 0; i < pending.length; i++) {
          pending[i].translation = translated[i].translation.trim();
          // Re-translation invalidates any earlier refinement checkpoint.
          project.refinedSegmentIds.remove(pending[i].id);
        }
        await repository.save(project);
      }

      // A completed translation checkpoint is persisted before refinement.
      await _stage(project, ProjectStage.refining, onProgress);
      // Refinement is optional for recovery safety: preserve the translated
      // dialogue until a complete validated refinement batch is available.
      for (var offset = 0; offset < project.segments.length; offset += batchSize) {
        final pending = project.segments.skip(offset).take(batchSize)
            .where((segment) => !project.refinedSegmentIds.contains(segment.id)).toList();
        if (pending.isEmpty) continue;
        final batch = DubProject(
          id: project.id, title: project.title, sourcePath: project.sourcePath,
          targetLanguage: project.targetLanguage, sourceLanguage: project.sourceLanguage,
          segments: pending, characterVoices: project.characterVoices,
        );
        final refined = await engine.refineDialogue(batch);
        final next = _checkedSegments(refined['segments'], pending, 'Refinement');
        // Reject model-control text, wrong-script output, and dramatic
        // expansion. Keep the already validated translation instead.
        for (var i = 0; i < pending.length; i++) {
          final candidate = next[i].translation.trim();
          final previous = pending[i].translation.trim();
          final safe = DialogueQualityGate.acceptable(
                candidate, project.targetLanguage,
              ) &&
              candidate.length <= previous.length * 2 + 24;
          if (safe) pending[i].translation = candidate;
          project.refinedSegmentIds.add(pending[i].id);
        }
        await repository.save(project);
      }

      // Restore the persistent speaker-to-voice mapping.
      for (final segment in project.segments) {
        final assigned = project.characterVoices[
          segment.speakerId
        ];

        if (assigned == null ||
            VoiceCatalog.installedModel(assigned) == null) {
          throw OfflineEngineException(
            'A valid character voice is missing for '
            'segment ${segment.id}.',
          );
        }

        segment.voiceId = assigned;

        if (!DialogueQualityGate.acceptable(segment.translation, project.targetLanguage)) {
          throw OfflineEngineException(
            'Translated dialogue is missing or invalid for '
            'segment ${segment.id}.',
          );
        }
      }

      await repository.save(project);

      // STEP 6: Generate individual character voices
      await _stage(
        project,
        ProjectStage.synthesizing,
        onProgress,
      );

      final synthesis = await engine.synthesize(project);

      // Matches the native MainActivity synthesize response.
      final clips = synthesis['clips'];

      if (clips is! List || clips.isEmpty) {
        throw OfflineEngineException(
          'Voice synthesis produced no audio clips.',
        );
      }

      final expectedIds = project.segments.map((segment) => segment.id).toSet();
      final returnedIds = <int>{};
      for (final item in clips) {
        if (item is! Map || item['segment_id'] is! int ||
            !returnedIds.add(item['segment_id'] as int)) {
          throw OfflineEngineException('Synthesis returned invalid or duplicate clip IDs.');
        }
        final segment = project.segments.firstWhere(
          (s) => s.id == item['segment_id'],
          orElse: () => throw OfflineEngineException('Synthesis returned an unknown segment.'),
        );
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
      final accompaniment = stems['accompaniment_path'];
      if (accompaniment is! String || accompaniment.trim().isEmpty) {
        throw OfflineEngineException('Instrumental separation produced no accompaniment.');
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
