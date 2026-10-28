import 'dart:convert';
import 'dart:io';

/// Network access is restricted to explicitly configured approved endpoints.
/// No source video, audio, or frame bytes are accepted by this transport.
class OtakuMindReferenceProvider {
  final Uri endpoint;
  final Set<String> approvedHosts;
  const OtakuMindReferenceProvider(this.endpoint, this.approvedHosts);

  Future<Map<String, dynamic>?> lookup({required List<String> frameHashes,
      required List<String> dialogueHints}) async {
    if (endpoint.scheme != 'https' || endpoint.userInfo.isNotEmpty ||
        endpoint.hasFragment || endpoint.hasQuery || endpoint.port != 443 ||
        !approvedHosts.contains(endpoint.host) ||
        frameHashes.length > 16 || dialogueHints.length > 8 ||
        frameHashes.any((v) => !RegExp(r'^[a-fA-F0-9]{16}$').hasMatch(v)) ||
        dialogueHints.any((v) => v.length > 200)) {
      throw const FormatException('Unapproved reference request');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    client.autoUncompress = false;
    try {
      final request = await client.postUrl(endpoint).timeout(const Duration(seconds: 8));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode({'frame_hashes': frameHashes,
        'dialogue_hints': dialogueHints})));
      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.headers.contentLength > 262144) return null;
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 8))) {
        bytes.addAll(chunk);
        if (bytes.length > 262144) return null;
      }
      final parsed = jsonDecode(utf8.decode(bytes));
      if (parsed is! Map || parsed['source_id'] is! String ||
          (parsed['source_id'] as String).trim().isEmpty ||
          parsed['anime_id'] is! String || parsed['episode_id'] is! String ||
          parsed['dialogue'] is! List) return null;
      return Map<String, dynamic>.from(parsed);
    } on SocketException { return null;
    } on HttpException { return null;
    } on TimeoutException { return null;
    } on FormatException { return null;
    } finally { client.close(force: true); }
  }
}
