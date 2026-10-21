
package co.parikshit.otakudub

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * Complex FFT supporting:
 *
 * - Power-of-two sizes through SeparationFft
 * - 6144-point transforms through radix-3 decomposition
 *
 * Forward FFT is unnormalized.
 * Inverse FFT is normalized by the transform length.
 */
object SeparationMixedRadixFft {

    private const val MDX_FFT_SIZE = 6144
    private const val RADIX = 3
    private const val SUB_SIZE = 2048

    fun forward(
        real: DoubleArray,
        imaginary: DoubleArray
    ) {
        validate(real, imaginary)

        if (real.size != MDX_FFT_SIZE) {
            SeparationFft.forward(real, imaginary)
            return
        }

        transform6144(real, imaginary)
    }

    fun inverse(
        real: DoubleArray,
        imaginary: DoubleArray
    ) {
        validate(real, imaginary)

        if (real.size != MDX_FFT_SIZE) {
            SeparationFft.inverse(real, imaginary)
            return
        }

        // Inverse DFT through conjugation.
        for (index in imaginary.indices) {
            imaginary[index] = -imaginary[index]
        }

        transform6144(real, imaginary)

        val scale = MDX_FFT_SIZE.toDouble()

        for (index in real.indices) {
            real[index] /= scale
            imaginary[index] = -imaginary[index] / scale
        }
    }

    private fun transform6144(
        real: DoubleArray,
        imaginary: DoubleArray
    ) {
        val subReal = Array(RADIX) {
            DoubleArray(SUB_SIZE)
        }

        val subImaginary = Array(RADIX) {
            DoubleArray(SUB_SIZE)
        }

        // Decimate input into three 2048-point sequences.
        for (branch in 0 until RADIX) {
            for (index in 0 until SUB_SIZE) {
                val source = RADIX * index + branch

                subReal[branch][index] = real[source]
                subImaginary[branch][index] = imaginary[source]
            }

            SeparationFft.forward(
                subReal[branch],
                subImaginary[branch]
            )
        }

        // Combine the three transforms using DFT twiddle factors.
        for (frequency in 0 until MDX_FFT_SIZE) {
            val subFrequency = frequency % SUB_SIZE

            var resultReal = 0.0
            var resultImaginary = 0.0

            for (branch in 0 until RADIX) {
                val angle = -2.0 * PI *
                    frequency.toDouble() *
                    branch.toDouble() /
                    MDX_FFT_SIZE.toDouble()

                val weightReal = cos(angle)
                val weightImaginary = sin(angle)

                val valueReal =
                    subReal[branch][subFrequency]

                val valueImaginary =
                    subImaginary[branch][subFrequency]

                resultReal +=
                    valueReal * weightReal -
                        valueImaginary * weightImaginary

                resultImaginary +=
                    valueReal * weightImaginary +
                        valueImaginary * weightReal
            }

            real[frequency] = resultReal
            imaginary[frequency] = resultImaginary
        }
    }

    private fun validate(
        real: DoubleArray,
        imaginary: DoubleArray
    ) {
        require(real.size == imaginary.size) {
            "Real and imaginary arrays must have equal length."
        }

        require(real.isNotEmpty()) {
            "FFT input cannot be empty."
        }

        require(
            real.size == MDX_FFT_SIZE ||
                (real.size and (real.size - 1)) == 0
        ) {
            "Unsupported FFT size."
        }

        require(
            real.all { it.isFinite() } &&
                imaginary.all { it.isFinite() }
        ) {
            "FFT input contains non-finite values."
        }
    }
}
