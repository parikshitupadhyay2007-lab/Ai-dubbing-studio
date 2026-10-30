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
            "specialist_models": {role: {
                "sha256": "b" * 64, "rights_receipt": "fixture-original",
                "preprocessing_id": "fixture-preprocessing",
                "execution_receipt": "fixture-android-execution",
                "independent_review_receipt": "fixture-review",
                "actual_android_execution": True, "review": "passed",
            } for role in (
                "visual_embedding", "character_detector", "character_reidentification",
                "active_speaker", "emotion_performance", "narrative_context",
            )},
            "scene_bible": {"source_sha256": sha, "fingerprint_sha256": "d" * 64,
                "approved": True, "independent_review": "passed"},
            "held_out_benchmark": {"source_sha256": sha,
                "independent_review": "passed", "leakage_check": "passed",
                "thresholds_pre_registered": True, "professional_result": "passed"},
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

    def test_missing_specialist_execution_rejects(self):
        self.data["specialist_models"]["active_speaker"]["actual_android_execution"] = False
        self.assertFalse(review(self.data)["department02_unlocked"])

    def test_missing_scene_bible_or_heldout_benchmark_rejects(self):
        self.data["scene_bible"]["approved"] = False
        self.assertFalse(review(self.data)["passed"])
        self.data["scene_bible"]["approved"] = True
        self.data["held_out_benchmark"]["leakage_check"] = "pending"
        self.assertFalse(review(self.data)["passed"])

    def test_stale_source_rejects(self):
        self.data["device"]["source_sha256"] = "d" * 64
        self.assertFalse(review(self.data)["passed"])


if __name__ == "__main__":
    unittest.main()
