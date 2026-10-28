"""Strict interface for a local OtakuMind visual model.

No model is bundled or claimed operational here. Inference adapters must return
grounded observations with frame hashes; a separate verifier checks provenance.
"""
from __future__ import annotations
import json
import math
from pathlib import Path
from typing import Protocol
from departmental_pipeline import HandoffError
from intake_department import atomic_json
from otakumind_scene_evidence import verify_scene_frames

class LocalVisionEngine(Protocol):
    engine_id: str
    model_digest: str
    def describe_frame(self, image_path: Path) -> dict: ...

def analyze_frames(directory, intake, engine: LocalVisionEngine):
    if not engine.engine_id or not isinstance(engine.model_digest,str) or len(engine.model_digest)!=64:
        raise HandoffError("Verified local vision model identity and SHA-256 required")
    manifest=verify_scene_frames(directory,intake)
    directory=Path(directory)
    observations=[]
    for frame in manifest["frames"]:
        result=engine.describe_frame(directory/"otakumind-frames"/frame["file"])
        if not isinstance(result,dict):
            raise HandoffError("Vision engine returned invalid observation")
        description=result.get("description")
        if not isinstance(description,str) or not description.strip():
            raise HandoffError("Empty scene observation")
        if result.get("identity") is not None:
            raise HandoffError("Unverified identity claims are not accepted")
        observations.append({"timestamp":frame["timestamp"],"frame_sha256":frame["sha256"],
                             "description":description.strip(),"identity":None})
    output={"schema_version":1,"source_sha256":manifest["source_sha256"],
            "engine_id":engine.engine_id,"model_sha256":engine.model_digest,
            "observations":observations,"identity_recognition":"NOT VERIFIED",
            "semantic_review":"PENDING"}
    atomic_json(directory/"otakumind-frames"/"observations.json",output)
    return output

def verify_observations(directory,intake,expected_model_sha256):
    manifest=verify_scene_frames(directory,intake)
    path=Path(directory)/"otakumind-frames"/"observations.json"
    if path.is_symlink():raise HandoffError("Unsafe observation record")
    record=json.loads(path.read_text(encoding="utf-8"))
    if (record.get("schema_version")!=1 or
        record.get("source_sha256")!=manifest["source_sha256"] or
        record.get("model_sha256")!=expected_model_sha256 or
        record.get("semantic_review")!="PENDING" or
        record.get("identity_recognition")!="NOT VERIFIED"):
        raise HandoffError("Observation provenance mismatch")
    observations=record.get("observations")
    if not isinstance(observations,list) or len(observations)!=len(manifest["frames"]):
        raise HandoffError("Incomplete scene observations")
    for obs,frame in zip(observations,manifest["frames"]):
        if (not isinstance(obs,dict) or obs.get("timestamp")!=frame["timestamp"] or
            obs.get("frame_sha256")!=frame["sha256"] or
            not isinstance(obs.get("description"),str) or not obs["description"].strip() or
            obs.get("identity") is not None):
            raise HandoffError("Ungrounded scene observation")
    return record
