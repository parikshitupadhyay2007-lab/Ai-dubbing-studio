
package co.parikshit.otakudub

import java.io.File

/**
 * Offline phonemization interface for Piper-compatible voices.
 *
 * The native eSpeak NG implementation must provide the JNI
 * functions declared below before this component is operational.
 */
class OfflinePhonemizer(
    private val dataDirectory: File
) {

    companion object {
        private val libraryAvailable: Boolean by lazy {
            try {
                System.loadLibrary("otakudub_phonemizer")
                true
            } catch (_: UnsatisfiedLinkError) {
                false
            }
        }

        @JvmStatic
        private external fun nativeInitialize(
            dataPath: String
        ): Boolean

        @JvmStatic
        private external fun nativePhonemize(
            text: String,
            voice: String
        ): String

        @JvmStatic
        private external fun nativeShutdown()
    }

    private var initialized = false

    fun initialize() {
        check(libraryAvailable) {
            "Native eSpeak NG phonemizer is not integrated."
        }

        require(dataDirectory.isDirectory) {
            "eSpeak NG language data directory is missing."
        }

        check(nativeInitialize(dataDirectory.absolutePath)) {
            "Could not initialize offline phonemizer."
        }

        initialized = true
    }

    fun phonemize(
        text: String,
        config: PiperPhonemizerConfig
    ): String {
        check(initialized) {
            "Offline phonemizer has not been initialized."
        }

        require(text.isNotBlank()) {
            "Cannot phonemize empty dialogue."
        }

        require(config.requiresEspeak()) {
            "This voice does not use eSpeak phonemization."
        }

        val voice = config.voice
            ?: error("eSpeak voice identifier is missing.")

        val result = nativePhonemize(
            text.trim(),
            voice
        )

        check(result.isNotBlank()) {
            "Phonemization produced no output."
        }

        return result
    }

    fun shutdown() {
        if (initialized) {
            nativeShutdown()
            initialized = false
        }
    }
}
