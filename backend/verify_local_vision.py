"""Opt-in real offline visual-model smoke test. No simulated inference.

Usage:
 python backend/verify_local_vision.py PROJECT_DIR EXECUTABLE MODEL
Requires project directory with approved department00-checkpoint.json and source media.
Does not download models or invoke network services.
"""
from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path
from departmental_pipeline import HandoffError
from intake_department import media_evidence
from otakumind_scene_evidence import sample_scene_frames, verify_scene_frames
from otakumind_vision_adapter import analyze_frames, verify_observations
from otakumind_local_runtime import SubprocessVisionEngine

def verify(directory, executable, model):
    directory=Path(directory)
    checkpoint=json.loads((directory/"department00-checkpoint.json").read_text(encoding="utf-8"))
    if checkpoint.get("checkpoint_schema")!=1 or not isinstance(checkpoint.get("media"),dict):
        raise HandoffError("Verified intake checkpoint required")
    expected=checkpoint["media"]
    if media_evidence(directory,expected["source"]["name"])!=expected:
        raise HandoffError("Intake evidence changed")
    engine=SubprocessVisionEngine(executable,model)
    frames=sample_scene_frames(directory,checkpoint,interval=5.0,max_frames=12)
    verify_scene_frames(directory,checkpoint)
    result=analyze_frames(directory,checkpoint,engine)
    verify_observations(directory,checkpoint,engine.model_digest)
    return {"status":"inference_provenance_verified",
            "engine_id":engine.engine_id,"model_sha256":engine.model_digest,
            "frames":len(frames["frames"]),"observations":len(result["observations"]),
            "semantic_accuracy":"NOT EVALUATED","character_identity":"NOT VERIFIED",
            "department01_approval":"BLOCKED"}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("project_dir")
    parser.add_argument("executable")
    parser.add_argument("model")
    args=parser.parse_args()
    try:
        print(json.dumps(verify(args.project_dir,args.executable,args.model),sort_keys=True))
    except (HandoffError,OSError,ValueError,KeyError,TypeError) as exc:
        print(json.dumps({"status":"failed","error_type":type(exc).__name__}),file=sys.stderr)
        return 1
    return 0

if __name__=="__main__":raise SystemExit(main())
