package co.parikshit.otakudub

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer

/**
 * Copies the original video track and replaces its audio
 * with AAC-encoded dubbed dialogue.
 *
 * No external FFmpeg dependency or internet connection.
 */
object OfflineVideoExporter {

    private const val AAC_BITRATE = 128000
    private const val TIMEOUT_US = 10000L

    fun export(request: VideoExportRequest): File {
        val output = File(request.outputPath)
        val temporary = File(output.absolutePath + ".part")

        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        var muxer: MediaMuxer? = null
        var completed = false

        try {
            extractor.setDataSource(request.sourceVideoPath)

            val videoIndex = (0 until extractor.trackCount)
                .firstOrNull { index ->
                    extractor.getTrackFormat(index)
                        .getString(MediaFormat.KEY_MIME)
                        ?.startsWith("video/") == true
                } ?: error("Source contains no video track.")

            val videoFormat = extractor.getTrackFormat(videoIndex)
            val videoMime = videoFormat.getString(
                MediaFormat.KEY_MIME
            ) ?: error("Unknown video codec.")

            require(
                videoMime == "video/avc" ||
                    videoMime == "video/hevc" ||
                    videoMime == "video/mp4v-es" ||
                    videoMime == "video/3gpp" ||
                    videoMime == "video/av01"
            ) {
                "Source video codec is not supported by this MP4 exporter: $videoMime"
            }

            val rotation = if (
                videoFormat.containsKey("rotation-degrees")
            ) {
                videoFormat.getInteger("rotation-degrees")
            } else {
                0
            }

            val audioFormat = MediaFormat.createAudioFormat(
                MediaFormat.MIMETYPE_AUDIO_AAC,
                request.sampleRate,
                request.audioChannels
            ).apply {
                setInteger(
                    MediaFormat.KEY_AAC_PROFILE,
                    MediaCodecInfo.CodecProfileLevel.AACObjectLC
                )
                setInteger(
                    MediaFormat.KEY_BIT_RATE,
                    AAC_BITRATE
                )
                setInteger(
                    MediaFormat.KEY_MAX_INPUT_SIZE,
                    16384
                )
            }

            codec = MediaCodec.createEncoderByType(
                MediaFormat.MIMETYPE_AUDIO_AAC
            )
            val encoder = codec

            encoder.configure(
                audioFormat,
                null,
                null,
                MediaCodec.CONFIGURE_FLAG_ENCODE
            )
            encoder.start()

            if (temporary.exists()) {
                check(temporary.delete()) {
                    "Cannot clear previous temporary export."
                }
            }

            muxer = MediaMuxer(
                temporary.absolutePath,
                MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
            )

            val writer = muxer
            val videoTrack = writer.addTrack(videoFormat)
            writer.setOrientationHint(rotation)

            var audioTrack = -1
            var muxerStarted = false

            val info = MediaCodec.BufferInfo()
            var inputFinished = false
            var outputFinished = false
            var submittedFrames = 0L

            RandomAccessFile(
                request.dialogueWavPath,
                "r"
            ).use { wav ->

                val data = locatePcmData(wav)
                wav.seek(data.first)

                var remaining = data.second

                val bytesPerFrame =
                    request.audioChannels * 2

                while (!outputFinished) {

                    if (!inputFinished) {
                        val inputIndex = encoder.dequeueInputBuffer(
                            TIMEOUT_US
                        )

                        if (inputIndex >= 0) {
                            val input = encoder.getInputBuffer(
                                inputIndex
                            ) ?: error("AAC input buffer unavailable.")

                            input.clear()

                            val available = minOf(
                                remaining,
                                input.capacity().toLong(),
                                8192L
                            ).toInt()

                            val aligned = available -
                                available % bytesPerFrame

                            val timestampUs =
                                submittedFrames * 1000000L /
                                    request.sampleRate

                            if (aligned > 0) {
                                val bytes = ByteArray(aligned)
                                wav.readFully(bytes)
                                input.put(bytes)

                                encoder.queueInputBuffer(
                                    inputIndex,
                                    0,
                                    aligned,
                                    timestampUs,
                                    0
                                )

                                remaining -= aligned
                                submittedFrames +=
                                    aligned / bytesPerFrame
                            } else {
                                require(remaining == 0L) {
                                    "Incomplete PCM audio frame."
                                }

                                encoder.queueInputBuffer(
                                    inputIndex,
                                    0,
                                    0,
                                    timestampUs,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                )

                                inputFinished = true
                            }
                        }
                    }

                    val outputIndex = encoder.dequeueOutputBuffer(
                        info,
                        TIMEOUT_US
                    )

                    when (outputIndex) {
                        MediaCodec.INFO_TRY_AGAIN_LATER -> Unit

                        MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            check(!muxerStarted) {
                                "AAC format changed unexpectedly."
                            }

                            audioTrack = writer.addTrack(
                                encoder.outputFormat
                            )

                            writer.start()
                            muxerStarted = true

                            // Preserve the compressed video samples.
                            extractor.selectTrack(videoIndex)

                            val maxInputSize = if (
                                videoFormat.containsKey(
                                    MediaFormat.KEY_MAX_INPUT_SIZE
                                )
                            ) {
                                videoFormat.getInteger(
                                    MediaFormat.KEY_MAX_INPUT_SIZE
                                )
                            } else {
                                1024 * 1024
                            }

                            val videoBuffer = ByteBuffer.allocateDirect(
                                maxOf(maxInputSize, 4 * 1024 * 1024)
                            )

                            val videoInfo = MediaCodec.BufferInfo()

                            while (true) {
                                videoBuffer.clear()

                                val size = extractor.readSampleData(
                                    videoBuffer,
                                    0
                                )

                                if (size < 0) break

                                require(size <= videoBuffer.capacity()) {
                                    "Video sample exceeds export buffer."
                                }

                                videoInfo.set(
                                    0,
                                    size,
                                    extractor.sampleTime,
                                    extractor.sampleFlags
                                )

                                videoBuffer.position(0)
                                videoBuffer.limit(size)

                                writer.writeSampleData(
                                    videoTrack,
                                    videoBuffer,
                                    videoInfo
                                )

                                extractor.advance()
                            }
                        }

                        else -> {
                            if (outputIndex >= 0) {
                                val encoded = encoder.getOutputBuffer(
                                    outputIndex
                                ) ?: error(
                                    "AAC output buffer unavailable."
                                )

                                if (
                                    info.size > 0 &&
                                    info.flags and
                                        MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0
                                ) {
                                    check(muxerStarted && audioTrack >= 0) {
                                        "MP4 muxer is not ready."
                                    }

                                    encoded.position(info.offset)
                                    encoded.limit(
                                        info.offset + info.size
                                    )

                                    writer.writeSampleData(
                                        audioTrack,
                                        encoded,
                                        info
                                    )
                                }

                                if (
                                    info.flags and
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                                ) {
                                    outputFinished = true
                                }

                                encoder.releaseOutputBuffer(
                                    outputIndex,
                                    false
                                )
                            }
                        }
                    }
                }
            }

            check(muxerStarted) {
                "AAC encoder produced no output format."
            }

            writer.stop()
            writer.release()
            muxer = null

            encoder.stop()
            encoder.release()
            codec = null

            extractor.release()

            check(temporary.isFile && temporary.length() > 0L) {
                "MP4 export produced no output."
            }

            if (output.exists()) {
                check(output.delete()) {
                    "Cannot replace previous exported video."
                }
            }

            check(temporary.renameTo(output)) {
                "Cannot finalize exported MP4."
            }

            completed = true
            return output

        } finally {
            runCatching { codec?.stop() }
            runCatching { codec?.release() }
            runCatching { muxer?.stop() }
            runCatching { muxer?.release() }
            runCatching { extractor.release() }

            if (!completed) {
                temporary.delete()
            }
        }
    }

    /**
     * Locates PCM data rather than assuming every WAV
     * has a fixed 44-byte header.
     */
    private fun locatePcmData(
        wav: RandomAccessFile
    ): Pair<Long, Long> {

        fun ascii(): String {
            val bytes = ByteArray(4)
            wav.readFully(bytes)
            return String(bytes, Charsets.US_ASCII)
        }

        fun uint32(): Long {
            var value = 0L
            repeat(4) { shift ->
                value = value or (
                    wav.readUnsignedByte().toLong() shl
                        (shift * 8)
                )
            }
            return value
        }

        require(ascii() == "RIFF") {
            "Invalid dialogue WAV."
        }

        val riffSize = uint32()

        require(ascii() == "WAVE") {
            "Invalid WAV container."
        }

        val limit = riffSize + 8L

        require(limit <= wav.length()) {
            "Truncated WAV."
        }

        while (wav.filePointer + 8L <= limit) {
            val name = ascii()
            val size = uint32()
            val start = wav.filePointer
            val end = start + size

            require(end >= start && end <= limit) {
                "Invalid WAV chunk."
            }

            if (name == "data") {
                require(size > 0L) {
                    "Dialogue WAV contains no audio."
                }
                return start to size
            }

            val next = end + (size and 1L)
            require(next <= limit) {
                "Invalid WAV chunk padding."
            }
            wav.seek(next)
        }

        error("WAV audio data was not found.")
    }
}
