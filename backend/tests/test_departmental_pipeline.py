import unittest
from departmental_pipeline import Artifact, Review, Pipeline, DEPARTMENTS, REQUIRED_CHECKS, HandoffError

class Gates(unittest.TestCase):
    def test_cannot_skip_department(self):
        p=Pipeline("job")
        a=Artifact.build("job", DEPARTMENTS[1], {"data": 1}, {"proof": 1}, {})
        r=Review(DEPARTMENTS[2],a.content_digest,dict.fromkeys(REQUIRED_CHECKS[1],True))
        with self.assertRaises(HandoffError): p.submit_and_review(a,r)
    def test_rejected_work_cannot_advance(self):
        p=Pipeline("job")
        a=Artifact.build("job",DEPARTMENTS[0],{"data": 1},{"proof": 1},{})
        r=Review(DEPARTMENTS[1],a.content_digest,dict.fromkeys(REQUIRED_CHECKS[0],False))
        with self.assertRaises(HandoffError): p.submit_and_review(a,r)
        self.assertEqual(p.index,0)
    def test_full_gate_chain(self):
        p=Pipeline("job")
        for i,d in enumerate(DEPARTMENTS):
            a=Artifact.build("job",d,{"output":i},{"evidence":"verified"},{})
            reviewer=DEPARTMENTS[i+1] if i+1<len(DEPARTMENTS) else "external acceptance"
            r=Review(reviewer,a.content_digest,dict.fromkeys(REQUIRED_CHECKS[i],True))
            p.submit_and_review(a,r)
        self.assertTrue(p.completed())
    def test_stale_review_rejected(self):
        p=Pipeline("job")
        a=Artifact.build("job",DEPARTMENTS[0],{"data":1},{"proof":1},{})
        r=Review(DEPARTMENTS[1],"old",dict.fromkeys(REQUIRED_CHECKS[0],True))
        with self.assertRaises(HandoffError):p.submit_and_review(a,r)

if __name__ == "__main__": unittest.main()
