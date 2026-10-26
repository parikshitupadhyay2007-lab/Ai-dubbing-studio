"""Regression guard for bounded, pitch-preserving Supertonic dialogue placement."""
import unittest
from pathlib import Path

SOURCE = Path("android/android/app/src/main/kotlin/co/parikshit/otakudub/SupertonicSpeechSynthesizer.kt")
WSOLA = Path("android/android/app/src/main/kotlin/co/parikshit/otakudub/WsolaTimeStretch.kt")

class SupertonicDurationFitContract(unittest.TestCase):
    def test_bounded_fit_uses_wsola_not_pitch_changing_resampling(self):
        source = SOURCE.read_text()
        algorithm = WSOLA.read_text()
        self.assertIn("val targetSamples = floor(window * engine.sampleRate).toInt()", source)
        self.assertIn("val rendered = result.wav.copyOf(count)", source)
        self.assertIn("compression <= 1.50", source)
        self.assertIn("WsolaTimeStretch.compress(", source)
        self.assertIn("rendered, targetSamples, engine.sampleRate", source)
        self.assertIn("samples.size.toDouble() / engine.sampleRate <= window", source)
        self.assertNotIn("val step = (count - 1).toDouble()", source)
        self.assertNotIn("fitted[i] = rendered[left]", source)
        self.assertNotIn("Supertonic output exceeds dialogue timing window", source)
        self.assertIn("internal object WsolaTimeStretch", algorithm)
        self.assertIn("val ratio = input.size.toDouble() / outputSamples", algorithm)
        self.assertIn("require(ratio <= 1.50)", algorithm)
        self.assertIn("val score = dot / sqrt(leftEnergy * rightEnergy)", algorithm)
        self.assertIn("return FloatArray(outputSamples)", algorithm)

if __name__ == "__main__":
    unittest.main()
