"""Prepare a pinned, verified Supertonic 3 ONNX asset pack. No runtime inference claim."""
import hashlib
import json
import shutil
from pathlib import Path
from huggingface_hub import hf_hub_download

REPO = "Supertone/supertonic-3"
REVISION = "3cadd1ee6394adea1bd021217a0e650ede09a323"
SIZES = {
    "onnx/duration_predictor.onnx": 3700147,
    "onnx/text_encoder.onnx": 36416150,
    "onnx/tts.json": 8253,
    "onnx/unicode_indexer.json": 277676,
    "onnx/vector_estimator.onnx": 256534781,
    "onnx/vocoder.onnx": 101424195,
    "voice_styles/F1.json": 292046,
    "voice_styles/F2.json": 292423,
    "voice_styles/F3.json": 290794,
    "voice_styles/F4.json": 291808,
    "voice_styles/F5.json": 291479,
    "voice_styles/M1.json": 291748,
    "voice_styles/M2.json": 292055,
    "voice_styles/M3.json": 290198,
    "voice_styles/M4.json": 291522,
    "voice_styles/M5.json": 291469,
}
def prepare(root: Path):
    root.mkdir(parents=True, exist_ok=True)
    assets = {}
    for name, expected in {**SIZES, "LICENSE": None}.items():
        downloaded = Path(hf_hub_download(repo_id=REPO, filename=name, revision=REVISION))
        if expected is not None and downloaded.stat().st_size != expected:
            raise RuntimeError(f"Supertonic asset size mismatch: {name}")
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(downloaded, target)
        digest = hashlib.sha256()
        with target.open("rb") as f:
            for block in iter(lambda: f.read(1024 * 1024), b""):
                digest.update(block)
        assets[name] = {"bytes": target.stat().st_size, "sha256": digest.hexdigest()}
    for name in ("onnx/tts.json", "onnx/unicode_indexer.json", *[f"voice_styles/{s}{n}.json" for s in "FM" for n in range(1, 6)]):
        json.loads((root / name).read_text(encoding="utf-8"))
    (root / "asset_manifest.json").write_text(json.dumps({
        "source": REPO, "revision": REVISION, "license": "OpenRAIL-M",
        "engine": "supertonic-3", "runtime_status": "assets_only",
        "assets": assets
    }, indent=2) + "\n", encoding="utf-8")
if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("android/assets/models/supertonic3"))
    prepare(parser.parse_args().output)
