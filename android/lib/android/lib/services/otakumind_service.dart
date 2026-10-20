
import 'dart:convert';

import 'package:http/http.dart' as http;

const otakuServer = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://ai-dubbing-studio.onrender.com',
);

class OtakuMindService {
  final http.Client _client = http.Client();

  // =====================================
  // FETCH ALL OTAKUMIND PERSONALITIES
  // =====================================

  Future<List<dynamic>> personalities() async {
    final response = await _client
        .get(
          Uri.parse('$otakuServer/otakumind/personalities'),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception(
        'Could not load OtakuMind personalities. '
        'Server returned ${response.statusCode}.',
      );
    }

    final data = jsonDecode(response.body);

    return data['personalities'] as List<dynamic>;
  }

  // =====================================
  // FETCH A SINGLE PERSONALITY
  // =====================================

  Future<Map<String, dynamic>> getPersonality(
    String personalityId,
  ) async {
    final response = await _client
        .get(
          Uri.parse(
            '$otakuServer/otakumind/personalities/'
            '${Uri.encodeComponent(personalityId)}',
          ),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load personality: $personalityId',
      );
    }

    return Map<String, dynamic>.from(
      jsonDecode(response.body) as Map,
    );
  }

  // =====================================
  // SEND MESSAGE TO GROQ-POWERED OTAKUMIND
  // =====================================

  Future<Map<String, dynamic>> chat({
    required String personalityId,
    required String message,
    required String language,
    required List<Map<String, String>> history,
  }) async {
    final recentHistory = history.length > 12
        ? history.sublist(history.length - 12)
        : history;

    final response = await _client
        .post(
          Uri.parse('$otakuServer/otakumind/chat'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'personality_id': personalityId,
            'message': message,
            'language': language,
            'history': recentHistory,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      String detail = 'OtakuMind is temporarily unavailable.';

      try {
        final data = jsonDecode(response.body);

        if (data is Map && data['detail'] != null) {
          detail = data['detail'].toString();
        }
      } catch (_) {
        detail = 'Server error ${response.statusCode}';
      }

      throw Exception(detail);
    }

    return Map<String, dynamic>.from(
      jsonDecode(response.body) as Map,
    );
  }

  // =====================================
  // GENERATE CHARACTER VOICE
  // =====================================

  Future<List<int>> generateVoice({
    required String text,
    required String voice,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$otakuServer/studio/generate'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'text': text,
            'voice': voice,
            'style': 'natural',
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      String detail = 'Voice generation failed.';

      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['detail'] != null) {
          detail = data['detail'].toString();
        }
      } catch (_) {}

      throw Exception(detail);
    }

    return response.bodyBytes;
  }

  // =====================================
  // BACKEND HEALTH CHECK
  // =====================================

  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$otakuServer/otakumind/health'),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(response.body);

      return data is Map && data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // =====================================
  // CLEANUP
  // =====================================

  void dispose() {
    _client.close();
  }
}
