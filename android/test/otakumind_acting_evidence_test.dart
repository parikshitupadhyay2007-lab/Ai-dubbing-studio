import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/services/otakumind_acting_evidence.dart';

void main() {
  ActingEvidence evidence({String visual = 'visual-model', double confidence = 0.95}) =>
      ActingEvidence(segmentId: 1, acousticSourceId: 'acoustic-model',
        visualSourceId: visual, dialogueSourceId: 'script-source',
        delivery: 'tense', acousticConfidence: confidence,
        visualConfidence: confidence, dialogueConfidence: confidence);
  test('accepts independently corroborated acting intent', () {
    expect(const OtakuMindActingDirector().deliveryFor(evidence()), 'tense');
  });
  test('defaults to natural on missing or weak evidence', () {
    const director = OtakuMindActingDirector();
    expect(director.deliveryFor(null), 'natural');
    expect(director.deliveryFor(evidence(confidence: 0.4)), 'natural');
    expect(director.deliveryFor(evidence(visual: 'acoustic-model')), 'natural');
  });
}
