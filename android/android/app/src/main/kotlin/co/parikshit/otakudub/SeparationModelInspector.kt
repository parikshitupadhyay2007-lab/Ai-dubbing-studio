
package co.parikshit.otakudub

import ai.onnxruntime.OnnxJavaType
import ai.onnxruntime.OnnxTensorInfo
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.io.File

/**
 * Reads actual ONNX tensor metadata without running inference.
 *
 * Audio sample rate and channel count must be supplied from
 * trusted model documentation; ONNX tensor shapes alone
 * cannot reliably establish these audio properties.
 */
object SeparationModelInspector {

    data class TensorDescription(
        val name: String,
        val type: String,
        val shape: List<Long>
    )

    data class Inspection(
        val inputs: List<TensorDescription>,
        val outputs: List<TensorDescription>
    )

    fun inspect(modelPath: String): Inspection {
        require(File(modelPath).isFile) {
            "Separation model file does not exist."
        }

        require(modelPath.endsWith(".onnx", true)) {
            "Expected an ONNX model."
        }

        val environment = OrtEnvironment.getEnvironment()

        OrtSession.SessionOptions().use { options ->
            options.setIntraOpNumThreads(2)

            environment.createSession(
                modelPath,
                options
            ).use { session ->

                fun describe(
                    nodes: Map<String, ai.onnxruntime.NodeInfo>
                ): List<TensorDescription> {
                    return nodes.map { (name, node) ->
                        val info = node.info

                        require(info is OnnxTensorInfo) {
                            "Unsupported non-tensor ONNX node: $name"
                        }

                        TensorDescription(
                            name = name,
                            type = info.type.toString(),
                            shape = info.shape.toList()
                        )
                    }
                }

                return Inspection(
                    inputs = describe(session.inputInfo),
                    outputs = describe(session.outputInfo)
                )
            }
        }
    }

    fun verify(
        inspection: Inspection,
        config: SeparationModelConfig
    ) {
        config.validate()

        val input = inspection.inputs.firstOrNull {
            it.name == config.inputName
        } ?: error(
            "Configured separation input was not found."
        )

        require(input.type == OnnxJavaType.FLOAT.toString()) {
            "This integration requires a FLOAT input tensor."
        }

        require(
            shapesCompatible(
                config.inputShape,
                input.shape
            )
        ) {
            "Configured input shape differs from ONNX metadata."
        }

        for (index in config.outputNames.indices) {
            val name = config.outputNames[index]

            val output = inspection.outputs.firstOrNull {
                it.name == name
            } ?: error(
                "Configured separation output not found: $name"
            )

            require(
                output.type == OnnxJavaType.FLOAT.toString()
            ) {
                "Unsupported separation output type: $name"
            }

            require(
                shapesCompatible(
                    config.outputShapes[index],
                    output.shape
                )
            ) {
                "Output tensor shape mismatch: $name"
            }
        }
    }

    private fun shapesCompatible(
        expected: List<Long>,
        actual: List<Long>
    ): Boolean {
        if (expected.size != actual.size) {
            return false
        }

        return expected.zip(actual).all { (a, b) ->
            a == -1L || b == -1L || a == b
        }
    }
}
