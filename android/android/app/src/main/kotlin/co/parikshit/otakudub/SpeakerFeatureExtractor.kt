package co.parikshit.otakudub

/**
 * Contract for an offline speaker representation. A trained ONNX implementation
 * must supply its own verified preprocessing, tensor shape and model asset.
 * Do not interpret the current acoustic baseline as a trained embedding.
 */
fun interface SpeakerFeatureExtractor {
    fun extract(pcm16kMono: FloatArray): DoubleArray?
}

internal object SpeakerFeatureValidation {
    fun normalizedOrNull(raw: DoubleArray?): DoubleArray? {
        if (raw == null || raw.isEmpty() || raw.any { !it.isFinite() }) return null
        var sum = 0.0
        for (value in raw) sum += value * value
        if (!sum.isFinite() || sum <= 1e-12) return null
        val magnitude = kotlin.math.sqrt(sum)
        return DoubleArray(raw.size) { raw[it] / magnitude }
    }

    fun cosineDistance(a: DoubleArray, b: DoubleArray): Double {
        require(a.isNotEmpty() && a.size == b.size) {
            "Speaker embeddings must have matching nonempty dimensions."
        }
        val left = normalizedOrNull(a)
            ?: throw IllegalArgumentException("Invalid first speaker embedding.")
        val right = normalizedOrNull(b)
            ?: throw IllegalArgumentException("Invalid second speaker embedding.")
        var similarity = 0.0
        for (index in left.indices) similarity += left[index] * right[index]
        return 1.0 - similarity.coerceIn(-1.0, 1.0)
    }
}
