package co.parikshit.otakudub

import java.io.File

/**
 * Contract for offline soundtrack separation.
 *
 * A separation engine must produce:
 * - vocals: extracted original vocal content
 * - accompaniment: background music and effects
 *
 * This interface does not implement source separation.
 */
interface BackgroundAudioSeparator {

    fun separate(
        request: SeparationRequest
    ): SeparationResult
}

data class SeparationRequest(
    val sourceMediaPath: String,
    val outputDirectory: File,
    val modelPath: String
) {
    init {
        require(sourceMediaPath.isNotBlank()) {
            "Source media path is required."
        }

        require(modelPath.isNotBlank()) {
            "Separation model path is required."
        }
    }

    fun validate() {
        require(File(sourceMediaPath).isFile) {
            "Source media does not exist."
        }

        require(File(modelPath).isFile) {
            "Offline separation model does not exist."
        }

        require(
            outputDirectory.isDirectory ||
                outputDirectory.mkdirs()
        ) {
            "Cannot create separation output directory."
        }
    }
}

data class SeparationResult(
    val vocalsPath: String,
    val accompanimentPath: String,
    val sampleRate: Int,
    val channels: Int
) {
    fun validate() {
        require(File(vocalsPath).isFile) {
            "Separated vocals file is missing."
        }

        require(File(accompanimentPath).isFile) {
            "Separated background soundtrack is missing."
        }

        require(sampleRate in 8000..192000) {
            "Invalid separation sample rate."
        }

        require(channels in 1..2) {
            "Unsupported audio channel count."
        }
    }
}

class SeparationUnavailableException(
    message: String
) : IllegalStateException(message)

