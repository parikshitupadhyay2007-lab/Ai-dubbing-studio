import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Explicit execution states. A successful helper or metadata lookup is not
/// equivalent to verified model inference.
class ResearchEngineCoordinator {
  const ResearchEngineCoordinator();
  static const engines = <String>[
    'anime_recognition', 'scene_segmentation', 'visual_understanding',
    'character_recognition', 'context_research', 'continuity_intelligence',
  ];
  static const dependencies = <String, List<String>>{
    'anime_recognition': [],
    'scene_segmentation': [],
    'visual_understanding': ['scene_segmentation'],
    'context_research': ['anime_recognition'],
    'character_recognition': ['scene_segmentation', 'visual_understanding'],
    'continuity_intelligence': [
      'anime_recognition', 'scene_segmentation', 'visual_understanding',
      'character_recognition', 'context_research',
    ],
  };
  static const validStates = <String>{
    'unavailable', 'blocked', 'running', 'provisional', 'verified', 'failed',
    'stale',
  };

  Map<String, dynamic> initial(String sourceSha256) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sourceSha256)) {
      throw const FormatException('Invalid source SHA256');
    }
    return {
      'schema': 1, 'source_sha256': sourceSha256, 'revision': 0,
      'engines': {
        for (final name in engines) name: {
          'state': 'unavailable', 'revision': 0, 'input_fingerprint': null,
          'output_fingerprint': null, 'model_id': null, 'evidence_ids': <String>[],
        },
      },
      'reanalysis_requests': <Map<String, dynamic>>[],
      'handoff_ready': false,
    };
  }

  String fingerprint(Object value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();

  /// A change invalidates every transitive consumer, not unrelated findings.
  /// The update records evidence, but cannot itself attest model correctness.
  Map<String, dynamic> record({
    required Map<String, dynamic> ledger,
    required String engine,
    required String state,
    required String sourceSha256,
    required String inputFingerprint,
    required String outputFingerprint,
    required String modelId,
    required List<String> evidenceIds,
  }) {
    validate(ledger);
    if (!engines.contains(engine) || !validStates.contains(state) ||
        state == 'stale' || state == 'blocked' ||
        ledger['source_sha256'] != sourceSha256 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(inputFingerprint) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(outputFingerprint) ||
        modelId.trim().isEmpty || evidenceIds.any((e) => e.trim().isEmpty) ||
        (state == 'verified' && evidenceIds.isEmpty)) {
      throw const FormatException('Invalid engine execution record');
    }
    final next = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
    final records = next['engines'] as Map<String, dynamic>;
    final current = records[engine] as Map<String, dynamic>;
    final changed = current['input_fingerprint'] != inputFingerprint ||
        current['output_fingerprint'] != outputFingerprint ||
        current['model_id'] != modelId || current['state'] != state ||
        jsonEncode(current['evidence_ids']) != jsonEncode(evidenceIds);
    if (!changed) return next;
    final revision = (next['revision'] as int) + 1;
    next['revision'] = revision;
    records[engine] = {
      'state': state, 'revision': revision,
      'input_fingerprint': inputFingerprint,
      'output_fingerprint': outputFingerprint,
      'model_id': modelId, 'evidence_ids': evidenceIds,
    };
    final invalidated = <String>{engine};
    var advanced = true;
    while (advanced) {
      advanced = false;
      for (final name in engines) {
        if (invalidated.contains(name)) continue;
        if (dependencies[name]!.any(invalidated.contains)) {
          invalidated.add(name);
          records[name] = {...records[name] as Map<String, dynamic>,
            'state': 'stale', 'revision': revision};
          advanced = true;
        }
      }
    }
    next['handoff_ready'] = false;
    return next;
  }

  /// A reviewer or detector may request a bounded, targeted retry.
  Map<String, dynamic> requestReanalysis(Map<String, dynamic> ledger, {
    required String engine, required String reason,
    required List<String> evidenceIds, int maxAttempts = 2,
  }) {
    validate(ledger);
    if (!engines.contains(engine) || reason.trim().isEmpty ||
        evidenceIds.isEmpty || maxAttempts < 1 || maxAttempts > 5) {
      throw const FormatException('Invalid reanalysis request');
    }
    final next = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
    final requests = next['reanalysis_requests'] as List;
    final previous = requests.where((r) => r['engine'] == engine &&
        r['reason'] == reason).length;
    if (previous >= maxAttempts) {
      throw StateError('Reanalysis attempt limit reached: $engine');
    }
    requests.add({'engine': engine, 'reason': reason,
      'evidence_ids': evidenceIds, 'attempt': previous + 1,
      'source_revision': ledger['revision'], 'status': 'pending'});
    final records = next['engines'] as Map<String, dynamic>;
    final revision = (next['revision'] as int) + 1;
    final invalidated = <String>{engine};
    var advanced = true;
    while (advanced) {
      advanced = false;
      for (final name in engines) {
        if (invalidated.contains(name)) continue;
        if (dependencies[name]!.any(invalidated.contains)) {
          invalidated.add(name);
          advanced = true;
        }
      }
    }
    for (final name in invalidated) {
      records[name] = {...records[name] as Map<String, dynamic>,
        'state': 'stale', 'revision': revision};
    }
    next['revision'] = revision;
    next['handoff_ready'] = false;
    return next;
  }

  List<String> runnable(Map<String, dynamic> ledger) {
    validate(ledger);
    final records = ledger['engines'] as Map;
    return engines.where((name) {
      final state = (records[name] as Map)['state'];
      return (state == 'unavailable' || state == 'stale' ||
          state == 'failed' || state == 'blocked') &&
          dependencies[name]!.every((dependency) =>
            (records[dependency] as Map)['state'] == 'verified');
    }).toList();
  }

  bool canRequestHandoff(Map<String, dynamic> ledger) {
    validate(ledger);
    final records = ledger['engines'] as Map;
    return engines.every((name) => (records[name] as Map)['state'] == 'verified') &&
      (ledger['reanalysis_requests'] as List).every((r) => r['status'] == 'resolved');
  }

  void validate(Map<String, dynamic> ledger) {
    if (ledger['schema'] != 1 ||
        ledger['source_sha256'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(ledger['source_sha256'] as String) ||
        ledger['revision'] is! int || (ledger['revision'] as int) < 0 ||
        ledger['engines'] is! Map || ledger['reanalysis_requests'] is! List ||
        ledger['handoff_ready'] is! bool) {
      throw const FormatException('Malformed coordination ledger');
    }
    final records = ledger['engines'] as Map;
    if (records.length != engines.length) {
      throw const FormatException('Missing or unexpected engine');
    }
    for (final engine in engines) {
      final record = records[engine];
      if (record is! Map || !validStates.contains(record['state']) ||
          record['revision'] is! int ||
          record['revision'] < 0 || record['revision'] > ledger['revision'] ||
          record['evidence_ids'] is! List) {
        throw FormatException('Malformed engine record: $engine');
      }
    }
    for (final request in ledger['reanalysis_requests'] as List) {
      if (request is! Map || !engines.contains(request['engine']) ||
          !{'pending', 'resolved', 'failed'}.contains(request['status']) ||
          request['attempt'] is! int || request['attempt'] < 1) {
        throw const FormatException('Malformed reanalysis request');
      }
    }
  }
}
