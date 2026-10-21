
package co.parikshit.otakudub

import java.io.Closeable
import java.io.File
import java.io.RandomAccessFile
import kotlin.math.roundToInt

/**
 * Incremental stereo PCM16 WAV writer.
 *
 * Writes normalized Float32 stereo samples to a standard
 * 44-byte WAV container.
 *
 * Call finish() after all audio has been appended.
 */
class SeparationWavWriter(
    outputPath: String,
    val sampleRate: Int
) : Closeable {

    private val destination = File(outputPath)
    private val temporary = File("$outputPath.part")

    private val file: RandomAccessFile

    var framesWritten: Long = 0L
        private set

    private var finished = false
    private var closed = false

    init {
        require(sampleRate in 8000..192000) {
            "Unsupported WAV sample rate."
        }

        destination.parentFile?.mkdirs()

        require(!temporary.exists() || temporary.delete()) {
            "Cannot replace temporary WAV."
        }

        file = RandomAccessFile(temporary, "rw")
        file.setLength(0L)
        file.write(ByteArray(44))
    }

    /**
     * Appends equal-length left and right Float32 channels.
     */
    @Synchronized
    fun append(
        left: FloatArray,
        right: FloatArray,
        offset: Int = 0,
        length: Int = left.size - offset
    ) {
        check(!closed && !finished) {
            "WAV writer is already finished or closed."
        }

        require(left.size == right.size) {
            "Stereo channel lengths differ."
        }

        require(
            offset >= 0 &&
                length >= 0 &&
                offset <= left.size &&
                length <= left.size - offset
        ) {
            "Invalid audio append range."
        }

        require(
            framesWritten + length.toLong() <=
                (Int.MAX_VALUE - 44L) / 4L
        ) {
            "WAV exceeds supported size."
        }

        val buffer = ByteArray(8192)
        var bufferOffset = 0

        for (index in offset until offset + length) {
            val l = toPcm16(left[index])
            val r = toPcm16(right[index])

            buffer[bufferOffset++] = (l and 0xff).toByte()
            buffer[bufferOffset++] = ((l shr 8) and 0xff).toByte()

            buffer[bufferOffset++] = (r and 0xff).toByte()
            buffer[bufferOffset++] = ((r shr 8) and 0xff).toByte()

            if (bufferOffset == buffer.size) {
                file.write(buffer)
                bufferOffset = 0
            }
        }

        if (bufferOffset > 0) {
            file.write(buffer, 0, bufferOffset)
        }

        framesWritten += length.toLong()
    }

    /**
     * Finalizes the WAV header and publishes the output file.
     */
    @Synchronized
    fun finish(): String {
        check(!closed) {
            "WAV writer is closed."
        }

        if (finished) {
            return destination.absolutePath
        }

        require(framesWritten > 0L) {
            "Cannot finalize an empty WAV."
        }

        val dataBytes = framesWritten * 4L

        file.seek(0L)

        writeAscii("RIFF")
        writeInt32((36L + dataBytes).toInt())
        writeAscii("WAVE")

        writeAscii("fmt ")
        writeInt32(16)
        writeInt16(1)
        writeInt16(2)
        writeInt32(sampleRate)
        writeInt32(sampleRate * 4)
        writeInt16(4)
        writeInt16(16)

        writeAscii("data")
        writeInt32(dataBytes.toInt())

        file.fd.sync()
        file.close()

        if (destination.exists()) {
            check(destination.delete()) {
                "Cannot replace existing WAV."
            }
        }

        check(temporary.renameTo(destination)) {
            "Cannot publish completed WAV."
        }

        finished = true

        return destination.absolutePath
    }

    override fun close() {
        if (!closed) {
            closed = true

            if (!finished) {
                file.close()

                if (temporary.exists()) {
                    temporary.delete()
                }
            }
        }
    }

    private fun toPcm16(value: Float): Int {
        require(value.isFinite()) {
            "Audio contains a non-finite sample."
        }

        return (
            value.coerceIn(-1f, 1f) * 32767f
        ).roundToInt()
    }

    private fun writeAscii(value: String) {
        file.write(value.toByteArray(Charsets.US_ASCII))
    }

    private fun writeInt16(value: Int) {
        file.write(value and 0xff)
        file.write((value shr 8) and 0xff)
    }

    private fun writeInt32(value: Int) {
        file.write(value and 0xff)
        file.write((value shr 8) and 0xff)
        file.write((value shr 16) and 0xff)
        file.write((value shr 24) and 0xff)
    }
}
