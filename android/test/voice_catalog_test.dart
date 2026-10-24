import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/services/voice_catalog.dart';

void main() {
  test('Hindi and English voice profiles have unique stable IDs', () {
    final ids = VoiceCatalog.profiles.map((voice) => voice.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final language in ['hi', 'en']) {
      final voices = VoiceCatalog.forLanguage(language);
      expect(voices.length, 12);
      expect(voices.every((voice) => voice.language == language), isTrue);
      expect(voices.where((voice) => voice.role == VoiceRole.male).length,
          language == 'en' ? 5 : 6);
      expect(voices.where((voice) => voice.role == VoiceRole.female).length,
          language == 'en' ? 5 : 4);
      expect(voices.where((voice) => voice.role == VoiceRole.youthful).length, 2);
      expect(voices.every((voice) => voice.id.startsWith('${language}_')), isTrue);
    }
  });

  test('bundled Lessac is not misidentified as a male character voice', () {
    expect(VoiceCatalog.byId('en_hero').role, VoiceRole.female);
  });

  test('every bundled profile has role-compatible Supertonic style', () {
    for (final language in ['hi', 'en']) {
      final voices = VoiceCatalog.available(language);
      expect(voices.length, 12);
      for (final voice in voices) {
        final style = VoiceCatalog.supertonicStyle(voice.id);
        expect(style, isNotNull, reason: voice.id);
        if (voice.role == VoiceRole.male) {
          expect(style!.startsWith('M'), isTrue, reason: voice.id);
        } else {
          expect(style!.startsWith('F'), isTrue, reason: voice.id);
        }
      }
    }
    expect(VoiceCatalog.supertonicStyle('en_hero'), 'F1');
    expect(VoiceCatalog.supertonicStyle('en_young_male'), 'M2');
  });

  test('unknown voice ID is rejected rather than silently substituted', () {
    expect(() => VoiceCatalog.byId('nonexistent_voice'), throwsArgumentError);
  });
}
