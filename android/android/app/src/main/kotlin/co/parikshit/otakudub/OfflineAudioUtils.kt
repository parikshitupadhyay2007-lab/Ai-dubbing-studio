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
import kotlin.math.floor
import kotlin.math.roundToInt

object OfflineAudioUtils {

    private const val TARGET_RATE = 16000

    fun convertToWhisperWav(
        inputPath: String,
        outputPath: String
    ): String {
        require(File(inputPath).isFile) {
            "Source media file is missing."
        }

        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null

        try {
            extractor.setDataSource(inputPath)

            var trackIndex = -1
            var trackFormat: MediaFormat? = null

            for (i in 0 until extractor.trackCount) {
                val candidate = extractor.getTrackFormat(i)
                val mime = candidate.getString(
                    MediaFormat.KEY_MIME
                ) ?: continue

                if (mime.startsWith("audio/")) {
                    trackIndex = i
                    trackFormat = candidate
                    break
                }
            }

            require(trackIndex >= 0 && trackFormat != null) {
                "No decodable audio track was found."
            }

            extractor.selectTrack(trackIndex)

            val mime = trackFormat.getString(
                MediaFormat.KEY_MIME
            ) ?: error("Missing audio MIME type.")

            val codec = MediaCodec.createDecoderByType(mime)
            decoder = codec

            codec.configure(trackFormat, null, null, 0)
            codec.start()

            var sourceRate = trackFormat.getInteger(
                MediaFormat.KEY_SAMPLE_RATE
            )

            var channels = trackFormat.getInteger(
                MediaFormat.KEY_CHANNEL_COUNT
            )

            var encoding = AudioFormat.ENCODING_PCM_16BIT

            val destination = File(outputPath)
            destination.parentFile?.mkdirs()

            val temporary = File("$outputPath.part")
            if (temporary.exists()) temporary.delete()

            try {
                FileOutputStream(temporary).use { output ->
                    output.write(ByteArray(44))

                    val resampler = StreamingResampler()
                    var inputEnded = false
                    var outputEnded = false
                    val info = MediaCodec.BufferInfo()

                    while (!outputEnded) {
                        if (!inputEnded) {
                            val inputIndex =
                                codec.dequeueInputBuffer(10000)

                            if (inputIndex >= 0) {
                                val buffer = codec.getInputBuffer(
                                    inputIndex
                                ) ?: error("Missing decoder input buffer.")

                                buffer.clear()

                                val size = extractor.readSampleData(
                                    buffer,
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

                                sourceRate = format.getInteger(
                                    MediaFormat.KEY_SAMPLE_RATE
                                )

                                channels = format.getInteger(
                                    MediaFormat.KEY_CHANNEL_COUNT
                                )

                                encoding = format.getInteger(
                                    MediaFormat.KEY_PCM_ENCODING,
                                    AudioFormat.ENCODING_PCM_16BIT
                                )

                                require(
                                    encoding ==
                                        AudioFormat.ENCODING_PCM_16BIT ||
                                    encoding ==
                                        AudioFormat.ENCODING_PCM_FLOAT
                                ) {
                                    "Unsupported decoded PCM format."
                                }
                            }

                            else -> {
                                if (outputIndex >= 0) {
                                    val buffer =
                                        codec.getOutputBuffer(outputIndex)

                                    if (buffer != null && info.size > 0) {
                                        require(channels > 0 && sourceRate > 0)

                                        val bytes = ByteArray(info.size)

                                        buffer.position(info.offset)
                                        buffer.limit(
                                            info.offset + info.size
                                        )
                                        buffer.get(bytes)

                                        val mono = decodeMono(
                                            bytes,
                                            channels,
                                            encoding
                                        )

                                        resampler.process(
                                            mono,
                                            sourceRate,
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

                    resampler.finish(output)
                }

                val totalLength = temporary.length()
                require(totalLength > 44) {
                    "Decoded audio is empty."
                }

                writeWavHeader(
                    temporary,
                    totalLength - 44
                )

                if (destination.exists()) {
                    destination.delete()
                }

                check(temporary.renameTo(destination)) {
                    "Could not save converted audio."
                }

                return destination.absolutePath
            } finally {
                if (temporary.exists()) temporary.delete()
            }
        } finally {
            decoder?.let {
                runCatching { it.stop() }
                it.release()
            }

            extractor.release()
        }
    }

    private fun decodeMono(
        bytes: ByteArray,
        channels: Int,
        encoding: Int
    ): FloatArray {
        val buffer = ByteBuffer.wrap(bytes)
            .order(ByteOrder.LITTLE_ENDIAN)

        val bytesPerSample =
            if (encoding == AudioFormat.ENCODING_PCM_FLOAT) 4 else 2

        val frames = bytes.size / (channels * bytesPerSample)
        val mono = FloatArray(frames)

        for (frame in 0 until frames) {
            var sum = 0f

            for (channel in 0 until channels) {
                val value =
                    if (encoding == AudioFormat.ENCODING_PCM_FLOAT) {
                        buffer.float
                    } else {
                        buffer.short / 32768f
                    }

                sum += value
            }

            mono[frame] = (sum / channels).coerceIn(-1f, 1f)
        }

        return mono
    }

    private class StreamingResampler {
        private var previous = 0f
        private var hasPrevious = false
        private var inputPosition = 0L
        private var nextOutputPosition = 0.0
        private var currentRate = 0

        fun process(
            samples: FloatArray,
            sampleRate: Int,
            output: FileOutputStream
        ) {
            require(sampleRate > 0)

            if (currentRate == 0) {
                currentRate = sampleRate
            }

            require(currentRate == sampleRate) {
                "Changing sample rate within one audio stream is unsupported."
            }

            val step = sampleRate.toDouble() / TARGET_RATE

            for (sample in samples) {
                if (!hasPrevious) {
                    previous = sample
                    hasPrevious = true

                    while (nextOutputPosition <= 0.0) {
                        writeSample(output, sample)
                        nextOutputPosition += step
                    }

                    inputPosition++
                    continue
                }

                val leftPosition = inputPosition - 1.0
                val rightPosition = inputPosition.toDouble()

                while (nextOutputPosition <= rightPosition) {
                    val fraction = (
                        nextOutputPosition - leftPosition
                    ).coerceIn(0.0, 1.0)

                    val interpolated = previous +
                        (sample - previous) * fraction.toFloat()

                    writeSample(output, interpolated)
                    nextOutputPosition += step
                }

                previous = sample
                inputPosition++
            }
        }

        fun finish(output: FileOutputStream) {
            if (!hasPrevious) return

            val finalPosition = inputPosition.toDouble()

            while (nextOutputPosition < finalPosition) {
                writeSample(output, previous)
                nextOutputPosition +=
                    currentRate.toDouble() / TARGET_RATE
            }
        }

        private fun writeSample(
            output: FileOutputStream,
            sample: Float
        ) {
            val pcm = (
                sample.coerceIn(-1f, 1f) * 32767f
            ).roundToInt().toShort().toInt()

            output.write(pcm and 0xff)
            output.write((pcm shr 8) and 0xff)
        }
    }

    private fun writeWavHeader(
        file: File,
        dataLength: Long
    ) {
        require(dataLength <= Int.MAX_VALUE - 44L) {
            "Converted WAV exceeds supported size."
        }

        val header = ByteBuffer.allocate(44)
            .order(ByteOrder.LITTLE_ENDIAN)

        header.put("RIFF".toByteArray(Charsets.US_ASCII))
        header.putInt((36 + dataLength).toInt())
        header.put("WAVE".toByteArray(Charsets.US_ASCII))

        header.put("fmt ".toByteArray(Charsets.US_ASCII))
        header.putInt(16)
        header.putShort(1.toShort())
        header.putShort(1.toShort())
        header.putInt(TARGET_RATE)
        header.putInt(TARGET_RATE * 2)
        header.putShort(2.toShort())
        header.putShort(16.toShort())

        header.put("data".toByteArray(Charsets.US_ASCII))
        header.putInt(dataLength.toInt())

        RandomAccessFile(file, "rw").use {
            it.seek(0)
            it.write(header.array())
        }
    }
}
