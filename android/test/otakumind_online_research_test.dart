import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/otakumind_online_research.dart';

void main() {
  test('online research refuses requests unless explicitly enabled', () async {
    const research = OtakuMindOnlineResearch(enabled: false);
    await expectLater(research.searchAnime('Example'), throwsStateError);
  });
  test('rejects invalid query before network access', () async {
    const research = OtakuMindOnlineResearch(enabled: true);
    await expectLater(research.searchAnime(' '), throwsFormatException);
    await expectLater(research.searchAnime('a' * 121), throwsFormatException);
  });
}
