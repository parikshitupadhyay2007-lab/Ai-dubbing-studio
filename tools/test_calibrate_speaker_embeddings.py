import unittest

from calibrate_speaker_embeddings import calibrate


class CalibrationTests(unittest.TestCase):
    def test_separated_speakers(self):
        rows = [
            {"speaker_id": "a", "embedding": [1, 0]},
            {"speaker_id": "a", "embedding": [0.99, 0.1]},
            {"speaker_id": "b", "embedding": [0, 1]},
            {"speaker_id": "b", "embedding": [0.1, 0.99]},
        ]
        result = calibrate(rows)
        self.assertEqual(result["embedding_dimension"], 2)
        self.assertEqual(result["false_accept_pairs"], 0)
        self.assertEqual(result["false_reject_pairs"], 0)
        self.assertLess(result["candidate_match_threshold"], result["candidate_new_speaker_threshold"])

    def test_rejects_mismatched_dimensions(self):
        with self.assertRaisesRegex(ValueError, "dimensions"):
            calibrate([
                {"speaker_id": "a", "embedding": [1, 0]},
                {"speaker_id": "a", "embedding": [1, 0, 0]},
                {"speaker_id": "b", "embedding": [0, 1]},
                {"speaker_id": "b", "embedding": [0, 1]},
            ])

    def test_rejects_uninformative_labels(self):
        with self.assertRaisesRegex(ValueError, "both"):
            calibrate([
                {"speaker_id": "a", "embedding": [1, 0]},
                {"speaker_id": "a", "embedding": [1, 0]},
                {"speaker_id": "a", "embedding": [1, 0]},
                {"speaker_id": "a", "embedding": [1, 0]},
            ])


if __name__ == "__main__":
    unittest.main()
