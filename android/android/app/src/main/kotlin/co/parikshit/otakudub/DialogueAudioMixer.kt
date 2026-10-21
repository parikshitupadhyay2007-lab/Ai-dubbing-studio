
package co.parikshit.otakudub

import java.io.File
import java.io.RandomAccessFile
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.roundToInt

/**
 * Offline timestamp-based dialogue mixer.
 *
 * Input: mono PCM16 WAV clips from VoiceWavWriter.
 * Output: one continuous mono PCM16 WAV.
 *
 * Supports different source sample rates and overlapping
 * dialogue without loading the entire timeline into RAM.
 */
object DialogueAudioMixer {

    private const val OUTPUT_RATE = 24000
    private const val CHUNK_FRAMES = 4096
    private const val WAV_HEADER_SIZE = 44L

    private data class Source(
        val clip: TimedDialogueClip,
        val file: RandomAccessFile,
        val sampleCount: Long
    ) {
        fun sample(index: Long): Float {
            if (index < 0L || index >= sampleCount) {
                return 0f
            }

            file.seek(WAV_HEADER_SIZE + index * 2L)

            val low = file.readUnsignedByte()
            val high = file.readUnsignedByte()

            val value = (low or (high shl 8)).toShort()

            return value / 32768f
        }

        fun interpolated(position: Double): Float {
            if (position < 0.0 || position >= sampleCount) {
                return 0f
            }

            val first = floor(position).toLong()
            val second = first + 1L
            val fraction = (position - first).toFloat()

            val a = sample(first)
            val b = if (second < sampleCount) {
                sample(second)
            } else {
                a
            }

            return a + (b - a) * fraction
        }
    }

    fun mix(
        timeline: DialogueTimeline,
        destination: File
    ): File {

        require(timeline.totalDurationMs > 0L) {
            "Invalid dialogue timeline duration."
        }

        require(timeline.clips.isNotEmpty()) {
            "Dialogue timeline contains no clips."
        }

        val totalFrames = ceil(
            timeline.totalDurationMs.toDouble() *
                OUTPUT_RATE / 1000.0
        ).toLong()

        val dataBytes = totalFrames * 2L

        require(
            totalFrames > 0L &&
                dataBytes <= Int.MAX_VALUE - WAV_HEADER_SIZE
        ) {
            "Dialogue timeline exceeds supported WAV size."
        }

        destination.parentFile?.let { parent ->
            check(parent.isDirectory || parent.mkdirs()) {
                "Cannot create audio output directory."
            }
        }

        val temporary = File(
            destination.absolutePath + ".part"
        )

        val sources = ArrayList<Source>()

        try {
            for (clip in timeline.clips) {
                val file = RandomAccessFile(
                    File(clip.wavPath),
                    "r"
                )

                try {
                    require(file.length() >= WAV_HEADER_SIZE) {
                        "Invalid WAV for segment ${clip.segmentId}."
                    }

                    val sampleCount =
                        (file.length() - WAV_HEADER_SIZE) / 2L

                    require(sampleCount > 0L) {
                        "Empty WAV for segment ${clip.segmentId}."
                    }

                    sources.add(
                        Source(
                            clip = clip,
                            file = file,
                            sampleCount = sampleCount
                        )
                    )
                } catch (error: Exception) {
                    file.close()
                    throw error
                }
            }

            RandomAccessFile(temporary, "rw").use { output ->
                output.setLength(0L)
                writeHeader(output, dataBytes.toInt())

                var frame = 0L

                while (frame < totalFrames) {
                    val count = minOf(
                        CHUNK_FRAMES.toLong(),
                        totalFrames - frame
                    ).toInt()

                    val mixed = FloatArray(count)

                    val chunkStartMs =
                        frame.toDouble() * 1000.0 / OUTPUT_RATE

                    val chunkEndMs =
                        (frame + count).toDouble() *
                            1000.0 / OUTPUT_RATE

                    val active = sources.filter { source ->
                        source.clip.startMs < chunkEndMs &&
                            source.clip.audioEndMs > chunkStartMs
                    }

                    for (source in active) {
                        val clip = source.clip

                        for (i in 0 until count) {
                            val outputTimeMs =
                                (frame + i).toDouble() *
                                    1000.0 / OUTPUT_RATE

                            val relativeMs =
                                outputTimeMs - clip.startMs

                            if (
                                relativeMs < 0.0 ||
                                relativeMs >= clip.audioDurationMs
                            ) {
                                continue
                            }

                            val sourcePosition =
                                relativeMs * clip.sampleRate / 1000.0

                            mixed[i] += source.interpolated(
                                sourcePosition
                            )
                        }
                    }

                    for (value in mixed) {
                        // Prevent PCM overflow when characters overlap.
                        val pcm = (
                            value.coerceIn(-1f, 1f) * 32767f
                        ).roundToInt().toShort()

                        output.writeByte(pcm.toInt() and 0xff)
                        output.writeByte(
                            (pcm.toInt() shr 8) and 0xff
                        )
                    }

                    frame += count
                }

                output.fd.sync()
            }

            if (destination.exists()) {
                check(destination.delete()) {
                    "Cannot replace previous dialogue mix."
                }
            }

            check(temporary.renameTo(destination)) {
                "Cannot finalize dialogue mix."
            }

            return destination

        } finally {
            sources.forEach { source ->
                runCatching { source.file.close() }
            }

            if (temporary.exists()) {
                temporary.delete()
            }
        }
    }

    private fun writeHeader(
        output: RandomAccessFile,
        dataBytes: Int
    ) {
        fun ascii(value: String) {
            output.write(
                value.toByteArray(Charsets.US_ASCII)
            )
        }

        fun shortLE(value: Int) {
            output.writeByte(value and 0xff)
            output.writeByte((value shr 8) and 0xff)
        }

        fun intLE(value: Int) {
            output.writeByte(value and 0xff)
            output.writeByte((value shr 8) and 0xff)
            output.writeByte((value shr 16) and 0xff)
            output.writeByte((value shr 24) and 0xff)
        }

        ascii("RIFF")
        intLE(36 + dataBytes)
        ascii("WAVE")

        ascii("fmt ")
        intLE(16)

        shortLE(1)
        shortLE(1)

        intLE(OUTPUT_RATE)
        intLE(OUTPUT_RATE * 2)

        shortLE(2)
        shortLE(16)

        ascii("data")
        intLE(dataBytes)
    }
}
