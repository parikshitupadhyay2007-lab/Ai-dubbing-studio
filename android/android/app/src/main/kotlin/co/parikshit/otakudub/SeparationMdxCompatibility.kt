
package co.parikshit.otakudub

import ai.onnxruntime.OnnxJavaType

/**
 * Checks whether actual ONNX tensor metadata matches an
 * MDX preprocessing profile.
 *
 * This is structural validation only.
 * It does not verify model weights, audio quality, licensing,
 * normalization conventions or the predicted stem.
 */
object SeparationMdxCompatibility {

    data class Result(
        val compatible: Boolean,
        val reasons: List<String>,
        val expectedShape: List<Long>,
        val inputName: String,
        val outputName: String
    )

    fun check(
        inspection: SeparationModelInspector.Inspection,
        profile: SeparationMdxProfile,
        inputName: String,
        outputName: String
    ): Result {
        val reasons = mutableListOf<String>()
        val expected = profile.inputShape.toList()
        val floatType = OnnxJavaType.FLOAT.toString()

        if (inputName.isBlank()) {
            reasons += "Input tensor name is missing."
        }

        if (outputName.isBlank()) {
            reasons += "Output tensor name is missing."
        }

        if (inspection.inputs.size != 1) {
            reasons +=
                "This MDX integration requires exactly one input."
        }

        val input = inspection.inputs.firstOrNull {
            it.name == inputName
        }

        if (input == null) {
            reasons += "Configured ONNX input was not found."
        } else {
            if (input.type != floatType) {
                reasons += "ONNX input must be Float32."
            }

            if (!matches(input.shape, expected)) {
                reasons +=
                    "ONNX input dimensions do not match the MDX profile."
            }
        }

        val output = inspection.outputs.firstOrNull {
            it.name == outputName
        }

        if (output == null) {
            reasons += "Configured ONNX output was not found."
        } else {
            if (output.type != floatType) {
                reasons += "ONNX output must be Float32."
            }

            if (!matches(output.shape, expected)) {
                reasons +=
                    "ONNX output dimensions do not match the MDX profile."
            }
        }

        return Result(
            compatible = reasons.isEmpty(),
            reasons = reasons,
            expectedShape = expected,
            inputName = inputName,
            outputName = outputName
        )
    }

    fun requireCompatible(
        inspection: SeparationModelInspector.Inspection,
        profile: SeparationMdxProfile,
        inputName: String,
        outputName: String
    ) {
        val result = check(
            inspection = inspection,
            profile = profile,
            inputName = inputName,
            outputName = outputName
        )

        require(result.compatible) {
            result.reasons.joinToString(
                separator = "\n",
                prefix = "Incompatible MDX model:\n"
            )
        }
    }

    /**
     * Dynamic ONNX dimensions (-1) are accepted.
     * Every fixed dimension must match the profile.
     */
    private fun matches(
        actual: List<Long>,
        expected: List<Long>
    ): Boolean {
        if (actual.size != expected.size) {
            return false
        }

        return actual.zip(expected).all { (a, b) ->
            a == -1L || a == b
        }
    }
}
