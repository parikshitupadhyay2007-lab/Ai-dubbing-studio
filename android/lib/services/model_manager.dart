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
}

class ModelManager {
  Future<Directory> get directory async {
    final docs = await getApplicationDocumentsDirectory();

    final folder = Directory('${docs.path}/otakudub/models');
    await folder.create(recursive: true);

    return folder;
  }

  Future<File> modelFile(AiModel model) async {
    final folder = await directory;
    return File('${folder.path}/${model.filename}');
  }

  Future<bool> installed(AiModel model) async {
    final file = await modelFile(model);

    return file.existsSync() && file.lengthSync() > 0;
  }

  Future<String?> path(AiModel model) async {
    final file = await modelFile(model);

    if (!await installed(model)) return null;

    return file.path;
  }

  Future<bool> importModel(AiModel model) async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );

    if (selection == null) return false;

    final selected = selection.files.single.path;
    if (selected == null) return false;

    final source = File(selected);

    if (!await source.exists() || await source.length() == 0) {
      throw StateError('The selected model file is empty or missing.');
    }

    final destination = await modelFile(model);

    if (source.absolute.path != destination.absolute.path) {
      await source.copy(destination.path);
    }

    return true;
  }

  Future<List<AiModel>> missingModels() async {
    final missing = <AiModel>[];

    for (final model in AiModel.values) {
      if (!await installed(model)) missing.add(model);
    }

    return missing;
  }
}
