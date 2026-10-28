import json
import tempfile
import unittest
from pathlib import Path
from department_adapters import LegacyBackendAdapters
from departmental_pipeline import HandoffError

class LegacyAdapterTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.d=Path(self.tmp.name)
        (self.d/"source.mp4").write_bytes(b"media")
        (self.d/"audio.wav").write_bytes(b"audio")
        self.data={"id":"job1","source":"source.mp4","source_language":"ja","segments":[
            {"id":0,"start":0.0,"end":1.0,"text":"hello","speaker":"Character 1","translation":"नमस्ते"}],
            "target_language":"hi"}
        self.save()
    def tearDown(self): self.tmp.cleanup()
    def save(self): (self.d/"project.json").write_text(json.dumps(self.data))
    def test_real_artifacts(self):
        a=LegacyBackendAdapters(self.d)
        self.assertEqual(a.intake().department,"00 Production Office")
        self.assertEqual(a.original_script().department,"02 Original Script")
        self.assertEqual(a.translated_candidates("hi").evidence["semantic_review"],"NOT PERFORMED")
    def test_missing_audio_fails(self):
        (self.d/"audio.wav").unlink()
        with self.assertRaises(HandoffError):LegacyBackendAdapters(self.d)
    def test_invalid_timing_fails(self):
        self.data["segments"][0]["end"]=-1
        self.save()
        with self.assertRaises(HandoffError):LegacyBackendAdapters(self.d).original_script()
    def test_missing_translation_fails(self):
        self.data["segments"][0]["translation"]=""
        self.save()
        with self.assertRaises(HandoffError):LegacyBackendAdapters(self.d).translated_candidates("hi")
    def test_unsupported_fails_closed(self):
        with self.assertRaises(HandoffError):LegacyBackendAdapters(self.d).unsupported(6)

if __name__=="__main__":unittest.main()
