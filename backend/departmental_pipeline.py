"""Eleven-department orchestration contract. No engine is marked complete by this module."""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import Mapping, Any
import hashlib
import json

DEPARTMENTS = (
    "00 Production Office", "01 Research & Continuity", "02 Original Script",
    "03 Translation & Adaptation", "04 Script Supervision",
    "05 Casting & Performance Direction", "06 Voice Performance",
    "07 ADR & Timing", "08 Sound Post-production", "09 Quality Control",
    "10 Delivery",
)

class HandoffError(RuntimeError):
    pass

class Status(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    REJECTED = "rejected"
    APPROVED = "approved"

@dataclass(frozen=True)
class Artifact:
    job_id: str
    department: str
    schema_version: str
    payload: Mapping[str, Any]
    evidence: Mapping[str, Any]
    model_versions: Mapping[str, str]
    content_digest: str

    def verify_integrity(self) -> bool:
        return self.content_digest == self._digest(
            self.job_id, self.department, self.schema_version,
            self.payload, self.evidence, self.model_versions)

    @staticmethod
    def _digest(job_id, department, schema_version, payload, evidence, model_versions):
        canonical = json.dumps({
            "job_id": job_id, "department": department, "schema_version": schema_version,
            "payload": payload, "evidence": evidence, "model_versions": model_versions,
        }, sort_keys=True, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode("utf-8")
        return hashlib.sha256(canonical).hexdigest()

    @classmethod
    def build(cls, job_id: str, department: str, payload: Mapping[str, Any],
              evidence: Mapping[str, Any], model_versions: Mapping[str, str]) -> "Artifact":
        if not job_id or department not in DEPARTMENTS or not payload or not evidence:
            raise HandoffError("Missing job, department, payload or review evidence")
        # JSON round trip snapshots nested structures, rejecting unsupported and nonfinite values.
        try:
            snapshot = json.loads(json.dumps({
                "payload": payload, "evidence": evidence, "model_versions": model_versions
            }, ensure_ascii=False, allow_nan=False))
        except (TypeError, ValueError) as exc:
            raise HandoffError("Non-serializable or nonfinite artifact") from exc
        digest = cls._digest(job_id, department, "1", **snapshot)
        return cls(job_id, department, "1", snapshot["payload"], snapshot["evidence"],
                   snapshot["model_versions"], digest)

@dataclass(frozen=True)
class Review:
    reviewer: str
    source_digest: str
    checks: Mapping[str, bool]
    issues: tuple[str, ...] = ()
    @property
    def approved(self) -> bool:
        return bool(self.checks) and all(v is True for v in self.checks.values()) and not self.issues

# The NEXT department independently reviews the previous; Delivery receives external acceptance.
REQUIRED_CHECKS = (
    ("job_scope", "input_integrity", "checkpoint_plan"),
    ("continuity", "reference_provenance", "rights_constraints"),
    ("source_fidelity", "timestamp_coverage", "speaker_evidence"),
    ("semantic_fidelity", "natural_spoken_dialogue", "character_consistency", "performability", "duration_fit"),
    ("independent_semantic_review", "independent_fluency_review", "script_approval"),
    ("speaker_identity", "casting_consistency", "performance_direction"),
    ("intelligibility", "voice_consistency", "acting_quality", "audio_integrity"),
    ("alignment", "no_overlap", "no_out_of_bounds"),
    ("dialogue_clarity", "bgm_sfx_preservation", "mix_integrity"),
    ("end_to_end_playback", "perceptual_qc", "export_readiness"),
    ("file_integrity", "resume_integrity", "delivery_acceptance"),
)

@dataclass
class Pipeline:
    job_id: str
    index: int = 0
    status: Status = Status.PENDING
    artifacts: list[Artifact] = field(default_factory=list)
    reviews: list[Review] = field(default_factory=list)

    @property
    def active_department(self) -> str | None:
        return DEPARTMENTS[self.index] if self.index < len(DEPARTMENTS) else None

    def submit_and_review(self, artifact: Artifact, review: Review) -> None:
        if self.active_department is None:
            raise HandoffError("Delivery already completed")
        if artifact.job_id != self.job_id or artifact.department != self.active_department:
            raise HandoffError("Wrong job or out-of-order department")
        if (artifact.schema_version != "1" or not artifact.verify_integrity()
                or review.source_digest != artifact.content_digest):
            raise HandoffError("Review is not tied to current versioned artifact")
        reviewer = DEPARTMENTS[self.index + 1] if self.index + 1 < len(DEPARTMENTS) else "external acceptance"
        if review.reviewer != reviewer:
            raise HandoffError("Independent next-department review required")
        if set(review.checks) != set(REQUIRED_CHECKS[self.index]):
            raise HandoffError("Required completion checks absent or unexpected")
        # Explicit True is required: truthy values such as "passed" are not accepted.
        if not review.approved:
            self.status = Status.REJECTED
            raise HandoffError("Department rejected: " + "; ".join(review.issues or ("failed checks",)))
        self.artifacts.append(artifact)
        self.reviews.append(review)
        self.index += 1
        self.status = Status.APPROVED if self.active_department is None else Status.PENDING

    def completed(self) -> bool:
        return self.index == len(DEPARTMENTS) and len(self.artifacts) == len(DEPARTMENTS) and self.status == Status.APPROVED
