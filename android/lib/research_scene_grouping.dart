import 'dart:math' as math;

/// Groups visual observations into candidate scenes using measured embeddings
/// and native cut signals. This is a proposal, not certified scene semantics.
class ResearchSceneGrouping {
  const ResearchSceneGrouping();

  Map<String, dynamic> propose({
    required int durationMs,
    required List<Map<String, dynamic>> frames,
    double cutThreshold = 0.30,
    double semanticDistanceThreshold = 0.38,
    int minimumSceneMs = 1500,
  }) {
    if (durationMs <= 0 || frames.length < 2 || frames.length > 7200 ||
        !cutThreshold.isFinite || cutThreshold < 0 || cutThreshold > 1 ||
        !semanticDistanceThreshold.isFinite ||
        semanticDistanceThreshold < 0 || semanticDistanceThreshold > 2 ||
        minimumSceneMs < 0) {
      throw const FormatException('Invalid scene grouping configuration');
    }
    final parsed = <({int timestamp, double cut, List<double> embedding})>[];
    var previousTime = -1;
    int? dimension;
    for (final frame in frames) {
      final time = frame['timestamp_ms'], cut = frame['cut_score'];
      final raw = frame['embedding'];
      if (time is! int || time <= previousTime || time >= durationMs ||
          cut is! num || !cut.isFinite || cut < 0 || cut > 1 ||
          raw is! List || raw.isEmpty || raw.length > 4096 ||
          (dimension != null && raw.length != dimension) ||
          raw.any((v) => v is! num || !v.isFinite)) {
        throw const FormatException('Invalid chronological visual observations');
      }
      final values = raw.cast<num>().map((v) => v.toDouble()).toList();
      final norm = math.sqrt(values.fold<double>(0, (s, v) => s + v * v));
      if (!norm.isFinite || norm < 1e-12) {
        throw const FormatException('Degenerate scene embedding');
      }
      parsed.add((timestamp: time, cut: cut.toDouble(),
        embedding: values.map((v) => v / norm).toList()));
      dimension = values.length;
      previousTime = time;
    }
    double distance(List<double> a, List<double> b) {
      var dot = 0.0;
      for (var i = 0; i < a.length; i++) { dot += a[i] * b[i]; }
      return 1 - dot.clamp(-1.0, 1.0);
    }
    final candidates = <Map<String, dynamic>>[];
    var sceneStart = 0;
    var anchor = parsed.first.embedding;
    for (var i = 1; i < parsed.length; i++) {
      final current = parsed[i];
      final semantic = distance(anchor, current.embedding);
      final adjacent = distance(parsed[i - 1].embedding, current.embedding);
      final joint = current.cut >= cutThreshold &&
          semantic >= semanticDistanceThreshold &&
          adjacent >= semanticDistanceThreshold;
      if (!joint || current.timestamp - sceneStart < minimumSceneMs) continue;
      candidates.add({
        'start_ms': sceneStart, 'end_ms': current.timestamp,
        'boundary_ms': current.timestamp, 'cut_score': current.cut,
        'anchor_cosine_distance': semantic,
        'adjacent_cosine_distance': adjacent,
        'verified_scene': false,
      });
      sceneStart = current.timestamp;
      anchor = current.embedding;
    }
    candidates.add({
      'start_ms': sceneStart, 'end_ms': durationMs,
      'boundary_ms': null, 'verified_scene': false,
    });
    return {
      'method': 'visual_cut_and_embedding_joint_candidates_v1',
      'source_frame_count': frames.length,
      'embedding_dimension': dimension,
      'scenes': candidates,
      'semantic_scene_segmentation_verified': false,
      'requires_independent_review': true,
    };
  }
}
