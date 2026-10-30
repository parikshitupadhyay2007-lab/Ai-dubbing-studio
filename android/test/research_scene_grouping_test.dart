import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/research_scene_grouping.dart';

void main() {
  const grouping = ResearchSceneGrouping();
  Map<String, dynamic> frame(int t, double cut, List<double> vector) => {
    'timestamp_ms': t, 'cut_score': cut, 'embedding': vector,
  };
  test('a cut alone does not establish a scene boundary', () {
    final result = grouping.propose(durationMs: 5000, frames: [
      frame(0, 0, [1, 0]), frame(2000, 0.9, [1, 0]),
      frame(4000, 0, [1, 0]),
    ]);
    expect((result['scenes'] as List).length, 1);
    expect(result['semantic_scene_segmentation_verified'], false);
  });
  test('joint cut and measured embedding discontinuity propose boundary', () {
    final result = grouping.propose(durationMs: 6000, frames: [
      frame(0, 0, [1, 0]), frame(2000, 0.9, [0, 1]),
      frame(4000, 0, [0, 1]),
    ]);
    final scenes = result['scenes'] as List;
    expect(scenes.length, 2);
    expect((scenes.first as Map)['end_ms'], 2000);
    expect((scenes.last as Map)['start_ms'], 2000);
    expect((scenes.last as Map)['end_ms'], 6000);
    expect((scenes.first as Map)['verified_scene'], false);
  });
  test('rejects disorder, invalid scores and degenerate vectors', () {
    expect(() => grouping.propose(durationMs: 6000, frames: [
      frame(0, 0, [1, 0]), frame(0, 0.9, [0, 1]),
    ]), throwsFormatException);
    expect(() => grouping.propose(durationMs: 6000, frames: [
      frame(0, 0, [1, 0]), frame(2000, 0.9, [0, 0]),
    ]), throwsFormatException);
    expect(() => grouping.propose(durationMs: 6000, frames: [
      frame(0, 0, [1, 0]), frame(2000, 1.5, [0, 1]),
    ]), throwsFormatException);
  });
}
