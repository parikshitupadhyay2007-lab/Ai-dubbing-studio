
package co.parikshit.otakudub

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.io.Closeable
import java.nio.FloatBuffer
import java.nio.LongBuffer

/**
 * Runs Piper-compatible ONNX acoustic inference.
 *
 * This class expects already prepared phoneme IDs.
 * Text phonemization must happen before calling synthesize().
 */
class PiperOnnxEngine : Closeable {

    private val environment = OrtEnvironment.getEnvironment()

    private var session: OrtSession? = null
    private var activeModelPath: String? = null

    fun load(modelPath: String) {
        require(modelPath.isNotBlank()) {
            "Voice model path is empty."
        }

        if (session != null && activeModelPath == modelPath) {
            return
        }

        close()

        val options = OrtSession.SessionOptions()

        try {
            options.setIntraOpNumThreads(2)

            session = environment.createSession(
                modelPath,
                options
            )

            activeModelPath = modelPath

            val requiredInputs = setOf(
                "input",
                "input_lengths",
                "scales"
            )

            val actualInputs = session!!.inputNames

            require(actualInputs.containsAll(requiredInputs)) {
                "ONNX model does not expose the expected Piper inputs."
            }
        } catch (error: Exception) {
            close()
            throw error
        } finally {
            options.close()
        }
    }

    fun synthesize(
        phonemeIds: LongArray,
        speakerId: Long?,
        noiseScale: Float,
        lengthScale: Float,
        noiseW: Float
    ): FloatArray {
        val current = session
            ?: error("Piper voice model is not loaded.")

        require(phonemeIds.isNotEmpty()) {
            "Phoneme sequence is empty."
        }

        require(
            noiseScale.isFinite() &&
                lengthScale.isFinite() &&
                noiseW.isFinite()
        ) {
            "Invalid Piper inference scales."
        }

        require(lengthScale > 0f) {
            "Piper length scale must be positive."
        }

        val inputTensor = OnnxTensor.createTensor(
            environment,
            LongBuffer.wrap(phonemeIds),
            longArrayOf(1, phonemeIds.size.toLong())
        )

        val lengthTensor = OnnxTensor.createTensor(
            environment,
            LongBuffer.wrap(longArrayOf(phonemeIds.size.toLong())),
            longArrayOf(1)
        )

        val scalesTensor = OnnxTensor.createTensor(
            environment,
            FloatBuffer.wrap(
                floatArrayOf(
                    noiseScale,
                    lengthScale,
                    noiseW
                )
            ),
            longArrayOf(3)
        )

        val tensors = mutableMapOf<String, OnnxTensor>(
            "input" to inputTensor,
            "input_lengths" to lengthTensor,
            "scales" to scalesTensor
        )

        try {
            if (current.inputNames.contains("sid")) {
                require(speakerId != null) {
                    "This Piper model requires a speaker ID."
                }

                tensors["sid"] = OnnxTensor.createTensor(
                    environment,
                    LongBuffer.wrap(longArrayOf(speakerId)),
                    longArrayOf(1)
                )
            }

            current.run(tensors).use { result ->
                require(result.size() > 0) {
                    "Piper returned no audio output."
                }

                val output = result[0].value

                return flattenAudio(output).also {
                    require(it.isNotEmpty()) {
                        "Piper generated an empty audio clip."
                    }

                    require(it.all(Float::isFinite)) {
                        "Piper generated invalid audio samples."
                    }
                }
            }
        } finally {
            tensors.values.forEach { tensor ->
                tensor.close()
            }
        }
    }

    private fun flattenAudio(value: Any?): FloatArray {
        return when (value) {
            is FloatArray -> value

            is Array<*> -> {
                val output = ArrayList<Float>()

                fun collect(item: Any?) {
                    when (item) {
                        is Float -> output.add(item)

                        is FloatArray -> {
                            for (sample in item) {
                                output.add(sample)
                            }
                        }

                        is Array<*> -> {
                            for (child in item) {
                                collect(child)
                            }
                        }

                        else -> error(
                            "Unsupported Piper audio output structure."
                        )
                    }
                }

                collect(value)
                output.toFloatArray()
            }

            else -> error(
                "Unsupported Piper audio output type."
            )
        }
    }

    override fun close() {
        session?.close()
        session = null
        activeModelPath = null
    }
}
