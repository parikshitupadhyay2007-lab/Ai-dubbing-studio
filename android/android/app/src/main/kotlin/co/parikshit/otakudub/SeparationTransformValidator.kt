
package co.parikshit.otakudub

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Numerical validation for OtakuDub's FFT and STFT.
 *
 * This is a diagnostic utility, not an audio-separation model.
 * Call runAll() from a diagnostic entry point when testing.
 */
object SeparationTransformValidator {

    data class TestResult(
        val name: String,
        val passed: Boolean,
        val maximumError: Double,
        val tolerance: Double,
        val details: String
    )

    data class Report(
        val passed: Boolean,
        val results: List<TestResult>
    )

    fun runAll(): Report {
        val results = listOf(
            validateFft(2048),
            validateFft(6144),
            validateStft(2048, 512),
            validateStft(6144, 1024)
        )

        return Report(
            passed = results.all { it.passed },
            results = results
        )
    }

    private fun validateFft(size: Int): TestResult {
        val real = DoubleArray(size) { index ->
            sin(2.0 * PI * 17.0 * index / size) +
                0.35 * cos(2.0 * PI * 53.0 * index / size)
        }

        val imaginary = DoubleArray(size) { index ->
            0.2 * sin(2.0 * PI * 7.0 * index / size)
        }

        val originalReal = real.copyOf()
        val originalImaginary = imaginary.copyOf()

        SeparationMixedRadixFft.forward(real, imaginary)
        SeparationMixedRadixFft.inverse(real, imaginary)

        var maximumError = 0.0

        for (index in 0 until size) {
            maximumError = maxOf(
                maximumError,
                abs(real[index] - originalReal[index]),
                abs(imaginary[index] - originalImaginary[index])
            )
        }

        val tolerance = 1e-8

        return TestResult(
            name = "FFT round trip ($size)",
            passed = maximumError.isFinite() &&
                maximumError <= tolerance,
            maximumError = maximumError,
            tolerance = tolerance,
            details = "Complex forward/inverse reconstruction"
        )
    }

    private fun validateStft(
        fftSize: Int,
        hopSize: Int
    ): TestResult {
        val sampleRate = 44100
        val frameCount = sampleRate

        val left = FloatArray(frameCount) { index ->
            (
                0.4 * sin(
                    2.0 * PI * 440.0 * index / sampleRate
                ) +
                    0.2 * sin(
                        2.0 * PI * 880.0 * index / sampleRate
                    )
                ).toFloat()
        }

        val right = FloatArray(frameCount) { index ->
            (
                0.35 * sin(
                    2.0 * PI * 330.0 * index / sampleRate
                ) +
                    0.15 * cos(
                        2.0 * PI * 660.0 * index / sampleRate
                    )
                ).toFloat()
        }

        val config = SeparationStft.Config(
            fftSize = fftSize,
            hopSize = hopSize,
            center = true
        )

        val spectrogram = SeparationStft.transform(
            left,
            right,
            config
        )

        val reconstructed = SeparationStft.inverse(
            spectrogram
        )

        val outputLeft = reconstructed.first
        val outputRight = reconstructed.second

        require(
            outputLeft.size == frameCount &&
                outputRight.size == frameCount
        ) {
            "STFT reconstruction length mismatch."
        }

        var maximumError = 0.0
        var squaredError = 0.0

        for (index in 0 until frameCount) {
            val leftError = abs(
                left[index].toDouble() -
                    outputLeft[index].toDouble()
            )

            val rightError = abs(
                right[index].toDouble() -
                    outputRight[index].toDouble()
            )

            maximumError = maxOf(
                maximumError,
                leftError,
                rightError
            )

            squaredError +=
                leftError * leftError +
                    rightError * rightError
        }

        val rmsError = sqrt(
            squaredError / (frameCount.toDouble() * 2.0)
        )

        val tolerance = 1e-4

        return TestResult(
            name = "Stereo STFT round trip ($fftSize/$hopSize)",
            passed = maximumError.isFinite() &&
                rmsError.isFinite() &&
                maximumError <= tolerance,
            maximumError = maximumError,
            tolerance = tolerance,
            details = "RMS reconstruction error: $rmsError"
        )
    }

    /**
     * Throws when any numerical validation fails.
     */
    fun requireValid(): Report {
        val report = runAll()

        check(report.passed) {
            report.results
                .filterNot { it.passed }
                .joinToString("\n") {
                    "${it.name}: error=${it.maximumError}, " +
                        "tolerance=${it.tolerance}"
                }
        }

        return report
    }
}
