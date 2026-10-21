
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
        } catch (_: UnsatisfiedLinkError) {
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

    private external fun nativeTranscribeWav(
        modelPath: String,
        wavPath: String,
        language: String
    ): List<Map<String, Any>>

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

                // WHISPER TRANSCRIPTION

                "transcribe" -> {
                    if (!nativeAvailable) {
                        result.error(
                            "NATIVE_UNAVAILABLE",
                            "Native Whisper runtime unavailable.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val source =
                        call.argument<String>("source_path")

                    val model =
                        call.argument<String>("model_path")

                    val language =
                        call.argument<String>("language") ?: "auto"

                    if (
                        source.isNullOrBlank() ||
                        model.isNullOrBlank() ||
                        !File(source).isFile ||
                        !File(model).isFile
                    ) {
                        result.error(
                            "FILE_MISSING",
                            "Source or Whisper model missing.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    executor.execute {
                        val wav = File(
                            cacheDir,
                            "whisper_${System.nanoTime()}.wav"
                        )

                        try {
                            OfflineAudioUtils.convertToWhisperWav(
                                source,
                                wav.absolutePath
                            )

                            val segments = nativeTranscribeWav(
                                model,
                                wav.absolutePath,
                                language
                            ).mapIndexed { index, segment ->
                                mapOf(
                                    "id" to index,
                                    "start" to (segment["start"] ?: 0.0),
                                    "end" to (segment["end"] ?: 0.0),
                                    "original" to
                                        (segment["original"] ?: ""),
                                    "translation" to "",
                                    "speaker_id" to "unknown",
                                    "voice_id" to "",
                                    "speaker_confidence" to 0.0
                                )
                            }

                            runOnUiThread {
                                result.success(
                                    mapOf(
                                        "segments" to segments,
                                        "language" to language
                                    )
                                )
                            }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "TRANSCRIPTION_ERROR",
                                    error.message
                                        ?: "Transcription failed.",
                                    null
                                )
                            }
                        } finally {
                            wav.delete()
                        }
                    }
                }

                // AUTOMATIC SPEAKER IDENTIFICATION

                "identifySpeakers" -> {
                    val source =
                        call.argument<String>("source_path")

                    val segments =
                        call.argument<List<Map<String, Any?>>>(
                            "segments"
                        )

                    if (
                        source.isNullOrBlank() ||
                        !File(source).isFile ||
                        segments == null
                    ) {
                        result.error(
                            "INVALID_INPUT",
                            "Source media or dialogue segments missing.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    executor.execute {
                        val wav = File(
                            cacheDir,
                            "speakers_${System.nanoTime()}.wav"
                        )

                        try {
                            OfflineAudioUtils.convertToWhisperWav(
                                source,
                                wav.absolutePath
                            )

                            val identified =
                                SpeakerDiarizer.identify(
                                    wav.absolutePath,
                                    segments
                                )

                            runOnUiThread {
                                result.success(
                                    mapOf("segments" to identified)
                                )
                            }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "SPEAKER_ERROR",
                                    error.message
                                        ?: "Speaker analysis failed.",
                                    null
                                )
                            }
                        } finally {
                            wav.delete()
                        }
                    }
                }

                // AUTOMATIC OFFLINE TRANSLATION

                "translate" -> {
                    if (!nativeAvailable) {
                        result.error(
                            "NATIVE_UNAVAILABLE",
                            "OtakuMind runtime unavailable.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val model =
                        call.argument<String>("model_path")

                    val sourceLanguage =
                        call.argument<String>("source_language")
                            ?: "auto"

                    val targetLanguage =
                        call.argument<String>("target_language")
                            ?: "hi"

                    val segments =
                        call.argument<List<Map<String, Any?>>>(
                            "segments"
                        )

                    if (
                        model.isNullOrBlank() ||
                        !File(model).isFile ||
                        segments == null ||
                        targetLanguage !in listOf("hi", "en")
                    ) {
                        result.error(
                            "INVALID_INPUT",
                            "Invalid translation model or dialogue.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    executor.execute {
                        try {
                            ensureMindLoaded(model)

                            val translated = segments.map { segment ->
                                val original =
                                    segment["original"]
                                        ?.toString()
                                        ?.trim()
                                        .orEmpty()

                                val translation =
                                    if (original.isBlank()) {
                                        ""
                                    } else {
                                        val prompt =
                                            translationPrompt(
                                                original,
                                                sourceLanguage,
                                                targetLanguage
                                            )

                                        val generated =
                                            nativeGenerate(
                                                prompt,
                                                160
                                            ).trim()

                                        if (
                                            generated.isBlank() ||
                                            generated.startsWith("ERROR:")
                                        ) {
                                            throw IllegalStateException(
                                                "Translation failed for " +
                                                "segment ${segment["id"]}: " +
                                                generated
                                            )
                                        }

                                        cleanTranslation(generated)
                                    }

                                segment.toMutableMap().apply {
                                    put(
                                        "translation",
                                        translation
                                    )
                                }.toMap()
                            }

                            runOnUiThread {
                                result.success(
                                    mapOf(
                                        "segments" to translated
                                    )
                                )
                            }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "TRANSLATION_ERROR",
                                    error.message
                                        ?: "Offline translation failed.",
                                    null
                                )
                            }
                        }
                    }
                }

                // INTERNAL OTAKUMIND ENGINE

                "chat" -> {
                    if (!nativeAvailable) {
                        result.error(
                            "NATIVE_UNAVAILABLE",
                            "OtakuMind runtime unavailable.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val model =
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
                        model.isNullOrBlank() ||
                        !File(model).isFile ||
                        message.isBlank()
                    ) {
                        result.error(
                            "INVALID_INPUT",
                            "OtakuMind model or message missing.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    executor.execute {
                        try {
                            ensureMindLoaded(model)

                            val reply = nativeGenerate(
                                buildPrompt(
                                    message,
                                    personality,
                                    language,
                                    history
                                ),
                                96
                            )

                            runOnUiThread {
                                if (
                                    reply.isBlank() ||
                                    reply.startsWith("ERROR:")
                                ) {
                                    result.error(
                                        "INFERENCE_ERROR",
                                        reply.ifBlank {
                                            "OtakuMind returned no text."
                                        },
                                        null
                                    )
                                } else {
                                    result.success(
                                        mapOf(
                                            "reply" to reply.trim()
                                        )
                                    )
                                }
                            }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "OTAKUMIND_ERROR",
                                    error.message
                                        ?: "Inference failed.",
                                    null
                                )
                            }
                        }
                    }
                }

                "refineDialogue",
                "synthesize",
                "exportVideo" -> {
                    result.error(
                        "ENGINE_NOT_INTEGRATED",
                        "${call.method} is not implemented yet.",
                        null
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun translationPrompt(
        original: String,
        sourceLanguage: String,
        targetLanguage: String
    ): String {
        val target =
            if (targetLanguage == "hi") "Hindi" else "English"

        val source = when (sourceLanguage) {
            "ja" -> "Japanese"
            "en" -> "English"
            "hi" -> "Hindi"
            else -> "the original language"
        }

        return """
            You are a professional anime dialogue translator.

            Translate the following dialogue from $source into $target.

            Requirements:
            - Preserve the original meaning.
            - Use natural spoken $target.
            - Preserve character names.
            - Do not add explanations.
            - Do not add commentary.
            - Do not include the original sentence.
            - Output only the translated dialogue.

            Original dialogue:
            $original

            Translation:
        """.trimIndent()
    }

    private fun cleanTranslation(text: String): String {
        return text
            .substringBefore("\n\n")
            .lineSequence()
            .firstOrNull {
                it.isNotBlank()
            }
            ?.trim()
            ?.removePrefix("Translation:")
            ?.removePrefix("Assistant:")
            ?.trim()
            ?.trim('"')
            .orEmpty()
    }

    private fun ensureMindLoaded(path: String) {
        if (
            loadedModelPath == path &&
            nativeIsLoaded()
        ) {
            return
        }

        nativeRelease()
        loadedModelPath = null

        check(nativeLoadModel(path)) {
            "Could not load OtakuMind model."
        }

        loadedModelPath = path
    }

    private fun buildPrompt(
        message: String,
        personality: String,
        language: String,
        history: List<Map<String, String>>
    ): String {
        val responseLanguage =
            if (language == "hi") "Hindi" else "English"

        val conversation =
            history.takeLast(8).joinToString("\n") {
                val role =
                    if (it["role"] == "assistant") {
                        "Assistant"
                    } else {
                        "User"
                    }

                "$role: ${it["content"] ?: ""}"
            }

        return """
            You are OtakuMind, an offline anime-focused AI assistant.
            Personality: $personality.
            Respond in $responseLanguage.
            Be concise and helpful.

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
