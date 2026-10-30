import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/research_person_proposals.dart';

void main() {
  test('decodes pretrained DETR person class without inventing character identity', () {
    final logits = List<double>.filled(100 * 92, -20);
    final boxes = List<double>.filled(100 * 4, 0.5);
    logits[1] = 15;
    final proposals = const ResearchPersonProposals().decode(
      logits: logits, boxes: boxes);
    expect(proposals.length, 1);
    expect(proposals.single['class'], 'person');
    expect(proposals.single['query_id'], 0);
    expect(proposals.single['character_id'], isNull);
    expect(proposals.single['verified_anime_character'], false);
    expect(proposals.single['box_xyxy_normalized'], [0.25, 0.25, 0.75, 0.75]);
  });
  test('rejects unsupported tensor sizes and excludes nonperson proposals', () {
    final logits = List<double>.filled(100 * 92, -20);
    final boxes = List<double>.filled(100 * 4, 0.5);
    logits[0] = 15;
    expect(const ResearchPersonProposals().decode(
      logits: logits, boxes: boxes), isEmpty);
    expect(() => const ResearchPersonProposals().decode(
      logits: [0], boxes: boxes), throwsFormatException);
  });
}
