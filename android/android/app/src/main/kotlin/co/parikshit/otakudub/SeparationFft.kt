
package co.parikshit.otakudub

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * In-place radix-2 complex FFT.
 *
 * Uses DoubleArray for real and imaginary components.
 * Forward transform is unnormalized.
 * Inverse transform divides each output by FFT size.
 *
 * FFT size must be a positive power of two.
 */
object SeparationFft {

    fun forward(
        real: DoubleArray,
        imaginary: DoubleArray
    ) {
        transform(real, imaginary, inverse = false)
    }

    fun inverse(
        real: DoubleArray,
        imaginary: DoubleArray
    ) {
        transform(real, imaginary, inverse = true)
    }

    private fun transform(
        real: DoubleArray,
        imaginary: DoubleArray,
        inverse: Boolean
    ) {
        val size = real.size

        require(size > 0 && size and (size - 1) == 0) {
            "FFT size must be a positive power of two."
        }

        require(imaginary.size == size) {
            "Real and imaginary arrays must have equal length."
        }

        // Bit-reversal permutation.
        var reversed = 0

        for (index in 1 until size) {
            var bit = size shr 1

            while (reversed and bit != 0) {
                reversed = reversed xor bit
                bit = bit shr 1
            }

            reversed = reversed xor bit

            if (index < reversed) {
                val realValue = real[index]
                real[index] = real[reversed]
                real[reversed] = realValue

                val imaginaryValue = imaginary[index]
                imaginary[index] = imaginary[reversed]
                imaginary[reversed] = imaginaryValue
            }
        }

        // Iterative Cooley-Tukey butterfly stages.
        var length = 2

        while (length <= size) {
            val angle = (
                2.0 * PI / length
            ) * if (inverse) 1.0 else -1.0

            val stepReal = cos(angle)
            val stepImaginary = sin(angle)

            val half = length / 2

            var block = 0

            while (block < size) {
                var weightReal = 1.0
                var weightImaginary = 0.0

                for (offset in 0 until half) {
                    val first = block + offset
                    val second = first + half

                    val evenReal = real[first]
                    val evenImaginary = imaginary[first]

                    val oddReal =
                        real[second] * weightReal -
                            imaginary[second] * weightImaginary

                    val oddImaginary =
                        real[second] * weightImaginary +
                            imaginary[second] * weightReal

                    real[first] = evenReal + oddReal
                    imaginary[first] =
                        evenImaginary + oddImaginary

                    real[second] = evenReal - oddReal
                    imaginary[second] =
                        evenImaginary - oddImaginary

                    val nextReal =
                        weightReal * stepReal -
                            weightImaginary * stepImaginary

                    val nextImaginary =
                        weightReal * stepImaginary +
                            weightImaginary * stepReal

                    weightReal = nextReal
                    weightImaginary = nextImaginary
                }

                block += length
            }

            // Avoid overflow when doubling the final stage.
            if (length == size) break

            length = length shl 1
        }

        if (inverse) {
            val normalization = size.toDouble()

            for (index in 0 until size) {
                real[index] /= normalization
                imaginary[index] /= normalization
            }
        }
    }
}
