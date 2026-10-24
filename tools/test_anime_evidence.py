import unittest
from build_anime_scene_catalog import validate
from evaluate_anime_scene_identification import evaluate
class AnimeEvidenceTests(unittest.TestCase):
    def doc(self):
        return {"schema":1,"license":"OWNED","source":"synthetic fixture",
          "evidence":"fixture created for test","scenes":[{
          "anime_id":"fixture","title":"Fixture","episode_id":"ep1",
          "start_seconds":40,"dialogue":["First invented line one","Second invented line two","Third invented line three"],
          "characters":[{"id":"role1","name":"Test character","role":"unknown"}]}]}
    def test_valid_data(self):
        self.assertEqual(len(validate(self.doc())),1)
    def test_reject_unlicensed(self):
        d=self.doc();d["license"]="unspecified"
        with self.assertRaises(ValueError):validate(d)
    def test_reject_unlabeled_character(self):
        d=self.doc();d["scenes"][0]["characters"][0].pop("role")
        with self.assertRaises(ValueError):validate(d)
    def test_scene_evaluation_does_not_claim_accuracy_when_abstaining(self):
        rows=self.doc()["scenes"]
        report=evaluate(rows,[])
        self.assertEqual(report["coverage"],0)
        self.assertEqual(report["abstained"],1)
    def test_scene_evaluation_on_exact_licensed_fixture(self):
        rows=self.doc()["scenes"]
        report=evaluate(rows,rows)
        self.assertEqual(report["correct"],1)
        self.assertEqual(report["wrong"],0)
if __name__=="__main__":unittest.main()
