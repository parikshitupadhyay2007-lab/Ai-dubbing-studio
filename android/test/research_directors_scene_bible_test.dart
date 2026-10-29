import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/research_directors_scene_bible.dart';

void main() {
  const reviewer = ResearchDirectorsSceneBible();
  final sha = List.filled(64, 'a').join();
  test('draft is source bound and cannot be handed off', () {
    final draft = reviewer.draft(sourceSha256: sha, durationMs: 15000);
    expect(draft['approved'], false);
    expect(reviewer.review(draft)['passed'], false);
    expect(reviewer.fingerprint(draft).length, 64);
  });
  test('approval flag alone cannot certify missing inference', () {
    final draft = reviewer.draft(sourceSha256: sha, durationMs: 15000);
    draft['approved'] = true;
    expect(reviewer.review(draft)['passed'], false);
  });
  test('all independently reviewed fields and capabilities are required', () {
    final draft = reviewer.draft(sourceSha256: sha, durationMs: 15000);
    final capabilities = draft['capabilities'] as Map;
    for (final name in ResearchDirectorsSceneBible.additionalCapabilities) {
      capabilities[name] = {'state': 'verified',
        'independent_review': 'passed', 'evidence_ids': ['e1']};
    }
    final scene = <String, dynamic>{
      'scene_id': 's1', 'start_ms': 0, 'end_ms': 15000,
      'unresolved_conflicts': <String>[],
    };
    for (final name in ['narrative_context', 'dramatic_intent',
      'emotion_performance', 'dialogue_attribution', 'timing_constraints',
      'character_relationships']) {
      scene[name] = {'status': 'verified', 'evidence_ids': ['e1'],
        'review': 'passed'};
    }
    draft['scenes'] = [scene];
    draft['approved'] = true;
    expect(reviewer.review(draft)['passed'], true);
    scene['unresolved_conflicts'] = ['speaker identity disagreement'];
    expect(reviewer.review(draft)['passed'], false);
  });
}
