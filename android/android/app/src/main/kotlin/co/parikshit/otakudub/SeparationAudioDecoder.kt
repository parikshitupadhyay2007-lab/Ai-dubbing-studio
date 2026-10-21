
package co.parikshit.otakudub

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.roundToInt

/**
 * Decodes source media into stereo PCM16 WAV.
 *
 * Preserves the decoded sample rate.
 * Mono input is duplicated into left and right channels.
 *
 * Model-specific resampling and STFT are separate steps.
 */
object SeparationAudioDecoder {

    data class DecodedAudio(
        val wavPath: String,
        val sampleRate: Int,
        val channels: Int,
        val frameCount: Long
    )

    fun decode(
        sourcePath: String,
        outputPath: String
    ): DecodedAudio {
        require(File(sourcePath).isFile) {
            "Source media does not exist."
        }

        require(
            File(sourcePath).canonicalPath !=
                File(outputPath).canonicalPath
        ) {
            "Source and output paths must differ."
        }

        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null

        val destination = File(outputPath)
        destination.parentFile?.mkdirs()

        val temporary = File("$outputPath.part")
        if (temporary.exists()) temporary.delete()

        try {
            extractor.setDataSource(sourcePath)

            var trackIndex = -1
            var trackFormat: MediaFormat? = null

            for (index in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(index)

                val mime = format.getString(
                    MediaFormat.KEY_MIME
                ) ?: continue

                if (mime.startsWith("audio/")) {
                    trackIndex = index
                    trackFormat = format
                    break
                }
            }

            require(trackIndex >= 0 && trackFormat != null) {
                "No audio track was found."
            }

            extractor.selectTrack(trackIndex)

            val mime = trackFormat.getString(
                MediaFormat.KEY_MIME
            ) ?: error("Audio MIME type is missing.")

            val codec = MediaCodec.createDecoderByType(mime)
            decoder = codec

            codec.configure(trackFormat, null, null, 0)
            codec.start()

            var sampleRate = trackFormat.getInteger(
                MediaFormat.KEY_SAMPLE_RATE
            )

            var sourceChannels = trackFormat.getInteger(
                MediaFormat.KEY_CHANNEL_COUNT
            )

            var encoding = AudioFormat.ENCODING_PCM_16BIT
            var frameCount = 0L

            var inputEnded = false
            var outputEnded = false

            val info = MediaCodec.BufferInfo()

            FileOutputStream(temporary).use { output ->
                output.write(ByteArray(44))

                while (!outputEnded) {
                    if (!inputEnded) {
                        val inputIndex =
                            codec.dequeueInputBuffer(10000)

                        if (inputIndex >= 0) {
                            val inputBuffer =
                                codec.getInputBuffer(inputIndex)
                                    ?: error(
                                        "Decoder input buffer missing."
                                    )

                            inputBuffer.clear()

                            val size = extractor.readSampleData(
                                inputBuffer,
                                0
                            )

                            if (size < 0) {
                                codec.queueInputBuffer(
                                    inputIndex,
                                    0,
                                    0,
                                    0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                )

                                inputEnded = true
                            } else {
                                codec.queueInputBuffer(
                                    inputIndex,
                                    0,
                                    size,
                                    extractor.sampleTime,
                                    0
                                )

                                extractor.advance()
                            }
                        }
                    }

                    val outputIndex =
                        codec.dequeueOutputBuffer(info, 10000)

                    when (outputIndex) {
                        MediaCodec.INFO_TRY_AGAIN_LATER -> Unit

                        MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            val format = codec.outputFormat

                            sampleRate = format.getInteger(
                                MediaFormat.KEY_SAMPLE_RATE
                            )

                            sourceChannels = format.getInteger(
                                MediaFormat.KEY_CHANNEL_COUNT
                            )

                            encoding = format.getInteger(
                                MediaFormat.KEY_PCM_ENCODING,
                                AudioFormat.ENCODING_PCM_16BIT
                            )

                            require(sourceChannels in 1..2) {
                                "Multichannel source audio is not yet supported."
                            }

                            require(
                                encoding ==
                                    AudioFormat.ENCODING_PCM_16BIT ||
                                    encoding ==
                                    AudioFormat.ENCODING_PCM_FLOAT
                            ) {
                                "Unsupported decoded PCM encoding."
                            }
                        }

                        else -> {
                            if (outputIndex >= 0) {
                                val buffer =
                                    codec.getOutputBuffer(outputIndex)

                                if (buffer != null && info.size > 0) {
                                    require(sampleRate > 0)
                                    require(sourceChannels in 1..2)

                                    val bytes = ByteArray(info.size)

                                    buffer.position(info.offset)
                                    buffer.limit(
                                        info.offset + info.size
                                    )

                                    buffer.get(bytes)

                                    frameCount += writeStereo(
                                        bytes,
                                        sourceChannels,
                                        encoding,
                                        output
                                    )
                                }

                                outputEnded =
                                    info.flags and
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0

                                codec.releaseOutputBuffer(
                                    outputIndex,
                                    false
                                )
                            }
                        }
                    }
                }
            }

            require(frameCount > 0) {
                "Decoded soundtrack is empty."
            }

            require(sampleRate in 8000..192000) {
                "Unsupported decoded sample rate."
            }

            val dataBytes = frameCount * 4L

            writeHeader(
                temporary,
                sampleRate,
                dataBytes
            )

            if (destination.exists()) {
                check(destination.delete()) {
                    "Cannot replace existing decoded WAV."
                }
            }

            check(temporary.renameTo(destination)) {
                "Cannot save decoded stereo WAV."
            }

            return DecodedAudio(
                wavPath = destination.absolutePath,
                sampleRate = sampleRate,
                channels = 2,
                frameCount = frameCount
            )
        } finally {
            decoder?.let {
                runCatching { it.stop() }
                it.release()
            }

            extractor.release()

            if (temporary.exists()) {
                temporary.delete()
            }
        }
    }

    private fun writeStereo(
        bytes: ByteArray,
        channels: Int,
        encoding: Int,
        output: FileOutputStream
    ): Long {
        val bytesPerSample =
            if (encoding == AudioFormat.ENCODING_PCM_FLOAT) {
                4
            } else {
                2
            }

        val frameSize = channels * bytesPerSample

        require(bytes.size % frameSize == 0) {
            "Incomplete decoded PCM frame."
        }

        val input = ByteBuffer.wrap(bytes)
            .order(ByteOrder.LITTLE_ENDIAN)

        val frames = bytes.size / frameSize

        repeat(frames) {
            val left = readSample(input, encoding)

            val right = if (channels == 2) {
                readSample(input, encoding)
            } else {
                left
            }

            writeSample(output, left)
            writeSample(output, right)
        }

        return frames.toLong()
    }

    private fun readSample(
        input: ByteBuffer,
        encoding: Int
    ): Float {
        return if (encoding == AudioFormat.ENCODING_PCM_FLOAT) {
            input.float
        } else {
            input.short / 32768f
        }
    }

    private fun writeSample(
        output: FileOutputStream,
        value: Float
    ) {
        require(value.isFinite()) {
            "Decoded audio contains an invalid sample."
        }

        val pcm = (
            value.coerceIn(-1f, 1f) * 32767f
        ).roundToInt()

        output.write(pcm and 0xff)
        output.write((pcm shr 8) and 0xff)
    }

    private fun writeHeader(
        file: File,
        sampleRate: Int,
        dataBytes: Long
    ) {
        require(dataBytes <= Int.MAX_VALUE - 44L) {
            "Decoded WAV exceeds supported size."
        }

        val header = ByteBuffer.allocate(44)
            .order(ByteOrder.LITTLE_ENDIAN)

        header.put(
            "RIFF".toByteArray(Charsets.US_ASCII)
        )
        header.putInt((36L + dataBytes).toInt())

        header.put(
            "WAVE".toByteArray(Charsets.US_ASCII)
        )

        header.put(
            "fmt ".toByteArray(Charsets.US_ASCII)
        )
        header.putInt(16)
        header.putShort(1.toShort())
        header.putShort(2.toShort())
        header.putInt(sampleRate)
        header.putInt(sampleRate * 4)
        header.putShort(4.toShort())
        header.putShort(16.toShort())

        header.put(
            "data".toByteArray(Charsets.US_ASCII)
        )
        header.putInt(dataBytes.toInt())

        RandomAccessFile(file, "rw").use {
            it.seek(0)
            it.write(header.array())
        }
    }
}
