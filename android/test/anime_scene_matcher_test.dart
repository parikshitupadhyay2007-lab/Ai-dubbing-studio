import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/models/dub_project.dart';
import 'package:ai_dubbing_studio/services/anime_scene_matcher.dart';
void main() {
  DubSegment segment(int id, String text) => DubSegment(
      id: id, start: id.toDouble(), end: id + 0.8, original: text);
  final lines = [
    segment(1, '星が輝いているよ'),
    segment(2, '明日はまた会えるかな'),
    segment(3, 'この場所を忘れないで'),
  ];
  const match = AnimeSceneMatcher();
  test('requires licensed reference evidence, not filename', () {
    expect(match.identify(lines, []), isNull);
    expect(match.identify([lines.first], [
      const AnimeSceneReference(animeId: 'a', title: 'A', episodeId: '1',
        startSeconds: 42, dialogue: ['星が輝いているよ'])
    ]), isNull);
  });
  test('accepts three ordered corroborating lines', () {
    final hit = match.identify(lines, [
      const AnimeSceneReference(animeId: 'a', title: 'A', episodeId: '2',
        startSeconds: 60, dialogue: [
          '星が輝いているよ', '明日はまた会えるかな', 'この場所を忘れないで'])
    ]);
    expect(hit?.animeId, 'a');
    expect(hit?.episodeId, '2');
    expect(hit?.matchingLines, 3);
  });
  test('abstains for ambiguous identical reference scenes', () {
    final entries = [
      for (final id in ['a', 'b'])
        AnimeSceneReference(animeId: id, title: id, episodeId: '1',
          startSeconds: 60, dialogue: [
          '星が輝いているよ', '明日はまた会えるかな', 'この場所を忘れないで'])
    ];
    expect(match.identify(lines, entries), isNull);
  });
}
