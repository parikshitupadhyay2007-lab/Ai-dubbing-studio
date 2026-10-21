
package co.parikshit.otakudub

import org.json.JSONObject
import java.io.File

enum class PiperPhonemeType {
    ESPEAK,
    TEXT
}

data class PiperPhonemizerConfig(
    val type: PiperPhonemeType,
    val voice: String?,
    val language: String,
    val sampleRate: Int,
    val noiseScale: Float,
    val lengthScale: Float,
    val noiseW: Float
) {
    companion object {

        fun load(
            configFile: File,
            expectedLanguage: String
        ): PiperPhonemizerConfig {
            require(configFile.isFile) {
                "Piper configuration file is missing."
            }

            require(expectedLanguage in setOf("hi", "en")) {
                "Unsupported target language."
            }

            val root = JSONObject(configFile.readText())

            val type = when (
                root.optString("phoneme_type", "").lowercase()
            ) {
                "espeak" -> PiperPhonemeType.ESPEAK
                "text" -> PiperPhonemeType.TEXT

                else -> error(
                    "Unsupported or missing Piper phoneme_type."
                )
            }

            val languageValue = root.opt("language")

            val languageCode = when (languageValue) {
                is JSONObject -> languageValue.optString("code")
                is String -> languageValue
                else -> ""
            }

            val normalizedLanguage = languageCode
                .substringBefore('-')
                .substringBefore('_')
                .lowercase()

            require(normalizedLanguage == expectedLanguage) {
                "Voice language does not match the target language."
            }

            val espeakVoice = root
                .optJSONObject("espeak")
                ?.optString("voice")
                ?.trim()
                ?.takeIf { it.isNotEmpty() }

            if (type == PiperPhonemeType.ESPEAK) {
                require(espeakVoice != null) {
                    "This Piper model requires an eSpeak voice identifier."
                }
            }

            val audio = root.optJSONObject("audio")
                ?: error("Piper audio configuration is missing.")

            val sampleRate = audio.optInt("sample_rate", 0)

            require(sampleRate in 8000..192000) {
                "Invalid Piper sample rate."
            }

            val inference = root.optJSONObject("inference")
                ?: error("Piper inference settings are missing.")

            fun setting(name: String): Float {
                val value = inference.opt(name)

                require(value is Number) {
                    "Missing Piper inference setting: $name"
                }

                val number = value.toFloat()

                require(number.isFinite()) {
                    "Invalid Piper inference setting: $name"
                }

                return number
            }

            val noiseScale = setting("noise_scale")
            val lengthScale = setting("length_scale")
            val noiseW = setting("noise_w")

            require(noiseScale >= 0f) {
                "noise_scale cannot be negative."
            }

            require(lengthScale > 0f) {
                "length_scale must be positive."
            }

            require(noiseW >= 0f) {
                "noise_w cannot be negative."
            }

            return PiperPhonemizerConfig(
                type = type,
                voice = espeakVoice,
                language = normalizedLanguage,
                sampleRate = sampleRate,
                noiseScale = noiseScale,
                lengthScale = lengthScale,
                noiseW = noiseW
            )
        }
    }

    /**
     * Checks whether the requested voice can use a particular
     * phonemization backend.
     *
     * This does not claim that the backend is installed.
     */
    fun requiresEspeak(): Boolean {
        return type == PiperPhonemeType.ESPEAK
    }

    fun requiresTextPhonemes(): Boolean {
        return type == PiperPhonemeType.TEXT
    }
}
