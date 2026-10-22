import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'offline_engine.dart';

/// Loads the local checkpoint and its declared metadata. A self-supplied
/// manifest is NOT an independently trusted release pin or proof of stem
/// polarity. Production release must pin a reviewed digest in app code.
class SeparationInstallation {
  final String modelPath;
  final String sha256;
  final String inputName;
  final String outputName;

  const SeparationInstallation(this.modelPath, this.sha256, this.inputName, this.outputName);

  static Future<SeparationInstallation> load() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/otakudub/models');
    final model = File('${directory.path}/separation.onnx');
    final manifest = File('${directory.path}/separation.json');
    if (!await model.exists() || await model.length() == 0 ||
        !await manifest.exists()) {
      throw OfflineEngineException(
        'Background preservation requires a verified instrumental separation '
        'checkpoint (separation.onnx) and matching separation.json in the model vault.',
      );
    }
    late final Map<String, dynamic> metadata;
    try {
      metadata = Map<String, dynamic>.from(jsonDecode(await manifest.readAsString()) as Map);
    } catch (_) {
      throw OfflineEngineException('Separation model manifest is invalid JSON.');
    }
    final sha = metadata['sha256'];
    final input = metadata['input_name'];
    final output = metadata['output_name'];
    if (metadata['model_id'] != 'UVR-MDX-NET-Inst_HQ_3' ||
        metadata['stem'] != 'instrumental' ||
        metadata['reference_validated'] != true ||
        sha is! String || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha) ||
        input is! String || input.trim().isEmpty ||
        output is! String || output.trim().isEmpty) {
      throw OfflineEngineException(
        'The installed separation checkpoint needs reviewed instrumental '
        'metadata, tensor names and SHA-256; cannot safely preserve the soundtrack.',
      );
    }
    return SeparationInstallation(model.path, sha, input, output);
  }
}
