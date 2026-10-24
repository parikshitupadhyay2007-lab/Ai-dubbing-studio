#!/usr/bin/env python3
"""Fail-closed release qualification for an Android speaker embedding pack.

This checks evidence manifests, not model quality itself. Independent reviewers
must supply the held-out report and Android device results.
"""
import argparse
import hashlib
import json
from pathlib import Path

REQUIRED = ("model_sha256", "model_license", "redistribution_approved",
            "onnx_export_verified", "preprocessing_verified", "android_inference_verified",
            "held_out_speaker_count", "held_out_recording_count",
            "held_out_conservative_accuracy", "held_out_false_accept_rate",
            "match_threshold", "new_speaker_threshold", "evidence_paths")


def verify(manifest_path):
    manifest_path = Path(manifest_path).resolve()
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    missing = [key for key in REQUIRED if key not in data]
    if missing:
        raise ValueError("Missing release evidence: " + ", ".join(missing))
    if any(data[key] is not True for key in
           ("redistribution_approved", "onnx_export_verified",
            "preprocessing_verified", "android_inference_verified")):
        raise ValueError("Unverified model conversion, license or Android inference")
    if not isinstance(data["model_license"], str) or not data["model_license"].strip():
        raise ValueError("Missing license provenance")
    if type(data["held_out_speaker_count"]) is not int or data["held_out_speaker_count"] < 20:
        raise ValueError("Insufficient held-out speakers")
    if type(data["held_out_recording_count"]) is not int or data["held_out_recording_count"] < 200:
        raise ValueError("Insufficient held-out recordings")
    if not 0.98 <= data["held_out_conservative_accuracy"] <= 1:
        raise ValueError("Speaker accuracy gate failed")
    if not 0 <= data["held_out_false_accept_rate"] <= 0.01:
        raise ValueError("Speaker false acceptance gate failed")
    if not 0 < data["match_threshold"] < data["new_speaker_threshold"] <= 2:
        raise ValueError("Invalid calibrated thresholds")
    model = (manifest_path.parent / data.get("model_path", "")).resolve()
    if not model.is_file() or not model.is_relative_to(manifest_path.parent):
        raise ValueError("Missing model artifact")
    digest = hashlib.sha256(model.read_bytes()).hexdigest()
    if digest != data["model_sha256"]:
        raise ValueError("Model checksum mismatch")
    paths = data["evidence_paths"]
    if not isinstance(paths, list) or len(paths) < 3 or any(
        not isinstance(p, str) or not p or
        not (manifest_path.parent / p).resolve().is_relative_to(manifest_path.parent) or
        not (manifest_path.parent / p).resolve().is_file() for p in paths
    ):
        raise ValueError("Missing independent evaluation, license or device evidence")
    return {"qualified_manifest": str(manifest_path), "model_sha256": digest}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest")
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.manifest), indent=2))
    except (ValueError, OSError, TypeError, KeyError) as error:
        parser.error(str(error))
