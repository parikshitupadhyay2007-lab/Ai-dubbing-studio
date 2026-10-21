import 'package:flutter/services.dart';

import '../models/dub_project.dart';
import 'model_manager.dart';
import 'voice_catalog.dart';

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

  Future<Map<String, dynamic>> synthesize(
    DubProject project,
  ) async {
    if (project.targetLanguage != 'hi' &&
        project.targetLanguage != 'en') {
      throw OfflineEngineException(
        'Voice synthesis currently supports Hindi and English.',
      );
    }

    if (project.segments.isEmpty) {
      throw OfflineEngineException(
        'No dialogue is available for voice synthesis.',
      );
    }

    final voiceModels = <String, Map<String, dynamic>>{};

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

      final speakerId = segment.speakerId.trim();
      final voiceId = segment.voiceId.trim();

      if (speakerId.isEmpty || speakerId == 'unknown') {
        throw OfflineEngineException(
          'Speaker identification is incomplete for segment ${segment.id}.',
        );
      }

      if (voiceId.isEmpty) {
        throw OfflineEngineException(
          'No voice assigned to segment ${segment.id}.',
        );
      }

      if (project.characterVoices[speakerId] != voiceId) {
        throw OfflineEngineException(
          'Character voice assignment mismatch for segment ${segment.id}.',
        );
      }

      final profile = VoiceCatalog.byId(voiceId);

      if (profile.language != project.targetLanguage) {
        throw OfflineEngineException(
          'Voice $voiceId does not support the target language.',
        );
      }

      final installed = VoiceCatalog.installedModel(voiceId);

      if (installed == null) {
        throw OfflineEngineException(
          'Character voice $voiceId is not installed.',
        );
      }

      final config = installed.config;

      voiceModels[voiceId] = {
        'model_id': installed.modelId,
        'profile_id': installed.profileId,
        'model_path': config.modelPath,
        'config_path': config.configPath,
        'architecture': config.architecture,
        'language': config.language,
        'sample_rate': config.sampleRate,
        'num_speakers': config.numSpeakers,
        'speaker_id_map': config.speakers,
      };
    }

    if (voiceModels.isEmpty) {
      throw OfflineEngineException(
        'No usable character voice models were assigned.',
      );
    }

    return _invoke('synthesize', {
      'target_language': project.targetLanguage,
      'segments': project.segments
          .map((segment) => segment.toJson())
          .toList(),
      'character_voices':
          Map<String, String>.from(project.characterVoices),
      'voice_models': voiceModels,
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
