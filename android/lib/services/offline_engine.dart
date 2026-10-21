
import 'package:flutter/services.dart';

import '../models/dub_project.dart';
import 'model_manager.dart';

class OfflineEngineException implements Exception {
  final String message;

  OfflineEngineException(this.message);

  @override
  String toString() => message;
}

class OfflineEngine {
  static const MethodChannel _channel = MethodChannel(
    'co.parikshit.otakudub/offline_engine',
  );

  final ModelManager models;

  OfflineEngine(this.models);

  Future<void> verifyRuntime() async {
    try {
      final ready = await _channel.invokeMethod<bool>(
        'runtimeReady',
      );

      if (ready != true) {
        throw OfflineEngineException(
          'Android native inference runtime is not ready.',
        );
      }
    } on MissingPluginException {
      throw OfflineEngineException(
        'Native Android AI engine is not installed in this APK.',
      );
    } on PlatformException catch (e) {
      throw OfflineEngineException(
        e.message ?? 'Native runtime initialization failed.',
      );
    }
  }

  Future<Map<String, dynamic>> _invoke(
    String method,
    Map<String, dynamic> arguments,
  ) async {
    try {
      final response =
          await _channel.invokeMapMethod<String, dynamic>(
        method,
        arguments,
      );

      if (response == null) {
        throw OfflineEngineException(
          '$method returned no result.',
        );
      }

      return response;
    } on MissingPluginException {
      throw OfflineEngineException(
        'Native implementation missing for $method.',
      );
    } on PlatformException catch (e) {
      throw OfflineEngineException(
        e.message ?? '$method failed: ${e.code}',
      );
    }
  }

  Future<Map<String, dynamic>> transcribe(
    DubProject project,
  ) async {
    final model = await models.path(AiModel.whisper);

    if (model == null) {
      throw OfflineEngineException(
        'Install a compatible offline Whisper model first.',
      );
    }

    return _invoke('transcribe', {
      'source_path': project.sourcePath,
      'model_path': model,
      'language': project.sourceLanguage,
    });
  }

  Future<Map<String, dynamic>> identifySpeakers(
    DubProject project,
  ) {
    return _invoke('identifySpeakers', {
      'source_path': project.sourcePath,
      'segments': project.segments
          .map((segment) => segment.toJson())
          .toList(),
    });
  }

  Future<Map<String, dynamic>> translate(
    DubProject project,
  ) async {
    final model = await models.path(AiModel.otakuMind);

    if (model == null) {
      throw OfflineEngineException(
        'OtakuMind offline language model is missing.',
      );
    }

    return _invoke('translate', {
      'model_path': model,
      'source_language': project.sourceLanguage,
      'target_language': project.targetLanguage,
      'segments': project.segments
          .map((segment) => segment.toJson())
          .toList(),
    });
  }

  Future<Map<String, dynamic>> refineDialogue(
    DubProject project,
  ) async {
    final model = await models.path(AiModel.otakuMind);

    if (model == null) {
      throw OfflineEngineException(
        'OtakuMind local language model is missing.',
      );
    }

    return _invoke('refineDialogue', {
      'model_path': model,
      'target_language': project.targetLanguage,
      'segments': project.segments
          .map((segment) => segment.toJson())
          .toList(),
    });
  }

  // Offline character voice synthesis.
  // Requires a matching Piper model and configuration.

  Future<Map<String, dynamic>> synthesize(
    DubProject project,
  ) async {
    if (project.targetLanguage != 'hi' &&
        project.targetLanguage != 'en') {
      throw OfflineEngineException(
        'Voice synthesis currently supports Hindi and English.',
      );
    }

    final voiceModel = project.targetLanguage == 'hi'
        ? AiModel.hindiVoice
        : AiModel.englishVoice;

    final config = await models.loadVoiceConfig(voiceModel);

    if (project.segments.isEmpty) {
      throw OfflineEngineException(
        'No dialogue is available for voice synthesis.',
      );
    }

    for (final segment in project.segments) {
      if (segment.translation.trim().isEmpty) {
        throw OfflineEngineException(
          'Translated dialogue is missing for segment ${segment.id}.',
        );
      }

      if (segment.end <= segment.start) {
        throw OfflineEngineException(
          'Invalid dialogue timing for segment ${segment.id}.',
        );
      }
    }

    return _invoke('synthesize', {
      'voice_model_path': config.modelPath,
      'voice_config_path': config.configPath,
      'voice_architecture': config.architecture,
      'sample_rate': config.sampleRate,
      'num_speakers': config.numSpeakers,
      'speaker_id_map': config.speakers,
      'target_language': project.targetLanguage,
      'segments': project.segments
          .map((segment) => segment.toJson())
          .toList(),
      'character_voices': project.characterVoices,
    });
  }

  Future<Map<String, dynamic>> exportVideo(
    DubProject project,
    List<dynamic> audioClips,
  ) {
    return _invoke('exportVideo', {
      'source_path': project.sourcePath,
      'audio_clips': audioClips,
      'preserve_original_audio': true,
      'reduce_original_volume': true,
    });
  }

  // Internal OtakuMind access.
  // The public chatbot interface remains removed.

  Future<String> chat({
    required String message,
    required String personality,
    required String language,
    required List<Map<String, String>> history,
  }) async {
    final model = await models.path(AiModel.otakuMind);

    if (model == null) {
      throw OfflineEngineException(
        'OtakuMind GGUF model is missing.',
      );
    }

    final response = await _invoke('chat', {
      'model_path': model,
      'message': message,
      'personality': personality,
      'language': language,
      'history': history,
    });

    final reply = response['reply'];

    if (reply is! String || reply.trim().isEmpty) {
      throw OfflineEngineException(
        'OtakuMind returned an invalid response.',
      );
    }

    return reply;
  }
}

