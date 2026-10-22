import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'voice_model_config.dart';

enum AiModel {
  whisper,
  translator,
  speaker,
  hindiVoice,
  englishVoice,
  otakuMind,
}

extension AiModelName on AiModel {
  String get filename => switch (this) {
        AiModel.whisper => 'whisper.bin',
        AiModel.translator => 'translator.bin',
        AiModel.speaker => 'speaker.bin',
        AiModel.hindiVoice => 'hindi_voice.onnx',
        AiModel.englishVoice => 'english_voice.onnx',
        AiModel.otakuMind => 'otakumind.gguf',
      };

  String get displayName => switch (this) {
        AiModel.whisper => 'Whisper Speech Recognition',
        AiModel.translator => 'Offline Translator',
        AiModel.speaker => 'Speaker Recognition',
        AiModel.hindiVoice => 'Hindi Voice Engine',
        AiModel.englishVoice => 'English Voice Engine',
        AiModel.otakuMind => 'OtakuMind',
      };

  String get extension => switch (this) {
        AiModel.whisper ||
        AiModel.translator ||
        AiModel.speaker => 'bin',
        AiModel.hindiVoice ||
        AiModel.englishVoice => 'onnx',
        AiModel.otakuMind => 'gguf',
      };

  String get assetPath => 'assets/models/$filename';

  bool get isVoice =>
      this == AiModel.hindiVoice ||
      this == AiModel.englishVoice;

  String? get voiceLanguage => switch (this) {
        AiModel.hindiVoice => 'hi',
        AiModel.englishVoice => 'en',
        _ => null,
      };

  String? get configFilename =>
      isVoice ? '$filename.json' : null;
}

class ModelManager {
  Future<Directory> get directory async {
    final documents = await getApplicationDocumentsDirectory();

    final models = Directory(
      '${documents.path}/otakudub/models',
    );

    if (!await models.exists()) {
      await models.create(recursive: true);
    }

    return models;
  }

  Future<File> modelFile(AiModel model) async {
    final folder = await directory;
    return File('${folder.path}/${model.filename}');
  }

  Future<File?> voiceConfigFile(AiModel model) async {
    final filename = model.configFilename;

    if (filename == null) return null;

    final folder = await directory;
    return File('${folder.path}/$filename');
  }

  Future<bool> _valid(File file) async {
    return await file.exists() && await file.length() > 0;
  }

  Future<bool> _validWhisper(File file) async {
    if (!await _valid(file) || await file.length() != 147951465) return false;
    final reader = await file.open();
    try {
      final header = await reader.read(4);
      return header.length == 4 &&
          header[0] == 0x67 && header[1] == 0x67 &&
          header[2] == 0x6d && header[3] == 0x6c;
    } finally {
      await reader.close();
    }
  }

  Future<bool> _validOtakuMind(File file) async {
    if (!await _valid(file) || await file.length() < 400000000) return false;
    final reader = await file.open();
    try {
      final header = await reader.read(4);
      return header.length == 4 && String.fromCharCodes(header) == 'GGUF';
    } finally {
      await reader.close();
    }
  }

  Future<void> _copyAtomically(
    File source,
    File destination,
  ) async {
    if (!await _valid(source)) {
      throw StateError('Source file is missing or empty.');
    }

    final temporary = File('${destination.path}.importing');

    try {
      if (await temporary.exists()) {
        await temporary.delete();
      }

      await source.copy(temporary.path);

      if (await temporary.length() != await source.length()) {
        throw StateError('Incomplete file import.');
      }

      if (await destination.exists()) {
        await destination.delete();
      }

      await temporary.rename(destination.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  Future<bool> _extractAsset(
    String assetPath,
    File destination,
  ) async {
    // Android AssetManager streams large bundled models without allocating
    // the entire GGUF or Whisper model in the Dart heap.
    try {
      final length = await const MethodChannel(
        'co.parikshit.otakudub/offline_engine',
      ).invokeMethod<int>('installBundledAsset', {
        'asset': assetPath,
        'destination': destination.path,
      });
      return length != null && length > 0 &&
          await destination.exists() &&
          await destination.length() == length;
    } on PlatformException catch (error) {
      debugPrint('Bundled model installation failed ($assetPath): $error');
      return false;
    } on MissingPluginException {
      debugPrint('Native bundled asset installer is unavailable.');
      return false;
    }
  }

  Future<bool> ensureBundledModel(AiModel model) async {
    final destination = await modelFile(model);

    final validBefore = model == AiModel.otakuMind
        ? await _validOtakuMind(destination)
        : model == AiModel.whisper
            ? await _validWhisper(destination)
            : await _valid(destination);
    if (!validBefore) {
      final extracted = await _extractAsset(
        model.assetPath,
        destination,
      );

      if (!extracted) return false;
    }

    if (model == AiModel.otakuMind) return _validOtakuMind(destination);
    if (model == AiModel.whisper) return _validWhisper(destination);
    if (!model.isVoice) return true;

    final config = await voiceConfigFile(model);

    if (config == null) return false;

    if (!await _valid(config)) {
      final extracted = await _extractAsset(
        'assets/models/${model.configFilename}',
        config,
      );

      if (!extracted) return false;
    }

    return await validateVoiceModel(model);
  }

  Future<bool> validateVoiceModel(AiModel model) async {
    if (!model.isVoice) return false;

    final file = await modelFile(model);
    final config = await voiceConfigFile(model);

    if (config == null ||
        !await _valid(file) ||
        !await _valid(config)) {
      return false;
    }

    try {
      await VoiceModelConfig.load(
        modelPath: file.path,
        configPath: config.path,
        expectedLanguage: model.voiceLanguage!,
      );

      return true;
    } catch (error) {
      debugPrint(
        'OtakuDub voice validation failed: $error',
      );
      return false;
    }
  }

  Future<VoiceModelConfig> loadVoiceConfig(
    AiModel model,
  ) async {
    if (!model.isVoice) {
      throw ArgumentError('Selected model is not a voice model.');
    }

    if (!await ensureBundledModel(model)) {
      throw StateError(
        'Missing or incompatible ${model.displayName} files.',
      );
    }

    final file = await modelFile(model);
    final config = await voiceConfigFile(model);

    return VoiceModelConfig.load(
      modelPath: file.path,
      configPath: config!.path,
      expectedLanguage: model.voiceLanguage!,
    );
  }

  Future<Map<String, bool>> installBundledModels() async {
    final results = <String, bool>{};

    for (final model in [AiModel.whisper, AiModel.otakuMind]) {
      results[model.name] = await ensureBundledModel(model);
    }

    return results;
  }

  Future<bool> installed(AiModel model) {
    return ensureBundledModel(model);
  }

  Future<String?> path(AiModel model) async {
    if (!await ensureBundledModel(model)) {
      return null;
    }

    return (await modelFile(model)).path;
  }

  Future<int> modelSize(AiModel model) async {
    final file = await modelFile(model);

    if (!await file.exists()) return 0;

    return file.length();
  }

  Future<bool> importModel(AiModel model) async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [model.extension],
    );

    if (selection == null || selection.files.isEmpty) {
      return false;
    }

    final selectedPath = selection.files.single.path;

    if (selectedPath == null) return false;

    final destination = await modelFile(model);

    await _copyAtomically(
      File(selectedPath),
      destination,
    );

    return model.isVoice
        ? validateVoiceModel(model)
        : _valid(destination);
  }

  Future<bool> importVoiceConfig(AiModel model) async {
    if (!model.isVoice) {
      throw ArgumentError('A voice model must be selected.');
    }

    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (selection == null || selection.files.isEmpty) {
      return false;
    }

    final selectedPath = selection.files.single.path;

    if (selectedPath == null) return false;

    final destination = await voiceConfigFile(model);

    if (destination == null) return false;

    await _copyAtomically(
      File(selectedPath),
      destination,
    );

    return validateVoiceModel(model);
  }

  Future<List<AiModel>> missingModels() async {
    final missing = <AiModel>[];

    for (final model in [AiModel.whisper, AiModel.otakuMind]) {
      if (!await installed(model)) {
        missing.add(model);
      }
    }

    return missing;
  }

  Future<Map<String, bool>> installationStatus() async {
    final status = <String, bool>{};

    for (final model in [AiModel.whisper, AiModel.otakuMind]) {
      status[model.name] = await installed(model);
    }

    return status;
  }
}
