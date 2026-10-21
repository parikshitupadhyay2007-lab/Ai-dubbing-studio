package co.parikshit.otakudub

import kotlin.math.PI
import kotlin.math.cos

/**
 * Stereo Short-Time Fourier Transform.
 *
 * Supported FFT sizes:
 * - Powers of two
 * - 6144 (mixed radix)
 *
 * Model-specific tensor formatting, normalization and
 * frequency cropping are handled separately.
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
                    (
                        fftSize == 6144 ||
                            (fftSize and (fftSize - 1)) == 0
                    )
            ) {
                "Unsupported FFT size."
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
            "Stereo channel lengths differ."
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

        val paddedLength =
            audio.size.toLong() + padding.toLong() * 2L

        val frameCountLong = if (paddedLength <= fftSize) {
            1L
        } else {
            (paddedLength - fftSize) / hopSize + 1L
        }

        require(frameCountLong <= Int.MAX_VALUE) {
            "Too many STFT frames."
        }

        val frameCount = frameCountLong.toInt()
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

            val start =
                frame.toLong() * hopSize - padding

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

            SeparationMixedRadixFft.forward(
                real,
                imaginary
            )

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

    fun inverse(
        spectrogram: StereoSpectrogram
    ): Pair<FloatArray, FloatArray> {
        require(spectrogram.originalFrames > 0) {
            "Invalid original audio length."
        }

        val window = hannWindow(
            spectrogram.config.fftSize
        )

        return Pair(
            inverseChannel(
                spectrogram.left,
                spectrogram.originalFrames,
                spectrogram.config,
                window
            ),
            inverseChannel(
                spectrogram.right,
                spectrogram.originalFrames,
                spectrogram.config,
                window
            )
        )
    }

    private fun inverseChannel(
        spectrum: ComplexSpectrum,
        originalFrames: Int,
        config: Config,
        window: DoubleArray
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
            "Spectrogram frame counts differ."
        }

        val reconstructedLength =
            (spectrum.frameCount - 1).toLong() *
                hopSize + fftSize

        require(reconstructedLength <= Int.MAX_VALUE) {
            "Reconstructed audio is too large."
        }

        val output = DoubleArray(
            reconstructedLength.toInt()
        )

        val normalization = DoubleArray(output.size)

        for (frame in 0 until spectrum.frameCount) {
            require(
                spectrum.real[frame].size == bins &&
                    spectrum.imaginary[frame].size == bins
            ) {
                "Invalid spectrogram frequency dimensions."
            }

            val real = DoubleArray(fftSize)
            val imaginary = DoubleArray(fftSize)

            for (bin in 0 until bins) {
                real[bin] = spectrum.real[frame][bin]
                imaginary[bin] = spectrum.imaginary[frame][bin]
            }

            // Restore negative-frequency conjugate symmetry.
            for (bin in 1 until fftSize / 2) {
                real[fftSize - bin] = real[bin]
                imaginary[fftSize - bin] = -imaginary[bin]
            }

            // DC and Nyquist bins must be real-valued.
            imaginary[0] = 0.0
            imaginary[fftSize / 2] = 0.0

            SeparationMixedRadixFft.inverse(
                real,
                imaginary
            )

            val start = frame.toLong() * hopSize

            for (index in 0 until fftSize) {
                val position = (start + index).toInt()
                val weight = window[index]

                output[position] += real[index] * weight
                normalization[position] += weight * weight
            }
        }

        val padding = if (config.center) {
            fftSize / 2
        } else {
            0
        }

        val result = FloatArray(originalFrames)

        for (index in result.indices) {
            val position = index.toLong() + padding

            if (position >= output.size) {
                continue
            }

            val positionIndex = position.toInt()
            val weight = normalization[positionIndex]

            result[index] = if (weight > 1e-10) {
                (output[positionIndex] / weight).toFloat()
            } else {
                0f
            }
        }

        return result
    }

    /**
     * Periodic Hann window.
     */
    private fun hannWindow(size: Int): DoubleArray {
        return DoubleArray(size) { index ->
            0.5 - 0.5 * cos(
                2.0 * PI * index / size
            )
        }
    }
}
