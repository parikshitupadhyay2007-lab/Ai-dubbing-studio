
import '../models/dub_project.dart';

import 'offline_engine.dart';
import 'project_repository.dart';

typedef ProgressCallback = void Function(ProjectStage stage);

class DubbingPipeline {
  final OfflineEngine engine;
  final ProjectRepository repository;

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

  Future<DubProject> process(
    DubProject project, {
    ProgressCallback? onProgress,
  }) async {
    try {
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
