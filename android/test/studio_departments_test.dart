import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/services/studio_departments.dart';

void main() {
  const supervisor = ScriptSupervisionDepartment();

  test('translation requires independent semantic reviewer', () {
    final review = supervisor.reviewTranslation(
      original: 'I will come tomorrow.',
      candidate: 'मैं कल आऊँगा।',
      sourceLanguage: 'en',
      targetLanguage: 'hi',
    );
    expect(review.reviewer, StudioDepartment.scriptSupervision);
    expect(review.status, ReviewStatus.unresolved);
    expect(review.approved, isFalse);
  });

  test('malformed dialogue is rejected', () {
    final review = supervisor.reviewTranslation(
      original: 'Hello.',
      candidate: '',
      sourceLanguage: 'en',
      targetLanguage: 'hi',
    );
    expect(review.status, ReviewStatus.rejected);
  });

  test('unchanged accepted dialogue can retain previous approval', () {
    final review = supervisor.reviewRevision(
      original: 'I will come.',
      previous: 'मैं आऊँगा।',
      candidate: 'मैं आऊँगा।',
      sourceLanguage: 'en',
      targetLanguage: 'hi',
    );
    expect(review.approved, isTrue);
  });

  test('changed dialogue does not self-certify equivalence', () {
    final review = supervisor.reviewRevision(
      original: 'I will come.',
      previous: 'मैं आऊँगा।',
      candidate: 'मैं जरूर आऊँगा।',
      sourceLanguage: 'en',
      targetLanguage: 'hi',
    );
    expect(review.status, ReviewStatus.unresolved);
  });

  test('changed explicit quantities are rejected', () {
    final review = supervisor.reviewRevision(
      original: 'There are 2.',
      previous: 'There are 2.',
      candidate: 'There are 3.',
      sourceLanguage: 'en',
      targetLanguage: 'en',
    );
    expect(review.status, ReviewStatus.rejected);
  });
}
