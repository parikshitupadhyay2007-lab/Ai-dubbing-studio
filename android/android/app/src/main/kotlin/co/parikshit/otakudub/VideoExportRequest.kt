
package co.parikshit.otakudub

import java.io.File
import java.io.RandomAccessFile

/**
 * Validated input for OtakuDub's offline MP4 exporter.
 *
 * The first export implementation will:
 * - preserve the original video stream
 * - replace its audio with the dubbed dialogue
 * - encode the dialogue as AAC
 * - produce an MP4 file
 *
 * Original soundtrack separation is a separate milestone.
 */
data class VideoExportRequest(
    val sourceVideoPath: String,
    val dialogueWavPath: String,
    val outputPath: String,
    val sampleRate: Int,
    val audioChannels: Int
) {

    companion object {

        fun parse(arguments: Any?): VideoExportRequest {

            val root = arguments as? Map<*, *>
                ?: error("Video export request must be a map.")

            fun requiredPath(key: String): String {
                val value = root[key] as? String
                    ?: error("Missing required field: $key")

                require(value.isNotBlank()) {
                    "$key cannot be empty."
                }

                return value
            }

            val source = File(
                requiredPath("source_path")
            ).canonicalFile

            val dialogue = File(
                requiredPath("dialogue_wav_path")
            ).canonicalFile

            val output = File(
                requiredPath("output_path")
            ).canonicalFile

            require(
                source.isFile &&
                    source.length() > 0L
            ) {
                "Original video is missing or empty."
            }

            require(
                dialogue.isFile &&
                    dialogue.length() > 44L
            ) {
                "Dubbed dialogue WAV is missing or empty."
            }

            require(
                source != output &&
                    dialogue != output
            ) {
                "Export cannot overwrite an input file."
            }

            require(
                output.extension.equals(
                    "mp4",
                    ignoreCase = true
                )
            ) {
                "Export destination must be an MP4 file."
            }

            val parent = output.parentFile
                ?: error("Invalid export destination.")

            check(
                parent.isDirectory || parent.mkdirs()
            ) {
                "Cannot create export directory."
            }

            require(parent.canWrite()) {
                "Export directory is not writable."
            }

            val wavInfo = inspectWav(dialogue)

            require(wavInfo.channels == 1) {
                "The dialogue mixer must produce mono audio."
            }

            require(wavInfo.bitsPerSample == 16) {
                "Expected 16-bit PCM dialogue audio."
            }

            require(wavInfo.sampleRate in 8000..48000) {
                "Unsupported dialogue sample rate."
            }

            return VideoExportRequest(
                sourceVideoPath = source.absolutePath,
                dialogueWavPath = dialogue.absolutePath,
                outputPath = output.absolutePath,
                sampleRate = wavInfo.sampleRate,
                audioChannels = wavInfo.channels
            )
        }

        private data class WavInfo(
            val sampleRate: Int,
            val channels: Int,
            val bitsPerSample: Int
        )

        private fun inspectWav(file: File): WavInfo {

            RandomAccessFile(file, "r").use { wav ->

                fun ascii(length: Int): String {
                    val bytes = ByteArray(length)
                    wav.readFully(bytes)

                    return String(
                        bytes,
                        Charsets.US_ASCII
                    )
                }

                fun uint16(): Int {
                    val a = wav.readUnsignedByte()
                    val b = wav.readUnsignedByte()

                    return a or (b shl 8)
                }

                fun uint32(): Long {
                    val a = wav.readUnsignedByte().toLong()
                    val b = wav.readUnsignedByte().toLong()
                    val c = wav.readUnsignedByte().toLong()
                    val d = wav.readUnsignedByte().toLong()

                    return a or
                        (b shl 8) or
                        (c shl 16) or
                        (d shl 24)
                }

                require(ascii(4) == "RIFF") {
                    "Invalid WAV header."
                }

                val riffSize = uint32()

                require(ascii(4) == "WAVE") {
                    "Unsupported WAV container."
                }

                require(riffSize + 8L <= wav.length()) {
                    "Truncated WAV file."
                }

                var sampleRate = 0
                var channels = 0
                var bits = 0
                var encoding = 0
                var foundFormat = false
                var foundData = false

                val riffEnd = riffSize + 8L

                while (wav.filePointer + 8L <= riffEnd) {

                    val chunkName = ascii(4)
                    val chunkSize = uint32()

                    val chunkStart = wav.filePointer
                    val chunkEnd = chunkStart + chunkSize

                    require(
                        chunkEnd >= chunkStart &&
                            chunkEnd <= riffEnd
                    ) {
                        "Invalid WAV chunk."
                    }

                    when (chunkName) {

                        "fmt " -> {
                            require(chunkSize >= 16L) {
                                "Invalid WAV format chunk."
                            }

                            encoding = uint16()
                            channels = uint16()
                            sampleRate = uint32().toInt()

                            uint32()
                            uint16()

                            bits = uint16()
                            foundFormat = true
                        }

                        "data" -> {
                            require(
                                chunkSize > 0L &&
                                    chunkSize % 2L == 0L
                            ) {
                                "Invalid WAV audio data."
                            }

                            foundData = true
                        }
                    }

                    val next = chunkEnd +
                        (chunkSize and 1L)

                    require(next <= riffEnd) {
                        "Invalid WAV chunk padding."
                    }

                    wav.seek(next)
                }

                require(foundFormat && foundData) {
                    "WAV format or audio data is missing."
                }

                require(encoding == 1) {
                    "Only uncompressed PCM WAV is supported."
                }

                return WavInfo(
                    sampleRate = sampleRate,
                    channels = channels,
                    bitsPerSample = bits
                )
            }
        }
    }
}
