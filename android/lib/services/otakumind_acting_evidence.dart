import '../models/dub_project.dart';

/// OtakuMind combines independent acoustic, visual and dialogue evidence.
/// This class does not itself run emotion or active-speaker models.
class ActingEvidence {
  final int segmentId;
  final String acousticSourceId, visualSourceId, dialogueSourceId;
  final String delivery;
  final double acousticConfidence, visualConfidence, dialogueConfidence;
  const ActingEvidence({required this.segmentId, required this.acousticSourceId,
    required this.visualSourceId, required this.dialogueSourceId,
    required this.delivery, required this.acousticConfidence,
    required this.visualConfidence, required this.dialogueConfidence});

  bool get corroborated => segmentId >= 0 &&
      acousticSourceId.trim().isNotEmpty && visualSourceId.trim().isNotEmpty &&
      dialogueSourceId.trim().isNotEmpty &&
      acousticSourceId != visualSourceId && visualSourceId != dialogueSourceId &&
      acousticSourceId != dialogueSourceId &&
      acousticConfidence.isFinite && visualConfidence.isFinite &&
      dialogueConfidence.isFinite && acousticConfidence >= 0.8 &&
      visualConfidence >= 0.8 && dialogueConfidence >= 0.8 &&
      const {'natural', 'soft', 'urgent', 'excited', 'solemn'}
          .contains(delivery);
}

class OtakuMindActingDirector {
  const OtakuMindActingDirector();
  /// Unknown or conflicting evidence never becomes an invented performance.
  String deliveryFor(ActingEvidence? evidence) =>
      evidence != null && evidence.corroborated ? evidence.delivery : 'natural';

  /// Apply only segment-scoped corroborated evidence; otherwise retain natural.
  /// The native renderer interprets this as speed/stochasticity guidance,
  /// not as proof of a trained emotion-conditioning capability.
  void direct(DubSegment segment, ActingEvidence? evidence) {
    if (evidence != null && evidence.segmentId != segment.id) {
      segment.delivery = 'natural';
      return;
    }
    segment.delivery = deliveryFor(evidence);
  }
}
