package co.parikshit.otakudub

/**
 * Deterministic waveform window for models explicitly verified to accept
 * fixed-size raw PCM. Center-crops longer speech and zero-pads shorter speech.
 * This is not suitable for checkpoints requiring VAD, mel features or other
 * model-specific normalization.
 */
internal object SpeakerWaveformWindow {
    fun prepare(samples: FloatArray, targetSamples: Int): FloatArray? {
        require(targetSamples > 0) { "Speaker window size must be positive." }
        if (samples.isEmpty() || samples.any { !it.isFinite() }) return null
        if (samples.size == targetSamples) return samples.copyOf()
        val result = FloatArray(targetSamples)
        if (samples.size > targetSamples) {
            val offset = (samples.size - targetSamples) / 2
            samples.copyInto(result, 0, offset, offset + targetSamples)
        } else {
            val offset = (targetSamples - samples.size) / 2
            samples.copyInto(result, offset)
        }
        return result
    }
}
