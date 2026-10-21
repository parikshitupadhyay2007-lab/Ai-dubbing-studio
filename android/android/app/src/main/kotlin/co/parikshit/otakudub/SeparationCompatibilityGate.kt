
package co.parikshit.otakudub

/**
 * Validates compatibility between an inspected ONNX model and
 * OtakuDub's current complex-spectrogram processing pipeline.
 *
 * Supported input/output layout:
 * [1, 4, frequencyBins, timeFrames]
 *
 * This checks tensor compatibility only. It cannot establish
 * STFT conventions, normalization, model quality or licensing.
 */
object SeparationCompatibilityGate {

    data class Requirements(
        val sampleRate: Int,
        val fftSize: Int,
        val hopSize: Int,
        val frequencyBins: Int,
        val timeFrames: Int,
        val inputName: String,
        val outputName: String
    ) {
        init {
            require(sampleRate in 8000..192000)
            require(fftSize == 6144 || (fftSize >= 2 && (fftSize and (fftSize - 1)) == 0))
            require(hopSize in 1..fftSize)
            require(frequencyBins in 1..(fftSize / 2 + 1))
            require(timeFrames > 0)
            require(inputName.isNotBlank())
            require(outputName.isNotBlank())
        }
    }

    data class Result(
        val compatible: Boolean,
        val reasons: List<String>,
        val expectedShape: List<Long>
    )

    fun check(
        inspection: SeparationModelInspector.Inspection,
        requirements: Requirements
    ): Result {
        val reasons = mutableListOf<String>()

        val expectedShape = listOf(
            1L,
            4L,
            requirements.frequencyBins.toLong(),
            requirements.timeFrames.toLong()
        )

        val input = inspection.inputs.firstOrNull {
            it.name == requirements.inputName
        }

        if (input == null) {
            reasons += "Configured input tensor was not found."
        } else {
            if (input.type != "FLOAT") {
                reasons += "Input must use Float32."
            }

            if (!matches(input.shape, expectedShape)) {
                reasons +=
                    "Input shape is incompatible with [1, 4, F, T]."
            }
        }

        val output = inspection.outputs.firstOrNull {
            it.name == requirements.outputName
        }

        if (output == null) {
            reasons += "Configured output tensor was not found."
        } else {
            if (output.type != "FLOAT") {
                reasons += "Output must use Float32."
            }

            if (!matches(output.shape, expectedShape)) {
                reasons +=
                    "Output shape is incompatible with [1, 4, F, T]."
            }
        }

        if (inspection.inputs.size != 1) {
            reasons +=
                "Current integration supports exactly one model input."
        }

        if (inspection.outputs.size != 1) {
            reasons +=
                "Current integration supports exactly one model output."
        }

        return Result(
            compatible = reasons.isEmpty(),
            reasons = reasons,
            expectedShape = expectedShape
        )
    }

    fun requireCompatible(
        inspection: SeparationModelInspector.Inspection,
        requirements: Requirements
    ) {
        val result = check(inspection, requirements)

        require(result.compatible) {
            result.reasons.joinToString(
                separator = "\n",
                prefix = "Incompatible separation model:\n"
            )
        }
    }

    private fun matches(
        actual: List<Long>,
        expected: List<Long>
    ): Boolean {
        if (actual.size != expected.size) {
            return false
        }

        return actual.zip(expected).all { (dimension, required) ->
            dimension == -1L || dimension == required
        }
    }
}
