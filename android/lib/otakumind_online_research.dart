import 'dart:convert';
import 'dart:io';

/// Online metadata lookup. Never sends a project file, dialogue or frame.
class OtakuMindOnlineResearch {
  const OtakuMindOnlineResearch({required this.enabled});
  final bool enabled;
  static const endpoint = 'https://graphql.anilist.co';

  Future<Map<String, dynamic>> searchAnime(String title) async {
    if (!enabled) throw StateError('Internet research is disabled');
    final query = title.trim();
    if (query.length < 2 || query.length > 120) {
      throw const FormatException('Search title must be 2–120 characters');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 10));
      request.headers.contentType = ContentType.json;
      request.followRedirects = false;
      request.write(jsonEncode({
        'query': r'query ($search: String) { Media(search: $search, type: ANIME) { id title { romaji english native } format episodes description(asHtml: false) siteUrl } }',
        'variables': {'search': query},
      }));
      final response = await request.close().timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw HttpException('Metadata service returned ${response.statusCode}');
      }
      final bytes = await response.fold<List<int>>(<int>[], (previous, chunk) {
        if (previous.length + chunk.length > 256000) {
          throw const FormatException('Metadata response too large');
        }
        return previous..addAll(chunk);
      }).timeout(const Duration(seconds: 12));
      final result = jsonDecode(utf8.decode(bytes));
      if (result is! Map || result['errors'] != null ||
          result['data'] is! Map || (result['data'] as Map)['Media'] is! Map) {
        throw const FormatException('No usable metadata result');
      }
      final media = Map<String, dynamic>.from((result['data'] as Map)['Media'] as Map);
      return {
        'provider': 'AniList', 'retrieved_at': DateTime.now().toUtc().toIso8601String(),
        'search_query': query, 'metadata': media,
        'verification': 'unverified_reference_only',
        'video_uploaded': false,
      };
    } finally {
      client.close(force: true);
    }
  }
}
