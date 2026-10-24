
package co.parikshit.otakudub

import java.io.File

data class NativeVoiceModel(
    val profileId: String,
    val modelId: String,
    val modelPath: String,
    val configPath: String,
    val language: String,
    val sampleRate: Int,
    val numSpeakers: Int,
    val speakerIds: Map<String, Int>
)

data class NativeDialogueSegment(
    val id: Int,
    val start: Double,
    val end: Double,
    val text: String,
    val speakerId: String,
    val voiceId: String,
    val delivery: String = "natural"
)

data class VoiceSynthesisRequest(
    val targetLanguage: String,
    val voices: Map<String, NativeVoiceModel>,
    val characterVoices: Map<String, String>,
    val segments: List<NativeDialogueSegment>
) {
    companion object {

        fun parse(arguments: Any?): VoiceSynthesisRequest {
            val root = arguments.asStringMap("Synthesis request")

            val language = root["target_language"] as? String
                ?: error("Target language is missing.")

            require(language in setOf("hi", "en")) {
                "Unsupported synthesis language: $language"
            }

            val rawModels =
                root["voice_models"].asStringMap("Voice models")

            require(rawModels.isNotEmpty()) {
                "No character voice models were supplied."
            }

            val voices = rawModels.mapValues { (profileId, value) ->
                val data = value.asStringMap(
                    "Voice model $profileId"
                )

                val modelPath = data.requiredString("model_path")
                val configPath = data.requiredString("config_path")
                val modelLanguage = data.requiredString("language")

                require(modelLanguage == language) {
                    "Voice $profileId has the wrong language."
                }

                require(File(modelPath).isFile) {
                    "ONNX file missing for $profileId."
                }

                require(File(modelPath).length() > 0L) {
                    "ONNX file is empty for $profileId."
                }

                require(File(configPath).isFile) {
                    "Voice configuration missing for $profileId."
                }

                require(File(configPath).length() > 0L) {
                    "Voice configuration is empty for $profileId."
                }

                require(data["architecture"] == "piper") {
                    "Unsupported architecture for $profileId."
                }

                require(data.requiredString("profile_id") == profileId) {
                    "Voice profile identifier mismatch."
                }

                val sampleRate = data.requiredInt("sample_rate")
                val numSpeakers = data.requiredInt("num_speakers")

                require(sampleRate > 0) {
                    "Invalid sample rate for $profileId."
                }

                require(numSpeakers > 0) {
                    "Invalid speaker count for $profileId."
                }

                val speakerIds = data["speaker_id_map"]
                    .asStringMap("Speaker ID map")
                    .mapValues { (_, id) ->
                        val number = id as? Number
                            ?: error("Invalid model speaker ID.")

                        val integer = number.toInt()

                        require(integer.toDouble() == number.toDouble()) {
                            "Model speaker ID must be an integer."
                        }

                        require(integer in 0 until numSpeakers) {
                            "Model speaker ID is out of range."
                        }

                        integer
                    }

                NativeVoiceModel(
                    profileId = profileId,
                    modelId = data.requiredString("model_id"),
                    modelPath = modelPath,
                    configPath = configPath,
                    language = modelLanguage,
                    sampleRate = sampleRate,
                    numSpeakers = numSpeakers,
                    speakerIds = speakerIds
                )
            }

            val assignments = root["character_voices"]
                .asStringMap("Character assignments")
                .mapValues { (_, value) ->
                    value as? String
                        ?: error("Invalid character voice assignment.")
                }

            val rawSegments = root["segments"] as? List<*>
                ?: error("Dialogue segments are missing.")

            require(rawSegments.isNotEmpty()) {
                "There is no dialogue to synthesize."
            }

            val segments = rawSegments.map { item ->
                val data = item.asStringMap("Dialogue segment")

                val id = data.requiredInt("id")
                val start = data.requiredDouble("start")
                val end = data.requiredDouble("end")

                val text = data.requiredString("translation")
                val speaker = data.requiredString("speaker_id")
                val voice = data.requiredString("voice_id")

                require(start.isFinite() && end.isFinite()) {
                    "Non-finite dialogue timing for segment $id."
                }

                require(start >= 0.0 && end > start) {
                    "Invalid dialogue timing for segment $id."
                }

                require(speaker != "unknown") {
                    "Unidentified speaker in segment $id."
                }

                require(assignments[speaker] == voice) {
                    "Character voice mismatch in segment $id."
                }

                require(voices.containsKey(voice)) {
                    "Voice model $voice is unavailable."
                }

                val delivery = (data["delivery"] as? String) ?: "natural"
                require(delivery in setOf("natural", "soft", "urgent", "excited", "solemn")) {
                    "Unsupported delivery style for segment $id."
                }

                NativeDialogueSegment(
                    id = id,
                    start = start,
                    end = end,
                    text = text,
                    speakerId = speaker,
                    voiceId = voice,
                    delivery = delivery
                )
            }

            require(segments.map { it.id }.toSet().size == segments.size) {
                "Dialogue segment IDs must be unique."
            }

            return VoiceSynthesisRequest(
                targetLanguage = language,
                voices = voices,
                characterVoices = assignments,
                segments = segments
            )
        }

        private fun Any?.asStringMap(
            label: String
        ): Map<String, Any?> {
            val source = this as? Map<*, *>
                ?: error("$label must be a map.")

            require(source.keys.all { it is String }) {
                "$label contains invalid keys."
            }

            return source.entries.associate { entry ->
                (entry.key as String) to entry.value
            }
        }

        private fun Map<String, Any?>.requiredString(
            key: String
        ): String {
            val value = this[key] as? String
                ?: error("Missing or invalid $key.")

            require(value.isNotBlank()) {
                "$key cannot be empty."
            }

            return value
        }

        private fun Map<String, Any?>.requiredInt(
            key: String
        ): Int {
            val value = this[key] as? Number
                ?: error("Missing or invalid $key.")

            val number = value.toInt()

            require(number.toDouble() == value.toDouble()) {
                "$key must be an integer."
            }

            return number
        }

        private fun Map<String, Any?>.requiredDouble(
            key: String
        ): Double {
            return (this[key] as? Number)?.toDouble()
                ?: error("Missing or invalid $key.")
        }
    }
}
