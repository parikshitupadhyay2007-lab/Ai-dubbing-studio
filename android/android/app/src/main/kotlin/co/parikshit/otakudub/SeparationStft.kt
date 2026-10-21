package co.parikshit.otakudub

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sqrt

/**
 * Stereo Short-Time Fourier Transform.
 *
 * Produces separate complex spectrograms for left and right audio.
 *
 * Model-specific normalization, frequency cropping and tensor
 * formatting must be implemented separately.
 */
object SeparationStft {

    data class Config(
        val fftSize: Int,
        val hopSize: Int,
        val center: Boolean = true
    ) {
        init {
            require(
                fftSize >= 2 &&
                    (fftSize and (fftSize - 1)) == 0
            ) {
                "FFT size must be a power of two >= 2."
            }

            require(hopSize in 1..fftSize) {
                "Invalid STFT hop size."
            }
        }
    }

    data class ComplexSpectrum(
        val real: Array<DoubleArray>,
        val imaginary: Array<DoubleArray>
    ) {
        val frameCount: Int
            get() = real.size

        val frequencyBins: Int
            get() = if (real.isEmpty()) 0 else real[0].size
    }

    data class StereoSpectrogram(
        val left: ComplexSpectrum,
        val right: ComplexSpectrum,
        val originalFrames: Int,
        val config: Config
    )

    fun transform(
        left: FloatArray,
        right: FloatArray,
        config: Config
    ): StereoSpectrogram {
        require(left.size == right.size) {
            "Stereo channels must have equal lengths."
        }

        require(left.isNotEmpty()) {
            "Cannot transform empty audio."
        }

        val window = hannWindow(config.fftSize)

        return StereoSpectrogram(
            left = transformChannel(left, config, window),
            right = transformChannel(right, config, window),
            originalFrames = left.size,
            config = config
        )
    }

    private fun transformChannel(
        audio: FloatArray,
        config: Config,
        window: DoubleArray
    ): ComplexSpectrum {
        val fftSize = config.fftSize
        val hopSize = config.hopSize

        val padding = if (config.center) {
            fftSize / 2
        } else {
            0
        }

        val paddedLength = audio.size.toLong() +
            padding.toLong() * 2L

        val frameCount = if (paddedLength <= fftSize) {
            1
        } else {
            (
                (paddedLength - fftSize) / hopSize + 1L
            ).toInt()
        }

        val bins = fftSize / 2 + 1

        val realFrames = Array(frameCount) {
            DoubleArray(bins)
        }

        val imaginaryFrames = Array(frameCount) {
            DoubleArray(bins)
        }

        for (frame in 0 until frameCount) {
            val real = DoubleArray(fftSize)
            val imaginary = DoubleArray(fftSize)

            val start = frame.toLong() * hopSize - padding

            for (index in 0 until fftSize) {
                val sourceIndex = start + index

                val sample = if (
                    sourceIndex >= 0L &&
                    sourceIndex < audio.size.toLong()
                ) {
                    audio[sourceIndex.toInt()].toDouble()
                } else {
                    0.0
                }

                real[index] = sample * window[index]
            }

            SeparationFft.forward(real, imaginary)

            for (bin in 0 until bins) {
                realFrames[frame][bin] = real[bin]
                imaginaryFrames[frame][bin] = imaginary[bin]
            }
        }

        return ComplexSpectrum(
            real = realFrames,
            imaginary = imaginaryFrames
        )
    }

    /**
     * Periodic Hann window.
     *
     * This convention must match the selected ONNX model.
     */
    private fun hannWindow(size: Int): DoubleArray {
        return DoubleArray(size) { index ->
            0.5 - 0.5 * cos(
                2.0 * PI * index / size
            )
        }
    }

    /**
     * Reconstructs stereo audio from a complex spectrogram.
     *
     * Uses overlap-add and window-square normalization.
     */
    fun inverse(
        spectrogram: StereoSpectrogram
    ): Pair<FloatArray, FloatArray> {
        val left = inverseChannel(
            spectrogram.left,
            spectrogram.originalFrames,
            spectrogram.config
        )

        val right = inverseChannel(
            spectrogram.right,
            spectrogram.originalFrames,
            spectrogram.config
        )

        return left to right
    }

    private fun inverseChannel(
        spectrum: ComplexSpectrum,
        originalFrames: Int,
        config: Config
    ): FloatArray {
        val fftSize = config.fftSize
        val hopSize = config.hopSize
        val bins = fftSize / 2 + 1

        require(spectrum.frameCount > 0) {
            "Spectrogram contains no frames."
        }

        require(
            spectrum.imaginary.size == spectrum.frameCount
        ) {
            "Spectrogram frame counts do not match."
        }

        val padding = if (config.center) {
            fftSize / 2
        } else {
            0
        }

        val reconstructedLength = (
            (spectrum.frameCount - 1).toLong() *
                hopSize + fftSize
        )

        require(reconstructedLength <= Int.MAX_VALUE) {
            "Reconstructed audio is too large."
        }

        val output = DoubleArray(
            reconstructedLength.toInt()
        )

        val normalization = DoubleArray(output.size)

        val window = hannWindow(fftSize)

        for (frame in 0 until spectrum.frameCount) {
            require(
                spectrum.real[frame].size == bins &&
                    spectrum.imaginary[frame].size == bins
            ) {
                "Unexpected spectrogram frequency-bin count."
            }

            val real = DoubleArray(fftSize)
            val imaginary = DoubleArray(fftSize)

            for (bin in 0 until bins) {
                real[bin] = spectrum.real[frame][bin]
                imaginary[bin] = spectrum.imaginary[frame][bin]
            }

            // Restore conjugate symmetry for a real-valued signal.
            for (bin in 1 until fftSize / 2) {
                real[fftSize - bin] = real[bin]
                imaginary[fftSize - bin] = -imaginary[bin]
            }

            SeparationFft.inverse(real, imaginary)

            val start = frame * hopSize

            for (index in 0 until fftSize) {
                val position = start + index
                val weight = window[index]

                output[position] += real[index] * weight
                normalization[position] += weight * weight
            }
        }

        val result = FloatArray(originalFrames)

        for (index in 0 until originalFrames) {
            val position = index + padding

            if (position !in output.indices) {
                continue
            }

            val weight = normalization[position]

            result[index] = if (weight > 1e-10) {
                (output[position] / weight).toFloat()
            } else {
                0f
            }
        }

        return result
    }
}
