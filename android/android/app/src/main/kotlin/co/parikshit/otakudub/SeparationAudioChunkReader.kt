
package co.parikshit.otakudub

import java.io.Closeable
import java.io.File
import java.io.RandomAccessFile
import kotlin.math.min

/**
 * Reads standard stereo PCM16 WAV files in overlapping chunks.
 *
 * Audio is returned as normalized FloatArray channels.
 * This class does not perform STFT or ONNX inference.
 */
class SeparationAudioChunkReader(
    wavPath: String,
    val chunkFrames: Int,
    val overlapFrames: Int = 0
) : Closeable {

    data class AudioChunk(
        val index: Long,
        val startFrame: Long,
        val validFrames: Int,
        val left: FloatArray,
        val right: FloatArray
    )

    private val file = RandomAccessFile(wavPath, "r")

    val sampleRate: Int
    val totalFrames: Long

    private val hopFrames: Int
    private val dataOffset: Long
    private var nextFrame = 0L
    private var chunkIndex = 0L
    private var closed = false

    init {
        try {
            require(chunkFrames > 0 && chunkFrames <= Int.MAX_VALUE / 4) {
                "Chunk size must fit a stereo PCM16 byte buffer."
            }

            require(overlapFrames >= 0 && overlapFrames < chunkFrames) {
                "Overlap must be smaller than chunk size."
            }

            hopFrames = chunkFrames - overlapFrames

            require(File(wavPath).isFile) {
                "Input WAV does not exist."
            }

            val header = ByteArray(44)
            file.readFully(header)

            require(
                String(header, 0, 4, Charsets.US_ASCII) == "RIFF" &&
                    String(header, 8, 4, Charsets.US_ASCII) == "WAVE" &&
                    String(header, 12, 4, Charsets.US_ASCII) == "fmt " &&
                    String(header, 36, 4, Charsets.US_ASCII) == "data"
            ) {
                "Expected a standard 44-byte PCM WAV."
            }

            require(readInt16(header, 20) == 1) {
                "Expected uncompressed PCM audio."
            }

            require(readInt16(header, 22) == 2) {
                "Expected stereo audio."
            }

            require(readInt16(header, 34) == 16) {
                "Expected 16-bit PCM."
            }

            sampleRate = readInt32(header, 24)

            require(sampleRate in 8000..192000) {
                "Invalid WAV sample rate."
            }

            require(readInt16(header, 32) == 4) {
                "Invalid stereo frame alignment."
            }

            val dataSize = readUInt32(header, 40)

            require(dataSize > 0 && dataSize % 4L == 0L) {
                "Invalid WAV data size."
            }

            dataOffset = 44L
            totalFrames = dataSize / 4L

            require(file.length() >= dataOffset + dataSize) {
                "WAV audio data is truncated."
            }
        } catch (error: Throwable) {
            file.close()
            throw error
        }
    }

    /**
     * Returns the next chunk, or null after all audio is read.
     *
     * The last chunk is padded with silence.
     */
    fun nextChunk(): AudioChunk? {
        check(!closed) {
            "Audio chunk reader is closed."
        }

        if (nextFrame >= totalFrames) {
            return null
        }

        val start = nextFrame

        val valid = min(
            chunkFrames.toLong(),
            totalFrames - start
        ).toInt()

        val left = FloatArray(chunkFrames)
        val right = FloatArray(chunkFrames)

        val bytes = ByteArray(valid * 4)

        file.seek(dataOffset + start * 4L)
        file.readFully(bytes)

        var byteOffset = 0

        for (frame in 0 until valid) {
            val leftSample = readInt16(bytes, byteOffset)
            val rightSample = readInt16(bytes, byteOffset + 2)

            left[frame] = leftSample / 32768f
            right[frame] = rightSample / 32768f

            byteOffset += 4
        }

        val result = AudioChunk(
            index = chunkIndex,
            startFrame = start,
            validFrames = valid,
            left = left,
            right = right
        )

        chunkIndex++
        nextFrame += hopFrames.toLong()

        return result
    }

    /**
     * Resets sequential reading to the beginning.
     */
    fun reset() {
        check(!closed) {
            "Audio chunk reader is closed."
        }

        nextFrame = 0L
        chunkIndex = 0L
    }

    override fun close() {
        if (!closed) {
            closed = true
            file.close()
        }
    }

    private fun readInt16(
        bytes: ByteArray,
        offset: Int
    ): Int {
        val value =
            (bytes[offset].toInt() and 0xff) or
                ((bytes[offset + 1].toInt() and 0xff) shl 8)

        return value.toShort().toInt()
    }

    private fun readInt32(
        bytes: ByteArray,
        offset: Int
    ): Int {
        return (bytes[offset].toInt() and 0xff) or
            ((bytes[offset + 1].toInt() and 0xff) shl 8) or
            ((bytes[offset + 2].toInt() and 0xff) shl 16) or
            ((bytes[offset + 3].toInt() and 0xff) shl 24)
    }

    private fun readUInt32(
        bytes: ByteArray,
        offset: Int
    ): Long {
        return readInt32(bytes, offset).toLong() and 0xffffffffL
    }
}
