/// Structured output contract for a future native active-speaker model.
/// Frame hashes alone are scene retrieval, never lip synchronization evidence.
class VisualSpeakerEvidence {
  final int segmentId;
  final String trackId;
  final double startSeconds;
  final double endSeconds;
  final double lipSyncScore;
  final double competingTrackScore;
  final String modelId;
  final String sourceHash;

  const VisualSpeakerEvidence({
    required this.segmentId, required this.trackId,
    required this.startSeconds, required this.endSeconds,
    required this.lipSyncScore, required this.competingTrackScore,
    required this.modelId, required this.sourceHash,
  });

  bool get structurallyValid =>
      segmentId >= 0 && trackId.trim().isNotEmpty &&
      startSeconds.isFinite && endSeconds.isFinite &&
      endSeconds > startSeconds && startSeconds >= 0 &&
      lipSyncScore.isFinite && competingTrackScore.isFinite &&
      lipSyncScore >= 0 && lipSyncScore <= 1 &&
      competingTrackScore >= 0 && competingTrackScore <= 1 &&
      modelId.trim().isNotEmpty && sourceHash.trim().isNotEmpty;

  /// Conservative proposal gate; it is not proof of a named character.
  bool get unambiguousCandidate => structurallyValid &&
      lipSyncScore >= 0.85 && lipSyncScore - competingTrackScore >= 0.20;

  factory VisualSpeakerEvidence.fromJson(Map<String, dynamic> json) =>
      VisualSpeakerEvidence(
        segmentId: (json['segment_id'] as num).toInt(),
        trackId: json['track_id'] as String,
        startSeconds: (json['start'] as num).toDouble(),
        endSeconds: (json['end'] as num).toDouble(),
        lipSyncScore: (json['lip_sync_score'] as num).toDouble(),
        competingTrackScore: (json['competing_track_score'] as num).toDouble(),
        modelId: json['model_id'] as String,
        sourceHash: json['source_hash'] as String,
      );
}
