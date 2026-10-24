package co.parikshit.otakudub

import android.content.Context
import ai.onnxruntime.OrtEnvironment
import java.io.Closeable
import java.io.File
import kotlin.math.abs
import kotlin.math.sqrt

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
            val expressivePrefix = when(segment.delivery) {
                "soft" -> "<breath>"
                "solemn" -> "<sigh>"
                "excited" -> "<laugh>"
                else -> ""
            }
            val window = segment.end - segment.start
            require(window > 0.0 && segment.text.isNotBlank())
            val text = expressivePrefix + segment.text
            val result = engine.call(text, request.targetLanguage, style(styleId), 8, 1.05f, 0.15f, env)
            val count = (result.duration[0] * engine.sampleRate).toInt().coerceIn(0, result.wav.size)
            require(count > 0) { "Supertonic produced no samples for segment ${segment.id}" }
            val samples = result.wav.copyOf(count)
            var power = 0.0
            var peak = 0.0
            for (sample in samples) {
                require(sample.isFinite()) { "Non-finite generated audio" }
                val value = abs(sample.toDouble())
                power += value * value
                if (value > peak) peak = value
            }
            require(sqrt(power / count) >= 0.0001 && peak >= 0.001 && peak < 0.9999695) {
                "Supertonic output is silent or clipping"
            }
            require(count.toDouble() / engine.sampleRate <= window * 1.12) {
                "Supertonic output exceeds dialogue timing window for segment ${segment.id}"
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
