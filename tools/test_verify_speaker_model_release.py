import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from verify_speaker_model_release import verify


class ReleaseQualificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "speaker.onnx").write_bytes(b"test fixture, not a real model")
        for name in ("license.txt", "evaluation.json", "android-test.json"):
            (self.root / name).write_text("fixture", encoding="utf-8")
        self.data = dict(
            model_path="speaker.onnx",
            model_sha256=hashlib.sha256((self.root / "speaker.onnx").read_bytes()).hexdigest(),
            model_license="Apache-2.0", redistribution_approved=True,
            onnx_export_verified=True, preprocessing_verified=True,
            android_inference_verified=True, held_out_speaker_count=20,
            held_out_recording_count=200, held_out_conservative_accuracy=0.99,
            held_out_false_accept_rate=0.005, match_threshold=0.2,
            new_speaker_threshold=0.4,
            evidence_paths=["license.txt", "evaluation.json", "android-test.json"])

    def check(self):
        path = self.root / "manifest.json"
        path.write_text(json.dumps(self.data), encoding="utf-8")
        return verify(path)

    def test_complete_evidence_manifest(self):
        self.assertEqual(self.check()["model_sha256"], self.data["model_sha256"])

    def test_unverified_android_model_rejected(self):
        self.data["android_inference_verified"] = False
        with self.assertRaisesRegex(ValueError, "Unverified"):
            self.check()

    def test_checksum_mismatch_rejected(self):
        self.data["model_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "checksum"):
            self.check()

    def test_low_accuracy_rejected(self):
        self.data["held_out_conservative_accuracy"] = 0.90
        with self.assertRaisesRegex(ValueError, "accuracy"):
            self.check()

    def test_missing_evidence_rejected(self):
        (self.root / "android-test.json").unlink()
        with self.assertRaisesRegex(ValueError, "evidence"):
            self.check()


if __name__ == "__main__":
    unittest.main()
