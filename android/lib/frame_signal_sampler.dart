import 'package:flutter/services.dart';

/// Grounded visual observations, not an AI model or a verified scene classifier.
/// Native Android decodes bounded video frames at requested timestamps.
class FrameSignalSampler {
  const FrameSignalSampler({MethodChannel? channel})
      : channel = channel ?? const MethodChannel('co.parikshit.otakudub/production_office');
  final MethodChannel channel;

  Future<List<FrameSignal>> sample(String path, List<int> timestampsMs) async {
    if (path.trim().isEmpty || timestampsMs.length > 240 ||
        timestampsMs.any((t) => t < 0)) {
      throw const FormatException('Invalid video path or sample timestamps');
    }
    final response = await channel.invokeMapMethod<String, dynamic>(
      'sampleFrames', {'path': path, 'timestamps_ms': timestampsMs});
    if (response == null || response['samples'] is! List) {
      throw const FormatException('Missing native frame observations');
    }
    final raw = response['samples'] as List;
    if (raw.length != timestampsMs.length) {
      throw const FormatException('Frame observation count mismatch');
    }
    return List.generate(raw.length, (index) {
      final item = Map<String, dynamic>.from(raw[index] as Map);
      if (item['timestamp_ms'] != timestampsMs[index] || item['available'] != true) {
        throw FormatException('Missing or misplaced frame at sample $index');
      }
      final values = item['luma8x8'];
      if (values is! List || values.length != 64 ||
          values.any((v) => v is! int || v < 0 || v > 255)) {
        throw const FormatException('Invalid frame signal');
      }
      return FrameSignal(timestampsMs[index], List<int>.unmodifiable(values.cast<int>()));
    });
  }
}

class FrameSignal {
  const FrameSignal(this.timestampMs, this.luma8x8);
  final int timestampMs;
  final List<int> luma8x8;
}

/// Candidate discontinuities only: needs model-assisted semantic scene grouping.
class ShotBoundaryCandidates {
  const ShotBoundaryCandidates();
  List<Map<String, dynamic>> detect(List<FrameSignal> frames,
      {double threshold = .30}) {
    if (!threshold.isFinite || threshold <= 0 || threshold > 1) {
      throw const FormatException('Invalid boundary threshold');
    }
    final output = <Map<String, dynamic>>[];
    for (var i = 1; i < frames.length; i++) {
      final previous = frames[i - 1], current = frames[i];
      if (previous.luma8x8.length != 64 || current.luma8x8.length != 64 ||
          current.timestampMs <= previous.timestampMs) {
        throw const FormatException('Invalid chronological frame signals');
      }
      var total = 0;
      for (var p = 0; p < 64; p++) {
        total += (current.luma8x8[p] - previous.luma8x8[p]).abs();
      }
      final score = total / (64 * 255);
      if (score >= threshold) output.add({
        'start_ms': previous.timestampMs,
        'end_ms': current.timestampMs,
        'difference': score,
        'kind': 'shot_boundary_candidate',
        'verified_scene_boundary': false,
        'source': 'native_decoded_frame_luma8x8',
      });
    }
    return output;
  }
}
