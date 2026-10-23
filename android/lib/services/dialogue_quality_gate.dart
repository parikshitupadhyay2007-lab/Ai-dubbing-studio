import '../models/dub_project.dart';

/// Rejects obvious model-control text and wrong-script outputs before TTS.
/// This is a conservative guard, not a substitute for translation evaluation.
class DialogueQualityGate {
  static final _control = RegExp(
    r'(<\\|im_start|im_end|\\[INST\\]|\\[/INST\\]|</?s>|'
    r'^(assistant|translation|refined dialogue|output|response)\\s*:)',
    caseSensitive: false,
  );
  static final _devanagari = RegExp(r'[\u0900-\u097F]');
  static final _japanese = RegExp(r'[\u3040-\u30FF\u3400-\u9FFF]');

  static bool acceptable(String value, String targetLanguage) {
    final text = value.trim();
    if (text.isEmpty || text.length > 900 || _control.hasMatch(text)) {
      return false;
    }
    if (text.contains('\n') || text.contains('\\`\\`\\`')) return false;
    if (targetLanguage == 'hi') {
      // Spoken Hindi should be Hindi-script output, not unchanged Japanese
      // or English hallucinations. Permit short nonverbal interjections.
      if (_japanese.hasMatch(text)) return false;
      if (!_devanagari.hasMatch(text) &&
          RegExp(r'[A-Za-z]').allMatches(text).length > 3) return false;
    } else if (targetLanguage == 'en' && _japanese.hasMatch(text)) {
      return false;
    }
    return true;
  }

  static bool preservesIdentity(DubSegment before, DubSegment after) =>
      before.id == after.id &&
      before.original == after.original &&
      before.speakerId == after.speakerId &&
      (before.start - after.start).abs() <= 0.001 &&
      (before.end - after.end).abs() <= 0.001;
}
