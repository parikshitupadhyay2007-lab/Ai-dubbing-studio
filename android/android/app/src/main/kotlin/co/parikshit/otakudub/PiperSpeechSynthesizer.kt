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

            val samples = engine.synthesize(
                phonemeIds = phonemeIds,
                speakerId = speakerId,
                noiseScale = config.noiseScale,
                lengthScale = config.lengthScale,
                noiseW = config.noiseW
            )

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
