
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
  static const _channel = MethodChannel(
    'co.parikshit.otakudub/offline_engine',
  );

  final ModelManager models;

  OfflineEngine(this.models);

  Future<void> verifyRuntime() async {
    try {
      final ready = await _channel.invokeMethod<bool>('runtimeReady');

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
      final response = await _channel.invokeMapMethod<String, dynamic>(
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
  ) async {
    final model = await models.path(AiModel.speaker);

    if (model == null) {
      throw OfflineEngineException(
        'Speaker identification model is missing.',
      );
    }

    return _invoke('identifySpeakers', {
      'source_path': project.sourcePath,
      'model_path': model,
      'segments': project.segments.map((s) => s.toJson()).toList(),
    });
  }

  Future<Map<String, dynamic>> translate(
    DubProject project,
  ) async {
    final model = await models.path(AiModel.translator);

    if (model == null) {
      throw OfflineEngineException(
        'Compatible offline translation model is missing.',
      );
    }

    return _invoke('translate', {
      'model_path': model,
      'source_language': project.sourceLanguage,
      'target_language': project.targetLanguage,
      'segments': project.segments.map((s) => s.toJson()).toList(),
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
      'segments': project.segments.map((s) => s.toJson()).toList(),
    });
  }

  Future<Map<String, dynamic>> synthesize(
    DubProject project,
  ) async {
    final voiceModel = project.targetLanguage == 'hi'
        ? AiModel.hindiVoice
        : AiModel.englishVoice;

    final voicePath = await models.path(voiceModel);

    if (voicePath == null) {
      throw OfflineEngineException(
        'Install a compatible local voice model first.',
      );
    }

    return _invoke('synthesize', {
      'voice_model_path': voicePath,
      'target_language': project.targetLanguage,
      'segments': project.segments.map((s) => s.toJson()).toList(),
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

  Future<String> chat({
    required String message,
    required String personality,
    required String language,
    required List<Map<String, String>> history,
  }) async {
    final model = await models.path(AiModel.otakuMind);

    if (model == null) {
      throw OfflineEngineException(
        'Import a compatible OtakuMind GGUF model first.',
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
        'Local OtakuMind returned an invalid response.',
      );
    }

    return reply;
  }
}
