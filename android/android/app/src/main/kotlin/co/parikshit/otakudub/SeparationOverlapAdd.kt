
package co.parikshit.otakudub

import java.io.Closeable
import kotlin.math.min

/**
 * Streaming stereo overlap reconstruction.
 *
 * Accepts processed chunks in chronological order and writes
 * their valid audio to an existing SeparationWavWriter.
 *
 * Overlapping samples are combined using complementary
 * linear crossfade weights.
 *
 * This class does not own or close the WAV writer.
 */
class SeparationOverlapAdd(
    private val writer: SeparationWavWriter
) : Closeable {

    private var pendingStart = 0L
    private var pendingLeft = FloatArray(0)
    private var pendingRight = FloatArray(0)

    private var receivedFirst = false
    private var finished = false

    private var nextExpectedStart = 0L

    /**
     * Appends a processed stereo chunk.
     *
     * startFrame must match the source-audio position.
     * validFrames excludes any artificial final-chunk padding.
     */
    @Synchronized
    fun append(
        startFrame: Long,
        left: FloatArray,
        right: FloatArray,
        validFrames: Int
    ) {
        check(!finished) {
            "Overlap reconstruction is already finished."
        }

        require(startFrame >= 0L) {
            "Negative chunk start position."
        }

        require(left.size == right.size) {
            "Stereo chunk lengths differ."
        }

        require(validFrames in 1..left.size) {
            "Invalid chunk frame count."
        }

        require(
            left.take(validFrames).all { it.isFinite() } &&
                right.take(validFrames).all { it.isFinite() }
        ) {
            "Chunk contains non-finite audio."
        }

        require(startFrame <= Long.MAX_VALUE - validFrames) {
            "Chunk position overflow."
        }

        if (!receivedFirst) {
            require(startFrame == 0L) {
                "The first chunk must start at frame zero."
            }

            pendingStart = 0L
            pendingLeft = left.copyOf(validFrames)
            pendingRight = right.copyOf(validFrames)

            receivedFirst = true
            nextExpectedStart = startFrame + 1L
            return
        }

        require(startFrame >= nextExpectedStart) {
            "Chunks must arrive in increasing start-frame order."
        }

        val pendingEnd = pendingStart + pendingLeft.size

        require(startFrame <= pendingEnd) {
            "A gap exists between processed audio chunks."
        }

        // Samples before the new chunk cannot be changed
        // by any subsequent chronological chunk.
        val flushCount = (startFrame - pendingStart).toInt()

        if (flushCount > 0) {
            writer.append(
                pendingLeft,
                pendingRight,
                0,
                flushCount
            )

            pendingLeft = pendingLeft.copyOfRange(
                flushCount,
                pendingLeft.size
            )

            pendingRight = pendingRight.copyOfRange(
                flushCount,
                pendingRight.size
            )

            pendingStart = startFrame
        }

        val overlap = min(
            pendingLeft.size,
            validFrames
        )

        val newLength = maxOf(
            pendingLeft.size,
            validFrames
        )

        val mergedLeft = FloatArray(newLength)
        val mergedRight = FloatArray(newLength)

        // Retain the existing pending audio, including any
        // portion extending beyond the incoming chunk.
        pendingLeft.copyInto(mergedLeft)
        pendingRight.copyInto(mergedRight)

        for (index in 0 until overlap) {
            val incomingWeight = if (overlap == 1) {
                0.5f
            } else {
                index.toFloat() / (overlap - 1).toFloat()
            }

            val existingWeight = 1f - incomingWeight

            mergedLeft[index] =
                pendingLeft[index] * existingWeight +
                    left[index] * incomingWeight

            mergedRight[index] =
                pendingRight[index] * existingWeight +
                    right[index] * incomingWeight
        }

        // Copy the portion that extends beyond pending audio.
        for (index in overlap until validFrames) {
            mergedLeft[index] = left[index]
            mergedRight[index] = right[index]
        }

        pendingLeft = mergedLeft
        pendingRight = mergedRight

        nextExpectedStart = startFrame + 1L
    }

    /**
     * Writes the remaining pending audio.
     *
     * The caller must subsequently call writer.finish().
     */
    @Synchronized
    fun finish() {
        if (finished) return

        require(receivedFirst) {
            "No audio chunks were supplied."
        }

        if (pendingLeft.isNotEmpty()) {
            writer.append(
                pendingLeft,
                pendingRight
            )
        }

        pendingLeft = FloatArray(0)
        pendingRight = FloatArray(0)

        finished = true
    }

    override fun close() {
        pendingLeft = FloatArray(0)
        pendingRight = FloatArray(0)
        finished = true
    }
}
