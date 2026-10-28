import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from departmental_pipeline import HandoffError
from otakumind_scene_evidence import sample_scene_frames, verify_scene_frames
from intake_department import digest_file

class FrameEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.d=Path(self.tmp.name)
        (self.d/"source.mp4").write_bytes(b"media fixture")
        self.intake={"media":{"source":{"name":"source.mp4",
            "sha256":digest_file(self.d/"source.mp4")},"duration_seconds":10.0}}
    def tearDown(self):self.tmp.cleanup()
    def fake_ffmpeg(self,args,**kwargs):
        Path(args[-1]).write_bytes(b"JPEG fixture "+args[6].encode())
    def sample(self):
        with patch("otakumind_scene_evidence.subprocess.run",side_effect=self.fake_ffmpeg):
            return sample_scene_frames(self.d,self.intake,interval=5)
    def test_manifest_and_independent_hash_validation(self):
        m=self.sample()
        self.assertEqual(len(m["frames"]),2)
        self.assertEqual(verify_scene_frames(self.d,self.intake),m)
        self.assertEqual(m["semantic_analysis"],"NOT PERFORMED")
    def test_changed_frame_rejected(self):
        self.sample()
        (self.d/"otakumind-frames"/"frame-0000.jpg").write_bytes(b"tampered")
        with self.assertRaises(HandoffError):verify_scene_frames(self.d,self.intake)
    def test_changed_source_rejected(self):
        (self.d/"source.mp4").write_bytes(b"changed")
        with self.assertRaises(HandoffError):self.sample()
    def test_unsafe_source_rejected(self):
        self.intake["media"]["source"]["name"]="../source.mp4"
        with self.assertRaises(HandoffError):self.sample()
    def test_bad_interval_rejected(self):
        with self.assertRaises(HandoffError):
            sample_scene_frames(self.d,self.intake,interval=0)
    def test_missing_frame_rejected(self):
        self.sample()
        (self.d/"otakumind-frames"/"frame-0000.jpg").unlink()
        with self.assertRaises(HandoffError):verify_scene_frames(self.d,self.intake)

if __name__=="__main__":unittest.main()
