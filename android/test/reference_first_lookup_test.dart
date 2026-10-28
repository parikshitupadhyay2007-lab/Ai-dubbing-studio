import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_dubbing_studio/services/reference_first_lookup.dart';
import 'package:ai_dubbing_studio/services/verified_anime_catalog.dart';

void main() {
  const digest = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  Map<String, dynamic> fixture() => {
    'anime_id': 'original-fixture', 'episode_id': 'episode-1',
    'title': 'Original test animation', 'source_id': 'source-1',
    'provenance': 'original test fixture', 'redistribution_license': 'CC0',
    'asset_sha256': digest, 'source_language': 'ja',
    'start_seconds': 0, 'end_seconds': 6,
    'dialogue': ['First line', 'Second line', 'Third line'],
    'timeline': [
      {'start_seconds': 0, 'end_seconds': 1, 'dialogue': 'First line',
       'speaker_id': 'speaker-a', 'voice_role': 'female', 'source_id': 'source-1'},
      {'start_seconds': 2, 'end_seconds': 3, 'dialogue': 'Second line',
       'speaker_id': 'speaker-b', 'voice_role': 'male', 'source_id': 'source-1'},
      {'start_seconds': 4, 'end_seconds': 5, 'dialogue': 'Third line',
       'speaker_id': 'speaker-a', 'source_id': 'source-1'},
    ],
  };
  test('byte-exact registered source supplies dialogue and immutable times', () {
    final rows = const VerifiedAnimeCatalog().parse(
      '[${_encode(fixture())}]');
    final match = const ExactReferenceDialogue().match(rows, digest)!;
    expect(match['source_language'], 'ja');
    expect(match['context']['reference_dialogue_status'],
        'exact_asset_script_applied');
    final lines = match['segments'] as List;
    expect(lines.length, 3);
    expect(lines.first.original, 'First line');
    expect(lines.last.start, 4);
    expect(lines.first.speakerId, 'speaker-a');
    expect(match['context']['speaker_roles']['speaker-a'], 'female');
  });
  test('unregistered digest and ambiguous duplicate source abstain', () {
    final entry = fixture();
    expect(const ExactReferenceDialogue().match([entry],
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'), isNull);
    expect(const ExactReferenceDialogue().match([entry, {...entry}], digest), isNull);
  });
  test('incomplete exact source script is refused', () {
    final entry = fixture();
    (entry['timeline'] as List).removeLast();
    expect(() => const VerifiedAnimeCatalog().parse('[${_encode(entry)}]'),
        throwsFormatException);
  });
  test('visual match cannot silently become exact dialogue', () {
    final entry = fixture();
    entry['frame_hashes'] = [
      '0123456789abcdef', 'fedcba9876543210', '0011223344556677'];
    final candidate = const ReferenceFirstLookup().candidate([entry],
        List<String>.from(entry['frame_hashes'] as List))!;
    expect(candidate['reference_dialogue_status'], 'not_applied');
    expect(candidate['identity_status'],
        'candidate_pending_exact_timeline_verification');
  });
}

String _encode(Map<String, dynamic> item) {
  // JSON fixture, avoiding external corpus or copyrighted dialogue.
  return const JsonEncoder().convert(item);
}
