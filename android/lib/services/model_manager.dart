
import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
}

class ModelManager {
  Future<Directory> get directory async {
    final documents = await getApplicationDocumentsDirectory();

    final folder = Directory(
      '${documents.path}/otakudub/models',
    );

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    return folder;
  }

  Future<File> modelFile(AiModel model) async {
    final folder = await directory;

    return File(
      '${folder.path}/${model.filename}',
    );
  }

  Future<bool> installed(AiModel model) async {
    final file = await modelFile(model);

    if (!await file.exists()) {
      return false;
    }

    return await file.length() > 0;
  }

  Future<String?> path(AiModel model) async {
    if (!await installed(model)) {
      return null;
    }

    final file = await modelFile(model);
    return file.path;
  }

  Future<int> modelSize(AiModel model) async {
    final file = await modelFile(model);

    if (!await file.exists()) {
      return 0;
    }

    return file.length();
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
      throw StateError(
        'The selected file could not be accessed.',
      );
    }

    final source = File(selectedPath);

    if (!await source.exists()) {
      throw StateError(
        'The selected model file does not exist.',
      );
    }

    final sourceSize = await source.length();

    if (sourceSize <= 0) {
      throw StateError(
        'The selected model file is empty.',
      );
    }

    if (!selectedPath.toLowerCase().endsWith(model.extension)) {
      throw StateError(
        '${model.displayName} requires a '
        '${model.extension} model file.',
      );
    }

    final destination = await modelFile(model);

    if (source.absolute.path == destination.absolute.path) {
      return true;
    }

    final temporary = File(
      '${destination.path}.importing',
    );

    try {
      if (await temporary.exists()) {
        await temporary.delete();
      }

      await source.copy(temporary.path);

      final copiedSize = await temporary.length();

      if (copiedSize != sourceSize) {
        throw StateError(
          'Model import failed: copied file size does not match.',
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
