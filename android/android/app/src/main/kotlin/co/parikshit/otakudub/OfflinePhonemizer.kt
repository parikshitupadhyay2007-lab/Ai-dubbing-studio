
package co.parikshit.otakudub

import android.content.Context
import java.io.File

/**
 * Offline phonemization interface for Piper voices.
 *
 * The native eSpeak NG library and compiled language-data
 * assets must be included in the Android build.
 */
class OfflinePhonemizer private constructor(
    private val dataParentDirectory: File
) {

    companion object {

        /**
         * Installs the bundled language data when necessary.
         *
         * eSpeak expects the parent directory containing
         * the espeak-ng-data folder.
         */
        fun create(context: Context): OfflinePhonemizer {
            val directory = EspeakDataInstaller.install(
                context.applicationContext
            )

            return OfflinePhonemizer(directory)
        }

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

    @Synchronized
    fun initialize() {
        if (initialized) return

        check(libraryAvailable) {
            "Native eSpeak NG phonemizer is not integrated."
        }

        val data = File(
            dataParentDirectory,
            "espeak-ng-data"
        )

        require(data.isDirectory) {
            "Offline language data is missing."
        }

        check(
            nativeInitialize(
                dataParentDirectory.absolutePath
            )
        ) {
            "Could not initialize eSpeak NG."
        }

        initialized = true
    }

    @Synchronized
    fun phonemize(
        text: String,
        config: PiperPhonemizerConfig
    ): String {
        check(initialized) {
            "Offline phonemizer is not initialized."
        }

        require(text.isNotBlank()) {
            "Cannot phonemize empty dialogue."
        }

        require(config.requiresEspeak()) {
            "This voice does not use eSpeak phonemization."
        }

        val voice = config.voice
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: error(
                "eSpeak voice identifier is missing."
            )

        val result = nativePhonemize(
            text.trim(),
            voice
        )

        check(result.isNotBlank()) {
            "Phonemization produced no output."
        }

        return result
    }

    @Synchronized
    fun shutdown() {
        if (!initialized) return

        nativeShutdown()
        initialized = false
    }
}

