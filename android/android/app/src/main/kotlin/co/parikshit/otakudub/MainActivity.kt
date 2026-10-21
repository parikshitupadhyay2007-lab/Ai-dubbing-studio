
package co.parikshit.otakudub

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL =
            "co.parikshit.otakudub/offline_engine"

        init {
            System.loadLibrary("otakudub_native")
        }
    }

    private val executor = Executors.newSingleThreadExecutor()

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
                    result.success(
                        mapOf(
                            "ready" to true,
                            "engine" to "OtakuDub Native",
                            "otakumind" to true
                        )
                    )
                }

                "chat" -> {
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
                            "OtakuMind GGUF model is missing.",
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
                            if (!nativeIsLoaded()) {
                                if (!nativeLoadModel(modelPath)) {
                                    throw IllegalStateException(
                                        "Could not load the GGUF model."
                                    )
                                }
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
                                } else {
                                    result.success(
                                        mapOf("reply" to reply.trim())
                                    )
                                }
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error(
                                    "OTAKUMIND_ERROR",
                                    e.message ?: "Inference failed.",
                                    null
                                )
                            }
                        }
                    }
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
            nativeRelease()
        }
        super.onDestroy()
    }
}
