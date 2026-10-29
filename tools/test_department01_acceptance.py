import unittest
from department01_acceptance import review, CAPABILITIES


class AcceptanceTests(unittest.TestCase):
    def setUp(self):
        sha = "a" * 64
        self.data = {
            "schema": "otakudub_department01_acceptance_v1",
            "source_sha256": sha,
            "reference": {"source_sha256": sha, "rights_review": "cleared",
                "rights_receipt": "original fixture signed receipt",
                "annotation_status": "independently_reviewed", "annotator_receipt": "reviewer-1"},
            "capabilities": {name: {"state": "verified", "model_sha256": "b" * 64,
                "independent_review": "passed", "evidence_ids": ["e1"], "metric": 0.9,
                "benchmark_run_source_sha256": sha} for name in CAPABILITIES},
            "device": {"platform": "android", "result": "passed",
                "device_fingerprint": "physical-android-build-id", "apk_sha256": "c" * 64,
                "instrumentation_receipt": "device-run-log", "source_sha256": sha,
                "simulated": False},
        }

    def test_complete_receipts_structurally_pass(self):
        self.assertTrue(review(self.data)["passed"])

    def test_missing_engine_rejects(self):
        del self.data["capabilities"]["audiovisual_dialogue_attribution"]
        self.assertFalse(review(self.data)["department02_unlocked"])

    def test_uncleared_rights_rejects(self):
        self.data["reference"]["rights_review"] = "pending"
        self.assertFalse(review(self.data)["passed"])

    def test_unmeasured_metric_rejects(self):
        self.data["capabilities"]["scene_segmentation"]["metric"] = None
        self.assertFalse(review(self.data)["passed"])

    def test_simulation_rejects(self):
        self.data["device"]["simulated"] = True
        self.assertFalse(review(self.data)["passed"])

    def test_stale_source_rejects(self):
        self.data["device"]["source_sha256"] = "d" * 64
        self.assertFalse(review(self.data)["passed"])


if __name__ == "__main__":
    unittest.main()
