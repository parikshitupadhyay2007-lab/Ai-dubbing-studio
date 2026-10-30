import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/dinov2_parity.dart';

void main() {
  const parity = Dinov2Parity();
  final input = 'a' * 64;
  final model = 'b' * 64;
  final expected = List<double>.filled(384, 0.5);
  test('same model and tensor pass bounded float parity', () {
    final actual = List<double>.filled(384, 0.50001);
    final result = parity.compare(reference: expected, android: actual,
      referenceModelSha256: model, androidModelSha256: model,
      referenceInputSha256: input, androidInputSha256: input);
    expect(result['passed'], true);
    expect(result['compared_dimensions'], 384);
    expect(result['semantic_recognition_verified'], false);
  });
  test('different model or input must not compare', () {
    final result = parity.compare(reference: expected, android: expected,
      referenceModelSha256: model, androidModelSha256: 'c' * 64,
      referenceInputSha256: input, androidInputSha256: input);
    expect(result['passed'], false);
    expect(result['reason'], 'model_or_input_mismatch');
  });
  test('large errors and nonfinite values fail closed', () {
    final divergent = List<double>.filled(384, 0.5)..[7] = 0.8;
    final result = parity.compare(reference: expected, android: divergent,
      referenceModelSha256: model, androidModelSha256: model,
      referenceInputSha256: input, androidInputSha256: input);
    expect(result['passed'], false);
    expect(result['failed_dimensions'], 1);
    expect(() => parity.compare(reference: expected,
      android: List<double>.filled(384, double.nan),
      referenceModelSha256: model, androidModelSha256: model,
      referenceInputSha256: input, androidInputSha256: input), throwsFormatException);
  });
}
