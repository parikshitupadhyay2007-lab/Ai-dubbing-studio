package co.parikshit.otakudub

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Test
import kotlin.math.PI
import kotlin.math.sin

class WsolaTimeStretchTest {
    private val rate = 16000
    private fun tone(seconds: Double, frequency: Double = 220.0) =
        FloatArray((rate * seconds).toInt()) { i ->
            (0.35 * sin(2.0 * PI * frequency * i / rate)).toFloat()
        }

    private fun crossingFrequency(samples: FloatArray): Double {
        var rising = 0
        for (i in 1 until samples.size) {
            if (samples[i - 1] <= 0f && samples[i] > 0f) rising++
        }
        return rising.toDouble() * rate / samples.size
    }

    @Test fun compressesToExactWindowAndPreservesApproximatePitch() {
        val source = tone(1.2)
        val rendered = WsolaTimeStretch.compress(source, rate, rate)
        assertEquals(rate, rendered.size)
        assertTrue(rendered.all { it.isFinite() })
        val hz = crossingFrequency(rendered)
        assertTrue("Unexpected pitch: $hz Hz", hz in 195.0..245.0)
    }

    @Test fun preservesUncompressedSource() {
        val source = tone(0.5)
        val rendered = WsolaTimeStretch.compress(source, source.size + 50, rate)
        assertTrue(rendered.contentEquals(source))
    }

    @Test fun rejectsUnboundedCompression() {
        val source = tone(1.6)
        assertThrows(IllegalArgumentException::class.java) {
            WsolaTimeStretch.compress(source, rate, rate)
        }
    }

    @Test fun rejectsNonFiniteAudio() {
        val source = tone(1.2)
        source[100] = Float.NaN
        assertThrows(IllegalArgumentException::class.java) {
            WsolaTimeStretch.compress(source, rate, rate)
        }
    }
}
