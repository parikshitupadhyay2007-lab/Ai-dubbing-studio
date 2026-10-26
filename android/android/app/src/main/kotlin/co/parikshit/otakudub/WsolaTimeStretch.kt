package co.parikshit.otakudub

import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Mono waveform-similarity overlap-add compression. Keeps the original sample
 * rate (and therefore pitch) rather than resampling the waveform. This is a
 * bounded duration fitter, not an audiovisual lip-sync model.
 */
internal object WsolaTimeStretch {
    fun compress(input: FloatArray, outputSamples: Int, sampleRate: Int): FloatArray {
        require(sampleRate > 0 && outputSamples > 0 && input.isNotEmpty())
        require(input.all { it.isFinite() }) { "Invalid source speech samples" }
        if (input.size <= outputSamples) return input.copyOf()
        val ratio = input.size.toDouble() / outputSamples
        require(ratio <= 1.50) { "Unsafe WSOLA compression ratio" }
        val frame = (sampleRate * 0.040).roundToInt().coerceAtLeast(32)
        if (outputSamples < frame * 2 || input.size < frame * 2) {
            throw IllegalArgumentException("Speech window too short for WSOLA")
        }
        val hop = frame / 2
        val search = (sampleRate * 0.006).roundToInt().coerceAtLeast(1)
        val lastOutput = outputSamples - frame
        val lastInput = input.size - frame
        val starts = mutableListOf<Int>()
        var position = 0
        while (position < lastOutput) {
            starts.add(position)
            position += hop
        }
        if (starts.lastOrNull() != lastOutput) starts.add(lastOutput)
        val accumulated = DoubleArray(outputSamples)
        val weights = DoubleArray(outputSamples)
        val window = DoubleArray(frame) { i ->
            // Nonzero endpoints ensure stable normalization at boundaries.
            0.5 - 0.5 * kotlin.math.cos(2.0 * Math.PI * (i + 0.5) / frame)
        }
        for ((index, outStart) in starts.withIndex()) {
            val inStart = when {
                index == 0 -> 0
                index == starts.lastIndex -> lastInput
                else -> {
                    val nominal = (outStart * ratio).roundToInt().coerceIn(0, lastInput)
                    val low = max(0, nominal - search)
                    val high = min(lastInput, nominal + search)
                    val overlap = min(frame, starts[index - 1] + frame - outStart)
                        .coerceAtLeast(0)
                    var best = nominal
                    var bestScore = Double.NEGATIVE_INFINITY
                    // Search a small synchronized neighborhood, comparing
                    // normalized overlap to avoid amplitude-only matches.
                    for (candidate in low..high step 2) {
                        var dot = 0.0
                        var leftEnergy = 1e-12
                        var rightEnergy = 1e-12
                        for (j in 0 until overlap step 2) {
                            val at = outStart + j
                            val old = accumulated[at] / weights[at].coerceAtLeast(1e-12)
                            val next = input[candidate + j].toDouble()
                            dot += old * next
                            leftEnergy += old * old
                            rightEnergy += next * next
                        }
                        val score = dot / sqrt(leftEnergy * rightEnergy)
                        if (score > bestScore) {
                            bestScore = score
                            best = candidate
                        }
                    }
                    best
                }
            }
            for (j in 0 until frame) {
                val at = outStart + j
                val weight = window[j]
                accumulated[at] += input[inStart + j] * weight
                weights[at] += weight
            }
        }
        return FloatArray(outputSamples) { i ->
            val sample = (accumulated[i] / weights[i].coerceAtLeast(1e-12)).toFloat()
            require(sample.isFinite()) { "WSOLA produced invalid audio" }
            sample
        }
    }
}
