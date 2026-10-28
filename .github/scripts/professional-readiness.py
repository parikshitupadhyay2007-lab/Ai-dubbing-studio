#!/usr/bin/env python3
"""Truthful, machine-readable release readiness audit; not a substitute for device tests."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
def audit(root: Path):
    android = root / "android"
    catalog_path = android / "assets/anime_scene_catalog.json"
    native = (android / "android/app/src/main/kotlin/co/parikshit/otakudub/MainActivity.kt").read_text()
    pipeline = (android / "lib/services/dubbing_pipeline.dart").read_text()
    catalog = json.loads(catalog_path.read_text())
    if not isinstance(catalog, list):
        raise ValueError("Bundled anime catalog is not an array")
    catalog_ok = bool(catalog) and all(isinstance(row, dict) and all(row.get(k) for k in
        ("anime_id", "episode_id", "provenance", "redistribution_license", "source_id", "dialogue"))
        for row in catalog)
    visual_ok = ('"analyzeActiveSpeakers" ->' in native
                 and "ACTIVE_SPEAKER_MODEL_NOT_INSTALLED" not in native
                 and "model_verified" in native)
    checks = {
        "anime_reference_corpus": {"passed": catalog_ok, "evidence": f"{len(catalog)} bundled records; rights and coverage require independent review"},
        "native_visual_inference": {"passed": visual_ok, "evidence": "Native handler must run a verified model; source scan alone is insufficient proof"},
        "director_pipeline_wiring": {"passed": "director.translateLine" in pipeline and "_assignCharacterVoices(project)" in pipeline,
            "evidence": "Static orchestration check only; not real-model execution"},
        "real_model_inference": {"passed": False, "evidence": "Requires recorded on-device/model-run measurements; APK assets alone do not count"},
        "end_to_end_device": {"passed": False, "evidence": "Requires signed device acceptance with playable final MP4 and resume test"},
        "professional_quality": {"passed": False, "evidence": "Requires held-out annotated dataset, objective metrics and blinded listening results"},
    }
    # The seven P0 deliverables are separate release gates. A static source
    # presence check is NOT evidence of accuracy or successful inference.
    p0 = {
        "audiovisual_ai": (
            "AV_ALIGNMENT_MODEL_NOT_INSTALLED" not in native and
            "ACTIVE_SPEAKER_MODEL_NOT_INSTALLED" not in native,
            "Requires verified compatible checkpoint, native inference, calibrated on-device run"),
        "anime_reference_database": (
            catalog_ok,
            "Requires rights-cleared scripts, provenance, timestamp and speaker coverage audit"),
        "character_recognition": (
            False,
            "Requires held-out line-level named character accuracy with offscreen/overlap cases"),
        "dialogue_accuracy": (
            False,
            "Requires bilingual Japanese-to-Hindi and Japanese-to-English semantic human review"),
        "lip_synchronization": (
            False,
            "Requires actual source/clip-bound visual inference and measured per-line drift"),
        "professional_voices": (
            False,
            "Requires human-rated intelligibility, pronunciation, delivery and cross-scene consistency"),
        "real_device_validation": (
            False,
            "Requires signed device evidence: export, playback, resume, resources and long-video run"),
    }
    for name, (static_candidate, requirement) in p0.items():
        checks["p0_" + name] = {
            "passed": False,
            "static_candidate": static_candidate,
            "evidence": requirement,
        }
    # A source scan cannot prove model inference, even when no placeholder remains.
    checks["native_visual_inference"]["passed"] = False
    return {"schema_version": 1, "project": "OtakuDub", "certified_professional": all(v["passed"] for v in checks.values()),
            "checks": checks, "note": "Fail closed until independent dynamic evidence is attached; do not interpret static checks as certification."}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--require-professional", action="store_true")
    args = parser.parse_args()
    report = audit(args.root)
    result = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(result)
    print(result)
    if args.require_professional and not report["certified_professional"]:
        raise SystemExit("Professional release NOT certified: required dynamic evidence is missing")

if __name__ == "__main__":
    main()
