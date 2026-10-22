import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'offline_engine.dart';

/// The pinned SHA identifies the exact public Inst HQ 3 ONNX checkpoint.
/// Shape validation and reference-audio parity remain separate release gates.
class SeparationInstallation {
  static const pinnedSha256 =
      '317554b07fe1ea5279a77f2b1520a41ea4b93432560c4ffd08792c30fddf9adc';

  final String modelPath;
  final String sha256;
  final String inputName;
  final String outputName;
  const SeparationInstallation(this.modelPath, this.sha256, this.inputName, this.outputName);

  static Future<SeparationInstallation> load() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/otakudub/models');
    await directory.create(recursive: true);
    final model = File('${directory.path}/separation.onnx');
    final manifest = File('${directory.path}/separation.json');
    // Bundle extraction is atomic; preserve an existing installation.
    for (final entry in <(String, File)>[
      ('assets/models/separation.onnx', model),
      ('assets/models/separation.json', manifest),
    ]) {
      if (!await entry.$2.exists() || await entry.$2.length() == 0) {
        try {
          final copied = await const MethodChannel(
            'co.parikshit.otakudub/offline_engine',
          ).invokeMethod<int>('installBundledAsset', {
            'asset': entry.$1,
            'destination': entry.$2.path,
          });
          if (copied == null || copied <= 0 ||
              !await entry.$2.exists() ||
              await entry.$2.length() != copied) {
            throw OfflineEngineException(
              'Bundled separation asset was not completely installed: ${entry.$1}',
            );
          }
        } on PlatformException catch (error) {
          throw OfflineEngineException(
            'Cannot install bundled separation asset ${entry.$1}: ${error.message}',
          );
        }
      }
    }
    late final Map<String, dynamic> metadata;
    try {
      metadata = Map<String, dynamic>.from(jsonDecode(await manifest.readAsString()) as Map);
    } catch (_) {
      throw OfflineEngineException('Bundled separation manifest is invalid.');
    }
    final sha = metadata['sha256'];
    final input = metadata['input_name'];
    final output = metadata['output_name'];
    if (metadata['model_id'] != 'UVR-MDX-NET-Inst_HQ_3' ||
        metadata['stem'] != 'instrumental' ||
        sha is! String || sha.toLowerCase() != pinnedSha256 ||
        input is! String || input.trim().isEmpty ||
        output is! String || output.trim().isEmpty) {
      throw OfflineEngineException('Separation model metadata does not match the pinned checkpoint.');
    }
    // Native separation computes the actual file SHA-256 before inference.
    return SeparationInstallation(model.path, pinnedSha256, input, output);
  }
}
