package co.parikshit.otakudub

/**
 * Decodes a compatible ONNX Float32 output tensor into
 * a stereo complex spectrogram.
 *
 * Supported tensor layout:
 * [1, 4, frequencyBins, timeFrames]
 *
 * Channel order:
 * 0 = left real
 * 1 = left imaginary
 * 2 = right real
 * 3 = right imaginary
 */
object SeparationOutputDecoder {

    data class Config(
        val originalFrequencyBins: Int,
        val removeLowestBin: Boolean = false,
        val normalization: Float = 1f
    ) {
        init {
            require(originalFrequencyBins > 1) {
                "Invalid original frequency-bin count."
            }

            require(normalization.isFinite() && normalization > 0f) {
                "Normalization must be finite and positive."
            }
        }
    }

    fun decode(
        output: SeparationOnnxRunner.OutputTensor,
        originalFrames: Int,
        stftConfig: SeparationStft.Config,
        config: Config
    ): SeparationStft.StereoSpectrogram {

        val shape = output.shape

        require(shape.size == 4) {
            "Expected a four-dimensional ONNX output."
        }

        require(shape[0] == 1L && shape[1] == 4L) {
            "Expected tensor shape [1, 4, F, T]."
        }

        require(
            shape[2] > 0L &&
                shape[3] > 0L &&
                shape[2] <= Int.MAX_VALUE &&
                shape[3] <= Int.MAX_VALUE
        ) {
            "Invalid output tensor dimensions."
        }

        val frequencyBins = shape[2].toInt()
        val timeFrames = shape[3].toInt()

        val binOffset = if (config.removeLowestBin) 1 else 0

        require(
            frequencyBins + binOffset <= config.originalFrequencyBins
        ) {
            "Output frequency bins exceed original STFT dimensions."
        }

        require(
            config.originalFrequencyBins ==
                stftConfig.fftSize / 2 + 1
        ) {
            "Original frequency-bin count does not match FFT size."
        }

        require(originalFrames > 0) {
            "Original audio length must be positive."
        }

        val expectedElements =
            4L * frequencyBins.toLong() * timeFrames.toLong()

        require(expectedElements == output.values.size.toLong()) {
            "ONNX output shape and data length differ."
        }

        val leftReal = Array(timeFrames) {
            DoubleArray(config.originalFrequencyBins)
        }

        val leftImaginary = Array(timeFrames) {
            DoubleArray(config.originalFrequencyBins)
        }

        val rightReal = Array(timeFrames) {
            DoubleArray(config.originalFrequencyBins)
        }

        val rightImaginary = Array(timeFrames) {
            DoubleArray(config.originalFrequencyBins)
        }

        val channelStride = frequencyBins * timeFrames

        for (frame in 0 until timeFrames) {
            for (bin in 0 until frequencyBins) {
                val destinationBin = bin + binOffset
                val index = bin * timeFrames + frame

                leftReal[frame][destinationBin] = checkedValue(
                    output.values[index],
                    config.normalization
                )

                leftImaginary[frame][destinationBin] = checkedValue(
                    output.values[channelStride + index],
                    config.normalization
                )

                rightReal[frame][destinationBin] = checkedValue(
                    output.values[2 * channelStride + index],
                    config.normalization
                )

                rightImaginary[frame][destinationBin] = checkedValue(
                    output.values[3 * channelStride + index],
                    config.normalization
                )
            }
        }

        return SeparationStft.StereoSpectrogram(
            left = SeparationStft.ComplexSpectrum(
                real = leftReal,
                imaginary = leftImaginary
            ),
            right = SeparationStft.ComplexSpectrum(
                real = rightReal,
                imaginary = rightImaginary
            ),
            originalFrames = originalFrames,
            config = stftConfig
        )
    }

    private fun checkedValue(
        value: Float,
        normalization: Float
    ): Double {
        require(value.isFinite()) {
            "ONNX output contains non-finite values."
        }

        val result = value.toDouble() * normalization.toDouble()

        require(result.isFinite()) {
            "Reconstructed spectrogram contains invalid values."
        }

        return result
    }
}
