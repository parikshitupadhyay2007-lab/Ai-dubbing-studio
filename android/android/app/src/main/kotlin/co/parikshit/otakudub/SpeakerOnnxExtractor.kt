package co.parikshit.otakudub

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import ai.onnxruntime.TensorInfo
import java.io.Closeable
import java.nio.FloatBuffer

/**
 * Optional raw-waveform ONNX extractor. This is NOT activated by default.
 * Only checkpoints independently verified to accept [1, inputSamples] raw
 * 16 kHz mono Float32 waveform and return [1, embeddingDimension] qualify.
 * Model-specific normalization, mel features or multiple inputs are unsupported.
 */
class SpeakerOnnxExtractor(
    private val config: SpeakerEmbeddingModelConfig
) : SpeakerFeatureExtractor, Closeable {
    private val environment = OrtEnvironment.getEnvironment()
    private val options = OrtSession.SessionOptions().apply { setIntraOpNumThreads(2) }
    private val session: OrtSession
    private var closed = false

    init {
        try {
            config.validate()
            session = environment.createSession(config.modelPath, options)
            try {
                require(session.inputInfo.size == 1 && session.outputInfo.size == 1) {
                    "Speaker model must have exactly one input and one output."
                }
                val input = session.inputInfo[config.inputName]?.info as? TensorInfo
                    ?: throw IllegalArgumentException("Speaker input tensor missing or unsupported.")
                val output = session.outputInfo[config.outputName]?.info as? TensorInfo
                    ?: throw IllegalArgumentException("Speaker output tensor missing or unsupported.")
                require(input.type.toString() == "FLOAT" && output.type.toString() == "FLOAT") {
                    "Speaker ONNX tensors must be Float32."
                }
                require(input.shape.size == 2 && (input.shape[0] == 1L || input.shape[0] == -1L) &&
                    (input.shape[1] == -1L || input.shape[1] == config.inputSamples.toLong())) {
                    "Speaker ONNX input shape does not match verified waveform contract."
                }
                require(output.shape.contentEquals(longArrayOf(config.embeddingDimension.toLong())) ||
                    (output.shape.size == 2 && output.shape[0] in longArrayOf(-1L, 1L) &&
                    output.shape[1] == config.embeddingDimension.toLong())) {
                    "Speaker ONNX output shape does not match verified embedding contract."
                }
            } catch (error: Throwable) {
                session.close()
                throw error
            }
        } catch (error: Throwable) {
            options.close()
            throw error
        }
    }

    @Synchronized
    override fun extract(pcm16kMono: FloatArray): DoubleArray? {
        check(!closed) { "Speaker extractor is closed." }
        val window = SpeakerWaveformWindow.prepare(pcm16kMono, config.inputSamples)
            ?: return null
        OnnxTensor.createTensor(
            environment, FloatBuffer.wrap(window),
            longArrayOf(1, config.inputSamples.toLong())
        ).use { input ->
            session.run(mapOf(config.inputName to input), setOf(config.outputName)).use { result ->
                val output = result.get(config.outputName).orElseThrow {
                    IllegalStateException("Speaker embedding output missing.")
                } as? OnnxTensor ?: throw IllegalStateException("Speaker output is not a tensor.")
                val values = FloatArray(config.embeddingDimension)
                val buffer = output.floatBuffer
                require(buffer.remaining() == values.size) { "Speaker embedding length mismatch." }
                buffer.get(values)
                return SpeakerFeatureValidation.normalizedOrNull(
                    DoubleArray(values.size) { values[it].toDouble() }
                )
            }
        }
    }

    @Synchronized
    override fun close() {
        if (!closed) {
            closed = true
            try { session.close() } finally { options.close() }
        }
    }
}
