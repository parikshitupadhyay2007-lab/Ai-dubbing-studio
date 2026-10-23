package co.parikshit.otakudub

import java.io.File
import java.security.MessageDigest

/**
 * Explicit contract for a verified speaker embedding checkpoint.
 * No model is enabled just because a similarly named ONNX file exists.
 * Preprocessing and calibrated thresholds must be supplied from evaluation.
 */
data class SpeakerEmbeddingModelConfig(
    val modelPath: String,
    val sha256: String,
    val sampleRate: Int,
    val inputName: String,
    val outputName: String,
    val embeddingDimension: Int,
    val matchThreshold: Double,
    val newSpeakerThreshold: Double,
    val licenseRecord: String
) {
    fun validate() {
        val file = File(modelPath)
        require(file.isFile && file.length() > 0L) { "Speaker ONNX checkpoint is missing." }
        require(sha256.matches(Regex("[0-9a-fA-F]{64}"))) { "Expected SHA-256 checksum." }
        require(sampleRate == 16000) { "Speaker diarizer requires 16 kHz mono input." }
        require(inputName.isNotBlank() && outputName.isNotBlank()) { "ONNX tensor names are required." }
        require(embeddingDimension in 16..4096) { "Invalid speaker embedding dimension." }
        require(matchThreshold.isFinite() && newSpeakerThreshold.isFinite() &&
            matchThreshold > 0 && newSpeakerThreshold > matchThreshold &&
            newSpeakerThreshold <= 2.0) { "Uncalibrated speaker thresholds." }
        require(licenseRecord.isNotBlank() && File(licenseRecord).isFile) {
            "Speaker checkpoint license record is missing."
        }
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input ->
            val block = ByteArray(65536)
            while (true) {
                val size = input.read(block)
                if (size < 0) break
                digest.update(block, 0, size)
            }
        }
        val actual = digest.digest().joinToString("") { "%02x".format(it) }
        require(actual.equals(sha256, ignoreCase = true)) {
            "Speaker ONNX checkpoint checksum mismatch."
        }
    }
}
