
package co.parikshit.otakudub

import android.media.MediaMetadataRetriever
import java.io.File

/**
 * Connects synthesized character dialogue to the
 * timestamp planner and offline audio mixer.
 *
 * Produces a continuous mono WAV aligned with the
 * source video's timeline.
 */
object OfflineDialogueMixService {

    data class Result(
        val wavPath: String,
        val durationMs: Long,
        val segmentCount: Int,
        val overlapCount: Int,
        val sampleRate: Int
    )

    fun createMix(
        sourceVideoPath: String,
        clips: List<SynthesizedDialogueClip>,
        outputDirectory: File
    ): Result {

        val source = File(sourceVideoPath)

        require(source.isFile && source.length() > 0L) {
            "Source video is missing or empty."
        }

        require(clips.isNotEmpty()) {
            "No synthesized dialogue is available."
        }

        check(
            outputDirectory.isDirectory ||
                outputDirectory.mkdirs()
        ) {
            "Cannot create dialogue output directory."
        }

        val durationMs = readMediaDuration(
            source.absolutePath
        )

        val timeline = DialogueTimelinePlanner.plan(
            clips = clips,
            videoDurationMs = durationMs
        )

        val destination = File(
            outputDirectory,
            "otakudub_dialogue.wav"
        )

        val mixedFile = DialogueAudioMixer.mix(
            timeline = timeline,
            destination = destination
        )

        check(
            mixedFile.isFile &&
                mixedFile.length() > 44L
        ) {
            "Dialogue mixing produced no audio."
        }

        return Result(
            wavPath = mixedFile.absolutePath,
            durationMs = timeline.totalDurationMs,
            segmentCount = timeline.clips.size,
            overlapCount = timeline.overlapCount,
            sampleRate = 24000
        )
    }

    private fun readMediaDuration(
        mediaPath: String
    ): Long {

        val retriever = MediaMetadataRetriever()

        try {
            retriever.setDataSource(mediaPath)

            val duration = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION
            )?.toLongOrNull()

            require(duration != null && duration > 0L) {
                "Could not determine source video duration."
            }

            return duration

        } finally {
            retriever.release()
        }
    }
}
