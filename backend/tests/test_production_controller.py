import unittest
from departmental_pipeline import Artifact, Review, Pipeline, DEPARTMENTS, REQUIRED_CHECKS, HandoffError
from production_controller import Assignment, ProductionController

class Producer:
    def __init__(self, index, fail=False):
        self.engine_id=f"producer-{index}"
        self.index=index
        self.fail=fail
        self.calls=0
    def produce(self, context):
        self.calls+=1
        if self.fail: raise RuntimeError("model unavailable")
        return Artifact.build(context["job_id"],DEPARTMENTS[self.index],
                              {"segment_count":self.index+1},{"actual_evidence":"fixture"},{})

class Evaluator:
    def __init__(self,index,reject=False):
        self.engine_id=f"evaluator-{index}"
        self.index=index
        self.reject=reject
    def evaluate(self, artifact, context):
        reviewer=DEPARTMENTS[self.index+1] if self.index+1<len(DEPARTMENTS) else "external acceptance"
        return Review(reviewer,artifact.content_digest,
                      dict.fromkeys(REQUIRED_CHECKS[self.index],not self.reject),
                      ("failed fixture",) if self.reject else ())

def assignments(reject_at=None, fail_at=None, attempts=2):
    return {name:Assignment(Producer(i, fail=i==fail_at),Evaluator(i,reject=i==reject_at),attempts)
            for i,name in enumerate(DEPARTMENTS)}

class ControllerTests(unittest.TestCase):
    def test_complete_fixture_chain(self):
        c=ProductionController(Pipeline("job"),assignments())
        self.assertTrue(c.run({"job_id":"job"}).completed())
        self.assertEqual(len(c.audit),11)
    def test_rejection_stops_next_department(self):
        items=assignments(reject_at=3)
        c=ProductionController(Pipeline("job"),items)
        with self.assertRaises(HandoffError):c.run({"job_id":"job"})
        self.assertEqual(c.pipeline.index,3)
        self.assertEqual(items[DEPARTMENTS[4]].producer.calls,0)
        self.assertEqual(items[DEPARTMENTS[3]].producer.calls,2)
    def test_model_failure_exhausts_budget(self):
        items=assignments(fail_at=0)
        c=ProductionController(Pipeline("job"),items)
        with self.assertRaises(HandoffError):c.run({"job_id":"job"})
        self.assertEqual(c.pipeline.index,0)
        self.assertEqual(items[DEPARTMENTS[0]].producer.calls,2)
    def test_self_review_forbidden(self):
        p=Producer(0)
        p.engine_id="same"
        e=Evaluator(0)
        e.engine_id="same"
        with self.assertRaises(HandoffError):Assignment(p,e)
    def test_missing_assignment_forbidden(self):
        with self.assertRaises(HandoffError):ProductionController(Pipeline("job"),{})
    def test_wrong_job_forbidden(self):
        c=ProductionController(Pipeline("job"),assignments())
        with self.assertRaises(HandoffError):c.run({"job_id":"another"})
    def test_unvalidated_resume_forbidden(self):
        p=Pipeline("job",index=1)
        c=ProductionController(p,assignments())
        with self.assertRaises(HandoffError):c.run({"job_id":"job"})

if __name__=="__main__":unittest.main()
