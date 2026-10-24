"""Regression tests for the bilingual human-review release gate."""
import json
import tempfile
import unittest
from pathlib import Path

from evaluate_translation import evaluate


def row(**changes):
    item = dict(id="s1", source="source dialogue", reference="reviewed translation",
                candidate="candidate dialogue", reviewer="bilingual-1",
                meaning=4, names=4, tone=3, naturalness=3)
    item.update(changes)
    return item


class TranslationEvaluationTests(unittest.TestCase):
    def run_review(self, rows):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "reviews.jsonl"
            path.write_text("".join(json.dumps(value) + "\n" for value in rows),
                            encoding="utf-8")
            return evaluate(path)

    def test_release_rates_are_derived_from_human_scores(self):
        report = self.run_review([row(), row(id="s2", meaning=2, names=4)])
        self.assertEqual(report["meaning_pass_rate"], 0.5)
        self.assertEqual(report["name_pass_rate"], 1.0)
        self.assertEqual(report["critical_failures"][0]["id"], "s2")

    def test_valid_review(self):
        report = self.run_review([row()])
        self.assertEqual(report["reviewed_segments"], 1)
        self.assertFalse(report["critical_failures"])

    def test_critical_meaning_failure(self):
        report = self.run_review([row(meaning=2)])
        self.assertEqual(report["critical_failures"][0]["failed_dimensions"], ["meaning"])

    def test_critical_name_failure(self):
        report = self.run_review([row(names=1)])
        self.assertEqual(report["critical_failures"][0]["failed_dimensions"], ["names"])

    def test_duplicate_segment_rejected(self):
        with self.assertRaisesRegex(ValueError, "duplicate id"):
            self.run_review([row(), row()])

    def test_boolean_score_rejected(self):
        with self.assertRaisesRegex(ValueError, "must be integer"):
            self.run_review([row(meaning=True)])

    def test_unreviewed_data_rejected(self):
        with self.assertRaisesRegex(ValueError, "missing reviewer"):
            self.run_review([row(reviewer="")])


if __name__ == "__main__":
    unittest.main()
