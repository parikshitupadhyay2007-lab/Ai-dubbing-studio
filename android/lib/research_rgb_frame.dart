import 'package:flutter/services.dart';

/// Real decoded RGB pixels, not the 8x8 cut-detection proxy.
class ResearchRgbFrame {
  const ResearchRgbFrame({this.channel = const MethodChannel(
    'co.parikshit.otakudub/production_office')});
  final MethodChannel channel;

  Future<Uint8List> sample({
    required String sourcePath, required int timestampMs, int size = 224,
  }) async {
    if (sourcePath.trim().isEmpty || timestampMs < 0 ||
        size < 32 || size > 384) {
      throw const FormatException('Invalid RGB frame request');
    }
    final response = await channel.invokeMapMethod<String, dynamic>(
      'sampleRgbFrame', {'path': sourcePath, 'timestamp_ms': timestampMs,
      'size': size});
    if (response == null || response['timestamp_ms'] != timestampMs ||
        response['width'] != size || response['height'] != size ||
        response['pixel_format'] != 'RGB_U8_INTERLEAVED' ||
        response['rgb'] is! Uint8List) {
      throw const FormatException('Malformed decoded RGB frame');
    }
    final rgb = response['rgb'] as Uint8List;
    if (rgb.length != size * size * 3) {
      throw const FormatException('Incomplete RGB frame');
    }
    return rgb;
  }

  /// ImageNet-style CHW preprocessing; use only when a pinned model's own
  /// documented preprocessing contract explicitly requires these values.
  List<double> toChwNormalized(Uint8List rgb, {
    required int size,
    required List<double> mean,
    required List<double> std,
  }) {
    if (size < 32 || size > 384 || rgb.length != size * size * 3 ||
        mean.length != 3 || std.length != 3 ||
        mean.any((n) => !n.isFinite) ||
        std.any((n) => !n.isFinite || n <= 0)) {
      throw const FormatException('Invalid preprocessing contract');
    }
    final plane = size * size;
    final result = List<double>.filled(plane * 3, 0);
    for (var pixel = 0; pixel < plane; pixel++) {
      for (var channel = 0; channel < 3; channel++) {
        result[channel * plane + pixel] =
          (rgb[pixel * 3 + channel] / 255.0 - mean[channel]) / std[channel];
      }
    }
    return result;
  }
}
