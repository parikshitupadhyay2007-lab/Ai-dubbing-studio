import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/services/dialogue_quality_gate.dart';

void main() {
  test('reports actionable translation failure without exposing generated text', () {
    expect(DialogueQualityGate.rejectionReason(
      'Hello there', 'こんにちは', 'ja', 'hi',
    ), contains('Devanagari'));
    expect(DialogueQualityGate.rejectionReason(
      '<think>private model output', 'こんにちは', 'ja', 'en',
    ), contains('control tokens'));
    expect(DialogueQualityGate.rejectionReason(
      'We should go home.', 'We should go home.', 'en', 'hi',
    ), contains('unchanged source'));
    expect(DialogueQualityGate.rejectionReason(
      '', 'こんにちは', 'ja', 'hi',
    ), contains('empty dialogue'));
  });

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
  test('rejects reasoning leakage and repeated generated fragments', () {
    expect(DialogueQualityGate.acceptable('<think>reasoning</think> Hello', 'en'), isFalse);
    expect(DialogueQualityGate.acceptable('hello hello hello hello hello ', 'en'), isFalse);
  });
  test('rejects unchanged translations including restored checkpoints', () {
    expect(DialogueQualityGate.acceptableTranslation(
      'We should go home.', 'We should go home.', 'en', 'hi'), isFalse);
    expect(DialogueQualityGate.acceptableTranslation(
      'मुझे घर जाना है।', 'We should go home.', 'en', 'hi'), isTrue);
    expect(DialogueQualityGate.acceptableTranslation(
      'We should go home.', 'We should go home.', 'en', 'en'), isTrue);
    expect(DialogueQualityGate.acceptableTranslation(
      'We should go home.', 'We should go home.', 'en-US', 'hi-IN'), isFalse);
  });
  test('regional language codes obey the same script rules', () {
    expect(DialogueQualityGate.acceptable('Plain English output', 'hi-IN'), isFalse);
    expect(DialogueQualityGate.acceptable('मुझे घर जाना है।', 'hi_IN'), isTrue);
    expect(DialogueQualityGate.acceptable('こんにちは', 'en-US'), isFalse);
  });
  test('rejects multiline or empty generated output', () {
    expect(DialogueQualityGate.acceptable('', 'en'), isFalse);
    expect(DialogueQualityGate.acceptable('One line\nAnother line', 'en'), isFalse);
  });
}
