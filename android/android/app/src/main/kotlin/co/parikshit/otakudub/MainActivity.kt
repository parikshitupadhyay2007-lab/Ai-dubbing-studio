package co.parikshit.otakudub

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import android.content.Intent
import android.content.ContentValues
import android.content.ContentUris
import android.provider.MediaStore
import android.os.Build
import androidx.core.content.ContextCompat
import java.io.FileOutputStream
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
    private var cachedTranscriptionSource: String? = null
    private var cachedTranscriptionWav: File? = null

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
    ): Map<String, Any>

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "saveCompletedVideo" -> {
                    val path = call.argument<String>("path")
                    val projectId = call.argument<String>("projectId")
                    if (path.isNullOrBlank() || projectId == null ||
                        !Regex("^[0-9]+$").matches(projectId)) {
                        result.error("INVALID_VIDEO", "Invalid completed video.", null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        var uri: android.net.Uri? = null
                        try {
                            if (Build.VERSION.SDK_INT < 29) {
                                error("Gallery auto-save requires Android 10 or newer.")
                            }
                            val source = File(path)
                            if (!source.isFile || source.length() == 0L ||
                                source.name != "OtakuDub-$projectId.mp4" ||
                                !source.canonicalPath.startsWith(filesDir.parentFile!!.canonicalPath + File.separator)) {
                                error("Completed project MP4 is missing or outside app storage.")
                            }
                            val resolver = contentResolver
                            val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                            val name = "OtakuDub-$projectId.mp4"
                            val projection = arrayOf(MediaStore.Video.Media._ID)
                            val selection = "${MediaStore.Video.Media.DISPLAY_NAME}=? AND ${MediaStore.Video.Media.RELATIVE_PATH}=?"
                            resolver.query(collection, projection, selection,
                                arrayOf(name, "Movies/OtakuDub/"), null)?.use { cursor ->
                                if (cursor.moveToFirst()) {
                                    uri = ContentUris.withAppendedId(collection, cursor.getLong(0))
                                }
                            }
                            if (uri == null) {
                                val values = ContentValues().apply {
                                    put(MediaStore.Video.Media.DISPLAY_NAME, name)
                                    put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                                    put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/OtakuDub/")
                                    put(MediaStore.Video.Media.IS_PENDING, 1)
                                }
                                uri = resolver.insert(collection, values) ?: error("Cannot create gallery video.")
                            } else {
                                resolver.update(uri!!, ContentValues().apply {
                                    put(MediaStore.Video.Media.IS_PENDING, 1)
                                }, null, null)
                            }
                            resolver.openOutputStream(uri!!, "wt")!!.use { output ->
                                source.inputStream().use { input -> input.copyTo(output, 1024 * 1024) }
                            }
                            resolver.update(uri!!, ContentValues().apply {
                                put(MediaStore.Video.Media.IS_PENDING, 0)
                            }, null, null)
                            runOnUiThread { result.success(uri.toString()) }
                        } catch (error: Exception) {
                            uri?.let {
                                try {
                                    contentResolver.update(it, ContentValues().apply {
                                        put(MediaStore.Video.Media.IS_PENDING, 0)
                                    }, null, null)
                                } catch (_: Exception) {}
                            }
                            runOnUiThread { result.error("VIDEO_SAVE_FAILED",
                                error.message ?: "Could not save video to Movies.", null) }
                        }
                    }
                }

                "startBackgroundDubbing" -> {
                    try {
                        ContextCompat.startForegroundService(this,
                            Intent(this, DubbingForegroundService::class.java))
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("BACKGROUND_START_FAILED", error.message, null)
                    }
                }

                "stopBackgroundDubbing" -> {
                    stopService(Intent(this, DubbingForegroundService::class.java))
                    result.success(true)
                }

                "installBundledAsset" -> {
                    val asset = call.argument<String>("asset")
                    val destination = call.argument<String>("destination")
                    if (asset == null || destination == null ||
                        !Regex("^assets/models/[a-zA-Z0-9_./-]+$").matches(asset) ||
                        asset.contains("..")) {
                        result.error("INVALID_ASSET", "Invalid bundled model path.", null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        val target = File(destination)
                        val temporary = File(destination + ".extracting")
                        try {
                            target.parentFile?.mkdirs()
                            val key = io.flutter.FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
                            assets.open(key).use { source ->
                                FileOutputStream(temporary).use { output ->
                                    source.copyTo(output, 1024 * 1024)
                                    output.fd.sync()
                                }
                            }
                            if (temporary.length() == 0L) error("Bundled asset is empty.")
                            if (target.exists() && !target.delete()) error("Cannot replace old model.")
                            if (!temporary.renameTo(target)) error("Cannot install bundled model.")
                            runOnUiThread { result.success(target.length()) }
                        } catch (error: Exception) {
                            temporary.delete()
                            runOnUiThread {
                                result.error("ASSET_INSTALL_FAILED",
                                    error.message ?: "Bundled model extraction failed.", null)
                            }
                        }
                    }
                }

                "runtimeReady" -> {
                    result.success(nativeAvailable)
                }

                // Numerical FFT and STFT diagnostics.
                "validateSeparationTransforms" -> {
                    executor.execute {
                        try {
                            val report =
                                SeparationTransformValidator.runAll()

                            val response = mapOf(
                                "passed" to report.passed,
                                "tests" to report.results.map { test ->
                                    mapOf(
                                        "name" to test.name,
                                        "passed" to test.passed,
                                        "maximum_error" to
                                            test.maximumError,
                                        "tolerance" to test.tolerance,
                                        "details" to test.details
                                    )
                                }
                            )

                            runOnUiThread {
                                result.success(response)
                            }

                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "TRANSFORM_VALIDATION_ERROR",
                                    error.message
                                        ?: "Transform validation failed.",
                                    null
                                )
                            }
                        }
                    }
                }

                "separateSoundtrack" -> {
                    executor.execute {
                        try {
                            val source = requireNotNull(call.argument<String>("source_path"))
                            val model = requireNotNull(call.argument<String>("model_path"))
                            val checksum = requireNotNull(call.argument<String>("checkpoint_sha256"))
                            val input = requireNotNull(call.argument<String>("input_name"))
                            val output = requireNotNull(call.argument<String>("output_name"))
                            val profile = SeparationMdxProfile.instrumentalCandidate()
                            val shape = profile.inputShape.toList()
                            val separator = OfflineMdxSeparator(
                                SeparationModelConfig(model, profile.sampleRate,
                                    profile.channels, input, listOf(output),
                                    listOf(-1L) + shape.drop(1),
                                    listOf(listOf(-1L) + shape.drop(1))),
                                profile, checksum
                            )
                            val stems = separator.separate(SeparationRequest(
                                source, File(cacheDir, "stems/" + System.nanoTime()), model
                            ))
                            runOnUiThread { result.success(mapOf(
                                "vocals_path" to stems.vocalsPath,
                                "accompaniment_path" to stems.accompanimentPath,
                                "sample_rate" to stems.sampleRate,
                                "channels" to stems.channels
                            )) }
                        } catch (error: Exception) {
                            runOnUiThread { result.error("SEPARATION_ERROR",
                                error.message ?: "Separation failed.", null) }
                        }
                    }
                }

                "inspectSeparationModel" -> {
                    val modelPath =
                        call.argument<String>("model_path")

                    if (modelPath.isNullOrBlank()) {
                        result.error(
                            "INVALID_INPUT",
                            "Separation model path is required.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    executor.execute {
                        try {
                            val inspection =
                                SeparationInspectionService.inspect(
                                    modelPath
                                )

                            runOnUiThread {
                                result.success(inspection)
                            }

                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "SEPARATION_INSPECTION_ERROR",
                                    error.message
                                        ?: "Could not inspect ONNX model.",
                                    null
                                )
                            }
                        }
                    }
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

                            val transcription = nativeTranscribeWav(
                                model,
                                wav.absolutePath,
                                language
                            )
                            val detectedLanguage =
                                (transcription["language"] as? String)?.trim().orEmpty()
                            if (detectedLanguage.isBlank() ||
                                detectedLanguage == "auto" ||
                                detectedLanguage == "unknown") {
                                throw IllegalStateException(
                                    "Whisper did not return a detected source language."
                                )
                            }
                            @Suppress("UNCHECKED_CAST")
                            val rawSegments = transcription["segments"]
                                as? List<Map<String, Any>>
                                ?: throw IllegalStateException(
                                    "Whisper returned invalid dialogue segments."
                                )
                            val segments = rawSegments.mapIndexed { index, segment ->
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

                            cachedTranscriptionWav?.delete()
                            cachedTranscriptionWav = wav
                            cachedTranscriptionSource = File(source).canonicalPath +
                                ":" + File(source).length() + ":" + File(source).lastModified()
                            runOnUiThread {
                                result.success(
                                    mapOf(
                                        "segments" to segments,
                                        "language" to detectedLanguage
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
                            if (cachedTranscriptionWav != wav) wav.delete()
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
                        var wav: File? = null
                        try {
                            val sourceFile = File(source)
                            val sourceKey = sourceFile.canonicalPath + ":" +
                                sourceFile.length() + ":" + sourceFile.lastModified()
                            val reusable = cachedTranscriptionWav?.takeIf {
                                cachedTranscriptionSource == sourceKey &&
                                    it.isFile && it.length() > 44
                            }
                            val workingWav = reusable ?: File(
                                cacheDir,
                                "speakers_${System.nanoTime()}.wav"
                            )
                            wav = workingWav
                            if (reusable == null) {
                                OfflineAudioUtils.convertToWhisperWav(
                                    source,
                                    workingWav.absolutePath
                                )
                            }

                            // A requested trained pack must actually run; never silently
                            // substitute the handcrafted acoustic baseline on load failure.
                            val speakerPack = call.argument<String>("speaker_model_manifest")
                            val identified = if (speakerPack.isNullOrBlank()) {
                                SpeakerDiarizer.identify(
                                    workingWav.absolutePath, segments
                                )
                            } else {
                                val manifest = org.json.JSONObject(
                                    File(speakerPack).readText(Charsets.UTF_8)
                                )
                                val packDirectory = File(speakerPack).canonicalFile.parentFile
                                    ?: error("Speaker pack has no parent directory.")
                                fun packFile(key: String): File {
                                    val candidate = File(packDirectory, manifest.getString(key)).canonicalFile
                                    require(candidate.parentFile == packDirectory) {
                                        "Speaker pack paths must refer to files inside its directory."
                                    }
                                    return candidate
                                }
                                val config = SpeakerEmbeddingModelConfig(
                                    modelPath = packFile("model_path").absolutePath,
                                    sha256 = manifest.getString("model_sha256"),
                                    sampleRate = manifest.getInt("sample_rate"),
                                    inputName = manifest.getString("input_name"),
                                    outputName = manifest.getString("output_name"),
                                    embeddingDimension = manifest.getInt("embedding_dimension"),
                                    matchThreshold = manifest.getDouble("match_threshold"),
                                    newSpeakerThreshold = manifest.getDouble("new_speaker_threshold"),
                                    licenseRecord = packFile("license_record").absolutePath,
                                    inputSamples = manifest.getInt("input_samples"),
                                    preprocessing = manifest.getString("preprocessing")
                                )
                                SpeakerOnnxExtractor(config).use { extractor ->
                                    SpeakerDiarizer.identify(
                                        workingWav.absolutePath, segments, extractor,
                                        config.matchThreshold, config.newSpeakerThreshold
                                    )
                                }
                            }

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
                            wav?.delete()
                            if (cachedTranscriptionWav == wav) {
                                cachedTranscriptionWav = null
                                cachedTranscriptionSource = null
                            }
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

                "supertonicSmokeTest" -> {
                    executor.execute {
                        try {
                            val root = File(filesDir, "supertonic3")
                            val report = mutableListOf<Map<String, Any>>()
                            SupertonicSpeechSynthesizer(applicationContext, root).use { engine ->
                                for ((language, profile, sentence) in listOf(
                                    Triple("en", "en_hero", "Hello, this is OtakuDub speaking clearly."),
                                    Triple("hi", "hi_heroine", "नमस्ते, यह ओटाकूडब की आवाज़ का परीक्षण है।")
                                )) {
                                    val voice = NativeVoiceModel(
                                        profile, "supertonic-3", "bundled-supertonic-3",
                                        "bundled-supertonic-3", language, 24000, 1, emptyMap()
                                    )
                                    val request = VoiceSynthesisRequest(
                                        language, mapOf(profile to voice),
                                        mapOf("test_speaker" to profile),
                                        listOf(NativeDialogueSegment(
                                            1, 0.0, 30.0, sentence, "test_speaker", profile, "natural"
                                        ))
                                    )
                                    val destination = File(cacheDir, "supertonic_smoke_$language")
                                    val started = android.os.SystemClock.elapsedRealtime()
                                    val clip = engine.synthesize(request, destination).single()
                                    val elapsed = android.os.SystemClock.elapsedRealtime() - started
                                    val output = File(clip.wavPath)
                                    check(output.isFile && output.length() > 44L)
                                    report.add(mapOf(
                                        "language" to language,
                                        "voice_id" to profile,
                                        "wav_path" to clip.wavPath,
                                        "wav_bytes" to output.length(),
                                        "sample_rate" to clip.sampleRate,
                                        "inference_ms" to elapsed
                                    ))
                                }
                            }
                            runOnUiThread { result.success(mapOf("passed" to true, "clips" to report)) }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error("SUPERTONIC_SMOKE_FAILED", error.message, null)
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

                            val clips = SupertonicSpeechSynthesizer(
                                applicationContext,
                                File(filesDir, "supertonic3")
                            ).use { synthesizer ->
                                synthesizer.synthesize(request, directory)
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
                 * Copies the source video stream and replaces
                 * its audio with AAC-encoded dubbed dialogue.
                 */
                "mixSoundtrack" -> {
                    executor.execute {
                        try {
                            val dialogue = requireNotNull(call.argument<String>("dialogue_wav_path"))
                            val accompaniment = requireNotNull(call.argument<String>("accompaniment_path"))
                            val output = File(filesDir, "soundtrack_mix/${System.nanoTime()}/mix.wav")
                            val path = OfflineSoundtrackMixer.mix(
                                dialogue, accompaniment, output.absolutePath
                            )
                            runOnUiThread { result.success(mapOf("wav_path" to path)) }
                        } catch (error: Exception) {
                            runOnUiThread { result.error("SOUNDTRACK_MIX_ERROR",
                                error.message ?: "Soundtrack mixing failed.", null) }
                        }
                    }
                }

                "exportVideo" -> {
                    executor.execute {
                        try {
                            val request =
                                VideoExportRequest.parse(
                                    call.arguments
                                )

                            val exportedFile =
                                OfflineVideoExporter.export(
                                    request
                                )

                            runOnUiThread {
                                result.success(
                                    mapOf(
                                        "output_path" to
                                            exportedFile.absolutePath,
                                        "file_size" to
                                            exportedFile.length(),
                                        "success" to true
                                    )
                                )
                            }

                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "VIDEO_EXPORT_ERROR",
                                    error.message
                                        ?: "Offline MP4 export failed.",
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

                        // Retry only malformed/unfinished model output. Each
                        // attempt starts with cleared native context; never
                        // publish partial reasoning as dubbed dialogue.
                        var accepted: String? = null
                        var lastFailure: Exception? = null
                        for (attempt in 0 until 2) {
                            // Retain the full translation/refinement contract on
                            // retry. Reducing this to "Input: ..." previously
                            // dropped source language, original dialogue and
                            // the meaning-preservation instructions.
                            // A compact retry avoids exhausting small-model output
                            // budgets on the original verbose prompt.
                            val request = if (attempt == 0) prompt else if (refine) {
                                "/no_think\nRewrite this $targetLanguage spoken dialogue naturally " +
                                    "without changing its meaning. Output only the spoken line.\n" +
                                    "Dialogue: $input\nAnswer:"
                            } else {
                                "/no_think\nTranslate this dialogue from $sourceLanguage to " +
                                    "$targetLanguage. Output only the translation.\n" +
                                    "Dialogue: $original\nAnswer:"
                            }
                            val response = nativeGenerate(
                                request,
                                if (attempt == 0) {
                                    if (refine) 256 else 384
                                } else 512
                            )
                            try {
                                if (response.isBlank() ||
                                    response.startsWith("ERROR:")) {
                                    throw IllegalStateException(
                                        "OtakuMind generation failed on segment ${segment["id"]}: $response"
                                    )
                                }
                                accepted = cleanDialogue(response)
                                break
                            } catch (error: IllegalStateException) {
                                lastFailure = error
                            }
                        }
                        accepted ?: throw IllegalStateException(
                            "OtakuMind could not produce spoken dialogue for " +
                            "segment ${segment["id"]} after two attempts: " +
                            (lastFailure?.message ?: "invalid output")
                        )
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
            /no_think
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
            /no_think
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

    private fun cleanDialogue(response: String): String {
        // Qwen reasoning must never be read aloud as character dialogue.
        var cleaned = response.trim()
        if (cleaned.contains("<think>")) {
            val closing = cleaned.lastIndexOf("</think>")
            if (closing < 0) {
                throw IllegalStateException("OtakuMind returned unfinished reasoning instead of dialogue.")
            }
            cleaned = cleaned.substring(closing + "</think>".length).trim()
        }
        if (cleaned.contains("<|") || cleaned.contains("</think>") ||
            cleaned.contains("<think>") || cleaned.contains("```")) {
            throw IllegalStateException("OtakuMind returned model-control text instead of dialogue.")
        }
        val line = cleaned.lineSequence()
            .map { it.trim() }
            .map {
                it.replace(
                    Regex("^(Translation|Refined dialogue|Assistant|Answer):\\s*", RegexOption.IGNORE_CASE),
                    ""
                ).trim()
            }
            .firstOrNull { it.isNotBlank() }
            .orEmpty()
            .trim('"', '“', '”')
            .trim()
        if (line.isBlank() || line.startsWith("ERROR:") ||
            line.startsWith("Dialogue:", ignoreCase = true)) {
            throw IllegalStateException("OtakuMind did not return usable spoken dialogue.")
        }
        return line
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
            cachedTranscriptionWav?.delete()
            cachedTranscriptionWav = null
            cachedTranscriptionSource = null
            if (nativeAvailable) {
                nativeRelease()
                loadedModelPath = null
            }
        }

        executor.shutdown()

        super.onDestroy()
    }
}
