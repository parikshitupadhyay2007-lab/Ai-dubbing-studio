import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from departmental_pipeline import HandoffError
from intake_department import digest_file
from otakumind_scene_evidence import sample_scene_frames
from otakumind_vision_adapter import analyze_frames, verify_observations

MODEL="a"*64
class FakeModel:
    engine_id="fixture-model"
    model_digest=MODEL
    def describe_frame(self,path):
        return {"description":"A scene with two figures","identity":None}

class VisionTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.d=Path(self.tmp.name)
        (self.d/"source.mp4").write_bytes(b"fixture")
        self.intake={"media":{"source":{"name":"source.mp4",
            "sha256":digest_file(self.d/"source.mp4")},"duration_seconds":1.0}}
        def fake(args,**kwargs):Path(args[-1]).write_bytes(b"frame fixture")
        with patch("otakumind_scene_evidence.subprocess.run",side_effect=fake):
            sample_scene_frames(self.d,self.intake)
    def tearDown(self):self.tmp.cleanup()
    def test_frame_grounded_record(self):
        record=analyze_frames(self.d,self.intake,FakeModel())
        self.assertEqual(verify_observations(self.d,self.intake,MODEL),record)
        self.assertEqual(record["semantic_review"],"PENDING")
    def test_model_mismatch_rejected(self):
        analyze_frames(self.d,self.intake,FakeModel())
        with self.assertRaises(HandoffError):
            verify_observations(self.d,self.intake,"b"*64)
    def test_identity_claim_rejected(self):
        class Bad(FakeModel):
            def describe_frame(self,path):return {"description":"scene","identity":"Character X"}
        with self.assertRaises(HandoffError):analyze_frames(self.d,self.intake,Bad())
    def test_empty_description_rejected(self):
        class Bad(FakeModel):
            def describe_frame(self,path):return {"description":" "}
        with self.assertRaises(HandoffError):analyze_frames(self.d,self.intake,Bad())
    def test_changed_frame_rejected(self):
        analyze_frames(self.d,self.intake,FakeModel())
        (self.d/"otakumind-frames"/"frame-0000.jpg").write_bytes(b"changed")
        with self.assertRaises(HandoffError):verify_observations(self.d,self.intake,MODEL)

if __name__=="__main__":unittest.main()
