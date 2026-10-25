import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'voice_model_config.dart';

typedef VoiceDownloadProgress = void Function(
  String stage,
  int received,
  int total,
);

class VoiceModelDownloader {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30);

  Future<Directory> get voiceDirectory async {
    final documents = await getApplicationDocumentsDirectory();

    final directory = Directory(
      '${documents.path}/otakudub/voices',
    );

    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _download({
    required Uri url,
    required File destination,
    VoiceDownloadProgress? onProgress,
    required String stage,
  }) async {
    if (url.scheme != 'https') {
      throw ArgumentError('HTTPS is required for model downloads.');
    }

    final request = await _client.getUrl(url);
    final response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException(
        'Download failed: HTTP ${response.statusCode}',
        uri: url,
      );
    }

    final sink = destination.openWrite();
    var received = 0;
    final total = response.contentLength;

    try {
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(stage, received, total);
      }

      await sink.flush();
    } finally {
      await sink.close();
    }

    if (received == 0) {
      throw StateError('Downloaded file is empty.');
    }

    if (total >= 0 && received != total) {
      throw StateError('Incomplete download: $stage');
    }
  }

  Future<VoiceModelConfig> install({
    required String voiceId,
    required String language,
    required Uri modelUrl,
    required Uri configUrl,
    VoiceDownloadProgress? onProgress,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(voiceId)) {
      throw ArgumentError('Invalid voice identifier.');
    }

    final directory = await voiceDirectory;

    final model = File('${directory.path}/$voiceId.onnx');
    final config = File('${directory.path}/$voiceId.onnx.json');

    final temporaryModel =
        File('${directory.path}/$voiceId.onnx.download');

    final temporaryConfig =
        File('${directory.path}/$voiceId.onnx.json.download');

    try {
      for (final file in [temporaryModel, temporaryConfig]) {
        if (await file.exists()) {
          await file.delete();
        }
      }

      await _download(
        url: modelUrl,
        destination: temporaryModel,
        stage: 'Downloading voice model',
        onProgress: onProgress,
      );

      await _download(
        url: configUrl,
        destination: temporaryConfig,
        stage: 'Downloading voice configuration',
        onProgress: onProgress,
      );

      // Validate the downloaded pair before installation.
      await VoiceModelConfig.load(
        modelPath: temporaryModel.path,
        configPath: temporaryConfig.path,
        expectedLanguage: language,
      );

      if (await model.exists()) await model.delete();
      if (await config.exists()) await config.delete();

      await temporaryModel.rename(model.path);
      await temporaryConfig.rename(config.path);

      return await VoiceModelConfig.load(
        modelPath: model.path,
        configPath: config.path,
        expectedLanguage: language,
      );
    } finally {
      for (final file in [temporaryModel, temporaryConfig]) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  void dispose() {
    _client.close();
  }
}
