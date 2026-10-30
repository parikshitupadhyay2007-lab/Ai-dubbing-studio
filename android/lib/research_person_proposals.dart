import 'dart:math' as math;

/// Decodes real DETR COCO person proposals. A detection is not a character ID.
class ResearchPersonProposals {
  const ResearchPersonProposals();

  List<Map<String, dynamic>> decode({
    required List<double> logits,
    required List<double> boxes,
    double minimumConfidence = 0.65,
  }) {
    if (logits.length != 100 * 92 || boxes.length != 100 * 4 ||
        minimumConfidence <= 0 || minimumConfidence >= 1 ||
        logits.any((v) => !v.isFinite) || boxes.any((v) => !v.isFinite)) {
      throw const FormatException('Invalid DETR tensor contract');
    }
    final proposals = <Map<String, dynamic>>[];
    for (var q = 0; q < 100; q++) {
      final offset = q * 92;
      var maxLogit = logits[offset];
      for (var c = 1; c < 92; c++) {
        if (logits[offset + c] > maxLogit) maxLogit = logits[offset + c];
      }
      var sum = 0.0;
      for (var c = 0; c < 92; c++) {
        sum += _exp(logits[offset + c] - maxLogit);
      }
      final person = _exp(logits[offset + 1] - maxLogit) / sum;
      var best = 0;
      for (var c = 1; c < 92; c++) {
        if (logits[offset + c] > logits[offset + best]) best = c;
      }
      if (best != 1 || person < minimumConfidence) continue;
      final cx = boxes[q * 4], cy = boxes[q * 4 + 1];
      final w = boxes[q * 4 + 2], h = boxes[q * 4 + 3];
      if (cx < 0 || cx > 1 || cy < 0 || cy > 1 ||
          w <= 0 || w > 1 || h <= 0 || h > 1) continue;
      final left = (cx - w / 2).clamp(0.0, 1.0);
      final top = (cy - h / 2).clamp(0.0, 1.0);
      final right = (cx + w / 2).clamp(0.0, 1.0);
      final bottom = (cy + h / 2).clamp(0.0, 1.0);
      if (right <= left || bottom <= top) continue;
      proposals.add({
        'query_id': q, 'class': 'person', 'confidence': person,
        'box_xyxy_normalized': [left, top, right, bottom],
        'character_id': null, 'verified_anime_character': false,
      });
    }
    proposals.sort((a, b) => (b['confidence'] as double)
        .compareTo(a['confidence'] as double));
    return proposals;
  }

  double _exp(double value) {
    // math.exp handles stable shifted softmax; logits are shifted <= 0.
    return math.exp(value);
  }

}
