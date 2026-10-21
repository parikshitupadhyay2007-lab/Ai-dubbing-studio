
import '../models/dub_project.dart';

import 'character_voice_caster.dart';
import 'offline_engine.dart';
import 'project_repository.dart';
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

  Future<void> _assignCharacterVoices(
    DubProject project,
  ) async {
    // Refresh registrations in case voice files changed
    // while the app was running.
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

    // Do not silently generate dialogue with an unassigned voice.
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

      await engine.verifyRuntime();

      await _stage(
        project,
        ProjectStage.transcribing,
        onProgress,
      );

      final transcript = await engine.transcribe(project);

      project.sourceLanguage =
          transcript['language'] as String? ?? 'unknown';

      project.segments
        ..clear()
        ..addAll(_parseSegments(transcript['segments']));

      if (project.segments.isEmpty) {
        throw OfflineEngineException(
          'No dialogue was detected in the selected media.',
        );
      }

      await _stage(
        project,
        ProjectStage.casting,
        onProgress,
      );

      final casting = await engine.identifySpeakers(project);

      project.segments
        ..clear()
        ..addAll(_parseSegments(casting['segments']));

      if (project.segments.isEmpty) {
        throw OfflineEngineException(
          'Speaker identification returned no dialogue.',
        );
      }

      await _assignCharacterVoices(project);

      await _stage(
        project,
        ProjectStage.translating,
        onProgress,
      );

      final translation = await engine.translate(project);

      project.segments
        ..clear()
        ..addAll(_parseSegments(translation['segments']));

      await _stage(
        project,
        ProjectStage.refining,
        onProgress,
      );

      final refined = await engine.refineDialogue(project);

      project.segments
        ..clear()
        ..addAll(_parseSegments(refined['segments']));

      // Native translation/refinement can return newly constructed
      // segments. Restore the persistent speaker-to-voice mapping.
      for (final segment in project.segments) {
        final assigned = project.characterVoices[
          segment.speakerId,
        ];

        if (assigned == null ||
            VoiceCatalog.installedModel(assigned) == null) {
          throw OfflineEngineException(
            'A valid character voice is missing for '
            'segment ${segment.id}.',
          );
        }

        segment.voiceId = assigned;

        if (segment.translation.trim().isEmpty) {
          throw OfflineEngineException(
            'Translated dialogue is missing for '
            'segment ${segment.id}.',
          );
        }
      }

      await repository.save(project);

      await _stage(
        project,
        ProjectStage.synthesizing,
        onProgress,
      );

      final synthesis = await engine.synthesize(project);

      final clips = synthesis['audio_clips'];

      if (clips is! List || clips.isEmpty) {
        throw OfflineEngineException(
          'Voice synthesis produced no audio clips.',
        );
      }

      await _stage(
        project,
        ProjectStage.exporting,
        onProgress,
      );

      final exported = await engine.exportVideo(
        project,
        clips,
      );

      final output = exported['output_path'];

      if (output is! String || output.isEmpty) {
        throw OfflineEngineException(
          'The media engine did not return an output file.',
        );
      }

      project.outputPath = output;

      await _stage(
        project,
        ProjectStage.completed,
        onProgress,
      );

      return project;
    } catch (error) {
      project.error = error.toString();

      await _stage(
        project,
        ProjectStage.failed,
        onProgress,
      );

      rethrow;
    }
  }
}

