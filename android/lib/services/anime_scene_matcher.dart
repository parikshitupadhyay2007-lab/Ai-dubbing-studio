import 'dart:math' as math;
import '../models/dub_project.dart';

/// Evidence-backed scene retrieval. The catalog must be built from licensed,
/// independently timed reference transcripts; no guessed episode/timestamp.
class AnimeSceneCandidate {
  final String animeId, title, episodeId;
  final double referenceStartSeconds, confidence;
  final int matchingLines;
  const AnimeSceneCandidate(this.animeId, this.title, this.episodeId,
      this.referenceStartSeconds, this.confidence, this.matchingLines);
  Map<String, dynamic> toJson() => {
    'anime_id': animeId, 'title': title, 'episode_id': episodeId,
    'reference_start_seconds': referenceStartSeconds,
    'confidence': confidence, 'matching_lines': matchingLines,
  };
}

/// Each entry represents consecutive lines, not a general franchise synopsis.
class AnimeSceneReference {
  final String animeId, title, episodeId;
  final double startSeconds;
  final List<String> dialogue;
  const AnimeSceneReference({
    required this.animeId, required this.title, required this.episodeId,
    required this.startSeconds, required this.dialogue,
  });
  factory AnimeSceneReference.fromJson(Map<String, dynamic> value) =>
      AnimeSceneReference(
        animeId: value['anime_id'] as String,
        title: value['title'] as String,
        episodeId: value['episode_id'] as String,
        startSeconds: (value['start_seconds'] as num).toDouble(),
        dialogue: List<String>.from(value['dialogue'] as List),
      );
}

class AnimeSceneMatcher {
  const AnimeSceneMatcher();
  String _normalized(String text) => text.toLowerCase()
      .replaceAll(RegExp(r'[\s\p{P}\p{S}]+', unicode: true), '');
  /// Strict ordered matching minimizes false identification from common
  /// greetings. The result is a candidate, never automatic speaker identity.
  AnimeSceneCandidate? identify(
      List<DubSegment> segments, List<AnimeSceneReference> corpus) {
    final lines = segments.map((s) => _normalized(s.original))
        .where((s) => s.length >= 8).toList();
    if (lines.length < 3 || corpus.isEmpty) return null;
    final results = <AnimeSceneCandidate>[];
    for (final entry in corpus) {
      if (entry.animeId.isEmpty || entry.episodeId.isEmpty ||
          !entry.startSeconds.isFinite || entry.startSeconds < 0) continue;
      final reference = entry.dialogue.map(_normalized).toList();
      var best = 0;
      var offset = 0;
      for (var i = 0; i < reference.length; i++) {
        var count = 0;
        while (count < lines.length && i + count < reference.length &&
            reference[i + count] == lines[count]) {
          count++;
        }
        if (count > best) { best = count; offset = i; }
      }
      if (best < 3) continue;
      final confidence = best / math.max(3, lines.length);
      results.add(AnimeSceneCandidate(entry.animeId, entry.title,
          entry.episodeId, entry.startSeconds, confidence, best));
    }
    results.sort((a,b) => b.confidence.compareTo(a.confidence));
    if (results.isEmpty || results.first.confidence < 0.8 ||
        (results.length > 1 &&
          results.first.confidence - results[1].confidence < 0.15)) return null;
    return results.first;
  }
}
