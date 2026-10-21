package co.parikshit.otakudub

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OnnxTensorInfo
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.io.Closeable
import java.nio.FloatBuffer

/**
 * Runs a verified Float32 ONNX separation model.
 *
 * This class performs inference only.
 * Audio preprocessing and reconstruction are separate.
 *
 * Instances must be closed after use.
 */
class SeparationOnnxRunner(
    private val config: SeparationModelConfig
) : Closeable {

    data class OutputTensor(
        val name: String,
        val shape: LongArray,
        val values: FloatArray
    )

    private val environment = OrtEnvironment.getEnvironment()

    private val options = OrtSession.SessionOptions().apply {
        setIntraOpNumThreads(2)
    }

    private val session: OrtSession

    private var closed = false

    init {
        try {
            config.validate()

            session = environment.createSession(
                config.modelPath,
                options
            )

            try {
                val inspection = SeparationModelInspector.Inspection(
                    inputs = session.inputInfo.map { (name, node) ->
                        val info = node.info as? OnnxTensorInfo
                            ?: error("Unsupported input node: $name")

                        SeparationModelInspector.TensorDescription(
                            name = name,
                            type = info.type.toString(),
                            shape = info.shape.toList()
                        )
                    },
                    outputs = session.outputInfo.map { (name, node) ->
                        val info = node.info as? OnnxTensorInfo
                            ?: error("Unsupported output node: $name")

                        SeparationModelInspector.TensorDescription(
                            name = name,
                            type = info.type.toString(),
                            shape = info.shape.toList()
                        )
                    }
                )

                SeparationModelInspector.verify(
                    inspection,
                    config
                )
            } catch (error: Throwable) {
                session.close()
                throw error
            }
        } catch (error: Throwable) {
            options.close()
            throw error
        }
    }

    /**
     * Executes inference using the supplied flattened tensor.
     *
     * The input shape must match the configured model input.
     * Dynamic dimensions are supported.
     */
    @Synchronized
    fun run(
        inputValues: FloatArray,
        inputShape: LongArray
    ): List<OutputTensor> {
        check(!closed) {
            "ONNX separation runner is closed."
        }

        require(inputValues.isNotEmpty()) {
            "ONNX input tensor is empty."
        }

        require(inputValues.all { it.isFinite() }) {
            "ONNX input contains non-finite values."
        }

        validateShape(
            inputShape,
            config.inputShape,
            "Input"
        )

        require(elementCount(inputShape) == inputValues.size.toLong()) {
            "Input tensor shape does not match its data length."
        }

        OnnxTensor.createTensor(
            environment,
            FloatBuffer.wrap(inputValues),
            inputShape
        ).use { input ->

            session.run(
                mapOf(config.inputName to input),
                config.outputNames.toSet()
            ).use { results ->

                return config.outputNames.mapIndexed { index, name ->
                    val value = results.get(name).orElseThrow {
                        IllegalStateException(
                            "Missing ONNX output: $name"
                        )
                    }

                    val tensor = value as? OnnxTensor
                        ?: error(
                            "ONNX output is not a tensor: $name"
                        )

                    val info = tensor.info as? OnnxTensorInfo
                        ?: error(
                            "Invalid ONNX output metadata: $name"
                        )

                    val shape = info.shape.copyOf()

                    validateShape(
                        shape,
                        config.outputShapes[index],
                        "Output $name"
                    )

                    val count = elementCount(shape)

                    require(count <= Int.MAX_VALUE) {
                        "ONNX output exceeds supported array size."
                    }

                    val buffer = tensor.floatBuffer

                    require(buffer.remaining().toLong() == count) {
                        "ONNX output data length mismatch: $name"
                    }

                    val values = FloatArray(count.toInt())
                    buffer.get(values)

                    require(values.all { it.isFinite() }) {
                        "ONNX output contains non-finite values: $name"
                    }

                    OutputTensor(
                        name = name,
                        shape = shape,
                        values = values
                    )
                }
            }
        }
    }

    private fun validateShape(
        actual: LongArray,
        expected: List<Long>,
        label: String
    ) {
        require(actual.size == expected.size) {
            "$label tensor rank mismatch."
        }

        for (index in actual.indices) {
            require(actual[index] > 0L) {
                "$label contains an unresolved dimension."
            }

            require(
                expected[index] == -1L ||
                    expected[index] == actual[index]
            ) {
                "$label tensor dimension mismatch at index $index."
            }
        }
    }

    private fun elementCount(shape: LongArray): Long {
        var count = 1L

        for (dimension in shape) {
            require(dimension > 0L) {
                "Tensor dimensions must be positive."
            }

            require(count <= Long.MAX_VALUE / dimension) {
                "Tensor element count overflow."
            }

            count *= dimension
        }

        return count
    }

    @Synchronized
    override fun close() {
        if (!closed) {
            closed = true

            try {
                session.close()
            } finally {
                options.close()
            }
        }
    }
}
