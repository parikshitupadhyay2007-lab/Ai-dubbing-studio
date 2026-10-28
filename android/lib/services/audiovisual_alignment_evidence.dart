/// Output of a validated native audiovisual alignment model.
/// This is measured evidence, not scene fingerprint similarity or an LLM guess.
class AudiovisualAlignmentEvidence {
  final int segmentId;
  final String sourceHash, modelId, modelHash, clipHash;
  final double mouthStart, mouthEnd, syncScore;
  final bool modelVerified;
  const AudiovisualAlignmentEvidence({
    required this.segmentId, required this.sourceHash,
    required this.modelId, required this.modelHash, required this.clipHash,
    required this.mouthStart, required this.mouthEnd,
    required this.syncScore, required this.modelVerified,
  });

  factory AudiovisualAlignmentEvidence.fromJson(Map<String, dynamic> row) =>
      AudiovisualAlignmentEvidence(
        segmentId: row['segment_id'] as int,
        sourceHash: row['source_sha256'] as String,
        modelId: row['model_id'] as String,
        modelHash: row['model_sha256'] as String,
        clipHash: row['clip_sha256'] as String,
        mouthStart: (row['mouth_start_seconds'] as num).toDouble(),
        mouthEnd: (row['mouth_end_seconds'] as num).toDouble(),
        syncScore: (row['sync_score'] as num).toDouble(),
        modelVerified: row['model_verified'] == true,
      );

  static bool _digest(String s) => RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(s);

  bool validFor({required int id, required String sourceSha256,
      required String clipSha256}) =>
      segmentId == id && modelVerified && modelId.trim().isNotEmpty &&
      _digest(sourceHash) && _digest(modelHash) && _digest(clipHash) &&
      sourceHash.toLowerCase() == sourceSha256.toLowerCase() &&
      clipHash.toLowerCase() == clipSha256.toLowerCase() &&
      mouthStart.isFinite && mouthEnd.isFinite &&
      mouthStart >= 0 && mouthEnd > mouthStart &&
      syncScore.isFinite && syncScore >= 0 && syncScore <= 1;
}
