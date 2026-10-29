import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/research_engine_coordinator.dart';

void main() {
  const coordinator = ResearchEngineCoordinator();
  final source = 'a' * 64;
  final digest = 'b' * 64;
  Map<String, dynamic> completed() {
    var ledger = coordinator.initial(source);
    for (final name in ResearchEngineCoordinator.engines) {
      ledger = coordinator.record(ledger: ledger, engine: name,
        state: 'verified', sourceSha256: source,
        inputFingerprint: digest, outputFingerprint: digest,
        modelId: 'fixture-model-v1', evidenceIds: ['fixture_$name']);
    }
    return ledger;
  }

  test('initially only independent engines are runnable', () {
    final ledger = coordinator.initial(source);
    expect(coordinator.runnable(ledger),
      ['anime_recognition', 'scene_segmentation']);
    expect(coordinator.canRequestHandoff(ledger), false);
  });

  test('change invalidates dependent engines but preserves unrelated engines', () {
    var ledger = completed();
    expect(coordinator.canRequestHandoff(ledger), true);
    ledger = coordinator.record(ledger: ledger, engine: 'scene_segmentation',
      state: 'verified', sourceSha256: source,
      inputFingerprint: digest, outputFingerprint: 'c' * 64,
      modelId: 'fixture-model-v2', evidenceIds: ['revised_scene']);
    final records = ledger['engines'] as Map;
    expect((records['anime_recognition'] as Map)['state'], 'verified');
    expect((records['context_research'] as Map)['state'], 'verified');
    expect((records['visual_understanding'] as Map)['state'], 'stale');
    expect((records['character_recognition'] as Map)['state'], 'stale');
    expect((records['continuity_intelligence'] as Map)['state'], 'stale');
    expect(coordinator.canRequestHandoff(ledger), false);
    expect(coordinator.runnable(ledger), ['visual_understanding']);
  });

  test('bounded targeted reanalysis cannot silently approve handoff', () {
    var ledger = completed();
    ledger = coordinator.requestReanalysis(ledger, engine: 'anime_recognition',
      reason: 'Episode mismatch', evidenceIds: ['candidate_1']);
    expect(coordinator.canRequestHandoff(ledger), false);
    ledger = coordinator.requestReanalysis(ledger, engine: 'anime_recognition',
      reason: 'Episode mismatch', evidenceIds: ['candidate_1']);
    expect(() => coordinator.requestReanalysis(ledger,
      engine: 'anime_recognition', reason: 'Episode mismatch',
      evidenceIds: ['candidate_1']), throwsStateError);
  });

  test('rejects changed source and empty verified evidence', () {
    final ledger = coordinator.initial(source);
    expect(() => coordinator.record(ledger: ledger, engine: 'anime_recognition',
      state: 'verified', sourceSha256: 'c' * 64,
      inputFingerprint: digest, outputFingerprint: digest,
      modelId: 'model', evidenceIds: ['x']), throwsFormatException);
    expect(() => coordinator.record(ledger: ledger, engine: 'anime_recognition',
      state: 'verified', sourceSha256: source,
      inputFingerprint: digest, outputFingerprint: digest,
      modelId: 'model', evidenceIds: []), throwsFormatException);
  });
}
