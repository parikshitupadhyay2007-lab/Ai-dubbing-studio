import 'research_continuity.dart';

/// Deterministic evidence reconciliation used by OtakuMind's continuity layer.
/// This is a verifier, not a substitute for the missing inference models.
class ContinuityEvidenceVerifier {
  const ContinuityEvidenceVerifier();

  Map<String, dynamic> verify({
    required int durationMs,
    required List<SceneEvidence> observations,
    required List<Map<String, dynamic>> identityClaims,
  }) {
    if (durationMs <= 0) throw const FormatException('Invalid source duration');
    final errors = <String>[];
    final ordered = [...observations]..sort((a, b) {
      final first = a.startMs.compareTo(b.startMs);
      return first != 0 ? first : a.endMs.compareTo(b.endMs);
    });
    for (final item in ordered) {
      if (item.startMs < 0 || item.endMs <= item.startMs ||
          item.endMs > durationMs || !item.confidence.isFinite ||
          item.confidence < 0 || item.confidence > 1 ||
          item.source.trim().isEmpty || item.description.trim().isEmpty ||
          item.kind.trim().isEmpty) errors.add('Invalid source-grounded observation');
    }
    final claims = <String, List<Map<String, dynamic>>>{};
    for (final claim in identityClaims) {
      final label = claim['identity'];
      final start = claim['start_ms'], end = claim['end_ms'];
      final evidence = claim['evidence_indices'];
      if (label is! String || label.trim().isEmpty || start is! int ||
          end is! int || start < 0 || end <= start || end > durationMs ||
          evidence is! List || evidence.isEmpty ||
          evidence.any((i) => i is! int || i < 0 || i >= observations.length)) {
        errors.add('Unattributed or invalid identity claim');
        continue;
      }
      final supporting = evidence.cast<int>().map((i) => observations[i]);
      if (!supporting.any((item) => item.startMs < end && item.endMs > start)) {
        errors.add('Identity evidence outside claimed interval');
      }
      final key = claim['track_id'];
      if (key is! String || key.trim().isEmpty) {
        errors.add('Missing identity track');
      } else {
        claims.putIfAbsent(key, () => []).add(claim);
      }
    }
    for (final track in claims.values) {
      final labels = track.map((claim) => claim['identity']).toSet();
      if (labels.length > 1) errors.add('Contradictory identity on recurring track');
    }
    return {
      'passed': errors.isEmpty,
      'errors': errors.toSet().toList(),
      'observation_count': observations.length,
      'identity_claim_count': identityClaims.length,
      'verified_identity': false,
      'requires_model_review': true,
    };
  }
}
