import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/models/dub_project.dart';
import 'package:ai_dubbing_studio/services/dialogue_alignment_gate.dart';

void main() {
  const gate = DialogueAlignmentGate();
  final a = DubSegment(id: 1, start: 1, end: 2, original: 'One');
  final b = DubSegment(id: 2, start: 2.5, end: 3.2, original: 'Two');
  test('accepts measured speech within bounded fit', () {
    expect(gate.rejection(segment: a, speechSeconds: 1.2,
        timeline: [a, b]), isNull);
  });
  test('rejects excessive speech without truncating the line', () {
    expect(gate.rejection(segment: a, speechSeconds: 1.8,
        timeline: [a, b]), 'speech_exceeds_safe_fit');
  });
  test('rejects overlap of next line after extended synthesis', () {
    a.synthesisEnd = 2.44;
    expect(gate.rejection(segment: a, speechSeconds: 1.1,
        timeline: [a, b]), 'overlaps_next_dialogue');
    a.synthesisEnd = null;
  });
  test('rejects unsupported visual timing claims', () {
    expect(gate.rejection(segment: a, speechSeconds: 1,
        timeline: [a, b], measuredMouthStart: 1.5,
        measuredMouthEnd: 2), 'visual_timing_mismatch');
    expect(gate.rejection(segment: a, speechSeconds: 1,
        timeline: [a, b], measuredMouthStart: 1.0),
        'incomplete_visual_measurement');
  });
}
