import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'voice_catalog.dart';

class VoiceInstallationRegistry {
  const VoiceInstallationRegistry();

  Future<Directory> get _directory async {
    final documents = await getApplicationDocumentsDirectory();

    final directory = Directory(
      '${documents.path}/otakudub/voices',
    );

    await directory.create(recursive: true);
    return directory;
  }

  /// Rebuilds the voice catalog from installed model/config pairs.
  ///
  /// Invalid or incomplete pairs are skipped. This does not delete
  /// downloaded files or claim that ONNX inference has been tested.
  Future<List<InstalledVoiceModel>> restore() async {
    VoiceCatalog.clearInstalled();

    final directory = await _directory;
    // Install verified voice/config pairs packaged with the APK on first launch.
    for (final profileId in ['hi_hero', 'en_hero']) {
      final model = File('${directory.path}/$profileId.onnx');
      final config = File('${directory.path}/$profileId.onnx.json');
      if (!await model.exists() || !await config.exists()) {
        final source = 'assets/models/voices/$profileId';
        final modelBytes = await rootBundle.load('$source.onnx');
        final configBytes = await rootBundle.load('$source.onnx.json');
        final pendingModel = File('${model.path}.partial');
        final pendingConfig = File('${config.path}.partial');
        await pendingModel.writeAsBytes(modelBytes.buffer.asUint8List(modelBytes.offsetInBytes, modelBytes.lengthInBytes), flush: true);
        await pendingConfig.writeAsBytes(configBytes.buffer.asUint8List(configBytes.offsetInBytes, configBytes.lengthInBytes), flush: true);
        await pendingModel.rename(model.path);
        await pendingConfig.rename(config.path);
      }
    }
    final restored = <InstalledVoiceModel>[];

    for (final profile in VoiceCatalog.profiles) {
      final model = File(
        '${directory.path}/${profile.id}.onnx',
      );

      final config = File(
        '${directory.path}/${profile.id}.onnx.json',
      );

      if (!await model.exists() || !await config.exists()) {
        continue;
      }

      try {
        final installed = await VoiceCatalog.registerInstalled(
          profileId: profile.id,
          modelId: profile.id,
          modelPath: model.path,
          configPath: config.path,
        );

        restored.add(installed);
      } catch (_) {
        VoiceCatalog.unregister(profile.id);
      }
    }

    return List.unmodifiable(restored);
  }

  /// Call after a successful download to refresh the catalog.
  Future<List<InstalledVoiceModel>> refresh() => restore();

  Future<bool> isInstalled(String profileId) async {
    VoiceCatalog.byId(profileId);

    final directory = await _directory;

    final model = File(
      '${directory.path}/$profileId.onnx',
    );

    final config = File(
      '${directory.path}/$profileId.onnx.json',
    );

    if (!await model.exists() || !await config.exists()) {
      VoiceCatalog.unregister(profileId);
      return false;
    }

    try {
      await VoiceCatalog.registerInstalled(
        profileId: profileId,
        modelId: profileId,
        modelPath: model.path,
        configPath: config.path,
      );

      return true;
    } catch (_) {
      VoiceCatalog.unregister(profileId);
      return false;
    }
  }
}
