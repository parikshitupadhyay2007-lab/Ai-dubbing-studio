import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/models/dub_project.dart';
import 'package:ai_dubbing_studio/services/otakumind_script_verifier.dart';

void main() {
  final transcript = [
    DubSegment(id: 1, start: 0, end: 2, original: 'This is the original dialogue'),
    DubSegment(id: 2, start: 2, end: 4, original: 'Another original dialogue'),
  ];
  OriginalScriptReference ref(List<String> lines, {String source = 'approved-source',
      List<int> ids = const [1, 2]}) => OriginalScriptReference(
    sourceId: source, animeId: 'anime', episodeId: 'episode',
    lines: lines, segmentIds: ids);

  test('accepts independently aligned identical source dialogue', () {
    final result = const OtakuMindScriptVerifier().verify(transcript,
        ref(['This is the original dialogue', 'Another original dialogue']));
    expect(result.accepted, isTrue);
    expect(result.verifiedLines[1], 'This is the original dialogue');
  });
  test('rejects fabricated or mismatched dialogue', () {
    final result = const OtakuMindScriptVerifier().verify(transcript,
        ref(['Different script entirely', 'Another original dialogue']));
    expect(result.accepted, isFalse);
    expect(result.verifiedLines, isEmpty);
  });
  test('rejects absent provenance and misaligned segment ids', () {
    final verifier = const OtakuMindScriptVerifier();
    expect(verifier.verify(transcript, ref(['This is the original dialogue',
        'Another original dialogue'], source: '')).accepted, isFalse);
    expect(verifier.verify(transcript, ref(['This is the original dialogue',
        'Another original dialogue'], ids: [2, 1])).accepted, isFalse);
  });
}
