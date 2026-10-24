import ast
import unittest
from pathlib import Path

SOURCE = Path(__file__).with_name("prepare_supertonic3_assets.py")
tree = ast.parse(SOURCE.read_text(encoding="utf-8"))
values = {}
for statement in tree.body:
    if isinstance(statement, ast.Assign) and len(statement.targets) == 1:
        if isinstance(statement.targets[0], ast.Name) and statement.targets[0].id in {"REVISION", "SIZES"}:
            values[statement.targets[0].id] = ast.literal_eval(statement.value)

class TestSupertonicAssetSpecification(unittest.TestCase):
    def test_pinned_revision(self):
        self.assertEqual(len(values["REVISION"]), 40)
    def test_four_required_onnx_stages(self):
        files = values["SIZES"]
        self.assertEqual(sum(name.endswith(".onnx") for name in files), 4)
        for name in ("duration_predictor", "text_encoder", "vector_estimator", "vocoder"):
            self.assertGreater(files[f"onnx/{name}.onnx"], 1000000)
    def test_language_resources_and_ten_preset_styles(self):
        files = values["SIZES"]
        self.assertIn("onnx/unicode_indexer.json", files)
        self.assertIn("onnx/tts.json", files)
        self.assertEqual(sum(name.startswith("voice_styles/") for name in files), 10)

if __name__ == "__main__":
    unittest.main()
