import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

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
    for (final profileId in ['hi_hero', 'hi_heroine', 'en_hero', 'en_young_male']) {
      final model = File('${directory.path}/$profileId.onnx');
      final config = File('${directory.path}/$profileId.onnx.json');
      for (final entry in <(String, File)>[
        ('assets/models/voices/$profileId.onnx', model),
        ('assets/models/voices/$profileId.onnx.json', config),
      ]) {
        if (!await entry.$2.exists() || await entry.$2.length() == 0) {
          final copied = await const MethodChannel(
            'co.parikshit.otakudub/offline_engine',
          ).invokeMethod<int>('installBundledAsset', {
            'asset': entry.$1,
            'destination': entry.$2.path,
          });
          if (copied == null || copied <= 0 ||
              !await entry.$2.exists() ||
              await entry.$2.length() != copied) {
            throw StateError('Unable to install bundled voice asset: ${entry.$1}');
          }
        }
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
