/// Conservative checks for malformed offline language-model output.
class DialogueQualityGate {
  static final RegExp _control = RegExp(
    r'<\\|im_start|im_end|\\[INST\\]|\\[/INST\\]|</?s>|^(assistant|translation|refined dialogue|output|response)\\s*:',
    caseSensitive: false,
  );
  static final RegExp _devanagari = RegExp('[\u0900-\u097F]');
  static final RegExp _japanese = RegExp('[\u3040-\u30FF\u3400-\u9FFF]');

  static bool acceptable(String value, String targetLanguage) {
    final text = value.trim();
    if (text.isEmpty || text.length > 900 || _control.hasMatch(text) ||
        text.contains('\n') || text.contains('```')) {
      return false;
    }
    if (targetLanguage == 'hi') {
      if (_japanese.hasMatch(text)) return false;
      if (!_devanagari.hasMatch(text) &&
          RegExp(r'[A-Za-z]').allMatches(text).length > 3) return false;
    } else if (targetLanguage == 'en' && _japanese.hasMatch(text)) {
      return false;
    }
    return true;
  }
}
