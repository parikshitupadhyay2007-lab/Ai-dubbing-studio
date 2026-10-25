"""Regression guard for bounded native Supertonic dialogue placement."""
import unittest
from pathlib import Path

SOURCE = Path("android/android/app/src/main/kotlin/co/parikshit/otakudub/SupertonicSpeechSynthesizer.kt")

class SupertonicDurationFitContract(unittest.TestCase):
    def test_bounded_fit_is_not_end_truncation(self):
        source = SOURCE.read_text()
        self.assertIn("val targetSamples = floor(window * engine.sampleRate).toInt()", source)
        self.assertIn("val rendered = result.wav.copyOf(count)", source)
        self.assertIn("compression <= 1.50", source)
        self.assertIn("val step = (count - 1).toDouble() / (targetSamples - 1)", source)
        self.assertIn("fitted[i] = rendered[left]", source)
        self.assertIn("samples.size.toDouble() / engine.sampleRate <= window", source)
        self.assertNotIn("Supertonic output exceeds dialogue timing window", source)

if __name__ == "__main__":
    unittest.main()
