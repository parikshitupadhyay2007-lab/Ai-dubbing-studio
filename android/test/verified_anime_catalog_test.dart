import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/services/verified_anime_catalog.dart';

void main() {
  const validator = VerifiedAnimeCatalog();
  const base = '''[{
    "anime_id":"licensed-demo", "episode_id":"s1e1", "title":"Demo",
    "provenance":"licensed test fixture", "redistribution_license":"CC0-1.0",
    "source_id":"fixture-1", "start_seconds":0, "end_seconds":8,
    "dialogue":["First original line","Second original line","Third original line"],
    "timeline":[
      {"start_seconds":0,"end_seconds":2,"dialogue":"First original line","speaker_id":"s1","source_id":"fixture-1",
       "expression":{"source_id":"fixture-1","delivery":"natural"}},
      {"start_seconds":2,"end_seconds":4,"dialogue":"Second original line","speaker_id":"s2","source_id":"fixture-1"}
    ], "frame_hashes":["0123456789abcdef"]
  }]''';
  test('accepts a provenance-bound timeline', () {
    expect(validator.parse(base).single['anime_id'], 'licensed-demo');
  });
  test('rejects invented timeline provenance', () {
    expect(() => validator.parse(base.replaceFirst(
      '"speaker_id":"s2","source_id":"fixture-1"',
      '"speaker_id":"s2","source_id":"unverified"')),
      throwsFormatException);
  });
  test('rejects invalid visual hash', () {
    expect(() => validator.parse(base.replaceFirst(
      '0123456789abcdef', 'not-a-hash')), throwsFormatException);
  });
  test('rejects overlapping timeline entries', () {
    expect(() => validator.parse(base.replaceFirst(
      '"start_seconds":2,"end_seconds":4', '"start_seconds":1,"end_seconds":4')),
      throwsFormatException);
  });
  test('rejects timeline dialogue absent from source corpus', () {
    expect(() => validator.parse(base.replaceFirst(
      '"dialogue":"First original line"', '"dialogue":"Invented line"')),
      throwsFormatException);
  });
  test('rejects forged expression provenance', () {
    expect(() => validator.parse(base.replaceFirst(
      '"expression":{"source_id":"fixture-1"', '"expression":{"source_id":"elsewhere"')),
      throwsFormatException);
  });
  test('empty catalog cannot invent anime identities', () {
    expect(validator.parse('[]'), isEmpty);
  });
}
