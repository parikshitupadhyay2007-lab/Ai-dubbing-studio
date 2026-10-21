import 'dart:convert';
import 'dart:io';

class VoiceModelConfig {
  final String language;
  final String architecture;
  final int sampleRate;
  final int numSpeakers;
  final Map<String, int> speakers;
  final String modelPath;
  final String configPath;
  final Map<String, dynamic> rawConfig;

  const VoiceModelConfig({
    required this.language,
    required this.architecture,
    required this.sampleRate,
    required this.numSpeakers,
    required this.speakers,
    required this.modelPath,
    required this.configPath,
    required this.rawConfig,
  });

  static Future<VoiceModelConfig> load({
    required String modelPath,
    required String configPath,
    required String expectedLanguage,
  }) async {
    if (!{'hi', 'en'}.contains(expectedLanguage)) {
      throw ArgumentError('Unsupported target language.');
    }

    final model = File(modelPath);
    final config = File(configPath);

    if (!await model.isFile || await model.length() == 0) {
      throw StateError('Voice ONNX model is missing or empty.');
    }

    if (!await config.isFile || await config.length() == 0) {
      throw StateError('Matching voice configuration is missing.');
    }

    final decoded = jsonDecode(await config.readAsString());

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid voice configuration JSON.');
    }

    final architecture = decoded['architecture'];

    if (architecture != null && architecture != 'piper') {
      throw const FormatException(
        'This engine currently expects Piper-compatible models.',
      );
    }

    final audio = decoded['audio'];
    final inference = decoded['inference'];
    final phonemeMap = decoded['phoneme_id_map'];

    if (audio is! Map || audio['sample_rate'] is! int) {
      throw const FormatException('Piper audio settings are missing.');
    }

    if ((audio['sample_rate'] as int) <= 0) {
      throw const FormatException('Invalid sample rate.');
    }

    if (inference is! Map ||
        inference['noise_scale'] is! num ||
        inference['length_scale'] is! num ||
        inference['noise_w'] is! num) {
      throw const FormatException(
        'Required Piper inference settings are missing.',
      );
    }

    if (phonemeMap is! Map || phonemeMap.isEmpty) {
      throw const FormatException('Phoneme ID mapping is missing.');
    }

    final language = decoded['language'];
    final languageCode = language is Map
        ? language['code']?.toString()
        : language?.toString();

    if (languageCode == null ||
        languageCode.split(RegExp('[-_]')).first.toLowerCase() !=
            expectedLanguage) {
      throw StateError(
        'Voice language does not match $expectedLanguage.',
      );
    }

    final count = decoded['num_speakers'];

    if (count is! int || count < 1) {
      throw const FormatException('Invalid speaker count.');
    }

    final speakerMap = <String, int>{};
    final rawSpeakers = decoded['speaker_id_map'];

    if (rawSpeakers is Map) {
      for (final entry in rawSpeakers.entries) {
        if (entry.key is! String ||
            entry.value is! int ||
            entry.value < 0 ||
            entry.value >= count) {
          throw const FormatException('Invalid speaker ID mapping.');
        }

        speakerMap[entry.key as String] = entry.value as int;
      }
    }

    if (count == 1 && speakerMap.isEmpty) {
      speakerMap['default'] = 0;
    }

    if (count > 1 && speakerMap.isEmpty) {
      throw const FormatException(
        'Multi-speaker model requires speaker_id_map.',
      );
    }

    return VoiceModelConfig(
      language: expectedLanguage,
      architecture: 'piper',
      sampleRate: audio['sample_rate'] as int,
      numSpeakers: count,
      speakers: speakerMap,
      modelPath: modelPath,
      configPath: configPath,
      rawConfig: decoded,
    );
  }

  bool supportsSpeaker(String name) {
    return speakers.containsKey(name);
  }

  int speakerId(String name) {
    final id = speakers[name];

    if (id == null) {
      throw StateError('Speaker "$name" is unavailable.');
    }

    return id;
  }

  bool get isMultiSpeaker => numSpeakers > 1;
}
