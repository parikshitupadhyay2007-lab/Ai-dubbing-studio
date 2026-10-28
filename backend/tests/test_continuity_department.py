import json
import tempfile
import unittest
from pathlib import Path
from departmental_pipeline import Artifact, DEPARTMENTS, HandoffError
from continuity_department import ContinuityProducer, ContinuityReviewer, load_continuity

class ContinuityTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.d=Path(self.tmp.name)
        self.intake=Artifact.build("job",DEPARTMENTS[0],
            {"job_id":"job","media":{"duration_seconds":10}},{"verified":True},{})
        self.data={"schema_version":1,"job_id":"job",
            "rights":{"basis":"user_supplied","attestation":"I supplied this reference"},
            "scenes":[{"id":"s1","start":0,"end":5,"observation":"A character enters"},
                      {"id":"s2","start":5,"end":10,"observation":"The scene changes"}]}
        self.save()
    def tearDown(self):self.tmp.cleanup()
    def save(self):(self.d/"continuity-input.json").write_text(json.dumps(self.data),encoding="utf-8")
    def context(self):return {"job_id":"job","previous_artifact":self.intake}
    def test_produces_provenance_bound_artifact(self):
        a=ContinuityProducer(self.d).produce(self.context())
        self.assertTrue(a.verify_integrity())
        self.assertEqual(a.payload["intake_digest"],self.intake.content_digest)
    def test_unverified_scene_and_rights_block_approval(self):
        a=ContinuityProducer(self.d).produce(self.context())
        r=ContinuityReviewer(self.d).evaluate(a,self.context())
        self.assertTrue(r.checks["reference_provenance"])
        self.assertFalse(r.checks["continuity"])
        self.assertFalse(r.checks["rights_constraints"])
        self.assertFalse(r.approved)
    def test_changed_reference_breaks_provenance(self):
        a=ContinuityProducer(self.d).produce(self.context())
        self.data["scenes"][0]["observation"]="Changed";self.save()
        self.assertFalse(ContinuityReviewer(self.d).evaluate(a,self.context()).approved)
    def test_overlap_rejected(self):
        self.data["scenes"][1]["start"]=4;self.save()
        with self.assertRaises(HandoffError):ContinuityProducer(self.d).produce(self.context())
    def test_out_of_bounds_rejected(self):
        self.data["scenes"][1]["end"]=11;self.save()
        with self.assertRaises(HandoffError):ContinuityProducer(self.d).produce(self.context())
    def test_rights_attestation_required(self):
        self.data["rights"]["attestation"]="";self.save()
        with self.assertRaises(HandoffError):ContinuityProducer(self.d).produce(self.context())
    def test_wrong_job_rejected(self):
        self.data["job_id"]="other";self.save()
        with self.assertRaises(HandoffError):ContinuityProducer(self.d).produce(self.context())
    def test_missing_intake_rejected(self):
        with self.assertRaises(HandoffError):ContinuityProducer(self.d).produce({"job_id":"job"})
    def test_duplicate_scene_rejected(self):
        self.data["scenes"][1]["id"]="s1";self.save()
        with self.assertRaises(HandoffError):ContinuityProducer(self.d).produce(self.context())

if __name__=="__main__":unittest.main()
