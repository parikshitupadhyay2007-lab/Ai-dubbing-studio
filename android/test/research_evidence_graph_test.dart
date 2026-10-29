import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/research_evidence_graph.dart';

void main() {
  const graph = ResearchEvidenceGraph();
  final hash = 'a' * 64;
  Map<String, dynamic> node(String id) => {
    'id': id, 'modality': 'visual', 'start_ms': 0, 'end_ms': 1000,
    'confidence': .8, 'provenance': 'decoded frame', 'observation': 'candidate',
    'verified': false,
  };
  test('source-bound graph can independently detect altered observations', () {
    final built = graph.build(sourceSha256: hash, durationMs: 2000,
      nodes: [node('shot_1')], links: []);
    expect(graph.validate(built), true);
    final edited = {...built, 'nodes': [ {...node('shot_1'), 'observation': 'forged'} ]};
    expect(graph.validate(edited), false);
  });
  test('rejects unsupported edges and duplicated node IDs', () {
    expect(() => graph.build(sourceSha256: hash, durationMs: 2000,
      nodes: [node('same'), node('same')], links: []), throwsFormatException);
    expect(() => graph.build(sourceSha256: hash, durationMs: 2000,
      nodes: [node('shot_1')], links: [
        {'from': 'shot_1', 'to': 'missing', 'relation': 'supports'}
      ]), throwsFormatException);
  });
  test('rejects preapproved, ungrounded and out-of-range evidence', () {
    expect(() => graph.build(sourceSha256: hash, durationMs: 2000,
      nodes: [{...node('shot_1'), 'verified': true}], links: []),
      throwsFormatException);
    expect(() => graph.build(sourceSha256: hash, durationMs: 2000,
      nodes: [{...node('shot_1'), 'end_ms': 3000}], links: []),
      throwsFormatException);
    expect(() => graph.build(sourceSha256: hash, durationMs: 2000,
      nodes: [{...node('shot_1'), 'provenance': ''}], links: []),
      throwsFormatException);
  });
}
