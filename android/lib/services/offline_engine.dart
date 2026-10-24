import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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

  /// Runs native FFT and STFT numerical diagnostics.
  ///
  /// Returns an overall pass/fail status and twelve individual
  /// reconstruction test results.
  ///
  /// No ONNX model is required for these tests.
  Future<Map<String, dynamic>>
      validateSeparationTransforms() async {
    final response = await _invoke(
      'validateSeparationTransforms',
      <String, dynamic>{},
    );

    if (response['passed'] is! bool ||
        response['tests'] is! List) {
      throw OfflineEngineException(
        'Invalid separation validation report.',
      );
    }

    return response;
  }

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

  /// Inspects an installed ONNX separation model.
  ///
  /// Returns its input and output tensor metadata.
  /// This does not execute audio separation.
  Future<Map<String, dynamic>> inspectSeparationModel(
    String modelPath,
  ) async {
    if (modelPath.trim().isEmpty) {
      throw OfflineEngineException(
        'Separation model path is required.',
      );
    }

    final model = File(modelPath);

    if (!await model.exists()) {
      throw OfflineEngineException(
        'Separation model file does not exist.',
      );
    }

    return _invoke('inspectSeparationModel', {
      'model_path': modelPath,
    });
  }

  Future<Map<String, dynamic>> separateSoundtrack({
    required String sourcePath,
    required String modelPath,
    required String checkpointSha256,
    required String inputName,
    required String outputName,
  }) async {
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(checkpointSha256)) {
      throw OfflineEngineException('A trusted checkpoint checksum is required.');
    }
    if (!await File(sourcePath).exists() || !await File(modelPath).exists()) {
      throw OfflineEngineException('Source or separation model is missing.');
    }
    final result = await _invoke('separateSoundtrack', {
      'source_path': sourcePath,
      'model_path': modelPath,
      'checkpoint_sha256': checkpointSha256,
      'input_name': inputName,
      'output_name': outputName,
    });
    for (final key in ['vocals_path', 'accompaniment_path']) {
      final path = result[key];
      if (path is! String || !await File(path).exists() ||
          await File(path).length() <= 44) {
        throw OfflineEngineException('Missing separation output: $key');
      }
    }
    return result;
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
    DubProject project, {
    String? speakerModelManifest,
  }) async {
    // A trained pack is selected explicitly or discovered from the app's
    // model directory. A malformed installed pack must fail visibly.
    final selected = speakerModelManifest ??
        (await models.directory).uri
            .resolve('speaker/manifest.json')
            .toFilePath();
    final manifest = File(selected);
    final bundledManifest = speakerModelManifest == null
        ? await rootBundle.loadString('assets/models/speaker/manifest.json')
        : null;
    final needsRefresh = bundledManifest != null &&
        (!await manifest.exists() || await manifest.readAsString() != bundledManifest ||
         !await File('${manifest.parent.path}/model.onnx').exists() ||
         !await File('${manifest.parent.path}/LICENSE.txt').exists());
    if (needsRefresh) {
      final folder = manifest.parent;
      await folder.create(recursive: true);
      for (final name in ['model.onnx', 'LICENSE.txt', 'manifest.json']) {
        final destination = File('${folder.path}/$name');
        final bytes = await const MethodChannel(
          'co.parikshit.otakudub/offline_engine',
        ).invokeMethod<int>('installBundledAsset', {
          'asset': 'assets/models/speaker/$name',
          'destination': destination.path,
        });
        if (bytes == null || bytes <= 0 || !await destination.exists() ||
            await destination.length() != bytes) {
          throw OfflineEngineException('Cannot install trained speaker asset: $name');
        }
      }
    }
    if (!await manifest.exists()) {
      throw OfflineEngineException(
        'Trained speaker model pack is missing: $selected',
      );
    }
    return _invoke('identifySpeakers', {
      'source_path': project.sourcePath,
      'segments': project.segments
          .map((segment) => segment.toJson())
          .toList(),
      'speaker_model_manifest': selected,
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

  Future<void> _installSupertonic() async {
    final manifestText = await rootBundle.loadString('assets/models/supertonic3/asset_manifest.json');
    final manifest = jsonDecode(manifestText) as Map<String, dynamic>;
    if (manifest['engine'] != 'supertonic-3') {
      throw OfflineEngineException('Invalid Supertonic manifest.');
    }
    final entries = manifest['assets'] as Map<String, dynamic>;
    final root = Directory('${(await getApplicationSupportDirectory()).path}/supertonic3');
    for (final entry in entries.entries) {
      final name = entry.key;
      if (name.contains('..') || name.startsWith('/') ||
          !RegExp(r'^[A-Za-z0-9_./-]+
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

      final styles = <String, String>{
        'hi_hero': 'M1', 'hi_heroine': 'F1',
        'en_hero': 'M1', 'en_young_male': 'M2',
      };
      if (!styles.containsKey(voiceId)) {
        throw OfflineEngineException('Supertonic style missing for $voiceId');
      }
      voiceModels[voiceId] = {
        'model_id': 'supertonic-3',
        'profile_id': voiceId,
        'model_path': 'bundled-supertonic-3',
        'config_path': 'bundled-supertonic-3',
        'architecture': 'supertonic3',
        'language': project.targetLanguage,
        'sample_rate': 24000,
        'num_speakers': 1,
        'speaker_id_map': <String, int>{},
      };
    }

    if (voiceModels.isEmpty) {
      throw OfflineEngineException(
        'No usable character voice models were assigned.',
      );
    }

    await _installSupertonic();
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

  /// Places synthesized WAV clips onto the source video's
  /// dialogue timeline.
  Future<Map<String, dynamic>> mixDialogue(
    DubProject project,
    List<dynamic> audioClips,
  ) async {
    if (audioClips.isEmpty) {
      throw OfflineEngineException(
        'Cannot mix an empty dialogue clip list.',
      );
    }

    final clips = <Map<String, dynamic>>[];

    for (final item in audioClips) {
      if (item is! Map) {
        throw OfflineEngineException(
          'Invalid synthesized dialogue clip.',
        );
      }

      clips.add(Map<String, dynamic>.from(item));
    }

    final result = await _invoke('mixDialogue', {
      'source_path': project.sourcePath,
      'clips': clips,
    });

    final wavPath = result['wav_path'];

    if (wavPath is! String || wavPath.isEmpty) {
      throw OfflineEngineException(
        'Dialogue mixing returned no WAV path.',
      );
    }

    if (!await File(wavPath).exists()) {
      throw OfflineEngineException(
        'The synchronized dialogue WAV was not created.',
      );
    }

    return result;
  }

  Future<String> mixSoundtrack({
    required String dialogueWavPath,
    required String accompanimentPath,
  }) async {
    for (final path in [dialogueWavPath, accompanimentPath]) {
      if (!await File(path).exists()) {
        throw OfflineEngineException('Required soundtrack WAV is missing: $path');
      }
    }
    final result = await _invoke('mixSoundtrack', {
      'dialogue_wav_path': dialogueWavPath,
      'accompaniment_path': accompanimentPath,
    });
    final path = result['wav_path'];
    if (path is! String || !await File(path).exists() ||
        await File(path).length() <= 44) {
      throw OfflineEngineException('Soundtrack recombination produced no audio.');
    }
    return path;
  }

  /// Exports a dubbed MP4 using the original video stream
  /// and synchronized dialogue WAV.
  ///
  /// The original soundtrack is replaced, not mixed.
  Future<Map<String, dynamic>> exportVideo(
    DubProject project,
    String dialogueWavPath,
  ) async {
    final dialogue = File(dialogueWavPath);

    if (!await dialogue.exists()) {
      throw OfflineEngineException(
        'Synchronized dialogue WAV is missing.',
      );
    }

    final source = File(project.sourcePath);

    if (!await source.exists()) {
      throw OfflineEngineException(
        'Original source video is missing.',
      );
    }

    // The imported source may live in a read-only picker/cache directory.
    // Export into OtakuDub's writable, persistent project storage instead.
    final docs = await getApplicationDocumentsDirectory();
    final outputDirectory = Directory(
      '${docs.path}/otakudub/projects/${project.id}',
    );
    await outputDirectory.create(recursive: true);

    final outputPath =
        '${outputDirectory.path}/OtakuDub-${project.id}.mp4';

    final response = await _invoke('exportVideo', {
      'source_path': project.sourcePath,
      'dialogue_wav_path': dialogueWavPath,
      'output_path': outputPath,
    });

    final exportedPath = response['output_path'];

    if (exportedPath is! String || exportedPath.isEmpty) {
      throw OfflineEngineException(
        'Video export returned no output path.',
      );
    }

    final exportedFile = File(exportedPath);

    if (!await exportedFile.exists() ||
        await exportedFile.length() == 0) {
      throw OfflineEngineException(
        'The exported MP4 is missing or empty.',
      );
    }

    return response;
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
).hasMatch(name)) {
        throw OfflineEngineException('Invalid Supertonic asset path.');
      }
      final spec = entry.value as Map<String, dynamic>;
      final file = File('${root.path}/$name');
      final size = (spec['bytes'] as num).toInt();
      final hash = spec['sha256'] as String;
      Future<bool> verified() async =>
          await file.exists() && await file.length() == size &&
          (await sha256.bind(file.openRead()).first).toString() == hash;
      if (await verified()) continue;
      await file.parent.create(recursive: true);
      final installed = await _channel.invokeMethod<int>('installBundledAsset', {
        'asset': 'assets/models/supertonic3/$name',
        'destination': file.path,
      });
      if (installed != size || !await verified()) {
        throw OfflineEngineException('Supertonic asset verification failed: $name');
      }
    }
  }

  Future<Map<String, dynamic>> validateSupertonicOnDevice() async {
    await _installSupertonic();
    final report = await _invoke('supertonicSmokeTest', <String, dynamic>{});
    if (report['passed'] != true || report['clips'] is! List ||
        (report['clips'] as List).length != 2) {
      throw OfflineEngineException('Supertonic device test failed.');
    }
    return report;
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

  /// Places synthesized WAV clips onto the source video's
  /// dialogue timeline.
  Future<Map<String, dynamic>> mixDialogue(
    DubProject project,
    List<dynamic> audioClips,
  ) async {
    if (audioClips.isEmpty) {
      throw OfflineEngineException(
        'Cannot mix an empty dialogue clip list.',
      );
    }

    final clips = <Map<String, dynamic>>[];

    for (final item in audioClips) {
      if (item is! Map) {
        throw OfflineEngineException(
          'Invalid synthesized dialogue clip.',
        );
      }

      clips.add(Map<String, dynamic>.from(item));
    }

    final result = await _invoke('mixDialogue', {
      'source_path': project.sourcePath,
      'clips': clips,
    });

    final wavPath = result['wav_path'];

    if (wavPath is! String || wavPath.isEmpty) {
      throw OfflineEngineException(
        'Dialogue mixing returned no WAV path.',
      );
    }

    if (!await File(wavPath).exists()) {
      throw OfflineEngineException(
        'The synchronized dialogue WAV was not created.',
      );
    }

    return result;
  }

  Future<String> mixSoundtrack({
    required String dialogueWavPath,
    required String accompanimentPath,
  }) async {
    for (final path in [dialogueWavPath, accompanimentPath]) {
      if (!await File(path).exists()) {
        throw OfflineEngineException('Required soundtrack WAV is missing: $path');
      }
    }
    final result = await _invoke('mixSoundtrack', {
      'dialogue_wav_path': dialogueWavPath,
      'accompaniment_path': accompanimentPath,
    });
    final path = result['wav_path'];
    if (path is! String || !await File(path).exists() ||
        await File(path).length() <= 44) {
      throw OfflineEngineException('Soundtrack recombination produced no audio.');
    }
    return path;
  }

  /// Exports a dubbed MP4 using the original video stream
  /// and synchronized dialogue WAV.
  ///
  /// The original soundtrack is replaced, not mixed.
  Future<Map<String, dynamic>> exportVideo(
    DubProject project,
    String dialogueWavPath,
  ) async {
    final dialogue = File(dialogueWavPath);

    if (!await dialogue.exists()) {
      throw OfflineEngineException(
        'Synchronized dialogue WAV is missing.',
      );
    }

    final source = File(project.sourcePath);

    if (!await source.exists()) {
      throw OfflineEngineException(
        'Original source video is missing.',
      );
    }

    // The imported source may live in a read-only picker/cache directory.
    // Export into OtakuDub's writable, persistent project storage instead.
    final docs = await getApplicationDocumentsDirectory();
    final outputDirectory = Directory(
      '${docs.path}/otakudub/projects/${project.id}',
    );
    await outputDirectory.create(recursive: true);

    final outputPath =
        '${outputDirectory.path}/OtakuDub-${project.id}.mp4';

    final response = await _invoke('exportVideo', {
      'source_path': project.sourcePath,
      'dialogue_wav_path': dialogueWavPath,
      'output_path': outputPath,
    });

    final exportedPath = response['output_path'];

    if (exportedPath is! String || exportedPath.isEmpty) {
      throw OfflineEngineException(
        'Video export returned no output path.',
      );
    }

    final exportedFile = File(exportedPath);

    if (!await exportedFile.exists() ||
        await exportedFile.length() == 0) {
      throw OfflineEngineException(
        'The exported MP4 is missing or empty.',
      );
    }

    return response;
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
