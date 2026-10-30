import unittest
from department01_extended_metrics import measure


class ExtendedDepartment01MetricsTests(unittest.TestCase):
    def setUp(self):
        self.reference = {
            "source_sha256": "a" * 64,
            "character_observations": [
                {"observation_id": "c1", "character_id": "hero"},
                {"observation_id": "c2", "character_id": "hero"},
            ],
            "episode_cases": [
                {"case_id": "known", "episode_id": "episode_1"},
                {"case_id": "novel", "episode_id": "unknown"},
            ],
            "dialogue_timing": [
                {"utterance_id": "u1", "start_ms": 100, "end_ms": 500},
            ],
        }
        self.prediction = {
            "source_sha256": "a" * 64,
            "character_observations": [
                {"observation_id": "c1", "character_id": "hero"},
                {"observation_id": "c2", "character_id": "unknown"},
            ],
            "episode_cases": [
                {"case_id": "known", "episode_id": "episode_1"},
                {"case_id": "novel", "episode_id": "unknown"},
            ],
            "dialogue_timing": [
                {"utterance_id": "u1", "start_ms": 110, "end_ms": 520},
            ],
            "unresolved_continuity_conflicts": ["speaker_identity_conflict"],
        }

    def test_measures_unknowns_and_timing_without_certification(self):
        result = measure(self.reference, self.prediction)
        self.assertFalse(result["passed"])
        self.assertEqual(result["metrics"]["character_accuracy_known"], 0.5)
        self.assertEqual(result["metrics"]["character_abstention_rate"], 0.5)
        self.assertEqual(result["metrics"]["episode_unknown_recall"], 1.0)
        self.assertEqual(result["metrics"]["dialogue_boundary_mae_ms"], 15)
        self.assertEqual(result["metrics"]["unresolved_continuity_conflicts"], 1)

    def test_missing_or_duplicate_observations_rejected(self):
        self.prediction["character_observations"] = [
            {"observation_id": "c1", "character_id": "hero"},
            {"observation_id": "c1", "character_id": "hero"},
        ]
        with self.assertRaises(ValueError):
            measure(self.reference, self.prediction)

    def test_cross_source_evaluation_rejected(self):
        self.prediction["source_sha256"] = "b" * 64
        with self.assertRaises(ValueError):
            measure(self.reference, self.prediction)


if __name__ == "__main__":
    unittest.main()
