import '../models/dub_project.dart';

/// A retrieved reference is evidence, never an automatic replacement for ASR.
/// The provider must independently establish provenance and usage rights.
class OriginalScriptReference {
  final String sourceId, animeId, episodeId;
  final List<String> lines;
  final List<int> segmentIds;
  const OriginalScriptReference({required this.sourceId, required this.animeId,
    required this.episodeId, required this.lines, required this.segmentIds});
}

class ScriptVerification {
  final bool accepted;
  final String reason;
  final Map<int, String> verifiedLines;
  const ScriptVerification(this.accepted, this.reason, this.verifiedLines);
}

class OtakuMindScriptVerifier {
  const OtakuMindScriptVerifier();

  String _normalize(String text) => text.toLowerCase().replaceAll(
      RegExp(r'[\s.,!?;:「」『』。、！？…—–()\[\]-]+'), '');

  /// Exact normalized agreement is deliberately conservative: a generic
  /// metadata hit or a paraphrase cannot replace the user's source dialogue.
  ScriptVerification verify(List<DubSegment> transcription,
      OriginalScriptReference reference) {
    if (reference.sourceId.trim().isEmpty || reference.animeId.trim().isEmpty ||
        reference.episodeId.trim().isEmpty) {
      return const ScriptVerification(false, 'missing_provenance', {});
    }
    if (transcription.isEmpty || reference.lines.length != transcription.length ||
        reference.segmentIds.length != transcription.length ||
        reference.segmentIds.toSet().length != transcription.length) {
      return const ScriptVerification(false, 'segment_alignment_mismatch', {});
    }
    final verified = <int, String>{};
    for (var i = 0; i < transcription.length; i++) {
      final source = transcription[i];
      final candidate = reference.lines[i].trim();
      if (reference.segmentIds[i] != source.id || candidate.isEmpty ||
          _normalize(candidate).length < 8 ||
          _normalize(candidate) != _normalize(source.original)) {
        return const ScriptVerification(false, 'dialogue_not_corroborated', {});
      }
      verified[source.id] = candidate;
    }
    return ScriptVerification(true, 'verified_against_local_transcription',
        Map<int, String>.unmodifiable(verified));
  }
}
