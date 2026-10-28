import json
import tempfile
import unittest
import wave
from pathlib import Path
from unittest.mock import patch
from departmental_pipeline import HandoffError, Pipeline
from intake_department import IntakeProducer, IntakeReviewer, media_evidence
from legacy_migration import migration_probe

class IntakeTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.d=Path(self.tmp.name)
        (self.d/"source.mp4").write_bytes(b"fixture-not-real-video")
        with wave.open(str(self.d/"audio.wav"),"wb") as w:
            w.setnchannels(1);w.setsampwidth(2);w.setframerate(8000)
            w.writeframes(b"\0\0"*8000)
        (self.d/"project.json").write_text(json.dumps({"id":"job","source":"source.mp4","segments":[]}))
        self.probe=patch("intake_department.probe",return_value=1.0)
        self.probe.start()
    def tearDown(self):
        self.probe.stop();self.tmp.cleanup()
    def test_verified_intake_can_advance_to_department_one(self):
        c=migration_probe(self.d,"job",verified_intake=True)
        with self.assertRaises(HandoffError):c.run({"job_id":"job"})
        self.assertEqual(c.pipeline.index,1)
        self.assertEqual(c.audit[0]["result"],"accepted")
    def test_independent_reviewer_detects_media_change(self):
        a=IntakeProducer(self.d).produce({"job_id":"job"})
        (self.d/"source.mp4").write_bytes(b"changed")
        self.assertFalse(IntakeReviewer(self.d).evaluate(a,{"job_id":"job"}).approved)
    def test_independent_reviewer_detects_checkpoint_change(self):
        a=IntakeProducer(self.d).produce({"job_id":"job"})
        p=self.d/"department00-checkpoint.json"
        data=json.loads(p.read_text());data["next_department"]="wrong"
        p.write_text(json.dumps(data))
        self.assertFalse(IntakeReviewer(self.d).evaluate(a,{"job_id":"job"}).approved)
    def test_invalid_source_name_rejected(self):
        (self.d/"project.json").write_text(json.dumps({"id":"job","source":"../source.mp4","segments":[]}))
        with self.assertRaises(HandoffError):IntakeProducer(self.d).produce({"job_id":"job"})
    def test_bad_duration_rejected(self):
        with patch("intake_department.probe",return_value=5.0):
            with self.assertRaises(HandoffError):IntakeProducer(self.d).produce({"job_id":"job"})
    def test_missing_audio_rejected(self):
        (self.d/"audio.wav").unlink()
        with self.assertRaises(HandoffError):IntakeProducer(self.d).produce({"job_id":"job"})
    def test_wrong_job_rejected(self):
        with self.assertRaises(HandoffError):IntakeProducer(self.d).produce({"job_id":"wrong"})

if __name__=="__main__":unittest.main()
