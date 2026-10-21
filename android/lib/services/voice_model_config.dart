
import 'dart:convert';
import 'dart:io';

class VoiceModelConfig {
  final String language;
  final String architecture;
  final int sampleRate;
  final Map<String, int> speakers;
  final String modelPath;

  const VoiceModelConfig({
    required this.language,
    required this.architecture,
    required this.sampleRate,
    required this.speakers,
    required this.modelPath,
  });

  static Future<VoiceModelConfig> load({
    required String modelPath,
    required String configPath,
  }) async {
    final model = File(modelPath);
    final config = File(configPath);

    if (!await model.exists() || await model.length() == 0) {
      throw StateError('Voice model is missing or empty.');
    }

    if (!await config.exists()) {
      throw StateError('Voice model configuration is missing.');
    }

    final data = jsonDecode(await config.readAsString());

    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid voice configuration.');
    }

    final language = data['language'];
    final architecture = data['architecture'];
    final sampleRate = data['sample_rate'];
    final rawSpeakers = data['speakers'];

    if (language != 'hi' && language != 'en') {
      throw const FormatException('Unsupported voice language.');
    }

    if (architecture is! String || architecture.isEmpty) {
      throw const FormatException('Model architecture is required.');
    }

    if (sampleRate is! int || sampleRate <= 0) {
      throw const FormatException('Invalid audio sample rate.');
    }

    if (rawSpeakers is! Map || rawSpeakers.isEmpty) {
      throw const FormatException('Speaker configuration is missing.');
    }

    final speakers = <String, int>{};

    for (final entry in rawSpeakers.entries) {
      if (entry.key is! String ||
          entry.value is! int ||
          entry.value < 0) {
        throw const FormatException('Invalid speaker mapping.');
      }

      speakers[entry.key as String] = entry.value as int;
    }

    return VoiceModelConfig(
      language: language,
      architecture: architecture,
      sampleRate: sampleRate,
      speakers: speakers,
      modelPath: modelPath,
    );
  }

  bool supportsSpeaker(String speaker) {
    return speakers.containsKey(speaker);
  }

  int speakerId(String speaker) {
    final id = speakers[speaker];

    if (id == null) {
      throw StateError('Unsupported speaker: $speaker');
    }

    return id;
  }
}
