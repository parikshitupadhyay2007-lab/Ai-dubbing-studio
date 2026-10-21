
package co.parikshit.otakudub

import java.io.File

data class DialogueMixRequest(
    val sourceVideoPath: String,
    val clips: List<SynthesizedDialogueClip>
) {
    companion object {

        fun parse(arguments: Any?): DialogueMixRequest {

            val root = arguments as? Map<*, *>
                ?: error("Dialogue mix request must be a map.")

            val source = root["source_path"] as? String
                ?: error("Source video path is missing.")

            require(source.isNotBlank()) {
                "Source video path cannot be empty."
            }

            val video = File(source)

            require(video.isFile && video.length() > 0L) {
                "Source video is missing or empty."
            }

            val rawClips = root["clips"] as? List<*>
                ?: error("Synthesized dialogue clips are missing.")

            require(rawClips.isNotEmpty()) {
                "No synthesized dialogue clips supplied."
            }

            val clips = rawClips.mapIndexed { index, item ->

                val data = item as? Map<*, *>
                    ?: error("Invalid dialogue clip at index $index.")

                fun requiredString(key: String): String {
                    val value = data[key] as? String
                        ?: error("Missing $key in clip $index.")

                    require(value.isNotBlank()) {
                        "$key cannot be empty in clip $index."
                    }

                    return value
                }

                fun requiredInt(key: String): Int {
                    val value = data[key] as? Number
                        ?: error("Missing $key in clip $index.")

                    val number = value.toInt()

                    require(number.toDouble() == value.toDouble()) {
                        "$key must be an integer in clip $index."
                    }

                    return number
                }

                fun requiredDouble(key: String): Double {
                    val value = data[key] as? Number
                        ?: error("Missing $key in clip $index.")

                    return value.toDouble()
                }

                val segmentId = requiredInt("segment_id")
                val speakerId = requiredString("speaker_id")
                val voiceId = requiredString("voice_id")
                val wavPath = requiredString("wav_path")
                val sampleRate = requiredInt("sample_rate")
                val start = requiredDouble("start")
                val end = requiredDouble("end")

                require(
                    start.isFinite() &&
                        end.isFinite() &&
                        start >= 0.0 &&
                        end > start
                ) {
                    "Invalid timing in clip $index."
                }

                require(sampleRate in 8000..192000) {
                    "Invalid sample rate in clip $index."
                }

                val wav = File(wavPath)

                require(wav.isFile && wav.length() > 44L) {
                    "Synthesized WAV is missing for clip $index."
                }

                SynthesizedDialogueClip(
                    segmentId = segmentId,
                    speakerId = speakerId,
                    voiceId = voiceId,
                    start = start,
                    end = end,
                    wavPath = wav.absolutePath,
                    sampleRate = sampleRate
                )
            }

            require(
                clips.map { it.segmentId }.toSet().size ==
                    clips.size
            ) {
                "Duplicate dialogue segment IDs."
            }

            return DialogueMixRequest(
                sourceVideoPath = video.absolutePath,
                clips = clips
            )
        }
    }
}
