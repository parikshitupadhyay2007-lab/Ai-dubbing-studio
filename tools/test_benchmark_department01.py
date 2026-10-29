import hashlib
import unittest
from benchmark_department01 import evaluate


class BenchmarkTests(unittest.TestCase):
    def setUp(self):
        self.source = b"synthetic-owned-fixture"
        sha = hashlib.sha256(self.source).hexdigest()
        self.reference = {
            "source_sha256": sha, "duration_ms": 5000,
            "annotation_status": "independently_reviewed",
            "rights_receipt": "original synthetic fixture",
            "shots_ms": [1000, 3000],
            "utterances": [{"id": "u1", "speaker_id": "speaker_a"},
                           {"id": "u2", "speaker_id": "speaker_b"}],
            "characters": [{"id": "speaker_a"}, {"id": "speaker_b"}],
            "dramatic_scenes": [{"start_ms": 0, "end_ms": 5000}],
        }
        self.prediction = {
            "source_sha256": sha, "duration_ms": 5000,
            "shots_ms": [1090, 2910, 4100],
            "utterances": [{"id": "u1", "speaker_id": "speaker_a"},
                           {"id": "u2", "speaker_id": "unknown"}],
            "characters": [], "dramatic_scenes": [],
        }

    def test_diagnostic_does_not_certify(self):
        result = evaluate(self.reference, self.prediction, self.source)
        self.assertFalse(result["passed"])
        self.assertEqual(result["metrics"]["matched_shots"], 2)
        self.assertAlmostEqual(result["metrics"]["shot_precision_250ms"], 2 / 3)
        self.assertEqual(result["metrics"]["speaker_accuracy_total"], 0.5)
        self.assertEqual(result["metrics"]["speaker_abstention_rate"], 0.5)

    def test_source_tampering_fails(self):
        result = evaluate(self.reference, self.prediction, b"altered")
        self.assertEqual(result["metrics"], {})
        self.assertIn("Source content differs from annotation SHA256", result["errors"])

    def test_unreviewed_ground_truth_fails(self):
        self.reference["annotation_status"] = "draft"
        self.assertEqual(evaluate(self.reference, self.prediction)["metrics"], {})

    def test_missing_model_outputs_fail(self):
        del self.prediction["utterances"]
        self.assertEqual(evaluate(self.reference, self.prediction)["metrics"], {})

    def test_duplicate_boundary_does_not_inflate_recall(self):
        self.prediction["shots_ms"] = [1000, 1000]
        self.assertEqual(evaluate(self.reference, self.prediction)["metrics"]["matched_shots"], 1)


if __name__ == "__main__":
    unittest.main()
