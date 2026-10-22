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
 * Offline MP4 exporter.
 *
 * Pass 1: Encode synchronized PCM dialogue to temporary AAC.
 * Pass 2: Interleave original compressed video and AAC audio.
 *
 * The original soundtrack is replaced in this implementation.
 */
object OfflineVideoExporter {

    private const val AAC_BITRATE = 128000
    private const val TIMEOUT_US = 10000L

    fun export(request: VideoExportRequest): File {
        val output = File(request.outputPath)
        val temporaryVideo = File(
            output.absolutePath + ".part.mp4"
        )
        val temporaryAudio = File(
            output.absolutePath + ".audio.part.m4a"
        )

        require(
            request.sourceVideoPath != output.absolutePath &&
                request.dialogueWavPath != output.absolutePath
        ) {
            "Export destination cannot overwrite an input."
        }

        try {
            require(!temporaryVideo.exists() ||
                temporaryVideo.delete()) {
                "Cannot clear previous temporary video."
            }

            require(!temporaryAudio.exists() ||
                temporaryAudio.delete()) {
                "Cannot clear previous temporary audio."
            }

            encodeDialogue(
                request = request,
                destination = temporaryAudio
            )

            combineTracks(
                sourceVideo = request.sourceVideoPath,
                encodedAudio = temporaryAudio.absolutePath,
                destination = temporaryVideo
            )

            check(
                temporaryVideo.isFile &&
                    temporaryVideo.length() > 0L
            ) {
                "MP4 export produced an empty file."
            }

            if (output.exists()) {
                check(output.delete()) {
                    "Cannot replace the previous exported video."
                }
            }

            check(temporaryVideo.renameTo(output)) {
                "Cannot finalize exported MP4."
            }

            val verify = MediaExtractor()
            try {
                verify.setDataSource(output.absolutePath)
                val formats = (0 until verify.trackCount).map {
                    verify.getTrackFormat(it).getString(MediaFormat.KEY_MIME) ?: ""
                }
                check(formats.any { it.startsWith("video/") } &&
                    formats.any { it.startsWith("audio/") }) {
                    "Exported MP4 is missing a video or audio track."
                }
            } catch (error: Exception) {
                output.delete()
                throw error
            } finally {
                verify.release()
            }
            return output

        } finally {
            temporaryAudio.delete()
            temporaryVideo.delete()
        }
    }

    private fun encodeDialogue(
        request: VideoExportRequest,
        destination: File
    ) {
        val format = MediaFormat.createAudioFormat(
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

        val encoder = MediaCodec.createEncoderByType(
            MediaFormat.MIMETYPE_AUDIO_AAC
        )

        var muxer: MediaMuxer? = null
        var encoderStarted = false
        var muxerStarted = false

        try {
            encoder.configure(
                format,
                null,
                null,
                MediaCodec.CONFIGURE_FLAG_ENCODE
            )

            encoder.start()
            encoderStarted = true

            muxer = MediaMuxer(
                destination.absolutePath,
                MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
            )

            val writer = muxer
            var audioTrack = -1

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

                require(
                    remaining % bytesPerFrame == 0L
                ) {
                    "Incomplete PCM audio frame."
                }

                while (!outputFinished) {

                    if (!inputFinished) {
                        val inputIndex =
                            encoder.dequeueInputBuffer(TIMEOUT_US)

                        if (inputIndex >= 0) {
                            val input = encoder.getInputBuffer(
                                inputIndex
                            ) ?: error(
                                "AAC input buffer unavailable."
                            )

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
                                check(remaining == 0L) {
                                    "AAC input buffer is too small."
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

                    val outputIndex =
                        encoder.dequeueOutputBuffer(
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
                        }

                        else -> {
                            if (outputIndex >= 0) {
                                val encoded =
                                    encoder.getOutputBuffer(
                                        outputIndex
                                    ) ?: error(
                                        "AAC output buffer unavailable."
                                    )

                                if (
                                    info.size > 0 &&
                                    info.flags and
                                        MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0
                                ) {
                                    check(
                                        muxerStarted &&
                                            audioTrack >= 0
                                    ) {
                                        "AAC muxer is not ready."
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

                                val endOfStream =
                                    info.flags and
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0

                                encoder.releaseOutputBuffer(
                                    outputIndex,
                                    false
                                )

                                if (endOfStream) {
                                    outputFinished = true
                                }
                            }
                        }
                    }
                }
            }

            check(muxerStarted) {
                "AAC encoder produced no output format."
            }

        } finally {
            if (encoderStarted) {
                runCatching { encoder.stop() }
            }

            runCatching { encoder.release() }

            if (muxerStarted) {
                runCatching { muxer?.stop() }
            }

            runCatching { muxer?.release() }
        }

        check(destination.isFile && destination.length() > 0L) {
            "AAC encoding produced no audio."
        }
    }

    private fun combineTracks(
        sourceVideo: String,
        encodedAudio: String,
        destination: File
    ) {
        val videoExtractor = MediaExtractor()
        val audioExtractor = MediaExtractor()

        var muxer: MediaMuxer? = null
        var started = false

        try {
            videoExtractor.setDataSource(sourceVideo)
            audioExtractor.setDataSource(encodedAudio)

            val videoIndex =
                (0 until videoExtractor.trackCount)
                    .firstOrNull { index ->
                        videoExtractor.getTrackFormat(index)
                            .getString(MediaFormat.KEY_MIME)
                            ?.startsWith("video/") == true
                    } ?: error(
                        "Source contains no video track."
                    )

            val audioIndex =
                (0 until audioExtractor.trackCount)
                    .firstOrNull { index ->
                        audioExtractor.getTrackFormat(index)
                            .getString(MediaFormat.KEY_MIME)
                            ?.startsWith("audio/") == true
                    } ?: error(
                        "Encoded dialogue contains no audio track."
                    )

            val videoFormat =
                videoExtractor.getTrackFormat(videoIndex)

            val audioFormat =
                audioExtractor.getTrackFormat(audioIndex)

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
                "Unsupported MP4 video codec: $videoMime"
            }

            videoExtractor.selectTrack(videoIndex)
            audioExtractor.selectTrack(audioIndex)

            muxer = MediaMuxer(
                destination.absolutePath,
                MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
            )

            val writer = muxer

            val videoTrack = writer.addTrack(videoFormat)
            val audioTrack = writer.addTrack(audioFormat)

            val rotation = if (
                videoFormat.containsKey("rotation-degrees")
            ) {
                videoFormat.getInteger("rotation-degrees")
            } else {
                0
            }

            if (rotation in listOf(0, 90, 180, 270)) {
                writer.setOrientationHint(rotation)
            }

            writer.start()
            started = true

            val videoBuffer = ByteBuffer.allocateDirect(
                bufferCapacity(videoFormat)
            )

            val audioBuffer = ByteBuffer.allocateDirect(
                bufferCapacity(audioFormat)
            )

            val videoInfo = MediaCodec.BufferInfo()
            val audioInfo = MediaCodec.BufferInfo()

            var videoReady = readSample(
                videoExtractor,
                videoBuffer,
                videoInfo
            )

            var audioReady = readSample(
                audioExtractor,
                audioBuffer,
                audioInfo
            )

            while (videoReady || audioReady) {
                val writeVideo = videoReady && (
                    !audioReady ||
                        videoInfo.presentationTimeUs <=
                        audioInfo.presentationTimeUs
                )

                if (writeVideo) {
                    writer.writeSampleData(
                        videoTrack,
                        videoBuffer,
                        videoInfo
                    )

                    videoExtractor.advance()

                    videoReady = readSample(
                        videoExtractor,
                        videoBuffer,
                        videoInfo
                    )

                } else {
                    writer.writeSampleData(
                        audioTrack,
                        audioBuffer,
                        audioInfo
                    )

                    audioExtractor.advance()

                    audioReady = readSample(
                        audioExtractor,
                        audioBuffer,
                        audioInfo
                    )
                }
            }

        } finally {
            if (started) {
                runCatching { muxer?.stop() }
            }

            runCatching { muxer?.release() }
            runCatching { videoExtractor.release() }
            runCatching { audioExtractor.release() }
        }
    }

    private fun bufferCapacity(format: MediaFormat): Int {
        val requested = if (
            format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)
        ) {
            format.getInteger(
                MediaFormat.KEY_MAX_INPUT_SIZE
            )
        } else {
            0
        }

        return maxOf(
            requested,
            8 * 1024 * 1024
        )
    }

    private fun readSample(
        extractor: MediaExtractor,
        buffer: ByteBuffer,
        info: MediaCodec.BufferInfo
    ): Boolean {
        buffer.clear()

        val size = extractor.readSampleData(
            buffer,
            0
        )

        if (size < 0) {
            return false
        }

        require(size <= buffer.capacity()) {
            "Media sample exceeds export buffer."
        }

        info.set(
            0,
            size,
            extractor.sampleTime,
            extractor.sampleFlags
        )

        buffer.position(0)
        buffer.limit(size)

        return true
    }

    private fun locatePcmData(
        wav: RandomAccessFile
    ): Pair<Long, Long> {

        fun ascii(): String {
            val bytes = ByteArray(4)
            wav.readFully(bytes)
            return String(
                bytes,
                Charsets.US_ASCII
            )
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
