
package co.parikshit.otakudub

import java.io.File

/**
 * Metadata describing an offline ONNX audio separation model.
 *
 * Tensor dimensions and audio requirements must come from
 * the actual model documentation, not assumptions.
 */
data class SeparationModelConfig(
    val modelPath: String,
    val sampleRate: Int,
    val channels: Int,
    val inputName: String,
    val outputNames: List<String>,
    val inputShape: List<Long>,
    val outputShapes: List<List<Long>>
) {

    fun validate() {
        require(File(modelPath).isFile) {
            "Separation ONNX model is missing."
        }

        require(
            modelPath.endsWith(
                ".onnx",
                ignoreCase = true
            )
        ) {
            "Separation model must be an ONNX file."
        }

        require(sampleRate in 8000..192000) {
            "Unsupported model sample rate."
        }

        require(channels in 1..2) {
            "Only mono or stereo separation is supported."
        }

        require(inputName.isNotBlank()) {
            "Model input tensor name is missing."
        }

        require(outputNames.isNotEmpty()) {
            "Model output tensor names are missing."
        }

        require(
            outputNames.all { it.isNotBlank() }
        ) {
            "Invalid output tensor name."
        }

        require(
            outputNames.distinct().size ==
                outputNames.size
        ) {
            "Duplicate output tensor names."
        }

        require(inputShape.isNotEmpty()) {
            "Model input tensor shape is missing."
        }

        require(
            inputShape.all { it == -1L || it > 0L }
        ) {
            "Invalid input tensor dimensions."
        }

        require(
            outputShapes.size == outputNames.size
        ) {
            "Output tensor metadata does not match."
        }

        require(
            outputShapes.all { shape ->
                shape.isNotEmpty() &&
                    shape.all { it == -1L || it > 0L }
            }
        ) {
            "Invalid output tensor dimensions."
        }
    }
}
