
package co.parikshit.otakudub

import java.io.File

/**
 * Exposes separation model metadata in a Flutter-compatible format.
 *
 * This service only inspects ONNX metadata.
 * It does not execute audio separation.
 */
object SeparationInspectionService {

    fun inspect(modelPath: String): Map<String, Any> {
        require(modelPath.isNotBlank()) {
            "Separation model path is required."
        }

        val model = File(modelPath)

        require(model.isFile) {
            "Separation model file does not exist."
        }

        require(model.extension.equals("onnx", ignoreCase = true)) {
            "Expected an ONNX separation model."
        }

        val inspection = SeparationModelInspector.inspect(
            model.absolutePath
        )

        fun serialize(
            tensor: SeparationModelInspector.TensorDescription
        ): Map<String, Any> {
            return mapOf(
                "name" to tensor.name,
                "type" to tensor.type,
                "shape" to tensor.shape
            )
        }

        return mapOf(
            "model_name" to model.name,
            "model_path" to model.absolutePath,
            "model_size_bytes" to model.length(),
            "inputs" to inspection.inputs.map(::serialize),
            "outputs" to inspection.outputs.map(::serialize),
            "inspection_success" to true
        )
    }
}
