package co.parikshit.otakudub

import android.content.Context
import ai.onnxruntime.OrtEnvironment
import java.io.Closeable
import java.io.File
import kotlin.math.abs
import kotlin.math.sqrt
import kotlin.math.floor

/** Four-stage Supertonic 3 renderer using the upstream Java ONNX graph. */
class SupertonicSpeechSynthesizer(
    context: Context,
    private val models: File
) : Closeable {
    private val env = OrtEnvironment.getEnvironment()
    private val engine: TextToSpeech
    private val styles = HashMap<String, Style>()
    private var closed = false
    init {
        val onnx = File(models, "onnx")
        listOf("duration_predictor.onnx", "text_encoder.onnx", "vector_estimator.onnx",
            "vocoder.onnx", "tts.json", "unicode_indexer.json").forEach {
            require(File(onnx, it).isFile) { "Supertonic component is missing: $it" }
        }
        engine = Helper.loadTextToSpeech(onnx.absolutePath, false, env)
    }
    private fun style(id: String): Style = styles.getOrPut(id) {
        require(Regex("[FM][1-5]").matches(id)) { "Invalid Supertonic voice style" }
        val asset = File(models, "voice_styles/$id.json")
        require(asset.isFile) { "Missing Supertonic voice style $id" }
        Helper.loadVoiceStyle(listOf(asset.absolutePath), false, env)
    }
    fun synthesize(request: VoiceSynthesisRequest, outputDirectory: File): List<SynthesizedDialogueClip> {
        check(!closed)
        require(outputDirectory.isDirectory || outputDirectory.mkdirs())
        return request.segments.sortedWith(compareBy<NativeDialogueSegment> { it.start }.thenBy { it.id }).map { segment ->
            val voice = request.characterVoices[segment.speakerId]
            require(voice == segment.voiceId) { "Character voice assignment mismatch" }
            require(request.voices.containsKey(voice)) { "Uninstalled character voice" }
            val styleId = when (voice) {
                "en_hero" -> "F1" // Legacy Lessac English heroine profile
                else -> when (voice?.removePrefix("hi_")?.removePrefix("en_")) {
                    "hero" -> "M1"
                    "young_male" -> "M2"
                    "deep_male" -> "M3"
                    "mature_male" -> "M4"
                    "villain", "rough_male" -> "M5"
                    "heroine" -> "F1"
                    "young_female" -> "F2"
                    "mature_female" -> "F3"
                    "strong_female" -> "F4"
                    "youthful_soft", "youthful_bright" -> "F5"
                    else -> error("Supertonic style not assigned for $voice")
                }
            }
            // Supertonic's verified ONNX interface exposes generation speed and
            // stochasticity, not a validated emotion-conditioning tensor.
            // Never inject unsupported pseudo-tags into spoken dialogue.
            val (baseSpeed, stochasticity) = when (segment.delivery) {
                "soft" -> 0.96f to 0.12f
                "solemn" -> 0.94f to 0.10f
                "urgent" -> 1.16f to 0.12f
                "excited" -> 1.10f to 0.18f
                else -> 1.05f to 0.15f
            }
            val window = segment.end - segment.start
            require(window > 0.0 && segment.text.isNotBlank())
            val text = segment.text
            val preset = style(styleId)
            var result = engine.call(text, request.targetLanguage, preset, 8,
                baseSpeed, stochasticity, env)
            // One bounded speed retry; never silently mix speech past the scene boundary.
            // Speech naturalness takes precedence over unlimited forced compression.
            val firstLength = result.duration[0].toDouble()
            if (firstLength.isFinite() && firstLength > window * 1.12 && window >= 0.5) {
                val speed = (baseSpeed * firstLength / window * 1.03).coerceIn(baseSpeed, 1.28f)
                if (speed > baseSpeed + 0.02f) {
                    val candidate = engine.call(text, request.targetLanguage, preset, 8, speed, stochasticity, env)
                    if (candidate.duration[0].isFinite() &&
                        kotlin.math.abs(candidate.duration[0] - window) <
                        kotlin.math.abs(result.duration[0] - window)) {
                        result = candidate
                    }
                }
            }
            val count = (result.duration[0] * engine.sampleRate).toInt().coerceIn(0, result.wav.size)
            require(count > 0) { "Supertonic produced no samples for segment ${segment.id}" }
            // The model's estimated duration does not guarantee a dialogue-window fit.
            // Use the generation-speed retry above before bounded post-render fitting.
            // Resample the ENTIRE waveform: never crop away the final spoken phonemes.
            val targetSamples = floor(window * engine.sampleRate).toInt()
            require(targetSamples >= 2) { "Dialogue timing window is too short for segment ${segment.id}" }
            val rendered = result.wav.copyOf(count)
            val samples = if (count > targetSamples) {
                val compression = count.toDouble() / targetSamples
                require(compression <= 1.50) {
                    "Dialogue for segment ${segment.id} requires excessive duration compression; rendered_seconds=${count.toDouble() / engine.sampleRate}; window_seconds=$window; required_ratio=$compression; shorten the translation."
                }
                // Preserve pitch through waveform-similarity overlap-add.
                // Never truncate the final spoken phonemes or change playback rate.
                val fitted = WsolaTimeStretch.compress(
                    rendered, targetSamples, engine.sampleRate
                )
                // A 10 ms fade avoids a discontinuity at the window boundary.
                val fade = (engine.sampleRate / 100).coerceAtMost(fitted.size)
                for (i in 0 until fade) {
                    val index = fitted.lastIndex - i
                    fitted[index] *= i.toFloat() / fade
                }
                fitted
            } else rendered
            var power = 0.0
            var peak = 0.0
            for (sample in samples) {
                require(sample.isFinite()) { "Non-finite generated audio" }
                val value = abs(sample.toDouble())
                power += value * value
                if (value > peak) peak = value
            }
            require(sqrt(power / samples.size) >= 0.0001 && peak >= 0.001 && peak < 0.9999695) {
                "Supertonic output is silent or clipping"
            }
            require(samples.size.toDouble() / engine.sampleRate <= window) {
                "Duration fitting failed for segment ${segment.id}"
            }
            val output = VoiceWavWriter.write(File(outputDirectory, "segment_${segment.id}.wav"),
                samples, engine.sampleRate)
            SynthesizedDialogueClip(segment.id, segment.speakerId, segment.voiceId,
                segment.start, segment.end, output.absolutePath, engine.sampleRate)
        }
    }
    override fun close() {
        if (closed) return
        closed = true
        styles.values.forEach { it.close() }
        engine.close()
    }
}
