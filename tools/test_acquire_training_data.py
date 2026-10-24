import json
import tempfile
import unittest
from pathlib import Path
from acquire_training_data import load_registry, acquire

class AcquisitionContractTests(unittest.TestCase):
    def test_registry_unique_and_all_engines_covered(self):
        rows=load_registry(Path("datasets/acquisition_registry.json"))
        self.assertTrue({"whisper","ecapa","qwen3","supertonic","mdx"}.issubset(
            {row["engine"] for row in rows.values()}))
    def test_nonpublic_sources_cannot_download(self):
        with tempfile.TemporaryDirectory() as root:
            for status in ("manual_review","account_required","permission_review",
                           "original_or_licensed_only","consent_required"):
                with self.assertRaises(ValueError):
                    acquire({"status":status,"url":"https://example.com/file",
                             "id":"x"},Path(root),True)
    def test_explicit_ack_required(self):
        rows=load_registry(Path("datasets/acquisition_registry.json"))
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaises(ValueError):
                acquire(rows["librispeech-dev-clean"],Path(root),False)
if __name__=="__main__": unittest.main()
