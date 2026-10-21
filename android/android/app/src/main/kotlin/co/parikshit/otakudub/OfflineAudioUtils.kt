
package co.parikshit.otakudub

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

object OfflineAudioUtils {

    private const val SAMPLE_RATE = 16000

    fun extractMonoPcm(
        inputPath: String,
        outputPath: String
    ): String {
        require(File(inputPath).isFile) {
            "Input media file does not exist."
        }

        val extractor = MediaExtractor()
        var codec: MediaCodec? = null

        try {
            extractor.setDataSource(inputPath)

            var audioTrack = -1
            var format: MediaFormat? = null

            for (index in 0 until extractor.trackCount) {
                val candidate = extractor.getTrackFormat(index)
                val mime = candidate.getString(
                    MediaFormat.KEY_MIME
                ) ?: continue

                if (mime.startsWith("audio/")) {
                    audioTrack = index
                    format = candidate
                    break
                }
            }

            require(audioTrack >= 0 && format != null) {
                "No supported audio track found."
            }

            extractor.selectTrack(audioTrack)

            val mime = format.getString(
                MediaFormat.KEY_MIME
            ) ?: error("Audio MIME type missing.")

            val decoder = MediaCodec.createDecoderByType(mime)
            codec = decoder

            decoder.configure(format, null, null, 0)
            decoder.start()

            val info = MediaCodec.BufferInfo()
            val output = File(outputPath)

            output.parentFile?.mkdirs()

            FileOutputStream(output).use { stream ->
                var inputFinished = false
                var outputFinished = false

                while (!outputFinished) {
                    if (!inputFinished) {
                        val index = decoder.dequeueInputBuffer(10000)

                        if (index >= 0) {
                            val buffer = decoder.getInputBuffer(index)
                                ?: error("Decoder input buffer missing.")

                            buffer.clear()

                            val size = extractor.readSampleData(
                                buffer,
                                0
                            )

                            if (size < 0) {
                                decoder.queueInputBuffer(
                                    index,
                                    0,
                                    0,
                                    0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                )
                                inputFinished = true
                            } else {
                                decoder.queueInputBuffer(
                                    index,
                                    0,
                                    size,
                                    extractor.sampleTime,
                                    0
                                )
                                extractor.advance()
                            }
                        }
                    }

                    val index = decoder.dequeueOutputBuffer(
                        info,
                        10000
                    )

                    when (index) {
                        MediaCodec.INFO_TRY_AGAIN_LATER -> Unit

                        MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            val decodedFormat = decoder.outputFormat

                            val encoding = decodedFormat.getInteger(
                                MediaFormat.KEY_PCM_ENCODING,
                                android.media.AudioFormat.ENCODING_PCM_16BIT
                            )

                            require(
                                encoding ==
                                    android.media.AudioFormat.ENCODING_PCM_16BIT
                            ) {
                                "Decoder output must be 16-bit PCM."
                            }
                        }

                        else -> {
                            if (index >= 0) {
                                val buffer = decoder.getOutputBuffer(index)

                                if (buffer != null && info.size > 0) {
                                    val bytes = ByteArray(info.size)

                                    buffer.position(info.offset)
                                    buffer.limit(
                                        info.offset + info.size
                                    )
                                    buffer.get(bytes)

                                    stream.write(bytes)
                                }

                                outputFinished =
                                    info.flags and
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0

                                decoder.releaseOutputBuffer(
                                    index,
                                    false
                                )
                            }
                        }
                    }
                }
            }

            return output.absolutePath
        } finally {
            codec?.let {
                runCatching { it.stop() }
                it.release()
            }

            extractor.release()
        }
    }

    fun writeWav(
        pcmPath: String,
        wavPath: String,
        sampleRate: Int,
        channels: Int
    ): String {
        require(sampleRate > 0)
        require(channels in 1..2)

        val pcm = File(pcmPath)
        require(pcm.isFile) {
            "PCM input is missing."
        }

        val dataSize = pcm.length()

        require(dataSize <= Int.MAX_VALUE - 44L) {
            "PCM input exceeds WAV size limit."
        }

        val header = ByteBuffer.allocate(44)
            .order(ByteOrder.LITTLE_ENDIAN)

        header.put("RIFF".toByteArray(Charsets.US_ASCII))
        header.putInt((36L + dataSize).toInt())
        header.put("WAVE".toByteArray(Charsets.US_ASCII))
        header.put("fmt ".toByteArray(Charsets.US_ASCII))
        header.putInt(16)
        header.putShort(1.toShort())
        header.putShort(channels.toShort())
        header.putInt(sampleRate)
        header.putInt(sampleRate * channels * 2)
        header.putShort((channels * 2).toShort())
        header.putShort(16.toShort())
        header.put("data".toByteArray(Charsets.US_ASCII))
        header.putInt(dataSize.toInt())

        val wav = File(wavPath)
        wav.parentFile?.mkdirs()

        FileOutputStream(wav).use { output ->
            output.write(header.array())

            pcm.inputStream().use { input ->
                input.copyTo(output)
            }
        }

        return wav.absolutePath
    }
}
