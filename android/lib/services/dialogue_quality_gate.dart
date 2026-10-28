/// Conservative checks for malformed offline language-model output.
class DialogueQualityGate {
  static final RegExp _devanagari = RegExp('[\u0900-\u097F]');
  static final RegExp _japanese = RegExp('[\u3040-\u30FF\u3400-\u9FFF]');
  static final RegExp _latin = RegExp('[A-Za-z]');

  static final RegExp _repeatedToken = RegExp(r'(.{4,40}?)\1{3,}', caseSensitive: false);

  /// High-precision revision guard, not a complete semantic equivalence test.
  /// Refuse changes in explicit numbers or polarity. Unknown semantic changes
  /// still require a separately validated multilingual verifier.
  static bool preservesRevisionAnchors(String previous, String candidate) {
    final numbers = RegExp(r'[0-9]+(?:[.,][0-9]+)*');
    List<String> quantities(String value) =>
        numbers.allMatches(value).map((m) => m.group(0)!).toList();
    if (quantities(previous).join('|') != quantities(candidate).join('|')) {
      return false;
    }
    final negatives = RegExp(
      '(?:^|\\\\W)(?:not|no|never|nothing|nobody|cannot)(?:$|\\\\W)|(?:नहीं|नही|मत)',
      caseSensitive: false,
    );
    bool hasNegation(String text) => negatives.hasMatch(text);
    if (hasNegation(previous) != hasNegation(candidate)) return false;
    return true;
  }

  /// Check both content and source-language provenance, including restored
  /// checkpoints. A prior untranslated line must never bypass validation.
  static bool acceptableTranslation(
    String value,
    String original,
    String sourceLanguage,
    String targetLanguage,
  ) {
    if (!acceptable(value, targetLanguage)) return false;
    final source = sourceLanguage.toLowerCase().split(RegExp('[-_]')).first;
    final target = targetLanguage.toLowerCase().split(RegExp('[-_]')).first;
    if (source.isNotEmpty && source != 'auto' && source != 'unknown' &&
        source != target && original.trim().length > 3 &&
        value.trim().toLowerCase() == original.trim().toLowerCase()) {
      return false;
    }
    return true;
  }

  /// Safe, actionable diagnostic. Never include generated model text in errors.
  static String rejectionReason(
    String value,
    String original,
    String sourceLanguage,
    String targetLanguage,
  ) {
    final text = value.trim();
    final lower = text.toLowerCase();
    final target = targetLanguage.toLowerCase().split(RegExp('[-_]')).first;
    final source = sourceLanguage.toLowerCase().split(RegExp('[-_]')).first;
    if (text.isEmpty) return 'model returned empty dialogue';
    if (text.length > 900) return 'generated dialogue exceeds length limit';
    if (text.contains('\\n')) return 'model returned multiple lines';
    if (text.contains('```') || lower.contains('<|') ||
        lower.contains('<think') || lower.contains('</think') ||
        lower.contains('im_start') || lower.contains('im_end') ||
        lower.contains('[inst]') || lower.contains('[/inst]')) {
      return 'model returned reasoning or control tokens';
    }
    if (_repeatedToken.hasMatch(text)) return 'model repeated generated text';
    if (lower.startsWith('assistant:') || lower.startsWith('translation:') ||
        lower.startsWith('refined dialogue:') || lower.startsWith('response:')) {
      return 'model returned a response label instead of dialogue';
    }
    if (source.isNotEmpty && source != 'auto' && source != 'unknown' &&
        source != target && original.trim().length > 3 &&
        text.toLowerCase() == original.trim().toLowerCase()) {
      return 'model returned the unchanged source instead of a translation';
    }
    if (target == 'hi' && _japanese.hasMatch(text) ||
        target == 'en' && _japanese.hasMatch(text)) {
      return 'Japanese script remains in target-language dialogue';
    }
    if (target == 'hi' && !_devanagari.hasMatch(text) &&
        _latin.allMatches(text).length > 3) {
      return 'Hindi dialogue contains no Devanagari speech';
    }
    return 'dialogue did not pass target-language validation';
  }

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
    final target = targetLanguage.toLowerCase().split('-').first.split('_').first;
    if (target == 'hi') {
      if (_japanese.hasMatch(text)) return false;
      if (!_devanagari.hasMatch(text) &&
          _latin.allMatches(text).length > 3) return false;
    } else if (target == 'en' && _japanese.hasMatch(text)) {
      return false;
    }
    return true;
  }
}
