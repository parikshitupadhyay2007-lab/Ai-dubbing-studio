package co.parikshit.otakudub

import org.junit.Assert.*
import org.junit.Test

class SpeakerFeatureValidationTest {
    @Test fun rejectsInvalidVectors() {
        assertNull(SpeakerFeatureValidation.normalizedOrNull(null))
        assertNull(SpeakerFeatureValidation.normalizedOrNull(doubleArrayOf()))
        assertNull(SpeakerFeatureValidation.normalizedOrNull(doubleArrayOf(0.0, 0.0)))
        assertNull(SpeakerFeatureValidation.normalizedOrNull(doubleArrayOf(Double.NaN, 1.0)))
        assertNull(SpeakerFeatureValidation.normalizedOrNull(doubleArrayOf(Double.POSITIVE_INFINITY)))
    }

    @Test fun normalizesValidVector() {
        val result = SpeakerFeatureValidation.normalizedOrNull(doubleArrayOf(3.0, 4.0))!!
        assertEquals(0.6, result[0], 1e-9)
        assertEquals(0.8, result[1], 1e-9)
    }

    @Test fun cosineDistanceHasExpectedBounds() {
        val x = doubleArrayOf(3.0, 0.0)
        assertEquals(0.0, SpeakerFeatureValidation.cosineDistance(x, doubleArrayOf(1.0, 0.0)), 1e-9)
        assertEquals(1.0, SpeakerFeatureValidation.cosineDistance(x, doubleArrayOf(0.0, 5.0)), 1e-9)
        assertEquals(2.0, SpeakerFeatureValidation.cosineDistance(x, doubleArrayOf(-1.0, 0.0)), 1e-9)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsDimensionMismatch() {
        SpeakerFeatureValidation.cosineDistance(doubleArrayOf(1.0), doubleArrayOf(1.0, 2.0))
    }
}
