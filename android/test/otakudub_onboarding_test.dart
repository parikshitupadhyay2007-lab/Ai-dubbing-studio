import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/otakudub_onboarding.dart';

void main() {
  test('agreement contains explicit copyright and commercial boundaries', () {
    expect(onboardingAgreement.split(RegExp(r'\s+')).length, greaterThan(900));
    expect(onboardingAgreement, contains('fifty percent (50%)'));
    expect(onboardingAgreement, contains('lifetime'));
    expect(onboardingAgreement, contains('separate written commercial agreement'));
    expect(onboardingAgreement, contains('without permission'));
    expect(onboardingAgreement, contains('third-party rights holders'));
    expect(onboardingAgreementVersion, isNotEmpty);
  });
}
