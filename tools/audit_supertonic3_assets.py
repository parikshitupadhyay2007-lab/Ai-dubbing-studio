"""Validate every pinned Supertonic model asset, on disk or inside an APK."""
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

PREFIX = "assets/flutter_assets/assets/models/supertonic3/"
CORE = {f"onnx/{n}.onnx" for n in (
    "duration_predictor", "text_encoder", "vector_estimator", "vocoder")}
CORE |= {"onnx/tts.json", "onnx/unicode_indexer.json", "LICENSE"}
CORE |= {f"voice_styles/{gender}{n}.json" for gender in "FM" for n in range(1, 6)}

def verify(read):
    manifest = json.loads(read("asset_manifest.json"))
    if manifest.get("engine") != "supertonic-3":
        raise ValueError("Invalid Supertonic engine ID")
    assets = manifest["assets"]
    if set(assets) != CORE:
        raise ValueError(f"Supertonic manifest mismatch: missing={CORE-set(assets)}, extra={set(assets)-CORE}")
    for name, spec in assets.items():
        payload = read(name)
        if len(payload) != spec["bytes"] or hashlib.sha256(payload).hexdigest() != spec["sha256"]:
            raise ValueError(f"Corrupt Supertonic asset: {name}")
    return len(assets)

def main():
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--directory", type=Path)
    group.add_argument("--apk", type=Path)
    args = parser.parse_args()
    if args.directory:
        root = args.directory.resolve()
        def read(name):
            file = (root / name).resolve()
            if not file.is_relative_to(root):
                raise ValueError("Escaping asset path")
            return file.read_bytes()
        count = verify(read)
    else:
        with ZipFile(args.apk) as archive:
            count = verify(lambda name: archive.read(PREFIX + name))
    print(f"Verified {count} Supertonic assets and SHA-256 digests")

if __name__ == "__main__":
    main()
