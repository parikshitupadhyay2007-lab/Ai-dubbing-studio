import 'dart:math' as math;
import '../models/dub_project.dart';

/// A scene match identifies a candidate, never an acoustic speaker.
class AnimeSceneCandidate {
  final String animeId, title, episodeId;
  final double referenceStartSeconds, confidence;
  final int matchingLines;
  final List<Map<String, String>> possibleCharacters;
  const AnimeSceneCandidate(this.animeId, this.title, this.episodeId,
      this.referenceStartSeconds, this.confidence, this.matchingLines,
      this.possibleCharacters);
  Map<String, dynamic> toJson() => {
    'anime_id': animeId, 'title': title, 'episode_id': episodeId,
    'reference_start_seconds': referenceStartSeconds,
    'confidence': confidence, 'matching_lines': matchingLines,
    'possible_characters': possibleCharacters,
  };
}

class AnimeSceneReference {
  final String animeId, title, episodeId;
  final double startSeconds;
  final List<String> dialogue;
  final List<Map<String, String>> characters;
  final List<String> frameHashes;
  const AnimeSceneReference({
    required this.animeId, required this.title, required this.episodeId,
    required this.startSeconds, required this.dialogue,
    this.characters = const [], this.frameHashes = const [],
  });
  factory AnimeSceneReference.fromJson(Map<String, dynamic> value) =>
      AnimeSceneReference(
        animeId: value['anime_id'] as String,
        title: value['title'] as String,
        episodeId: value['episode_id'] as String,
        startSeconds: (value['start_seconds'] as num).toDouble(),
        dialogue: List<String>.from(value['dialogue'] as List),
        characters: [
          for (final person in value['characters'] as List? ?? [])
            Map<String, String>.from(person as Map),
        ],
        frameHashes: List<String>.from(value['frame_hashes'] as List? ?? []),
      );
}

class AnimeSceneMatcher {
  const AnimeSceneMatcher();

  int? _parseHash(String text) {
    if (text.length != 16 ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) return null;
    return int.tryParse(text, radix: 16);
  }

  int _hamming(int a, int b) {
    var bits = 0;
    var value = a ^ b;
    while (value != 0) {
      value &= value - 1;
      bits++;
    }
    return bits;
  }

  String _normalized(String text) => text.toLowerCase().replaceAll(
      RegExp(r'[\s.,!?;:「」『』。、！？…—–()\[\]-]+'), '');

  /// Requires three ordered substantial lines, >=80% coverage, and a
  /// >=15-point margin over any competing candidate.
  /// Optional 64-bit dHashes must corroborate, never override, dialogue.
  AnimeSceneCandidate? identify(
      List<DubSegment> segments, List<AnimeSceneReference> corpus,
      {List<String> observedFrameHashes = const []}) {
    final lines = segments.map((s) => _normalized(s.original))
        .where((s) => s.length >= 8).toList();
    if (lines.length < 3 || corpus.isEmpty) return null;
    final results = <AnimeSceneCandidate>[];
    for (final entry in corpus) {
      if (entry.animeId.isEmpty || entry.episodeId.isEmpty ||
          !entry.startSeconds.isFinite || entry.startSeconds < 0) continue;
      final reference = entry.dialogue.map(_normalized).toList();
      var best = 0;
      for (var i = 0; i < reference.length; i++) {
        var count = 0;
        while (count < lines.length && i + count < reference.length &&
            reference[i + count] == lines[count]) {
          count++;
        }
        if (count > best) best = count;
      }
      if (best < 3) continue;
      if (observedFrameHashes.isNotEmpty) {
        if (entry.frameHashes.isEmpty) continue;
        var nearest = 65;
        for (final observed in observedFrameHashes) {
          final a = _parseHash(observed);
          if (a == null) continue;
          for (final expected in entry.frameHashes) {
            final b = _parseHash(expected);
            if (b == null) continue;
            nearest = math.min(nearest, _hamming(a, b));
          }
        }
        if (nearest > 8) continue;
      }
      final confidence = best / math.max(3, lines.length);
      results.add(AnimeSceneCandidate(entry.animeId, entry.title,
          entry.episodeId, entry.startSeconds, confidence, best,
          entry.characters));
    }
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    if (results.isEmpty || results.first.confidence < 0.8 ||
        (results.length > 1 &&
            results.first.confidence - results[1].confidence < 0.15)) {
      return null;
    }
    return results.first;
  }
}
