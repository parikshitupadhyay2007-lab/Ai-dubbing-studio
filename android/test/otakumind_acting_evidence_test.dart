import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/services/otakumind_acting_evidence.dart';
import 'package:ai_dubbing_studio/models/dub_project.dart';

void main() {
  ActingEvidence evidence({String visual = 'visual-model', double confidence = 0.95}) =>
      ActingEvidence(segmentId: 1, acousticSourceId: 'acoustic-model',
        visualSourceId: visual, dialogueSourceId: 'script-source',
        delivery: 'urgent', acousticConfidence: confidence,
        visualConfidence: confidence, dialogueConfidence: confidence);
  test('accepts independently corroborated acting intent', () {
    expect(const OtakuMindActingDirector().deliveryFor(evidence()), 'urgent');
  });
  test('applies acting direction to matching segment only', () {
    final segment = DubSegment(id: 1, start: 0, end: 2, original: 'Source');
    const director = OtakuMindActingDirector();
    director.direct(segment, evidence());
    expect(segment.delivery, 'urgent');
    director.direct(segment, null);
    expect(segment.delivery, 'natural');
  });
  test('defaults to natural on missing or weak evidence', () {
    const director = OtakuMindActingDirector();
    expect(director.deliveryFor(null), 'natural');
    expect(director.deliveryFor(evidence(confidence: 0.4)), 'natural');
    expect(director.deliveryFor(evidence(visual: 'acoustic-model')), 'natural');
  });
}
