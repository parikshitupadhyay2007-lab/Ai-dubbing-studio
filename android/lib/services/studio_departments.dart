import 'dialogue_quality_gate.dart';

/// A proposed artifact is never self-approved by its producing department.
enum StudioDepartment {
  production, research, originalScript, translationAdaptation,
  scriptSupervision, castingDirection, voicePerformance, adrTiming,
  soundPost, independentQc, delivery,
}

enum ReviewStatus { approved, rejected, unresolved }

class DepartmentReview {
  final StudioDepartment producer;
  final StudioDepartment reviewer;
  final ReviewStatus status;
  final String reasonCode;
  final String? previousDialogue;
  final String proposedDialogue;

  const DepartmentReview({
    required this.producer,
    required this.reviewer,
    required this.status,
    required this.reasonCode,
    required this.proposedDialogue,
    this.previousDialogue,
  });

  bool get approved => status == ReviewStatus.approved;
}

/// High-precision script-supervision checks. This is NOT a multilingual
/// semantic-equivalence model: new wording remains unresolved until a truly
/// independent meaning reviewer is integrated. Do not silently self-certify.
class ScriptSupervisionDepartment {
  const ScriptSupervisionDepartment();

  DepartmentReview reviewTranslation({
    required String original,
    required String candidate,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    final valid = DialogueQualityGate.acceptableTranslation(
        candidate, original, sourceLanguage, targetLanguage);
    return DepartmentReview(
      producer: StudioDepartment.translationAdaptation,
      reviewer: StudioDepartment.scriptSupervision,
      status: valid ? ReviewStatus.unresolved : ReviewStatus.rejected,
      reasonCode: valid
          ? 'independent_semantic_review_required'
          : 'target_language_or_source_copy_invalid',
      proposedDialogue: candidate,
    );
  }

  DepartmentReview reviewRevision({
    required String original,
    required String previous,
    required String candidate,
    required String sourceLanguage,
    required String targetLanguage,
    StudioDepartment producer = StudioDepartment.translationAdaptation,
  }) {
    if (!DialogueQualityGate.acceptableTranslation(
        candidate, original, sourceLanguage, targetLanguage)) {
      return DepartmentReview(
        producer: producer,
        reviewer: StudioDepartment.scriptSupervision,
        status: ReviewStatus.rejected,
        reasonCode: 'invalid_target_dialogue',
        previousDialogue: previous,
        proposedDialogue: candidate,
      );
    }
    if (!DialogueQualityGate.preservesRevisionAnchors(previous, candidate)) {
      return DepartmentReview(
        producer: producer,
        reviewer: StudioDepartment.scriptSupervision,
        status: ReviewStatus.rejected,
        reasonCode: 'protected_meaning_anchor_changed',
        previousDialogue: previous,
        proposedDialogue: candidate,
      );
    }
    final unchanged = candidate.trim() == previous.trim();
    return DepartmentReview(
      producer: producer,
      reviewer: StudioDepartment.scriptSupervision,
      status: unchanged ? ReviewStatus.approved : ReviewStatus.unresolved,
      reasonCode: unchanged
          ? 'previously_accepted_dialogue_unchanged'
          : 'independent_semantic_review_required',
      previousDialogue: previous,
      proposedDialogue: candidate,
    );
  }
}
