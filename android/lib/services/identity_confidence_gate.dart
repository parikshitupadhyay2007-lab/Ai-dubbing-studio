import '../models/dub_project.dart';

/// Separates acoustic identity readiness from named-character recognition.
/// Scene suggestions alone never resolve an unknown audible speaker.
class IdentityConfidenceGate {
  const IdentityConfidenceGate();

  List<DubSegment> unresolved(DubProject project) => project.segments.where((s) =>
      s.speakerId.trim().isEmpty || s.speakerId.trim() == 'unknown' ||
      !s.speakerConfidence.isFinite ||
      (s.speakerConfidence <= 0 &&
          !(s.speakerManuallyVerified && s.speakerConfidence == 0))).toList();

  bool readyForSynthesis(DubProject project) {
    if (project.segments.isEmpty || unresolved(project).isNotEmpty) return false;
    return project.segments.every((s) =>
        s.voiceId.trim().isNotEmpty &&
        project.characterVoices[s.speakerId] == s.voiceId);
  }

  /// An unknown character name is acceptable when the acoustic speaker and
  /// its voice remain stable; it is not evidence of a named anime character.
  bool hasStableProvisionalVoice(DubProject project, String speakerId) =>
      speakerId.trim().isNotEmpty && speakerId != 'unknown' &&
      project.characterVoices[speakerId] != null &&
      project.segments.where((s) => s.speakerId == speakerId).every((s) =>
          s.voiceId == project.characterVoices[speakerId]);
}
