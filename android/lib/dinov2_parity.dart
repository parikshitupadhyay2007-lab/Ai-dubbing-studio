import 'dart:math' as math;

/// Numerical comparison of the same model/input across ONNX CPU and Android.
/// Does not evaluate character identity or dubbing quality.
class Dinov2Parity {
  const Dinov2Parity();

  Map<String, dynamic> compare({
    required List<double> reference,
    required List<double> android,
    required String referenceModelSha256,
    required String androidModelSha256,
    required String referenceInputSha256,
    required String androidInputSha256,
    double absoluteTolerance = 1e-4,
    double relativeTolerance = 1e-3,
  }) {
    final digest = RegExp(r'^[a-f0-9]{64}$');
    if (!digest.hasMatch(referenceModelSha256) ||
        !digest.hasMatch(androidModelSha256) ||
        !digest.hasMatch(referenceInputSha256) ||
        !digest.hasMatch(androidInputSha256) ||
        reference.length != 384 || android.length != 384 ||
        reference.any((v) => !v.isFinite) ||
        android.any((v) => !v.isFinite) ||
        !absoluteTolerance.isFinite || absoluteTolerance < 0 ||
        !relativeTolerance.isFinite || relativeTolerance < 0) {
      throw const FormatException('Invalid parity evidence');
    }
    if (referenceModelSha256 != androidModelSha256 ||
        referenceInputSha256 != androidInputSha256) {
      return {'passed': false, 'reason': 'model_or_input_mismatch',
        'compared_dimensions': 0};
    }
    var maxAbsoluteError = 0.0;
    var maxRelativeError = 0.0;
    var failures = 0;
    var squaredError = 0.0;
    for (var i = 0; i < 384; i++) {
      final delta = (reference[i] - android[i]).abs();
      maxAbsoluteError = math.max(maxAbsoluteError, delta);
      maxRelativeError = math.max(maxRelativeError,
        delta / math.max(reference[i].abs(), 1e-12));
      squaredError += delta * delta;
      if (delta > absoluteTolerance + relativeTolerance * reference[i].abs()) {
        failures++;
      }
    }
    return {
      'passed': failures == 0, 'reason': failures == 0 ? 'within_tolerance' : 'numerical_divergence',
      'compared_dimensions': 384, 'failed_dimensions': failures,
      'max_absolute_error': maxAbsoluteError,
      'max_relative_error': maxRelativeError,
      'root_mean_squared_error': math.sqrt(squaredError / 384),
      'absolute_tolerance': absoluteTolerance,
      'relative_tolerance': relativeTolerance,
      'semantic_recognition_verified': false,
    };
  }
}
