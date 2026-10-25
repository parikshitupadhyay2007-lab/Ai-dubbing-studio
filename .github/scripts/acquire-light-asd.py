#!/usr/bin/env python3
"""Acquire actual upstream Light-ASD pretrained weights; do not claim ONNX conversion."""
import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile

URL = "https://github.com/Junhua-Liao/Light-ASD.git"

def run(*args, cwd=None):
    return subprocess.check_output(args, cwd=cwd, text=True).strip()

def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--revision", required=True, help="Full upstream Git commit SHA")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if len(args.revision) != 40 or any(c not in "0123456789abcdefABCDEF" for c in args.revision):
        parser.error("Pass the exact 40-character upstream revision")
    output = pathlib.Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="light-asd-") as temporary:
        repo = pathlib.Path(temporary) / "upstream"
        run("git", "clone", "--quiet", "--filter=blob:none", URL, str(repo))
        run("git", "checkout", "--quiet", "--detach", args.revision, cwd=repo)
        if run("git", "rev-parse", "HEAD", cwd=repo).lower() != args.revision.lower():
            raise RuntimeError("Unexpected upstream revision")
        candidates = sorted((repo / "weight").glob("*.model"))
        if not candidates:
            raise RuntimeError("Upstream does not contain pretrained .model weights")
        results = []
        for source in candidates:
            if not source.is_file() or source.stat().st_size < 100000:
                raise RuntimeError(f"Missing/suspicious checkpoint: {source.name}")
            if source.open("rb").read(64).startswith(b"version https://git-lfs.github.com/spec/v1"):
                raise RuntimeError(f"Git LFS pointer instead of actual model: {source.name}")
            target = output / source.name
            shutil.copyfile(source, target)
            results.append({"filename": target.name, "size": target.stat().st_size, "sha256": sha256(target),
                            "format": "upstream-pytorch-checkpoint-not-android-onnx"})
        manifest = {"model": "Light-ASD", "upstream_url": URL,
                    "upstream_revision": args.revision.lower(), "checkpoints": results,
                    "status": "acquired; ONNX conversion and native inference NOT VERIFIED"}
        (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        print(json.dumps(manifest, indent=2))

if __name__ == "__main__":
    main()
