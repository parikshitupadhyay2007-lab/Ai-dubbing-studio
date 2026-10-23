import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/services/dialogue_quality_gate.dart';

void main() {
  test('accepts valid Hindi and English speech', () {
    expect(DialogueQualityGate.acceptable('मुझे घर जाना है।', 'hi'), isTrue);
    expect(DialogueQualityGate.acceptable('We should go home.', 'en'), isTrue);
  });
  test('rejects wrong-script output and control tokens', () {
    expect(DialogueQualityGate.acceptable('This is unchanged English.', 'hi'), isFalse);
    expect(DialogueQualityGate.acceptable('こんにちは', 'hi'), isFalse);
    expect(DialogueQualityGate.acceptable('こんにちは', 'en'), isFalse);
    expect(DialogueQualityGate.acceptable('assistant: hello', 'en'), isFalse);
    expect(DialogueQualityGate.acceptable('<|im_start|> hello', 'en'), isFalse);
  });
  test('rejects multiline or empty generated output', () {
    expect(DialogueQualityGate.acceptable('', 'en'), isFalse);
    expect(DialogueQualityGate.acceptable('One line\nAnother line', 'en'), isFalse);
  });
}
