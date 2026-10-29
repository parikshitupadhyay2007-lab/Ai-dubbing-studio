import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/otakudub_onboarding.dart';

void main() {
  test('standalone introduction has a versioned completion key', () {
    expect(introVersion, isNotEmpty);
  });
}
