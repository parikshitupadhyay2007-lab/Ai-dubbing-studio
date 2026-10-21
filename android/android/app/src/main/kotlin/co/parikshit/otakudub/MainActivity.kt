
package co.parikshit.otakudub

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL =
            "co.parikshit.otakudub/offline_engine"

        private val nativeAvailable: Boolean = try {
            System.loadLibrary("otakudub_native")
            true
        } catch (error: UnsatisfiedLinkError) {
            false
        }
    }

    private val executor = Executors.newSingleThreadExecutor()

    private var loadedModelPath: String? = null

    private external fun nativeLoadModel(path: String): Boolean

    private external fun nativeGenerate(
        prompt: String,
        maxTokens: Int
    ): String

    private external fun nativeRelease()

    private external fun nativeIsLoaded(): Boolean

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "runtimeReady" -> {
                    result.success(nativeAvailable)
                }

                "chat" -> {
                    if (!nativeAvailable) {
                        result.error(
                            "NATIVE_UNAVAILABLE",
                            "OtakuDub native library is not installed.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val modelPath =
                        call.argument<String>("model_path")

                    val message =
                        call.argument<String>("message") ?: ""

                    val personality =
                        call.argument<String>("personality") ?: "spirit"

                    val language =
                        call.argument<String>("language") ?: "en"

                    val history =
                        call.argument<List<Map<String, String>>>(
                            "history"
                        ) ?: emptyList()

                    if (
                        modelPath.isNullOrBlank() ||
                        !File(modelPath).isFile
                    ) {
                        result.error(
                            "MODEL_MISSING",
                            "Import a compatible OtakuMind GGUF model.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    if (message.isBlank()) {
                        result.error(
                            "EMPTY_MESSAGE",
                            "Please enter a message.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    executor.execute {
                        try {
                            if (
                                loadedModelPath != modelPath ||
                                !nativeIsLoaded()
                            ) {
                                nativeRelease()
                                loadedModelPath = null

                                if (!nativeLoadModel(modelPath)) {
                                    throw IllegalStateException(
                                        "Could not load the GGUF model."
                                    )
                                }

                                loadedModelPath = modelPath
                            }

                            val prompt = buildPrompt(
                                message,
                                personality,
                                language,
                                history
                            )

                            val reply = nativeGenerate(prompt, 256)

                            runOnUiThread {
                                if (reply.startsWith("ERROR:")) {
                                    result.error(
                                        "INFERENCE_ERROR",
                                        reply,
                                        null
                                    )
                                } else if (reply.isBlank()) {
                                    result.error(
                                        "EMPTY_RESPONSE",
                                        "The local model returned no text.",
                                        null
                                    )
                                } else {
                                    result.success(
                                        mapOf("reply" to reply.trim())
                                    )
                                }
                            }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "OTAKUMIND_ERROR",
                                    error.message ?: "Inference failed.",
                                    null
                                )
                            }
                        }
                    }
                }

                "transcribe",
                "identifySpeakers",
                "translate",
                "refineDialogue",
                "synthesize",
                "exportVideo" -> {
                    result.error(
                        "ENGINE_NOT_INTEGRATED",
                        "${call.method} requires its native engine integration.",
                        null
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun buildPrompt(
        message: String,
        personality: String,
        language: String,
        history: List<Map<String, String>>
    ): String {
        val responseLanguage =
            if (language == "hi") "Hindi" else "English"

        val conversation = history.takeLast(8).joinToString("\n") {
            val role =
                if (it["role"] == "assistant") "Assistant" else "User"

            "$role: ${it["content"] ?: ""}"
        }

        return """
            You are OtakuMind, an offline anime-focused AI assistant.
            Personality: $personality.
            Respond in $responseLanguage.
            Be helpful, conversational and concise.

            $conversation
            User: $message
            Assistant:
        """.trimIndent()
    }

    override fun onDestroy() {
        executor.execute {
            if (nativeAvailable) {
                nativeRelease()
                loadedModelPath = null
            }
        }

        executor.shutdown()
        super.onDestroy()
    }
}
