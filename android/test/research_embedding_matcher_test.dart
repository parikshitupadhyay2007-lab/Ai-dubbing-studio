import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/research_embedding_matcher.dart';

void main() {
  const matcher = ResearchEmbeddingMatcher();
  test('ranks reference embeddings but never asserts verified identity', () {
    final result = matcher.rank(query: [1, 0, 0], references: {
      'reference_A': [1, 0, 0], 'reference_B': [0, 1, 0]});
    expect((result['candidates'] as List).first['reference_id'], 'reference_A');
    expect(result['status'], 'candidate_requires_independent_review');
    expect(result['verified_identity'], false);
    expect(result['calibrated_confidence'], false);
  });
  test('rejects unknown and near-tie references', () {
    final result = matcher.rank(query: [1, 0], references: {
      'A': [1, 0], 'B': [1, 0.01]});
    expect(result['status'], 'ambiguous_or_unknown');
  });
  test('rejects incompatible, zero or nonfinite embeddings', () {
    expect(() => matcher.rank(query: [1, 0], references: {'A': [1]}),
      throwsFormatException);
    expect(() => matcher.rank(query: [0, 0], references: {'A': [1, 0]}),
      throwsFormatException);
    expect(() => matcher.rank(query: [1, double.nan],
      references: {'A': [1, 0]}), throwsFormatException);
  });
}
