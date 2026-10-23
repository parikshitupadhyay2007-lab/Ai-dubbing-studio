import json
import pathlib
import unittest


class CandidateSafetyTest(unittest.TestCase):
    def test_candidate_is_not_mistaken_for_production_asset(self):
        manifest = json.loads(
            (pathlib.Path(__file__).with_name("speaker_model_candidate.json"))
            .read_text(encoding="utf-8")
        )
        self.assertEqual(manifest["sample_rate_hz"], 16000)
        self.assertEqual(manifest["embedding_dimensions"], 192)
        self.assertFalse(manifest["android_compatible"])
        self.assertFalse(manifest["redistribution_approved"])
        self.assertFalse(manifest["conversion_verified"])
        self.assertFalse(manifest["held_out_calibration_verified"])
        self.assertNotEqual(manifest["preprocessing"], "raw_pcm16k_mono_float32")


if __name__ == "__main__":
    unittest.main()
