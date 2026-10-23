package co.parikshit.otakudub

import android.content.Context
import java.io.Closeable
import java.io.File

data class SynthesizedDialogueClip(
    val segmentId: Int,
    val speakerId: String,
    val voiceId: String,
    val start: Double,
    val end: Double,
    val wavPath: String,
    val sampleRate: Int
)

class PiperSpeechSynthesizer(
    context: Context
) : Closeable {

    private val phonemizer =
        OfflinePhonemizer.create(context.applicationContext)

    private val engine = PiperOnnxEngine()

    private var phonemizerInitialized = false
    private var closed = false

    @Synchronized
    fun synthesize(
        request: VoiceSynthesisRequest,
        outputDirectory: File
    ): List<SynthesizedDialogueClip> {

        check(!closed) {
            "Speech synthesizer is already closed."
        }

        require(request.segments.isNotEmpty()) {
            "No dialogue segments supplied."
        }

        check(
            outputDirectory.isDirectory ||
                outputDirectory.mkdirs()
        ) {
            "Cannot create synthesis directory."
        }

        val configs =
            mutableMapOf<String, PiperPhonemizerConfig>()

        val encoders =
            mutableMapOf<String, PiperPhonemeEncoder>()

        val clips = ArrayList<SynthesizedDialogueClip>()

        val orderedSegments = request.segments.sortedWith(
            compareBy<NativeDialogueSegment> { it.start }
                .thenBy { it.id }
        )

        for (segment in orderedSegments) {

            require(segment.text.isNotBlank()) {
                "Empty translation for segment ${segment.id}."
            }

            val assignedVoice =
                request.characterVoices[segment.speakerId]

            require(assignedVoice == segment.voiceId) {
                "Character voice assignment mismatch."
            }

            val voice = request.voices[segment.voiceId]
                ?: error(
                    "Voice model unavailable: ${segment.voiceId}"
                )

            val config = configs.getOrPut(segment.voiceId) {
                PiperPhonemizerConfig.load(
                    File(voice.configPath),
                    request.targetLanguage
                )
            }

            require(config.sampleRate == voice.sampleRate) {
                "Voice sample rate mismatch."
            }

            val encoder = encoders.getOrPut(segment.voiceId) {
                PiperPhonemeEncoder(
                    File(voice.configPath)
                )
            }

            val phonemes = when (config.type) {
                PiperPhonemeType.ESPEAK -> {
                    if (!phonemizerInitialized) {
                        phonemizer.initialize()
                        phonemizerInitialized = true
                    }

                    phonemizer.phonemize(
                        segment.text,
                        config
                    )
                }

                PiperPhonemeType.TEXT -> segment.text
            }

            val phonemeIds =
                encoder.encodeCodePoints(phonemes)

            engine.load(voice.modelPath)

            val speakerId: Long? =
                if (voice.numSpeakers > 1) {
                    val id = voice.speakerIds[segment.voiceId]
                        ?: voice.speakerIds[voice.profileId]
                        ?: error(
                            "Missing model speaker ID: ${segment.voiceId}"
                        )

                    require(id in 0 until voice.numSpeakers) {
                        "Model speaker ID is out of range."
                    }

                    id.toLong()
                } else {
                    null
                }

            // Fit the generated utterance to its source dialogue window when
            // possible. Piper lengthScale controls speaking duration (smaller
            // means faster); one bounded retry avoids unbounded inference and
            // avoids extreme speed-ups that destroy intelligibility.
            var samples = engine.synthesize(
                phonemeIds = phonemeIds,
                speakerId = speakerId,
                noiseScale = config.noiseScale,
                lengthScale = config.lengthScale,
                noiseW = config.noiseW
            )
            val windowSeconds = segment.end - segment.start
            val actualSeconds = samples.size.toDouble() / config.sampleRate
            if (windowSeconds >= 0.5 && actualSeconds > windowSeconds * 1.12) {
                val adjustedScale = (config.lengthScale *
                    (windowSeconds / actualSeconds).toFloat() * 0.98f)
                    .coerceIn(config.lengthScale * 0.78f, config.lengthScale)
                if (adjustedScale < config.lengthScale * 0.99f) {
                    val candidate = engine.synthesize(
                        phonemeIds = phonemeIds,
                        speakerId = speakerId,
                        noiseScale = config.noiseScale,
                        lengthScale = adjustedScale,
                        noiseW = config.noiseW
                    )
                    // Synthesis duration is not guaranteed to be monotonic.
                    // Never replace the original with an empty or worse fit.
                    if (candidate.isNotEmpty() &&
                        kotlin.math.abs(candidate.size.toDouble() / config.sampleRate - windowSeconds) <
                        kotlin.math.abs(samples.size.toDouble() / config.sampleRate - windowSeconds)
                    ) {
                        samples = candidate
                    }
                }
            }

            // Inspect the generated waveform before it can enter the mix.
            // A successful ONNX invocation alone does not imply audible audio.
            require(samples.isNotEmpty()) {
                "Voice synthesis returned no samples for segment ${segment.id}."
            }
            var squared = 0.0
            var peak = 0.0
            for (sample in samples) {
                require(sample.isFinite()) {
                    "Non-finite synthesized audio for segment ${segment.id}."
                }
                val magnitude = kotlin.math.abs(sample.toDouble())
                peak = kotlin.math.max(peak, magnitude)
                squared += magnitude * magnitude
            }
            val rms = kotlin.math.sqrt(squared / samples.size)
            require(rms >= 0.0001 && peak >= 0.001) {
                "Synthesized dialogue is silent for segment ${segment.id}."
            }
            require(peak < 0.9999695) {
                "Synthesized dialogue is clipping for segment ${segment.id}."
            }
            require(samples.size.toDouble() / config.sampleRate <=
                windowSeconds * 1.12) {
                "Synthesized dialogue exceeds its timing window for segment ${segment.id}."
            }

            val wav = VoiceWavWriter.write(
                destination = File(
                    outputDirectory,
                    "segment_${segment.id}.wav"
                ),
                samples = samples,
                sampleRate = config.sampleRate
            )

            clips.add(
                SynthesizedDialogueClip(
                    segmentId = segment.id,
                    speakerId = segment.speakerId,
                    voiceId = segment.voiceId,
                    start = segment.start,
                    end = segment.end,
                    wavPath = wav.absolutePath,
                    sampleRate = config.sampleRate
                )
            )
        }

        return clips
    }

    @Synchronized
    override fun close() {
        if (closed) return

        try {
            engine.close()
        } finally {
            if (phonemizerInitialized) {
                phonemizer.shutdown()
                phonemizerInitialized = false
            }

            closed = true
        }
    }
}
