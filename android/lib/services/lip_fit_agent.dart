import '../models/dub_project.dart';
import 'dialogue_quality_gate.dart';
import 'offline_engine.dart';

/// Specialist offline dialogue adaptation agent. Uses the installed language
/// model through a separate task contract; it is NOT a second trained model.
/// Real audiovisual lip alignment requires verified mouth timing evidence.
class LipFitAgent {
  final OfflineEngine engine;
  const LipFitAgent(this.engine);

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
    if (proposed.length >= current.length ||
        !DialogueQualityGate.acceptableTranslation(proposed, line.original,
            project.sourceLanguage, project.targetLanguage)) return null;
    return proposed;
  }
}
