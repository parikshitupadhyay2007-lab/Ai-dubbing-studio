import 'dart:io';
import '../models/dub_project.dart';
import 'dialogue_quality_gate.dart';
import 'offline_engine.dart';

/// Specialist offline dialogue adaptation agent. Uses the installed language
/// model through a separate task contract; it is NOT a second trained model.
/// Real audiovisual lip alignment requires verified mouth timing evidence.
class LipFitAgent {
  final OfflineEngine engine;
  const LipFitAgent(this.engine);

  /// Probe real Supertonic output with an intentionally generous temporary
  /// window. This does not mutate the saved acoustic/timeline checkpoint.
  Future<double> measureSpokenSeconds(
      DubProject project, DubSegment line, String candidate) async {
    final probe = DubSegment(
      id: line.id, start: line.start, end: line.end,
      original: line.original, translation: candidate,
      speakerId: line.speakerId, voiceId: line.voiceId,
      speakerConfidence: line.speakerConfidence,
      speakerManuallyVerified: line.speakerManuallyVerified,
      delivery: line.delivery,
      synthesisEnd: line.start + 30.0,
    );
    final isolated = DubProject(
      id: project.id, title: project.title, sourcePath: project.sourcePath,
      targetLanguage: project.targetLanguage,
      sourceLanguage: project.sourceLanguage,
      segments: [probe], characterVoices: project.characterVoices,
    );
    final response = await engine.synthesize(isolated);
    final clips = response['clips'];
    if (clips is! List || clips.length != 1 || clips.single is! Map) {
      throw OfflineEngineException('LipFit measurement returned invalid clips.');
    }
    final clip = Map<String, dynamic>.from(clips.single as Map);
    final path = clip['wav_path'];
    final rate = clip['sample_rate'];
    if (path is! String || rate is! int || rate <= 0) {
      throw OfflineEngineException('LipFit measurement missing WAV metadata.');
    }
    final file = File(path);
    final bytes = await file.length();
    // Native VoiceWavWriter emits exactly 44 header bytes plus mono PCM16.
    if (bytes <= 44 || (bytes - 44).isOdd) {
      throw OfflineEngineException('LipFit measurement returned invalid WAV.');
    }
    final seconds = (bytes - 44) / (rate * 2);
    if (!seconds.isFinite || seconds <= 0 || seconds > 30) {
      throw OfflineEngineException('LipFit measurement duration is invalid.');
    }
    return seconds;
  }

  Future<String?> propose(DubProject project, DubSegment line,
      {required int attempt}) async {
    final current = line.translation.trim();
    if (attempt < 0 || attempt > 3 || current.isEmpty) return null;
    final isolated = DubProject(
      id: project.id, title: project.title, sourcePath: project.sourcePath,
      targetLanguage: project.targetLanguage,
      sourceLanguage: project.sourceLanguage,
      segments: [line], characterVoices: project.characterVoices,
    );
    final result = await engine.adaptDialogue(isolated, attempt: attempt);
    final raw = result['segments'];
    if (raw is! List || raw.length != 1 || raw.single is! Map) {
      throw OfflineEngineException('LipFit returned an invalid segment count.');
    }
    final candidate = DubSegment.fromJson(Map<String, dynamic>.from(raw.single as Map));
    if (candidate.id != line.id || candidate.original != line.original ||
        candidate.speakerId != line.speakerId ||
        (candidate.start - line.start).abs() > 0.001 ||
        (candidate.end - line.end).abs() > 0.001 ||
        candidate.voiceId != line.voiceId) {
      throw OfflineEngineException('LipFit altered immutable speaker/timeline metadata.');
    }
    final proposed = candidate.translation.trim();
    if (!DialogueQualityGate.acceptableTranslation(proposed, line.original,
        project.sourceLanguage, project.targetLanguage)) {
      throw OfflineEngineException('LipFit proposal failed target-language validation.');
    }
    if (proposed.runes.length >= current.runes.length) {
      throw OfflineEngineException('LipFit proposal did not reduce spoken text length.');
    }
    return proposed;
  }
}
