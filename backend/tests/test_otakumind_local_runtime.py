import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from departmental_pipeline import HandoffError
from intake_department import digest_file
from otakumind_local_runtime import SubprocessVisionEngine

class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.d=Path(self.tmp.name)
        for name in ("runtime","model.gguf","frame.jpg"):
            (self.d/name).write_bytes(name.encode())
        self.engine=SubprocessVisionEngine(self.d/"runtime",self.d/"model.gguf")
    def tearDown(self):self.tmp.cleanup()
    def response(self,**changes):
        result={"schema_version":1,"model_sha256":self.engine.model_digest,
                "image_sha256":digest_file(self.d/"frame.jpg"),
                "description":"Two visible figures","identity":None}
        result.update(changes)
        return type("Completed",(),{"stdout":json.dumps(result)})()
    def test_bound_inference_response(self):
        with patch("otakumind_local_runtime.subprocess.run",return_value=self.response()) as call:
            result=self.engine.describe_frame(self.d/"frame.jpg")
        self.assertEqual(result["description"],"Two visible figures")
        self.assertEqual(call.call_args.kwargs["timeout"],120)
        self.assertEqual(json.loads(call.call_args.kwargs["input"])["task"],
                         "describe_visible_scene_without_identity_guessing")
    def test_model_hash_mismatch(self):
        with patch("otakumind_local_runtime.subprocess.run",
                   return_value=self.response(model_sha256="0"*64)):
            with self.assertRaises(HandoffError):self.engine.describe_frame(self.d/"frame.jpg")
    def test_frame_hash_mismatch(self):
        with patch("otakumind_local_runtime.subprocess.run",
                   return_value=self.response(image_sha256="0"*64)):
            with self.assertRaises(HandoffError):self.engine.describe_frame(self.d/"frame.jpg")
    def test_identity_claim_rejected(self):
        with patch("otakumind_local_runtime.subprocess.run",
                   return_value=self.response(identity="Guessed character")):
            with self.assertRaises(HandoffError):self.engine.describe_frame(self.d/"frame.jpg")
    def test_missing_model_rejected(self):
        with self.assertRaises(FileNotFoundError):
            SubprocessVisionEngine(self.d/"runtime",self.d/"missing.gguf")
    def test_timeout_rejected(self):
        with self.assertRaises(HandoffError):
            SubprocessVisionEngine(self.d/"runtime",self.d/"model.gguf",timeout=0)

if __name__=="__main__":unittest.main()
