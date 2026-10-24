import json
import tempfile
import unittest
from pathlib import Path
from evaluate_speaker_diarization import evaluate


class SpeakerEvaluationTests(unittest.TestCase):
    def report(self, rows):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "annotations.jsonl"
            path.write_text("".join(json.dumps(r) + "\n" for r in rows), encoding="utf-8")
            return evaluate(path)

    def test_permuted_cluster_labels_are_not_errors(self):
        rows = [
            dict(id="s:1", reference_speaker="a", predicted_speaker="cluster_2", overlap=False),
            dict(id="s:2", reference_speaker="b", predicted_speaker="cluster_1", overlap=False),
        ]
        self.assertEqual(self.report(rows)["conservative_accuracy"], 1.0)

    def test_unknown_is_not_counted_as_correct(self):
        rows = [
            dict(id="s:1", reference_speaker="a", predicted_speaker="cluster_1", overlap=False),
            dict(id="s:2", reference_speaker="a", predicted_speaker="unknown", overlap=False),
        ]
        self.assertEqual(self.report(rows)["conservative_accuracy"], 0.5)
        self.assertEqual(self.report(rows)["unresolved"], 1)

    def test_cluster_collision_does_not_count_as_two_characters(self):
        rows = [
            dict(id="s:1", reference_speaker="a", predicted_speaker="cluster_1", overlap=False),
            dict(id="s:2", reference_speaker="b", predicted_speaker="cluster_1", overlap=False),
        ]
        self.assertEqual(self.report(rows)["conservative_accuracy"], 0.5)

    def test_overlap_not_credited_as_correct(self):
        rows = [
            dict(id="s:1", reference_speaker="a", predicted_speaker="cluster_1", overlap=False),
            dict(id="s:2", reference_speaker="a", predicted_speaker="cluster_1", overlap=True),
        ]
        self.assertEqual(self.report(rows)["conservative_accuracy"], 0.5)

    def test_duplicate_id_rejected(self):
        item = dict(id="s:1", reference_speaker="a", predicted_speaker="c", overlap=False)
        with self.assertRaisesRegex(ValueError, "duplicate id"):
            self.report([item, item])


if __name__ == "__main__":
    unittest.main()
