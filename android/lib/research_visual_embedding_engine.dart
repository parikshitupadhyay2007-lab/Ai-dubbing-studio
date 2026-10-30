import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'department01_inference.dart';
import 'research_rgb_frame.dart';
import 'research_embedding_matcher.dart';
import 'research_reference_index.dart';

/// A real ONNX visual embedding execution plus conservative local retrieval.
/// Tensor preprocessing is specified by the chosen model, not guessed here.
/// This does not by itself identify an anime, episode, or character.
class ResearchVisualEmbeddingEngine {
  const ResearchVisualEmbeddingEngine({
    this.inference = const Department01Inference(),
    this.matcher = const ResearchEmbeddingMatcher(),
    this.frames = const ResearchRgbFrame(),
  });

  final Department01Inference inference;
  final ResearchEmbeddingMatcher matcher;
  final ResearchRgbFrame frames;

  /// DINOv2-specific inference using aspect-preserving 256 short-edge resize,
  /// 224 center crop, and published RGB channel normalization.
  Future<Map<String, dynamic>> evaluateDinov2Frame({
    required String sourcePath,
    required int timestampMs,
    required String modelSha256,
    Map<String, List<double>> authorisedReferences = const {},
  }) async {
    final rgb = await frames.sampleDinov2(sourcePath: sourcePath,
      timestampMs: timestampMs);
    final pixels = frames.toChwNormalized(rgb, size: 224,
      mean: [0.485, 0.456, 0.406], std: [0.229, 0.224, 0.225]);
    return evaluate(modelName: 'dinov2_small_cls.onnx',
      modelSha256: modelSha256, inputName: 'pixel_values',
      outputName: 'embedding', preprocessingId: 'dinov2_short256_crop224_v1',
      inputShape: [1, 3, 224, 224], preprocessedPixels: pixels,
      authorisedReferences: authorisedReferences);
  }

  /// Uses only a provenance-validated, model-pinned local reference index.
  Future<Map<String, dynamic>> evaluateIndexedFrame({
    required File referenceIndex,
    required String sourcePath,
    required int timestampMs,
    required int imageSize,
    int? cropSize,
    required List<double> channelMean,
    required List<double> channelStd,
    required String modelName,
    required String modelSha256,
    required String inputName,
    required String outputName,
    required String preprocessingId,
    required int embeddingDimension,
  }) async {
    final references = await const ResearchReferenceIndex().load(
      file: referenceIndex, expectedModelSha256: modelSha256,
      expectedPreprocessingId: preprocessingId, dimension: embeddingDimension);
    final result = await evaluateFrame(sourcePath: sourcePath,
      timestampMs: timestampMs, imageSize: imageSize, cropSize: cropSize,
      channelMean: channelMean, channelStd: channelStd,
      modelName: modelName, modelSha256: modelSha256,
      inputName: inputName, outputName: outputName,
      preprocessingId: preprocessingId, authorisedReferences: references);
    return {...result, 'reference_index_sha256':
      const ResearchReferenceIndex().fingerprint(references)};
  }

  /// Decodes a real video frame and applies the model card's supplied RGB
  /// preprocessing contract before running the pinned ONNX encoder.
  Future<Map<String, dynamic>> evaluateFrame({
    required String sourcePath,
    required int timestampMs,
    required int imageSize,
    int? cropSize,
    required List<double> channelMean,
    required List<double> channelStd,
    required String modelName,
    required String modelSha256,
    required String inputName,
    required String outputName,
    required String preprocessingId,
    required Map<String, List<double>> authorisedReferences,
  }) async {
    final rgb = await frames.sample(sourcePath: sourcePath,
      timestampMs: timestampMs, size: imageSize);
    // DINOv2 processor's resize and crop are separate operations.
    final inputSize = cropSize ?? imageSize;
    final prepared = cropSize == null ? rgb : frames.centerCrop(rgb,
      sourceSize: imageSize, cropSize: cropSize);
    final pixels = frames.toChwNormalized(prepared, size: inputSize,
      mean: channelMean, std: channelStd);
    return evaluate(modelName: modelName, modelSha256: modelSha256,
      inputName: inputName, outputName: outputName,
      preprocessingId: preprocessingId,
      inputShape: [1, 3, inputSize, inputSize],
      preprocessedPixels: pixels,
      authorisedReferences: authorisedReferences);
  }


  Future<Map<String, dynamic>> evaluate({
    required String modelName,
    required String modelSha256,
    required String inputName,
    required String outputName,
    required String preprocessingId,
    required List<int> inputShape,
    required List<double> preprocessedPixels,
    required Map<String, List<double>> authorisedReferences,
    double minimumSimilarity = 0.65,
    double minimumMargin = 0.08,
  }) async {
    if (preprocessingId.trim().isEmpty ||
        !RegExp(r'^[a-zA-Z0-9_.-]{1,100}$').hasMatch(preprocessingId) ||
        outputName.trim().isEmpty) {
      throw const FormatException('Missing model preprocessing or references');
    }
    // inspectModel checks the independently pinned bytes in private storage.
    final inspected = await inference.inspect(
      modelName: modelName, sha256: modelSha256);
    final inputs = inspected['inputs'], outputs = inspected['outputs'];
    if (inputs is! List || !inputs.contains(inputName) ||
        outputs is! List || !outputs.contains(outputName)) {
      throw const FormatException('Pinned model tensor signature mismatch');
    }
    final result = await inference.runFloat(
      modelName: modelName, sha256: modelSha256,
      inputName: inputName, shape: inputShape, values: preprocessedPixels);
    final rawOutputs = result['output_metadata'];
    if (rawOutputs is! List) {
      throw const FormatException('No actual ONNX inference outputs');
    }
    final selected = rawOutputs.whereType<Map>().where(
      (item) => item['name'] == outputName).toList();
    if (selected.length != 1) {
      throw const FormatException('Missing or ambiguous embedding output');
    }
    final output = selected.single;
    final shape = output['shape'];
    final rawValues = output['values'];
    // Supports a single [D] or [1,D] float embedding; rejects class logits,
    // spatial feature maps and batch inference rather than guessing semantics.
    if (output['type'] != 'float32' || shape is! List ||
        rawValues is! List || !(
          shape.length == 1 ||
          (shape.length == 2 && shape.first == 1))) {
      throw const FormatException('Unsupported embedding output shape');
    }
    final values = rawValues.map((v) {
      if (v is! num || !v.isFinite) {
        throw const FormatException('Nonfinite embedding');
      }
      return v.toDouble();
    }).toList(growable: false);
    if (values.isEmpty || values.length > 4096 ||
        shape.last != values.length) {
      throw const FormatException('Embedding dimension mismatch');
    }
    final ranking = authorisedReferences.isEmpty ? null : matcher.rank(query: values,
      references: authorisedReferences,
      minimumSimilarity: minimumSimilarity,
      minimumMargin: minimumMargin);
    final inputDigest = crypto.sha256.convert(utf8.encode(jsonEncode({
      'shape': inputShape, 'pixels': preprocessedPixels,
      'preprocessing_id': preprocessingId,
    }))).toString();
    final outputDigest = crypto.sha256.convert(utf8.encode(jsonEncode({
      'shape': shape, 'values': values, 'output_name': outputName,
    }))).toString();
    return {
      'engine': 'visual_embedding_retrieval',
      'model_name': modelName,
      'model_sha256': modelSha256,
      'preprocessing_id': preprocessingId,
      'input_sha256': inputDigest,
      'output_sha256': outputDigest,
      'actual_onnx_execution': true,
      'embedding_dimension': values.length,
      'embedding': values,
      'ranking': ranking,
      'reference_status': authorisedReferences.isEmpty ? 'no_authorised_references' : 'comparison_performed',
      'verified_anime': false,
      'verified_character': false,
      'requires_independent_review': true,
    };
  }
}
