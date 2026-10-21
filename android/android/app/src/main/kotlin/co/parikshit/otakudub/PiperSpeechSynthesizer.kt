
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

/**
 * Converts translated dialogue into individual offline
 * Piper WAV clips.
 *
 * This class performs synthesis only. Synchronization,
 * audio mixing and video export are separate stages.
 */
class PiperSpeechSynthesizer(
    context: Context
) : Closeable {

    private val phonemizer = OfflinePhonemizer.create(context)

    private val engine = PiperOnnxEngine()

    private var phonemizerInitialized = false

    @Synchronized
    fun synthesize(
        request: VoiceSynthesisRequest,
        outputDirectory: File
    ): List<SynthesizedDialogueClip> {

        require(request.segments.isNotEmpty()) {
            "No dialogue segments were supplied."
        }

        check(
            outputDirectory.isDirectory ||
                outputDirectory.mkdirs()
        ) {
            "Cannot create synthesis output directory."
        }

        val clips = ArrayList<SynthesizedDialogueClip>()

        val configCache =
            mutableMapOf<String, PiperPhonemizerConfig>()

        val encoderCache =
            mutableMapOf<String, PiperPhonemeEncoder>()

        for (segment in request.segments.sortedWith(
            compareBy<NativeDialogueSegment> { it.start }
                .thenBy { it.id }
        )) {

            val voice = request.voices[segment.voiceId]
                ?: error(
                    "Missing assigned voice: ${segment.voiceId}"
                )

            val config = configCache.getOrPut(
                segment.voiceId
            ) {
                PiperPhonemizerConfig.load(
                    File(voice.configPath),
                    request.targetLanguage
                )
            }

            require(config.sampleRate == voice.sampleRate) {
                "Voice sample rate does not match its configuration."
            }

            val encoder = encoderCache.getOrPut(
                segment.voiceId
            ) {
                PiperPhonemeEncoder(
                    File(voice.configPath)
                )
            }

            val phonemeText = when (config.type) {

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

            val phonemeIds = encoder.encodeCodePoints(
                phonemeText
            )

            engine.load(voice.modelPath)

            /*
             * Single-speaker models do not require sid.
             * Multi-speaker models use the configured
             * speaker ID associated with this voice profile.
             */
            val speakerId: Long? =
                if (voice.numSpeakers > 1) {
                    val id = voice.speakerIds[segment.voiceId]
                        ?: voice.speakerIds[voice.profileId]
                        ?: error(
                            "Missing Piper speaker ID for ${segment.voiceId}"
                        )

                    id.toLong()
                } else {
                    null
                }

            val audio = engine.synthesize(
                phonemeIds = phonemeIds,
                speakerId = speakerId,
                noiseScale = config.noiseScale,
                lengthScale = config.lengthScale,
                noiseW = config.noiseW
            )

            val destination = File(
                outputDirectory,
                "segment_${segment.id}.wav"
            )

            val wav = VoiceWavWriter.write(
                destination = destination,
                samples = audio,
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

    override fun close() {
        try {
            engine.close()
        } finally {
            if (phonemizerInitialized) {
                phonemizer.shutdown()
                phonemizerInitialized = false
            }
        }
    }
}
