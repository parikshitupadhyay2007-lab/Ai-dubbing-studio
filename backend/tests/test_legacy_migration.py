import json
import tempfile
import unittest
from pathlib import Path
from departmental_pipeline import HandoffError, DEPARTMENTS
from legacy_migration import migration_probe, LegacyProducer, EvidenceReviewer

class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.d=Path(self.tmp.name)
        (self.d/"source.mp4").write_bytes(b"media")
        (self.d/"audio.wav").write_bytes(b"audio")
        (self.d/"project.json").write_text(json.dumps({
            "id":"job1","source":"source.mp4","source_language":"ja",
            "segments":[{"id":0,"start":0,"end":1,"text":"hello",
                         "speaker":"Character 1","translation":"नमस्ते"}],
            "target_language":"hi"}),encoding="utf-8")
    def tearDown(self):self.tmp.cleanup()
    def test_real_project_intake_producer(self):
        a=LegacyProducer(self.d,0).produce({"job_id":"job1"})
        self.assertTrue(a.verify_integrity())
        self.assertEqual(a.department,DEPARTMENTS[0])
    def test_real_project_review_fails_without_checkpoint_plan(self):
        a=LegacyProducer(self.d,0).produce({"job_id":"job1"})
        r=EvidenceReviewer(0).evaluate(a,{"job_id":"job1"})
        self.assertFalse(r.approved)
        self.assertFalse(r.checks["checkpoint_plan"])
    def test_migration_probe_does_not_fabricate_completion(self):
        controller=migration_probe(self.d,"job1")
        with self.assertRaises(HandoffError):controller.run({"job_id":"job1","target_language":"hi"})
        self.assertEqual(controller.pipeline.index,0)
        self.assertEqual(controller.audit[-1]["result"],"rejected")
    def test_script_speaker_not_assumed_verified(self):
        a=LegacyProducer(self.d,2).produce({"job_id":"job1"})
        r=EvidenceReviewer(2).evaluate(a,{"job_id":"job1"})
        self.assertFalse(r.checks["speaker_evidence"])
        self.assertFalse(r.approved)
    def test_translation_not_auto_approved(self):
        a=LegacyProducer(self.d,3).produce({"job_id":"job1","target_language":"hi"})
        r=EvidenceReviewer(3).evaluate(a,{"job_id":"job1"})
        self.assertFalse(r.checks["semantic_fidelity"])
        self.assertFalse(r.approved)
    def test_wrong_job_blocked(self):
        with self.assertRaises(HandoffError):
            LegacyProducer(self.d,0).produce({"job_id":"wrong"})

if __name__=="__main__":unittest.main()
