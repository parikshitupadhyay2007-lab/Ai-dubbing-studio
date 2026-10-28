"""Department 01: provenance-bound continuity evidence, not automatic anime recognition.

A project owner supplies a rights declaration and scene observations. This module
verifies consistency and provenance; it does not assert that observations are true
without an independent audiovisual model or authorized human review.
"""
from __future__ import annotations
import json
import math
from pathlib import Path
from departmental_pipeline import Artifact, Review, DEPARTMENTS, REQUIRED_CHECKS, HandoffError
from intake_department import atomic_json, digest_file

REFERENCE = "continuity-input.json"
CHECKPOINT = "department01-checkpoint.json"

def load_continuity(directory, intake):
    directory=Path(directory)
    path=directory/REFERENCE
    if path.is_symlink() or not path.is_file():
        raise HandoffError("Continuity reference missing or unsafe")
    data=json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data,dict) or data.get("schema_version")!=1:
        raise HandoffError("Unsupported continuity schema")
    if data.get("job_id")!=intake["job_id"]:
        raise HandoffError("Continuity job mismatch")
    rights=data.get("rights")
    if not isinstance(rights,dict) or rights.get("basis") not in ("original", "licensed", "user_supplied"):
        raise HandoffError("Rights basis missing")
    if not isinstance(rights.get("attestation"),str) or not rights["attestation"].strip():
        raise HandoffError("Rights attestation missing")
    scenes=data.get("scenes")
    if not isinstance(scenes,list) or not scenes:
        raise HandoffError("No scene observations")
    duration=intake["media"]["duration_seconds"]
    previous_end=0.
    ids=set()
    for scene in scenes:
        if not isinstance(scene,dict):raise HandoffError("Invalid scene")
        start,end=scene.get("start"),scene.get("end")
        if (not isinstance(start,(int,float)) or isinstance(start,bool) or
            not isinstance(end,(int,float)) or isinstance(end,bool) or
            not math.isfinite(start) or not math.isfinite(end) or
            start<previous_end or end<=start or end>duration+.05):
            raise HandoffError("Scene boundaries invalid or overlapping")
        if not isinstance(scene.get("id"),str) or not scene["id"].strip() or scene["id"] in ids:
            raise HandoffError("Scene identifier invalid or duplicated")
        if not isinstance(scene.get("observation"),str) or not scene["observation"].strip():
            raise HandoffError("Scene observation missing")
        ids.add(scene["id"]);previous_end=end
    return data,digest_file(path)

class ContinuityProducer:
    engine_id="continuity-provenance-v1"
    def __init__(self,directory):self.directory=Path(directory)
    def produce(self,context):
        previous=context.get("previous_artifact")
        if (previous is None or previous.department!=DEPARTMENTS[0] or
            previous.job_id!=context.get("job_id") or not previous.verify_integrity()):
            raise HandoffError("Approved intake required")
        intake=previous.payload
        data,sha=load_continuity(self.directory,intake)
        manifest={"job_id":context["job_id"],"intake_digest":previous.content_digest,
                  "reference_sha256":sha,"continuity":data}
        atomic_json(self.directory/CHECKPOINT,manifest)
        return Artifact.build(context["job_id"],DEPARTMENTS[1],manifest,
            {"reference_file":REFERENCE,"reference_sha256":sha,
             "observations":"user supplied, not independently scene-verified",
             "rights":"declaration only, not legal clearance"}, {"continuity":"1"})

class ContinuityReviewer:
    engine_id="continuity-independent-verifier-v1"
    def __init__(self,directory):self.directory=Path(directory)
    def evaluate(self,artifact,context):
        checks=dict.fromkeys(REQUIRED_CHECKS[1],False)
        try:
            previous=context["previous_artifact"]
            manifest=json.loads((self.directory/CHECKPOINT).read_text(encoding="utf-8"))
            data,sha=load_continuity(self.directory,previous.payload)
            checks["reference_provenance"]=(manifest.get("reference_sha256")==sha and
                artifact.payload.get("reference_sha256")==sha and
                manifest.get("intake_digest")==previous.content_digest and previous.verify_integrity())
            # Structural continuity alone cannot independently verify visual scene claims.
            checks["continuity"]=False
            # A self-attestation is not independent rights clearance.
            checks["rights_constraints"]=False
            if manifest!=artifact.payload or manifest.get("continuity")!=data or not artifact.verify_integrity():
                checks=dict.fromkeys(REQUIRED_CHECKS[1],False)
        except (OSError,ValueError,KeyError,TypeError,HandoffError):
            pass
        issues=tuple("unverified: "+k for k,v in checks.items() if v is not True)
        return Review(DEPARTMENTS[2],artifact.content_digest,checks,issues)
