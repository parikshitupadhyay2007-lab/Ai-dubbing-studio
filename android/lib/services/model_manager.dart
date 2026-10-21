
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
        AiModel.translator => 'Offline Translation',
        AiModel.speaker => 'Speaker Recognition',
        AiModel.hindiVoice => 'OtakuVoice Hindi',
        AiModel.englishVoice => 'OtakuVoice English',
        AiModel.otakuMind => 'OtakuMind',
      };

  String get extension => switch (this) {
        AiModel.whisper => '.bin',
        AiModel.translator => '.bin',
        AiModel.speaker => '.bin',
        AiModel.hindiVoice => '.onnx',
        AiModel.englishVoice => '.onnx',
        AiModel.otakuMind => '.gguf',
      };

  String get assetPath => 'assets/models/$filename';
}

class ModelManager {
  Future<Directory> get directory async {
    final documents = await getApplicationDocumentsDirectory();

    final folder = Directory(
      '${documents.path}/otakudub/models',
    );

    await folder.create(recursive: true);
    return folder;
  }

  Future<File> modelFile(AiModel model) async {
    final folder = await directory;
    return File('${folder.path}/${model.filename}');
  }

  Future<bool> _valid(File file) async {
    return await file.exists() && await file.length() > 0;
  }

  /// Extracts a bundled model only when no installed copy exists.
  Future<bool> ensureBundledModel(AiModel model) async {
    final destination = await modelFile(model);

    if (await _valid(destination)) return true;

    ByteData data;

    try {
      data = await rootBundle.load(model.assetPath);
    } on FlutterError {
      // This model has not yet been included in the APK.
      return false;
    }

    if (data.lengthInBytes == 0) return false;

    final bytes = Uint8List.sublistView(data);
    final temporary = File('${destination.path}.extracting');

    try {
      if (await temporary.exists()) {
        await temporary.delete();
      }

      await temporary.writeAsBytes(bytes, flush: true);

      if (await temporary.length() != bytes.length) {
        throw StateError(
          '${model.displayName}: extraction verification failed.',
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

  /// Installs every model that is actually bundled in the APK.
  Future<Map<String, bool>> installBundledModels() async {
    final result = <String, bool>{};

    for (final model in AiModel.values) {
      result[model.name] = await ensureBundledModel(model);
    }

    return result;
  }

  Future<bool> installed(AiModel model) async {
    return ensureBundledModel(model);
  }

  Future<String?> path(AiModel model) async {
    if (!await ensureBundledModel(model)) return null;
    return (await modelFile(model)).path;
  }

  Future<int> modelSize(AiModel model) async {
    if (!await ensureBundledModel(model)) return 0;
    return (await modelFile(model)).length();
  }

  Future<bool> importModel(AiModel model) async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
    );

    if (selection == null || selection.files.isEmpty) {
      return false;
    }

    final selectedPath = selection.files.single.path;

    if (selectedPath == null || selectedPath.isEmpty) {
      throw StateError('Selected file could not be accessed.');
    }

    if (!selectedPath.toLowerCase().endsWith(model.extension)) {
      throw StateError(
        '${model.displayName} requires ${model.extension}.',
      );
    }

    final source = File(selectedPath);

    if (!await _valid(source)) {
      throw StateError('Selected model is missing or empty.');
    }

    final destination = await modelFile(model);

    if (source.absolute.path == destination.absolute.path) {
      return true;
    }

    final temporary = File('${destination.path}.importing');

    try {
      if (await temporary.exists()) {
        await temporary.delete();
      }

      await source.copy(temporary.path);

      if (await temporary.length() != await source.length()) {
        throw StateError('Model copy verification failed.');
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
    final result = <String, bool>{};

    for (final model in AiModel.values) {
      result[model.name] = await installed(model);
    }

    return result;
  }
}
