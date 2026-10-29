package co.parikshit.otakudub

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.FloatBuffer
import java.security.MessageDigest

/** Local-only ONNX executor; never uses network or declares semantic AI success. */
class Department01Inference(private val modelsDir: File) : MethodChannel.MethodCallHandler {
    private val environment by lazy { OrtEnvironment.getEnvironment() }

    private fun model(call: MethodCall): File {
        val name = call.argument<String>("model_name") ?: error("Missing model_name")
        require(Regex("[a-zA-Z0-9_-]{1,80}\\.onnx").matches(name)) { "Unsafe model name" }
        val root = modelsDir.canonicalFile
        val file = File(root, name).canonicalFile
        require(file.parentFile == root && file.isFile && file.length() > 0L) {
            "Local model weights not installed: $name"
        }
        val expected = call.argument<String>("sha256") ?: error("Missing pinned model checksum")
        require(Regex("[0-9a-f]{64}").matches(expected)) { "Invalid model checksum" }
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        val actual = digest.digest().joinToString("") { "%02x".format(it) }
        require(actual == expected) { "Model checksum mismatch" }
        return file
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "inspectModel" && call.method != "runFloatModel") {
            result.notImplemented()
            return
        }
        try {
            val file = model(call)
            environment.createSession(file.absolutePath, OrtSession.SessionOptions()).use { session ->
                val metadata = mapOf(
                    "model_name" to file.name,
                    "inputs" to session.inputNames.sorted(),
                    "outputs" to session.outputNames.sorted(),
                    "runtime" to "onnxruntime_android",
                    "checksum_verified" to true
                )
                if (call.method == "inspectModel") {
                    result.success(metadata)
                    return
                }
                val inputName = call.argument<String>("input_name") ?: error("Missing input_name")
                require(session.inputNames.contains(inputName) && session.inputNames.size == 1) {
                    "Only explicitly named single-input models are supported"
                }
                val shape = call.argument<List<Number>>("shape")?.map { it.toLong() }
                    ?: error("Missing tensor shape")
                require(shape.isNotEmpty() && shape.size <= 5 && shape.all { it in 1..4096 }) {
                    "Invalid tensor shape"
                }
                val count = shape.fold(1L) { a, b -> Math.multiplyExact(a, b) }
                require(count <= 4_194_304L) { "Input tensor exceeds memory budget" }
                val numbers = call.argument<List<Number>>("values") ?: error("Missing float values")
                require(numbers.size.toLong() == count && numbers.all { it.toFloat().isFinite() }) {
                    "Tensor contents do not match shape or contain nonfinite values"
                }
                OnnxTensor.createTensor(environment,
                    FloatBuffer.wrap(numbers.map { it.toFloat() }.toFloatArray()),
                    shape.toLongArray()).use { tensor ->
                    session.run(mapOf(inputName to tensor)).use { output ->
                        // Never label execution as recognition: a model-specific decoder
                        // must interpret the returned tensors.
                        val summary = session.outputNames.sorted().map { name ->
                            val value = output.get(name).orElseThrow {
                                IllegalStateException("Missing model output: $name")
                            }
                            require(value is OnnxTensor) {
                                "Unsupported non-tensor model output: $name"
                            }
                            val info = value.info
                            require(info.type.toString() == "FLOAT") {
                                "Only float32 model outputs are supported: $name"
                            }
                            val dimensions = info.shape
                            require(dimensions.isNotEmpty() && dimensions.all { it > 0 }) {
                                "Invalid output tensor dimensions: $name"
                            }
                            val count = dimensions.fold(1L) { a, b -> Math.multiplyExact(a, b) }
                            require(count <= 262144L) {
                                "Output tensor exceeds transfer budget: $name"
                            }
                            val floats = value.floatBuffer
                            val values = FloatArray(count.toInt())
                            floats.get(values)
                            require(values.all { it.isFinite() }) {
                                "Nonfinite model output: $name"
                            }
                            mapOf("name" to name, "type" to "float32",
                                "shape" to dimensions.toList(),
                                "values" to values.map { it.toDouble() })
                        }
                        result.success(metadata + mapOf(
                            "executed" to true, "output_metadata" to summary,
                            "semantic_result_verified" to false))
                    }
                }
            }
        } catch (e: Exception) {
            result.error("LOCAL_INFERENCE_FAILED", e.message ?: e.javaClass.simpleName, null)
        }
    }
}
