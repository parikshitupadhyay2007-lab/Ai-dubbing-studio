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

                "transcribe" -> {
                    if (!nativeAvailable) {
                        result.error(
                            "NATIVE_UNAVAILABLE",
                            "Whisper runtime unavailable.",
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
                            "Source media or Whisper model missing.",
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
                                    "start" to
                                        (segment["start"] ?: 0.0),
                                    "end" to
                                        (segment["end"] ?: 0.0),
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
                            "Source or dialogue segments missing.",
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
                                    mapOf(
                                        "segments" to identified
                                    )
                                )
                            }

                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "SPEAKER_ERROR",
                                    error.message
                                        ?: "Speaker identification failed.",
                                    null
                                )
                            }
                        } finally {
                            wav.delete()
                        }
                    }
                }

                "translate" -> {
                    processDialogue(
                        call.argument("model_path"),
                        call.argument("segments"),
                        call.argument<String>("source_language")
                            ?: "auto",
                        call.argument<String>("target_language")
                            ?: "hi",
                        false,
                        result
                    )
                }

                "refineDialogue" -> {
                    processDialogue(
                        call.argument("model_path"),
                        call.argument("segments"),
                        "auto",
                        call.argument<String>("target_language")
                            ?: "hi",
                        true,
                        result
                    )
                }

                "chat" -> {
                    val model =
                        call.argument<String>("model_path")

                    val message =
                        call.argument<String>("message") ?: ""

                    if (
                        !nativeAvailable ||
                        model.isNullOrBlank() ||
                        !File(model).isFile ||
                        message.isBlank()
                    ) {
                        result.error(
                            "INVALID_INPUT",
                            "OtakuMind model or input unavailable.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    executor.execute {
                        try {
                            ensureMindLoaded(model)

                            val reply = nativeGenerate(
                                """
                                You are OtakuMind.
                                Respond concisely.

                                User: $message
                                Assistant:
                                """.trimIndent(),
                                96
                            )

                            if (
                                reply.isBlank() ||
                                reply.startsWith("ERROR:")
                            ) {
                                throw IllegalStateException(
                                    "OtakuMind generation failed: $reply"
                                )
                            }

                            runOnUiThread {
                                result.success(
                                    mapOf(
                                        "reply" to reply.trim()
                                    )
                                )
                            }

                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "OTAKUMIND_ERROR",
                                    error.message,
                                    null
                                )
                            }
                        }
                    }
                }

                "synthesize" -> {
                    executor.execute {
                        try {
                            val request =
                                VoiceSynthesisRequest.parse(
                                    call.arguments
                                )

                            val directory = File(
                                filesDir,
                                "synthesis/${System.nanoTime()}"
                            )

                            val clips = PiperSpeechSynthesizer(
                                applicationContext
                            ).use { synthesizer ->
                                synthesizer.synthesize(
                                    request,
                                    directory
                                )
                            }

                            val output = clips.map { clip ->
                                mapOf(
                                    "segment_id" to clip.segmentId,
                                    "speaker_id" to clip.speakerId,
                                    "voice_id" to clip.voiceId,
                                    "start" to clip.start,
                                    "end" to clip.end,
                                    "wav_path" to clip.wavPath,
                                    "sample_rate" to clip.sampleRate
                                )
                            }

                            runOnUiThread {
                                result.success(
                                    mapOf(
                                        "clips" to output,
                                        "output_directory" to
                                            directory.absolutePath
                                    )
                                )
                            }

                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "SYNTHESIS_ERROR",
                                    error.message
                                        ?: "Speech synthesis failed.",
                                    null
                                )
                            }
                        }
                    }
                }

                /*
                 * Combines generated character dialogue into
                 * one timestamp-aligned offline audio track.
                 */
                "mixDialogue" -> {
                    executor.execute {
                        try {
                            val request =
                                DialogueMixRequest.parse(
                                    call.arguments
                                )

                            val outputDirectory = File(
                                filesDir,
                                "dialogue_mix/${System.nanoTime()}"
                            )

                            val mix =
                                OfflineDialogueMixService.createMix(
                                    sourceVideoPath =
                                        request.sourceVideoPath,
                                    clips = request.clips,
                                    outputDirectory = outputDirectory
                                )

                            runOnUiThread {
                                result.success(
                                    mapOf(
                                        "wav_path" to mix.wavPath,
                                        "duration_ms" to mix.durationMs,
                                        "segment_count" to
                                            mix.segmentCount,
                                        "overlap_count" to
                                            mix.overlapCount,
                                        "sample_rate" to
                                            mix.sampleRate
                                    )
                                )
                            }

                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "DIALOGUE_MIX_ERROR",
                                    error.message
                                        ?: "Offline dialogue mixing failed.",
                                    null
                                )
                            }
                        }
                    }
                }

                /*
                 * Final video export will be integrated
                 * after soundtrack processing and muxing.
                 */
                "exportVideo" -> {
                    result.error(
                        "ENGINE_NOT_INTEGRATED",
                        "Video export is not implemented yet.",
                        null
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun processDialogue(
        model: String?,
        segments: List<Map<String, Any?>>?,
        sourceLanguage: String,
        targetLanguage: String,
        refine: Boolean,
        result: MethodChannel.Result
    ) {
        if (
            !nativeAvailable ||
            model.isNullOrBlank() ||
            !File(model).isFile ||
            segments == null ||
            targetLanguage !in listOf("hi", "en")
        ) {
            result.error(
                "INVALID_INPUT",
                "Valid OtakuMind model and dialogue required.",
                null
            )
            return
        }

        executor.execute {
            try {
                ensureMindLoaded(model)

                val output = segments.map { segment ->

                    val original =
                        segment["original"]
                            ?.toString()
                            ?.trim()
                            .orEmpty()

                    val existing =
                        segment["translation"]
                            ?.toString()
                            ?.trim()
                            .orEmpty()

                    val input =
                        if (refine) existing else original

                    if (
                        refine &&
                        input.isBlank() &&
                        original.isNotBlank()
                    ) {
                        throw IllegalStateException(
                            "Translation missing for segment ${segment["id"]}."
                        )
                    }

                    val generated = if (input.isBlank()) {
                        ""
                    } else {
                        val prompt = if (refine) {
                            refinementPrompt(
                                input,
                                original,
                                targetLanguage,
                                segment
                            )
                        } else {
                            translationPrompt(
                                input,
                                sourceLanguage,
                                targetLanguage
                            )
                        }

                        val response = nativeGenerate(
                            prompt,
                            if (refine) 128 else 160
                        )

                        if (
                            response.isBlank() ||
                            response.startsWith("ERROR:")
                        ) {
                            throw IllegalStateException(
                                "OtakuMind failed on segment " +
                                    "${segment["id"]}: $response"
                            )
                        }

                        cleanDialogue(response).ifBlank {
                            throw IllegalStateException(
                                "Empty generated dialogue for " +
                                    "segment ${segment["id"]}."
                            )
                        }
                    }

                    segment.toMutableMap().apply {
                        put("translation", generated)
                    }.toMap()
                }

                runOnUiThread {
                    result.success(
                        mapOf("segments" to output)
                    )
                }

            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        if (refine) {
                            "REFINEMENT_ERROR"
                        } else {
                            "TRANSLATION_ERROR"
                        },
                        error.message
                            ?: "Dialogue processing failed.",
                        null
                    )
                }
            }
        }
    }

    private fun translationPrompt(
        dialogue: String,
        sourceLanguage: String,
        targetLanguage: String
    ): String {

        val target =
            if (targetLanguage == "hi") {
                "Hindi"
            } else {
                "English"
            }

        val source = when (sourceLanguage) {
            "ja" -> "Japanese"
            "en" -> "English"
            "hi" -> "Hindi"
            else -> "the detected original language"
        }

        return """
            Translate this anime dialogue from $source to $target.

            Preserve meaning, names and emotional intent.
            Use natural spoken language.
            Do not explain anything.
            Return only the translated dialogue.

            Dialogue:
            $dialogue

            Translation:
        """.trimIndent()
    }

    private fun refinementPrompt(
        translation: String,
        original: String,
        targetLanguage: String,
        segment: Map<String, Any?>
    ): String {

        val target =
            if (targetLanguage == "hi") {
                "Hindi"
            } else {
                "English"
            }

        val start =
            (segment["start"] as? Number)
                ?.toDouble() ?: 0.0

        val end =
            (segment["end"] as? Number)
                ?.toDouble() ?: start

        val duration =
            (end - start).coerceAtLeast(0.0)

        return """
            You are OtakuMind, an anime dubbing dialogue editor.

            Improve the following $target translation for spoken dubbing.

            Rules:
            - Preserve the original meaning.
            - Keep names and important story details unchanged.
            - Make the dialogue natural and emotionally appropriate.
            - Keep it concise for approximately $duration seconds.
            - Do not invent dialogue.
            - Do not add explanations, labels or quotation marks.
            - Output only one refined dialogue line.

            Original:
            $original

            Existing translation:
            $translation

            Refined dialogue:
        """.trimIndent()
    }

    private fun cleanDialogue(
        response: String
    ): String {

        val line = response
            .substringBefore("\n\n")
            .lineSequence()
            .firstOrNull { it.isNotBlank() }
            ?.trim()
            .orEmpty()

        return line
            .removePrefix("Translation:")
            .removePrefix("Refined dialogue:")
            .removePrefix("Assistant:")
            .trim()
            .trim('"', '“', '”')
            .trim()
    }

    private fun ensureMindLoaded(
        path: String
    ) {
        if (
            loadedModelPath == path &&
            nativeIsLoaded()
        ) {
            return
        }

        nativeRelease()
        loadedModelPath = null

        check(nativeLoadModel(path)) {
            "Could not load OtakuMind GGUF model."
        }

        loadedModelPath = path
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
