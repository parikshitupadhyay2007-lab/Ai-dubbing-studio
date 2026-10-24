"""Regression tests for the bilingual human-review release gate."""
import json
import subprocess
import sys
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

    def run_release_gate(self, rows):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "reviews.jsonl"
            path.write_text("".join(json.dumps(value) + "\n" for value in rows),
                            encoding="utf-8")
            return subprocess.run(
                [sys.executable, str(Path(__file__).with_name("evaluate_translation.py")),
                 str(path), "--production-gate"], capture_output=True, text=True)

    def test_gate_rejects_insufficient_review_count(self):
        result = self.run_release_gate([row(id=f"s{i}") for i in range(199)])
        self.assertEqual(result.returncode, 2)
        self.assertIn("Production translation acceptance gate failed", result.stderr)

    def test_gate_accepts_200_clean_human_reviews(self):
        result = self.run_release_gate([row(id=f"s{i}") for i in range(200)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["reviewed_segments"], 200)

    def test_gate_rejects_critical_meaning_error(self):
        result = self.run_release_gate([
            row(id=f"s{i}", meaning=2 if i == 10 else 4) for i in range(200)
        ])
        self.assertEqual(result.returncode, 2)

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
