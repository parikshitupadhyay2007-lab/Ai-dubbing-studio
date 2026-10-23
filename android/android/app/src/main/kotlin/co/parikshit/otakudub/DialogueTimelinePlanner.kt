
package co.parikshit.otakudub

import java.io.File
import kotlin.math.roundToLong

data class TimedDialogueClip(
    val segmentId: Int,
    val speakerId: String,
    val voiceId: String,
    val wavPath: String,
    val sampleRate: Int,
    val startMs: Long,
    val originalEndMs: Long,
    val audioDurationMs: Long,
    val audioEndMs: Long,
    val overlapsNext: Boolean
)

data class DialogueTimeline(
    val clips: List<TimedDialogueClip>,
    val totalDurationMs: Long,
    val overlapCount: Int
)

/**
 * Builds a timestamp-accurate placement plan for
 * synthesized dialogue clips.
 *
 * Does not alter audio, trim speech, or silently
 * stretch generated voices.
 */
object DialogueTimelinePlanner {

    fun plan(
        clips: List<SynthesizedDialogueClip>,
        videoDurationMs: Long
    ): DialogueTimeline {

        require(videoDurationMs > 0L) {
            "Video duration must be positive."
        }

        require(clips.isNotEmpty()) {
            "No synthesized dialogue clips supplied."
        }

        require(
            clips.map { it.segmentId }.toSet().size ==
                clips.size
        ) {
            "Duplicate dialogue segment IDs."
        }

        val ordered = clips.sortedWith(
            compareBy<SynthesizedDialogueClip> { it.start }
                .thenBy { it.segmentId }
        )

        val placements = ordered.map { clip ->

            require(
                clip.start.isFinite() &&
                    clip.end.isFinite() &&
                    clip.start >= 0.0 &&
                    clip.end > clip.start
            ) {
                "Invalid timing for segment ${clip.segmentId}."
            }

            val startMs =
                (clip.start * 1000.0).roundToLong()

            val originalEndMs =
                (clip.end * 1000.0).roundToLong()

            require(startMs < videoDurationMs) {
                "Segment ${clip.segmentId} begins after the video ends."
            }

            val file = File(clip.wavPath)

            require(file.isFile && file.length() >= 44L) {
                "Missing or empty WAV for segment ${clip.segmentId}."
            }

            val wav = readWavInfo(file)

            require(wav.sampleRate == clip.sampleRate) {
                "WAV sample rate mismatch for segment ${clip.segmentId}."
            }

            val durationMs =
                (wav.sampleCount.toDouble() * 1000.0 /
                    wav.sampleRate).roundToLong()

            require(durationMs > 0L) {
                "Empty speech audio for segment ${clip.segmentId}."
            }

            // Keep the generated WAV intact, but never place speech beyond
            // the source video's boundary. The mixer reads only this interval.
            val placementDurationMs = minOf(durationMs, videoDurationMs - startMs)
            require(placementDurationMs > 0L) {
                "No video time remains for segment ${clip.segmentId}."
            }
            val audioEndMs = startMs + placementDurationMs

            require(audioEndMs >= startMs) {
                "Dialogue timeline overflow."
            }

            TimedDialogueClip(
                segmentId = clip.segmentId,
                speakerId = clip.speakerId,
                voiceId = clip.voiceId,
                wavPath = file.absolutePath,
                sampleRate = wav.sampleRate,
                startMs = startMs,
                originalEndMs = originalEndMs,
                audioDurationMs = placementDurationMs,
                audioEndMs = audioEndMs,
                overlapsNext = false
            )
        }

        val result = placements.mapIndexed { index, clip ->

            val overlaps = placements
                .drop(index + 1)
                .any { next ->
                    next.startMs < clip.audioEndMs
                }

            clip.copy(overlapsNext = overlaps)
        }

        return DialogueTimeline(
            clips = result,
            totalDurationMs = videoDurationMs,
            overlapCount = result.count { it.overlapsNext }
        )
    }

    private data class WavInfo(
        val sampleRate: Int,
        val sampleCount: Long
    )

    /**
     * Validates the mono PCM16 WAV format generated
     * by VoiceWavWriter.
     */
    private fun readWavInfo(file: File): WavInfo {
        java.io.RandomAccessFile(file, "r").use { wav ->

            fun ascii(length: Int): String {
                val bytes = ByteArray(length)
                wav.readFully(bytes)
                return String(bytes, Charsets.US_ASCII)
            }

            fun uint16(): Int {
                val a = wav.readUnsignedByte()
                val b = wav.readUnsignedByte()
                return a or (b shl 8)
            }

            fun uint32(): Long {
                val a = wav.readUnsignedByte().toLong()
                val b = wav.readUnsignedByte().toLong()
                val c = wav.readUnsignedByte().toLong()
                val d = wav.readUnsignedByte().toLong()

                return a or
                    (b shl 8) or
                    (c shl 16) or
                    (d shl 24)
            }

            require(ascii(4) == "RIFF") {
                "Invalid WAV header: ${file.name}"
            }

            val riffSize = uint32()

            require(ascii(4) == "WAVE") {
                "Invalid WAV format: ${file.name}"
            }

            require(riffSize + 8L <= wav.length()) {
                "Truncated WAV: ${file.name}"
            }

            var rate = 0
            var validFormat = false
            var samples = -1L

            val riffEnd = riffSize + 8L
            while (wav.filePointer + 8L <= riffEnd) {
                val chunk = ascii(4)
                val size = uint32()
                val start = wav.filePointer
                val end = start + size

                require(end >= start && end <= riffEnd) {
                    "Invalid WAV chunk: ${file.name}"
                }

                when (chunk) {
                    "fmt " -> {
                        require(size >= 16L) {
                            "Invalid WAV format chunk."
                        }

                        val encoding = uint16()
                        val channels = uint16()
                        rate = uint32().toInt()
                        uint32()
                        uint16()
                        val bits = uint16()

                        validFormat =
                            encoding == 1 &&
                            channels == 1 &&
                            bits == 16 &&
                            rate in 8000..192000
                    }

                    "data" -> {
                        require(size > 0L && size % 2L == 0L) {
                            "Invalid WAV audio data."
                        }

                        samples = size / 2L
                    }
                }

                val next = end + (size and 1L)

                require(next <= riffEnd) { "Invalid WAV chunk padding." }

                wav.seek(next)
            }

            require(validFormat && samples > 0L) {
                "Expected mono PCM16 WAV: ${file.name}"
            }

            return WavInfo(
                sampleRate = rate,
                sampleCount = samples
            )
        }
    }
}
