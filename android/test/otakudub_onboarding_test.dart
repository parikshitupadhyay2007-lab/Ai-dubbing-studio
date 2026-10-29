import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/otakudub_onboarding.dart';

void main() {
  test('agreement contains explicit copyright and commercial boundaries', () {
    expect(onboardingAgreement.split(RegExp(r'\s+')).length, greaterThan(900));
    expect(onboardingAgreement, contains('fifty percent (50%)'));
    expect(onboardingAgreement.toLowerCase(), contains('lifetime'));
    expect(onboardingAgreement, contains('separate written commercial agreement'));
    expect(onboardingAgreement, contains('without the necessary permissions'));
    expect(onboardingAgreement, contains('anime rightsholder'));
    expect(onboardingAgreementVersion, isNotEmpty);
  });
}
