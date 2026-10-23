package co.parikshit.otakudub

import java.io.File
import java.io.RandomAccessFile
import org.junit.Assert.*
import org.junit.Test

class SpeakerDiarizerEmbeddingTest {
    private fun wav(): File {
        val file = File.createTempFile("speaker_embedding_", ".wav")
        val frames = 16000 * 3
        RandomAccessFile(file, "rw").use { out ->
            fun short(v: Int) {
                out.write(v and 255)
                out.write((v ushr 8) and 255)
            }
            fun int(v: Int) { short(v); short(v ushr 16) }
            out.writeBytes("RIFF"); int(36 + frames * 2)
            out.writeBytes("WAVEfmt "); int(16)
            short(1); short(1); int(16000); int(32000)
            short(2); short(16); out.writeBytes("data"); int(frames * 2)
            repeat(frames) { short(if (it % 16 < 8) 1200 else -1200) }
        }
        return file
    }

    private fun line(id: Int, start: Double, end: Double) =
        mapOf<String, Any?>(
            "id" to id, "start" to start, "end" to end,
            "original" to "A spoken line"
        )

    @Test fun requiresCalibratedThresholds() {
        try {
            SpeakerDiarizer.identify(
                "/nonexistent.wav", emptyList(),
                SpeakerFeatureExtractor { doubleArrayOf(1.0, 0.0) }
            )
            fail("Expected missing calibration rejection")
        } catch (expected: IllegalArgumentException) {
            assertTrue(expected.message!!.contains("calibrated"))
        }
    }

    @Test fun stableEmbeddingsKeepRecurringSpeakerIdentity() {
        val file = wav()
        try {
            val result = SpeakerDiarizer.identify(
                file.path, listOf(line(1, 0.0, 0.7), line(2, 1.0, 1.7)),
                SpeakerFeatureExtractor { doubleArrayOf(1.0, 0.0) },
                0.22, 0.38
            )
            assertEquals("speaker_1", result[0]["speaker_id"])
            assertEquals("speaker_1", result[1]["speaker_id"])
        } finally { file.delete() }
    }

    @Test fun distinctEmbeddingsCreateSeparateSpeakers() {
        val file = wav()
        var calls = 0
        try {
            val result = SpeakerDiarizer.identify(
                file.path, listOf(line(1, 0.0, 0.7), line(2, 1.0, 1.7)),
                SpeakerFeatureExtractor {
                    calls++
                    if (calls == 1) doubleArrayOf(1.0, 0.0)
                    else doubleArrayOf(0.0, 1.0)
                },
                0.22, 0.38
            )
            assertEquals("speaker_1", result[0]["speaker_id"])
            assertEquals("speaker_2", result[1]["speaker_id"])
        } finally { file.delete() }
    }

    @Test fun overlappingSegmentsAreNotUsedToTrainSpeakerProfiles() {
        val file = wav()
        var calls = 0
        try {
            val result = SpeakerDiarizer.identify(
                file.path, listOf(
                    line(1, 0.0, 0.9), line(2, 0.3, 1.1),
                    line(3, 1.5, 2.3)
                ),
                SpeakerFeatureExtractor {
                    calls++
                    doubleArrayOf(1.0, 0.0)
                },
                0.22, 0.38
            )
            assertEquals("unknown", result[0]["speaker_id"])
            assertEquals("unknown", result[1]["speaker_id"])
            assertEquals("speaker_1", result[2]["speaker_id"])
            assertEquals(1, calls)
        } finally { file.delete() }
    }

    @Test fun changingEmbeddingDimensionsFailsClosed() {
        val file = wav()
        var calls = 0
        try {
            SpeakerDiarizer.identify(
                file.path, listOf(line(1, 0.0, 0.7), line(2, 1.0, 1.7)),
                SpeakerFeatureExtractor {
                    calls++
                    if (calls == 1) doubleArrayOf(1.0, 0.0)
                    else doubleArrayOf(1.0, 0.0, 0.0)
                },
                0.22, 0.38
            )
            fail("Expected dimension mismatch")
        } catch (expected: IllegalArgumentException) {
            assertTrue(expected.message!!.contains("dimension"))
        } finally { file.delete() }
    }
}
