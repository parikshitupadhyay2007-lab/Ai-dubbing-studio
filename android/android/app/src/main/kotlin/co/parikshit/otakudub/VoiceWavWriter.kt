
package co.parikshit.otakudub

import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.roundToInt

object VoiceWavWriter {

    /**
     * Writes mono, 16-bit PCM WAV audio.
     *
     * Input samples must be normalized floating-point audio,
     * normally produced by a compatible ONNX voice model.
     */
    fun write(
        destination: File,
        samples: FloatArray,
        sampleRate: Int
    ): File {
        require(sampleRate in 8000..192000) {
            "Unsupported output sample rate: $sampleRate"
        }

        require(samples.isNotEmpty()) {
            "Cannot create an empty voice clip."
        }

        require(samples.size.toLong() * 2L <= Int.MAX_VALUE - 44L) {
            "Voice clip exceeds supported WAV size."
        }

        destination.parentFile?.mkdirs()

        val temporary = File(
            destination.parentFile,
            "${destination.name}.part"
        )

        if (temporary.exists()) {
            check(temporary.delete()) {
                "Could not clear temporary audio file."
            }
        }

        val dataLength = samples.size * 2
        val byteRate = sampleRate * 2

        try {
            FileOutputStream(temporary).use { output ->
                val header = ByteBuffer.allocate(44)
                    .order(ByteOrder.LITTLE_ENDIAN)

                header.put(
                    "RIFF".toByteArray(Charsets.US_ASCII)
                )
                header.putInt(36 + dataLength)

                header.put(
                    "WAVE".toByteArray(Charsets.US_ASCII)
                )

                header.put(
                    "fmt ".toByteArray(Charsets.US_ASCII)
                )

                header.putInt(16)
                header.putShort(1.toShort())
                header.putShort(1.toShort())

                header.putInt(sampleRate)
                header.putInt(byteRate)

                header.putShort(2.toShort())
                header.putShort(16.toShort())

                header.put(
                    "data".toByteArray(Charsets.US_ASCII)
                )

                header.putInt(dataLength)

                output.write(header.array())

                val buffer = ByteBuffer.allocate(8192)
                    .order(ByteOrder.LITTLE_ENDIAN)

                for (sample in samples) {
                    require(sample.isFinite()) {
                        "Voice model produced invalid audio samples."
                    }

                    val pcm = (
                        sample.coerceIn(-1f, 1f) * 32767f
                    ).roundToInt().toShort()

                    if (buffer.remaining() < 2) {
                        output.write(
                            buffer.array(),
                            0,
                            buffer.position()
                        )
                        buffer.clear()
                    }

                    buffer.putShort(pcm)
                }

                if (buffer.position() > 0) {
                    output.write(
                        buffer.array(),
                        0,
                        buffer.position()
                    )
                }

                output.fd.sync()
            }

            if (destination.exists()) {
                check(destination.delete()) {
                    "Could not replace existing voice clip."
                }
            }

            check(temporary.renameTo(destination)) {
                "Could not finalize synthesized WAV file."
            }

            return destination
        } finally {
            if (temporary.exists()) {
                temporary.delete()
            }
        }
    }
}
