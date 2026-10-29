#!/usr/bin/env python3
"""Independently audit Department 01 benchmark and real Android evidence.

Receipts are evidence, not self-certification. No inference is performed here.
A claim cannot pass without its model receipt, independent annotation source,
real measurements, Android instrumentation and explicit legal clearance.
"""
import argparse
import json
import re
from pathlib import Path

SHA = re.compile(r"^[a-f0-9]{64}$")
CAPABILITIES = (
    "anime_recognition", "scene_segmentation", "visual_understanding",
    "character_recognition", "context_research", "continuity_intelligence",
    "narrative_intelligence", "emotion_performance_intelligence",
    "audiovisual_dialogue_attribution", "scene_timing_constraints",
    "character_relationship_memory",
)


def review(package):
    errors = []
    if package.get("schema") != "otakudub_department01_acceptance_v1":
        errors.append("Unsupported acceptance schema")
    source = package.get("source_sha256")
    if not isinstance(source, str) or not SHA.fullmatch(source):
        errors.append("Missing source fingerprint")
    reference = package.get("reference", {})
    if not isinstance(reference, dict) or reference.get("source_sha256") != source:
        errors.append("Reference source mismatch")
        reference = {}
    if reference.get("rights_review") != "cleared" or not reference.get("rights_receipt"):
        errors.append("Rights review not cleared")
    if reference.get("annotation_status") != "independently_reviewed" or not reference.get("annotator_receipt"):
        errors.append("Independent ground truth absent")
    results = package.get("capabilities", {})
    if not isinstance(results, dict) or set(results) != set(CAPABILITIES):
        errors.append("Missing or unexpected capability evidence")
        results = {}
    for name in CAPABILITIES:
        entry = results.get(name, {})
        if not isinstance(entry, dict) or entry.get("state") != "verified":
            errors.append(f"{name}: no verified real inference")
            continue
        if not isinstance(entry.get("model_sha256"), str) or not SHA.fullmatch(entry["model_sha256"]):
            errors.append(f"{name}: model checksum missing")
        if entry.get("independent_review") != "passed" or not entry.get("evidence_ids"):
            errors.append(f"{name}: independent review absent")
        if not isinstance(entry.get("metric"), (int, float)) or isinstance(entry.get("metric"), bool) or not (0 <= entry["metric"] <= 1):
            errors.append(f"{name}: actual metric missing")
        if entry.get("benchmark_run_source_sha256") != source:
            errors.append(f"{name}: benchmark source mismatch")
    device = package.get("device", {})
    if not isinstance(device, dict) or device.get("platform") != "android" or device.get("result") != "passed":
        errors.append("Real Android validation missing")
    else:
        if not device.get("device_fingerprint") or not device.get("apk_sha256") or not device.get("instrumentation_receipt"):
            errors.append("Android device/build/instrumentation evidence incomplete")
        if device.get("source_sha256") != source:
            errors.append("Android-tested source mismatch")
        if device.get("simulated") is not False:
            errors.append("Emulated or undeclared device evidence")
    return {"passed": not errors, "department02_unlocked": not errors, "errors": errors}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("acceptance", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    data = json.loads(args.acceptance.read_text())
    result = review(data)
    output = json.dumps(result, indent=2, sort_keys=True)
    if args.output:
        args.output.write_text(output + "\n")
    print(output)
    raise SystemExit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
