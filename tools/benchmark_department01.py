#!/usr/bin/env python3
"""Offline, source-bound Department 01 benchmark. Does not ingest or upload video.

Inputs are independently annotated, rights-cleared ground truth and actual
model predictions. Empty annotations or claims cannot produce a passing score.
"""
import argparse
import hashlib
import json
from pathlib import Path


def evaluate(reference, prediction, source_bytes=None):
    errors = []
    digest = reference.get("source_sha256")
    if not isinstance(digest, str) or len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
        errors.append("Invalid source SHA256")
    if source_bytes is not None and hashlib.sha256(source_bytes).hexdigest() != digest:
        errors.append("Source content differs from annotation SHA256")
    if prediction.get("source_sha256") != digest:
        errors.append("Prediction source mismatch")
    duration = reference.get("duration_ms")
    if not isinstance(duration, int) or duration <= 0 or prediction.get("duration_ms") != duration:
        errors.append("Invalid or mismatched duration")
    if reference.get("annotation_status") != "independently_reviewed":
        errors.append("Ground truth not independently reviewed")
    if not isinstance(reference.get("rights_receipt"), str) or not reference["rights_receipt"].strip():
        errors.append("Missing rights receipt")
    required = ("shots_ms", "utterances", "characters", "dramatic_scenes")
    for key in required:
        if not isinstance(reference.get(key), list) or not reference[key]:
            errors.append("Missing reference annotations: " + key)
        if not isinstance(prediction.get(key), list):
            errors.append("Missing model predictions: " + key)
    if errors:
        return {"passed": False, "errors": errors, "metrics": {}}
    shots = reference["shots_ms"]
    found = prediction["shots_ms"]
    if any(not isinstance(t, int) or t <= 0 or t >= duration for t in shots + found):
        return {"passed": False, "errors": ["Invalid shot timestamps"], "metrics": {}}
    # One-to-one matching prevents a repeated predicted boundary from inflating recall.
    remaining = list(found)
    matches = 0
    for boundary in shots:
        candidates = [t for t in remaining if abs(t - boundary) <= 250]
        if candidates:
            chosen = min(candidates, key=lambda t: abs(t - boundary))
            remaining.remove(chosen)
            matches += 1
    precision = matches / len(found) if found else 0.0
    recall = matches / len(shots)
    utterances = reference["utterances"]
    predicted = prediction["utterances"]
    actual = {u.get("id"): u for u in utterances if isinstance(u, dict)}
    guesses = {u.get("id"): u for u in predicted if isinstance(u, dict)}
    if len(actual) != len(utterances) or None in actual or len(guesses) != len(predicted):
        return {"passed": False, "errors": ["Invalid or duplicate utterance IDs"], "metrics": {}}
    correct = 0
    abstained = 0
    for key, item in actual.items():
        got = guesses.get(key, {})
        predicted_speaker = got.get("speaker_id", "unknown")
        if predicted_speaker == "unknown":
            abstained += 1
        elif predicted_speaker == item.get("speaker_id"):
            correct += 1
    metrics = {
        "shot_precision_250ms": precision,
        "shot_recall_250ms": recall,
        "speaker_accuracy_total": correct / len(actual),
        "speaker_abstention_rate": abstained / len(actual),
        "annotated_utterances": len(actual),
        "matched_shots": matches,
        "annotated_shots": len(shots),
    }
    # Score is diagnostic. Coverage of all 11 engines, model receipts, and
    # real-device checks are separate mandatory gates; never auto-certify.
    return {"passed": False, "certification": "not_certified_diagnostic_only",
            "errors": ["Full eleven-capability and Android-device gates not evaluated"],
            "metrics": metrics}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--prediction", type=Path, required=True)
    parser.add_argument("--source", type=Path, help="Optional local file for hash verification; never uploaded")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = evaluate(json.loads(args.reference.read_text()),
                      json.loads(args.prediction.read_text()),
                      args.source.read_bytes() if args.source else None)
    report = json.dumps(result, indent=2, sort_keys=True)
    if args.output:
        args.output.write_text(report + "\n")
    print(report)


if __name__ == "__main__":
    main()
