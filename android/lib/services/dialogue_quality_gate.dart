/// Conservative checks for malformed offline language-model output.
class DialogueQualityGate {
  static final RegExp _devanagari = RegExp('[\u0900-\u097F]');
  static final RegExp _japanese = RegExp('[\u3040-\u30FF\u3400-\u9FFF]');
  static final RegExp _latin = RegExp('[A-Za-z]');

  static final RegExp _repeatedToken = RegExp(r'(.{4,40}?)\\1{3,}', caseSensitive: false);

  static bool acceptable(String value, String targetLanguage) {
    final text = value.trim();
    final lower = text.toLowerCase();
    if (text.isEmpty || text.length > 900 || text.contains('\n') ||
        text.contains('```') || lower.contains('im_start') ||
        lower.contains('im_end') || lower.contains('[inst]') ||
        lower.contains('[/inst]') || lower.contains('<|') ||
        lower.contains('<think') || lower.contains('</think') ||
        _repeatedToken.hasMatch(text) ||
        lower.startsWith('assistant:') || lower.startsWith('translation:') ||
        lower.startsWith('refined dialogue:') || lower.startsWith('response:')) {
      return false;
    }
    if (targetLanguage == 'hi') {
      if (_japanese.hasMatch(text)) return false;
      if (!_devanagari.hasMatch(text) &&
          _latin.allMatches(text).length > 3) return false;
    } else if (targetLanguage == 'en' && _japanese.hasMatch(text)) {
      return false;
    }
    return true;
  }
}
