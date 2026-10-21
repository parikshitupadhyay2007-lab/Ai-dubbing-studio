import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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

  Future<bool> _valid(File file) async {
    if (!await file.exists()) return false;
    return await file.length() > 0;
  }

  Future<bool> ensureBundledModel(AiModel model) async {
    final destination = await modelFile(model);

    if (await _valid(destination)) {
      return true;
    }

    ByteData data;

    try {
      data = await rootBundle.load(model.assetPath);
    } on FlutterError {
      return false;
    }

    if (data.lengthInBytes == 0) {
      return false;
    }

    final bytes = Uint8List.sublistView(data);

    final temporary = File(
      '${destination.path}.extracting',
    );

    try {
      if (await temporary.exists()) {
        await temporary.delete();
      }

      await temporary.writeAsBytes(
        bytes,
        flush: true,
      );

      if (await temporary.length() != bytes.length) {
        throw StateError(
          'Incomplete bundled model: ${model.filename}',
        );
      }

      if (await destination.exists()) {
        await destination.delete();
      }

      await temporary.rename(destination.path);

      return true;
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  Future<Map<String, bool>> installBundledModels() async {
    final results = <String, bool>{};

    for (final model in AiModel.values) {
      results[model.name] = await ensureBundledModel(model);
    }

    return results;
  }

  Future<bool> installed(AiModel model) async {
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

    if (!await file.exists()) {
      return 0;
    }

    return file.length();
  }

  Future<bool> importModel(AiModel model) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [model.extension],
    );

    if (result == null || result.files.isEmpty) {
      return false;
    }

    final selected = result.files.single;

    if (selected.path == null) {
      return false;
    }

    final source = File(selected.path!);

    if (!await _valid(source)) {
      throw StateError('Selected model file is empty.');
    }

    final destination = await modelFile(model);

    final temporary = File(
      '${destination.path}.importing',
    );

    try {
      if (await temporary.exists()) {
        await temporary.delete();
      }

      await source.copy(temporary.path);

      if (await temporary.length() != await source.length()) {
        throw StateError('Model import was incomplete.');
      }

      if (await destination.exists()) {
        await destination.delete();
      }

      await temporary.rename(destination.path);

      return true;
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  Future<List<AiModel>> missingModels() async {
    final missing = <AiModel>[];

    for (final model in AiModel.values) {
      if (!await installed(model)) {
        missing.add(model);
      }
    }

    return missing;
  }

  Future<Map<String, bool>> installationStatus() async {
    final status = <String, bool>{};

    for (final model in AiModel.values) {
      status[model.name] = await installed(model);
    }

    return status;
  }
}
