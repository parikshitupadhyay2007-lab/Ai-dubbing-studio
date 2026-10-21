
package co.parikshit.otakudub

/**
 * Preprocessing configuration for an MDX-family ONNX model.
 *
 * This profile describes the audio transform and tensor layout.
 * It does not establish compatibility with a particular checkpoint.
 *
 * Checkpoint-specific settings must be verified against the
 * model's reference implementation before inference is enabled.
 */
data class SeparationMdxProfile(
    val sampleRate: Int,
    val fftSize: Int,
    val hopSize: Int,
    val frequencyBins: Int,
    val timeFrames: Int,
    val channels: Int = 2,
    val center: Boolean = true,
    val removeLowestBin: Boolean = false,
    val normalization: Float = 1f
) {

    init {
        require(sampleRate in 8000..192000) {
            "Invalid MDX sample rate."
        }

        require(
            fftSize == 6144 ||
                (
                    fftSize >= 2 &&
                        (fftSize and (fftSize - 1)) == 0
                )
        ) {
            "Unsupported MDX FFT size."
        }

        require(hopSize in 1..fftSize) {
            "Invalid MDX hop size."
        }

        require(channels == 2) {
            "Current MDX tensor preparation requires stereo audio."
        }

        require(timeFrames > 0) {
            "Invalid MDX time-frame count."
        }

        val availableBins = fftSize / 2 + 1
        val binOffset = if (removeLowestBin) 1 else 0

        require(
            frequencyBins > 0 &&
                frequencyBins + binOffset <= availableBins
        ) {
            "MDX frequency-bin configuration is invalid."
        }

        require(
            normalization.isFinite() &&
                normalization > 0f
        ) {
            "Invalid MDX normalization."
        }

        require(
            4L * frequencyBins.toLong() *
                timeFrames.toLong() <= Int.MAX_VALUE
        ) {
            "MDX tensor exceeds supported array size."
        }
    }

    val inputShape: LongArray
        get() = longArrayOf(
            1L,
            4L,
            frequencyBins.toLong(),
            timeFrames.toLong()
        )

    val stftConfig: SeparationStft.Config
        get() = SeparationStft.Config(
            fftSize = fftSize,
            hopSize = hopSize,
            center = center
        )

    val tensorConfig: SeparationSpectrogramTensor.Config
        get() = SeparationSpectrogramTensor.Config(
            frequencyBins = frequencyBins,
            removeLowestBin = removeLowestBin,
            normalization = normalization
        )

    /**
     * Number of audio samples covered by the configured
     * STFT frame sequence before centered padding.
     *
     * Actual chunk preparation must also account for the
     * selected model's padding conventions.
     */
    val nominalChunkSamples: Long
        get() =
            (timeFrames.toLong() - 1L) *
                hopSize.toLong() +
                fftSize.toLong()

    companion object {

        /**
         * Provisional transform parameters for evaluating
         * the UVR-MDX-NET-Inst_HQ_3 candidate.
         *
         * Do not enable production inference until its exact
         * checkpoint metadata and preprocessing are verified.
         */
        fun instrumentalCandidate(): SeparationMdxProfile {
            return SeparationMdxProfile(
                sampleRate = 44100,
                fftSize = 6144,
                hopSize = 1024,
                frequencyBins = 3072,
                timeFrames = 256,
                channels = 2,
                center = true,
                removeLowestBin = false,
                normalization = 1f
            )
        }
    }
}
