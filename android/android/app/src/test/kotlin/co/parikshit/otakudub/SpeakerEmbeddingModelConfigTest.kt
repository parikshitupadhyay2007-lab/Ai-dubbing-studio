package co.parikshit.otakudub

import java.io.File
import java.security.MessageDigest
import org.junit.Assert.*
import org.junit.Test

class SpeakerEmbeddingModelConfigTest {
    @Test fun validatesCheckpointProvenanceAndCalibration() {
        val model = File.createTempFile("speaker_", ".onnx")
        val license = File.createTempFile("speaker_license_", ".txt")
        try {
            model.writeBytes(byteArrayOf(1, 2, 3))
            license.writeText("Test-only fixture; not a production checkpoint.")
            val digest = MessageDigest.getInstance("SHA-256")
                .digest(model.readBytes()).joinToString("") { "%02x".format(it) }
            val config = SpeakerEmbeddingModelConfig(
                model.absolutePath, digest, 16000, "audio", "embedding",
                192, 0.22, 0.38, license.absolutePath,
                inputSamples = 16000, preprocessing = "raw_pcm16k_mono_float32"
            )
            config.validate()
            try {
                config.copy(sha256 = "0".repeat(64)).validate()
                fail("Expected checksum mismatch")
            } catch (expected: IllegalArgumentException) {
                assertTrue(expected.message!!.contains("checksum"))
            }
            try {
                config.copy(matchThreshold = 0.5, newSpeakerThreshold = 0.4).validate()
                fail("Expected calibration rejection")
            } catch (expected: IllegalArgumentException) {
                assertTrue(expected.message!!.contains("threshold"))
            }
            try {
                config.copy(licenseRecord = "/missing-license-record").validate()
                fail("Expected license record rejection")
            } catch (expected: IllegalArgumentException) {
                assertTrue(expected.message!!.contains("license"))
            }
        } finally {
            model.delete()
            license.delete()
        }
    }
}
