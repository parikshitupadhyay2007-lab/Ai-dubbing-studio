
package co.parikshit.otakudub

/**
 * Converts stereo complex STFT data into a flattened tensor.
 *
 * Supported layout:
 *
 * [1, 4, frequencyBins, timeFrames]
 *
 * Channel order:
 * 0 = left real
 * 1 = left imaginary
 * 2 = right real
 * 3 = right imaginary
 *
 * This is a configurable preparation utility, not a declaration
 * that every separation model accepts this layout.
 */
object SeparationSpectrogramTensor {

    data class Config(
        val frequencyBins: Int,
        val removeLowestBin: Boolean = false,
        val normalization: Float = 1f
    ) {
        init {
            require(frequencyBins > 0) {
                "Frequency-bin count must be positive."
            }

            require(normalization.isFinite() && normalization > 0f) {
                "Normalization must be finite and positive."
            }
        }
    }

    data class TensorData(
        val values: FloatArray,
        val shape: LongArray,
        val frequencyBins: Int,
        val timeFrames: Int
    )

    fun prepare(
        spectrogram: SeparationStft.StereoSpectrogram,
        config: Config
    ): TensorData {
        val left = spectrogram.left
        val right = spectrogram.right

        require(left.frameCount == right.frameCount) {
            "Stereo spectrogram frame counts differ."
        }

        val timeFrames = left.frameCount

        require(timeFrames > 0) {
            "Spectrogram contains no frames."
        }

        val sourceBins = left.frequencyBins

        require(sourceBins == right.frequencyBins) {
            "Stereo frequency-bin counts differ."
        }

        val binOffset = if (config.removeLowestBin) 1 else 0

        require(config.frequencyBins + binOffset <= sourceBins) {
            "Requested frequency bins exceed STFT output."
        }

        val totalElements =
            4L * config.frequencyBins.toLong() * timeFrames.toLong()

        require(totalElements <= Int.MAX_VALUE) {
            "Spectrogram tensor exceeds supported size."
        }

        val values = FloatArray(totalElements.toInt())

        val channelStride = config.frequencyBins * timeFrames

        for (frame in 0 until timeFrames) {
            require(
                left.real[frame].size == sourceBins &&
                    left.imaginary[frame].size == sourceBins &&
                    right.real[frame].size == sourceBins &&
                    right.imaginary[frame].size == sourceBins
            ) {
                "Inconsistent spectrogram frame dimensions."
            }

            for (bin in 0 until config.frequencyBins) {
                val sourceBin = bin + binOffset

                val index = bin * timeFrames + frame

                values[index] =
                    checkedFloat(
                        left.real[frame][sourceBin],
                        config.normalization
                    )

                values[channelStride + index] =
                    checkedFloat(
                        left.imaginary[frame][sourceBin],
                        config.normalization
                    )

                values[2 * channelStride + index] =
                    checkedFloat(
                        right.real[frame][sourceBin],
                        config.normalization
                    )

                values[3 * channelStride + index] =
                    checkedFloat(
                        right.imaginary[frame][sourceBin],
                        config.normalization
                    )
            }
        }

        return TensorData(
            values = values,
            shape = longArrayOf(
                1L,
                4L,
                config.frequencyBins.toLong(),
                timeFrames.toLong()
            ),
            frequencyBins = config.frequencyBins,
            timeFrames = timeFrames
        )
    }

    private fun checkedFloat(
        value: Double,
        normalization: Float
    ): Float {
        require(value.isFinite()) {
            "Spectrogram contains non-finite values."
        }

        val result = value / normalization.toDouble()

        require(
            result.isFinite() &&
                result <= Float.MAX_VALUE &&
                result >= -Float.MAX_VALUE
        ) {
            "Spectrogram value exceeds Float32 range."
        }

        return result.toFloat()
    }
}
