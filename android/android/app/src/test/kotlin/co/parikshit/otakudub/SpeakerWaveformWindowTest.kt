package co.parikshit.otakudub

import org.junit.Assert.*
import org.junit.Test

class SpeakerWaveformWindowTest {
    @Test fun centerPadsShortSpeech() {
        assertArrayEquals(
            floatArrayOf(0f, 0f, 1f, 2f, 0f, 0f),
            SpeakerWaveformWindow.prepare(floatArrayOf(1f, 2f), 6)!!,
            0f
        )
    }

    @Test fun centerCropsLongSpeech() {
        assertArrayEquals(
            floatArrayOf(2f, 3f, 4f),
            SpeakerWaveformWindow.prepare(floatArrayOf(1f, 2f, 3f, 4f, 5f), 3)!!,
            0f
        )
    }

    @Test fun rejectsInvalidAudio() {
        assertNull(SpeakerWaveformWindow.prepare(floatArrayOf(), 4))
        assertNull(SpeakerWaveformWindow.prepare(floatArrayOf(Float.NaN), 4))
        assertNull(SpeakerWaveformWindow.prepare(floatArrayOf(Float.POSITIVE_INFINITY), 4))
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsInvalidTargetSize() {
        SpeakerWaveformWindow.prepare(floatArrayOf(1f), 0)
    }

    @Test fun equalSizeReturnsIndependentCopy() {
        val source = floatArrayOf(1f, 2f)
        val result = SpeakerWaveformWindow.prepare(source, 2)!!
        source[0] = 9f
        assertEquals(1f, result[0], 0f)
    }
}
