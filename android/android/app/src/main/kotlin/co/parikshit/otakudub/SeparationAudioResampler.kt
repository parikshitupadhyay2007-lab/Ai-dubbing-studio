
package co.parikshit.otakudub

import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.roundToInt

/**
 * Streaming stereo PCM16 WAV resampler.
 *
 * Uses linear interpolation to keep memory usage bounded.
 * A higher-quality resampler may be required by the selected
 * separation model before production use.
 */
object SeparationAudioResampler {

    data class ResampledAudio(
        val wavPath: String,
        val sampleRate: Int,
        val channels: Int,
        val frameCount: Long
    )

    fun resample(
        inputPath: String,
        outputPath: String,
        targetRate: Int
    ): ResampledAudio {
        require(targetRate in 8000..192000) {
            "Unsupported target sample rate."
        }

        val source = File(inputPath)

        require(source.isFile) {
            "Input WAV does not exist."
        }

        require(source.canonicalPath != File(outputPath).canonicalPath) {
            "Input and output WAV paths must differ."
        }

        val destination = File(outputPath)
        destination.parentFile?.mkdirs()

        val temporary = File("$outputPath.part")

        if (temporary.exists()) {
            temporary.delete()
        }

        try {
            FileInputStream(source).use { input ->
                val header = ByteArray(44)
                readFully(input, header)

                val metadata = parseHeader(header)

                val sourceRate = metadata.first
                val sourceFrames = metadata.second

                require(sourceFrames <= (source.length() - 44L) / 4L) {
                    "Input WAV audio data is truncated."
                }

                require(sourceFrames > 0) {
                    "Input WAV contains no audio."
                }

                var writtenFrames = 0L

                FileOutputStream(temporary).use { output ->
                    output.write(ByteArray(44))

                    val reader = StereoFrameReader(input)

                    var previous = reader.readFrame()
                        ?: error("Input WAV is empty.")

                    var current = reader.readFrame()

                    var sourceIndex = 0L
                    var outputIndex = 0L

                    val step =
                        sourceRate.toDouble() / targetRate.toDouble()

                    // Calculate in Long arithmetic; round to the nearest frame.
                    // Standard PCM16 stereo WAV has a bounded RIFF data size.
                    val maxFrames = (Int.MAX_VALUE - 44L) / 4L
                    require(sourceFrames <= Long.MAX_VALUE / targetRate.toLong()) {
                        "Resampled frame count overflow."
                    }
                    val scaledFrames = sourceFrames * targetRate.toLong()
                    val outputFrames = scaledFrames / sourceRate.toLong() +
                        if (scaledFrames % sourceRate.toLong() >=
                            (sourceRate.toLong() + 1L) / 2L) 1L else 0L
                    require(outputFrames in 1L..maxFrames) {
                        "Resampled WAV exceeds supported size."
                    }

                    while (outputIndex < outputFrames) {
                        val position = outputIndex * step

                        while (
                            current != null &&
                            sourceIndex + 1L <= position
                        ) {
                            previous = current
                            sourceIndex++
                            current = reader.readFrame()
                        }

                        val fraction = (
                            position - sourceIndex.toDouble()
                        ).coerceIn(0.0, 1.0).toFloat()

                        val next = current ?: previous

                        val left = previous.first +
                            (next.first - previous.first) * fraction

                        val right = previous.second +
                            (next.second - previous.second) * fraction

                        writeSample(output, left)
                        writeSample(output, right)

                        writtenFrames++
                        outputIndex++
                    }
                }

                require(writtenFrames > 0) {
                    "Resampling produced no audio."
                }

                writeHeader(
                    temporary,
                    targetRate,
                    writtenFrames * 4L
                )

                if (destination.exists()) {
                    check(destination.delete()) {
                        "Cannot replace existing resampled WAV."
                    }
                }

                check(temporary.renameTo(destination)) {
                    "Cannot save resampled WAV."
                }

                return ResampledAudio(
                    wavPath = destination.absolutePath,
                    sampleRate = targetRate,
                    channels = 2,
                    frameCount = writtenFrames
                )
            }
        } finally {
            if (temporary.exists()) {
                temporary.delete()
            }
        }
    }

    private fun parseHeader(
        header: ByteArray
    ): Pair<Int, Long> {
        val buffer = ByteBuffer.wrap(header)
            .order(ByteOrder.LITTLE_ENDIAN)

        fun text(offset: Int, length: Int): String {
            return String(
                header,
                offset,
                length,
                Charsets.US_ASCII
            )
        }

        require(
            text(0, 4) == "RIFF" &&
                text(8, 4) == "WAVE" &&
                text(12, 4) == "fmt " &&
                text(36, 4) == "data"
        ) {
            "Expected a standard 44-byte PCM WAV."
        }

        require(buffer.getInt(16) == 16) {
            "Extended WAV headers are not supported."
        }

        require(buffer.getShort(20).toInt() == 1) {
            "Expected uncompressed PCM."
        }

        require(buffer.getShort(22).toInt() == 2) {
            "Expected stereo audio."
        }

        require(buffer.getShort(34).toInt() == 16) {
            "Expected 16-bit PCM."
        }

        val rate = buffer.getInt(24)

        require(rate in 8000..192000) {
            "Invalid WAV sample rate."
        }

        require(buffer.getInt(28) == rate * 4) {
            "Invalid WAV byte rate."
        }

        require(buffer.getShort(32).toInt() == 4) {
            "Invalid WAV frame alignment."
        }

        val dataBytes =
            buffer.getInt(40).toLong() and 0xffffffffL

        require(dataBytes > 0 && dataBytes % 4L == 0L) {
            "Invalid stereo PCM data length."
        }

        return rate to (dataBytes / 4L)
    }

    private class StereoFrameReader(
        private val input: FileInputStream
    ) {
        private val bytes = ByteArray(4)

        fun readFrame(): Pair<Float, Float>? {
            var offset = 0

            while (offset < bytes.size) {
                val count = input.read(
                    bytes,
                    offset,
                    bytes.size - offset
                )

                if (count < 0) {
                    if (offset == 0) return null

                    error("Incomplete stereo PCM frame.")
                }

                offset += count
            }

            val left = (
                (bytes[0].toInt() and 0xff) or
                    (bytes[1].toInt() shl 8)
            ).toShort() / 32768f

            val right = (
                (bytes[2].toInt() and 0xff) or
                    (bytes[3].toInt() shl 8)
            ).toShort() / 32768f

            return left to right
        }
    }

    private fun writeSample(
        output: FileOutputStream,
        sample: Float
    ) {
        val pcm = (
            sample.coerceIn(-1f, 1f) * 32767f
        ).roundToInt()

        output.write(pcm and 0xff)
        output.write((pcm shr 8) and 0xff)
    }

    private fun readFully(
        input: FileInputStream,
        bytes: ByteArray
    ) {
        var offset = 0

        while (offset < bytes.size) {
            val count = input.read(
                bytes,
                offset,
                bytes.size - offset
            )

            require(count > 0) {
                "Unexpected end of WAV header."
            }

            offset += count
        }
    }

    private fun writeHeader(
        file: File,
        sampleRate: Int,
        dataBytes: Long
    ) {
        require(dataBytes <= Int.MAX_VALUE - 44L) {
            "Resampled WAV exceeds supported size."
        }

        val header = ByteBuffer.allocate(44)
            .order(ByteOrder.LITTLE_ENDIAN)

        header.put("RIFF".toByteArray(Charsets.US_ASCII))
        header.putInt((36L + dataBytes).toInt())
        header.put("WAVE".toByteArray(Charsets.US_ASCII))

        header.put("fmt ".toByteArray(Charsets.US_ASCII))
        header.putInt(16)
        header.putShort(1.toShort())
        header.putShort(2.toShort())
        header.putInt(sampleRate)
        header.putInt(sampleRate * 4)
        header.putShort(4.toShort())
        header.putShort(16.toShort())

        header.put("data".toByteArray(Charsets.US_ASCII))
        header.putInt(dataBytes.toInt())

        RandomAccessFile(file, "rw").use {
            it.seek(0)
            it.write(header.array())
        }
    }
}
