import '../models/dub_project.dart';
import 'dialogue_quality_gate.dart';
import 'anime_scene_matcher.dart';
import 'offline_engine.dart';
import 'otakumind_script_verifier.dart';
import 'otakumind_acting_evidence.dart';

/// OtakuMind is the offline dubbing director, never an interactive chatbot.
///
/// Specialist acoustic engines own transcription, diarization and audio.
/// The director coordinates contextual language work and rejects any attempt
/// by the language model to change immutable speaker identities or timing.
class OtakuMindDirector {
  final OfflineEngine engine;
  const OtakuMindDirector(this.engine);

  /// Optional grounded scene lookup, using an explicitly supplied catalog.
  /// No hit is preferable to claiming an unsupported anime or episode.
  AnimeSceneCandidate? identifyScene(DubProject project,
      List<AnimeSceneReference> catalog,
      {List<String> observedFrameHashes = const []}) {
    final candidate = const AnimeSceneMatcher().identify(project.segments, catalog,
        observedFrameHashes: observedFrameHashes);
    project.animeSceneContext = candidate?.toJson();
    return candidate;
  }

  /// Persist verified, segment-scoped delivery for native Supertonic.
  void directActing(DubProject project, Map<int, ActingEvidence> evidence) {
    const acting = OtakuMindActingDirector();
    for (final segment in project.segments) {
      acting.direct(segment, evidence[segment.id]);
    }
  }

  /// Only corroborated original scripts can be attached as reference evidence.
  /// Source dialogue and timestamps remain untouched on a failed match.
  ScriptVerification verifyOriginalScript(DubProject project,
      OriginalScriptReference reference) {
    final result = const OtakuMindScriptVerifier()
        .verify(project.segments, reference);
    if (result.accepted) {
      project.animeSceneContext = <String, dynamic>{
        ...?project.animeSceneContext,
        'script_source_id': reference.sourceId,
        'script_anime_id': reference.animeId,
        'script_episode_id': reference.episodeId,
        'script_verification': result.reason,
        'verified_original_lines': result.verifiedLines.map(
            (id, line) => MapEntry(id.toString(), line)),
      };
    }
    return result;
  }

  List<DubSegment> _checked(
      dynamic raw, List<DubSegment> source, String stage) {
    if (raw is! List || raw.length != source.length) {
      throw OfflineEngineException('$stage changed dialogue segment count.');
    }
    final ids = <int>{};
    final output = <DubSegment>[];
    for (var index = 0; index < source.length; index++) {
      final item = raw[index];
      if (item is! Map) {
        throw OfflineEngineException('$stage returned malformed dialogue.');
      }
      final line = DubSegment.fromJson(Map<String, dynamic>.from(item));
      final before = source[index];
      if (!ids.add(line.id) ||
          line.id != before.id ||
          line.original != before.original ||
          line.speakerId != before.speakerId ||
          (line.start - before.start).abs() > 0.001 ||
          (line.end - before.end).abs() > 0.001 ||
          !line.start.isFinite || !line.end.isFinite ||
          line.start < 0 || line.end <= line.start) {
        throw OfflineEngineException(
            '$stage changed speaker identity or timeline at segment ${before.id}.');
      }
      output.add(line);
    }
    return output;
  }

  /// Translate one line at a time for durable project checkpoints.
  Future<String> translateLine(DubProject project, DubSegment line) async {
    final single = DubProject(
      id: project.id,
      title: project.title,
      sourcePath: project.sourcePath,
      targetLanguage: project.targetLanguage,
      sourceLanguage: project.sourceLanguage,
      segments: [line],
      characterVoices: project.characterVoices,
    );
    final response = await engine.translate(single);
    final candidate = _checked(response['segments'], [line], 'Translation')
        .single.translation.trim();
    if (!DialogueQualityGate.acceptableTranslation(candidate, line.original,
        project.sourceLanguage, project.targetLanguage)) {
      throw OfflineEngineException(
        'OtakuMind rejected translation for segment ${line.id}: '
        '${DialogueQualityGate.rejectionReason(candidate, line.original, project.sourceLanguage, project.targetLanguage)}.',
      );
    }
    return candidate;
  }

  /// Optional contextual revision: rejection retains the verified translation.
  Future<Map<int, String>> refineBatch(
      DubProject project, List<DubSegment> batch) async {
    final request = DubProject(
      id: project.id,
      title: project.title,
      sourcePath: project.sourcePath,
      targetLanguage: project.targetLanguage,
      sourceLanguage: project.sourceLanguage,
      segments: batch,
      characterVoices: project.characterVoices,
    );
    final result = await engine.refineDialogue(request);
    final checked = _checked(result['segments'], batch, 'Refinement');
    final accepted = <int, String>{};
    for (var i = 0; i < batch.length; i++) {
      final candidate = checked[i].translation.trim();
      final previous = batch[i].translation.trim();
      if (DialogueQualityGate.acceptableTranslation(
          candidate, batch[i].original,
          project.sourceLanguage, project.targetLanguage) &&
          candidate == previous &&
          DialogueQualityGate.preservesRevisionAnchors(previous, candidate)) {
        accepted[batch[i].id] = candidate;
      }
    }
    return accepted;
  }

  /// Targeted duration recovery: the native model receives an explicit short-line
  /// contract. Never mutate the original segment until the candidate passes.
  Future<String?> shortenForTiming(DubProject project, DubSegment line, {int attempt = 0}) async {
    final request = DubProject(
      id: project.id,
      title: project.title,
      sourcePath: project.sourcePath,
      targetLanguage: project.targetLanguage,
      sourceLanguage: project.sourceLanguage,
      segments: [line],
      characterVoices: project.characterVoices,
    );
    final result = await engine.refineDialogue(request, fitForDuration: true, fitAttempt: attempt);
    final candidate = _checked(result['segments'], [line], 'Duration fit')
        .single.translation.trim();
    if (candidate.length >= line.translation.trim().length ||
        !DialogueQualityGate.acceptableTranslation(candidate, line.original,
            project.sourceLanguage, project.targetLanguage)) return null;
    return candidate;
  }

  /// Director output is a verifiable readiness decision, not guessed metadata.
  void verifyBeforeSynthesis(DubProject project) {
    if (project.segments.isEmpty) {
      throw OfflineEngineException('OtakuMind has no dialogue to direct.');
    }
    final seen = <int>{};
    for (final line in project.segments) {
      if (!seen.add(line.id) || !line.start.isFinite || !line.end.isFinite ||
          line.end <= line.start ||
          line.speakerId.isEmpty || line.speakerId == 'unknown' ||
          project.characterVoices[line.speakerId] != line.voiceId) {
        throw OfflineEngineException(
          'OtakuMind cannot verify character and timing for segment ${line.id}.');
      }
      if (!DialogueQualityGate.acceptableTranslation(line.translation,
          line.original, project.sourceLanguage, project.targetLanguage)) {
        throw OfflineEngineException(
          'OtakuMind cannot verify dialogue for segment ${line.id}.');
      }
    }
  }
}
