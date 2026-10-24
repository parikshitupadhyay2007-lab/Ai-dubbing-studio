import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("reference", Path(__file__).with_name("render_supertonic3_reference.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class TestSupertonicPlan(unittest.TestCase):
    def setUp(self):
        self.plan = {"language": "hi", "speaker_voices": {"speaker_1": "M1"},
            "segments": [{"id": 1, "speaker_id": "speaker_1", "text": "नमस्ते",
                          "start": 0.0, "end": 1.5, "expression": "sigh"}]}

    def test_valid(self):
        lang, voices, segments = module.validate_plan(self.plan)
        self.assertEqual(lang, "hi")
        self.assertEqual(voices["speaker_1"], "M1")
        self.assertEqual(len(segments), 1)

    def test_unassigned_speaker(self):
        self.plan["segments"][0]["speaker_id"] = "unknown"
        with self.assertRaises(ValueError):
            module.validate_plan(self.plan)

    def test_invalid_expression(self):
        self.plan["segments"][0]["expression"] = "angry"
        with self.assertRaises(ValueError):
            module.validate_plan(self.plan)

    def test_duplicate_ids(self):
        self.plan["segments"].append(dict(self.plan["segments"][0]))
        with self.assertRaises(ValueError):
            module.validate_plan(self.plan)

    def test_invalid_timing(self):
        self.plan["segments"][0]["end"] = 0
        with self.assertRaises(ValueError):
            module.validate_plan(self.plan)


if __name__ == "__main__":
    unittest.main()
