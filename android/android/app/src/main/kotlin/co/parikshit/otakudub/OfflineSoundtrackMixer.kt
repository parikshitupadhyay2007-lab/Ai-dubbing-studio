package co.parikshit.otakudub

import java.io.File
import java.io.RandomAccessFile

object OfflineSoundtrackMixer {
    fun mix(dialoguePath: String, accompanimentPath: String, outputPath: String): String {
        val speech = File(dialoguePath)
        val music = File(accompanimentPath)
        require(speech.canonicalPath != music.canonicalPath) {
            "Dialogue and accompaniment must be separate files."
        }
        require(speech.isFile && music.isFile)
        require(speech.length() >= 48L && music.length() >= 48L)
        require(File(outputPath).canonicalPath != speech.canonicalPath &&
            File(outputPath).canonicalPath != music.canonicalPath)
        RandomAccessFile(speech, "r").use { voice ->
            RandomAccessFile(music, "r").use { background ->
                val speechFrames = frames(voice, 1, 24000)
                val musicFrames = frames(background, 2, 44100)
                val total = (speechFrames * 44100L + 12000L) / 24000L
                require(total > 0 && total <= (Int.MAX_VALUE - 44L) / 4L)
                require(kotlin.math.abs(total - musicFrames) <= 44100L) {
                    "Soundtrack durations differ."
                }
                SeparationWavWriter(outputPath, 44100).use { writer ->
                    var index = 0L
                    while (index < total) {
                        val count = minOf(4096L, total - index).toInt()
                        val left = FloatArray(count)
                        val right = FloatArray(count)
                        for (i in 0 until count) {
                            val position = index + i
                            val hasMusic = position < musicFrames
                            if (hasMusic) background.seek(44L + position * 4L)
                            val ml = if (hasMusic) background.pcm() else 0f
                            val mr = if (hasMusic) background.pcm() else 0f
                            voice.seek(44L + minOf(position * 24000L / 44100L, speechFrames - 1L) * 2L)
                            val dialogue = voice.pcm()
                            left[i] = (ml * 0.65f + dialogue * 0.85f).coerceIn(-1f, 1f)
                            right[i] = (mr * 0.65f + dialogue * 0.85f).coerceIn(-1f, 1f)
                        }
                        writer.append(left, right)
                        index += count
                    }
                    return writer.finish()
                }
            }
        }
    }

    private fun RandomAccessFile.pcm(): Float {
        val lo = readUnsignedByte()
        val hi = readUnsignedByte()
        return (lo or (hi shl 8)).toShort() / 32768f
    }

    private fun frames(file: RandomAccessFile, channels: Int, rate: Int): Long {
        val header = ByteArray(44)
        file.readFully(header)
        fun word(offset: Int) = (header[offset].toInt() and 255) or
            ((header[offset + 1].toInt() and 255) shl 8)
        fun integer(offset: Int): Long = (0..3).fold(0L) { value, i ->
            value or ((header[offset + i].toLong() and 255L) shl (8 * i))
        }
        fun tag(offset: Int) = String(header, offset, 4, Charsets.US_ASCII)
        require(tag(0) == "RIFF" && tag(8) == "WAVE" &&
            tag(12) == "fmt " && tag(36) == "data" &&
            integer(16) == 16L && word(20) == 1 &&
            word(22) == channels && integer(24) == rate.toLong() &&
            word(34) == 16)
        val bytes = integer(40)
        require(integer(28) == rate.toLong() * channels * 2L &&
            word(32) == channels * 2)
        require(bytes > 0 && bytes % (channels * 2) == 0L &&
            bytes <= file.length() - 44L)
        return bytes / (channels * 2)
    }
}
