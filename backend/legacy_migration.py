"""Real legacy project producer wiring with fail-closed, non-approving reviewers.

This is a migration probe, not a production dubbing runner. A passing metadata
check never masquerades as independent semantic, acoustic, or perceptual QA.
"""
from __future__ import annotations
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Any
from department_adapters import LegacyBackendAdapters
from departmental_pipeline import Artifact, Review, DEPARTMENTS, REQUIRED_CHECKS, HandoffError
from production_controller import Assignment, ProductionController, Pipeline

@dataclass
class LegacyProducer:
    project_dir: Path
    index: int
    engine_id: str = ""
    def __post_init__(self):
        self.engine_id = f"legacy-project-producer-{self.index}"
    def produce(self, context: Mapping[str, Any]) -> Artifact:
        adapter = LegacyBackendAdapters(self.project_dir)
        if adapter.project["id"] != context["job_id"]:
            raise HandoffError("Project ID differs from production job")
        if self.index == 0:
            return adapter.intake()
        if self.index == 2:
            return adapter.original_script()
        if self.index == 3:
            return adapter.translated_candidates(context.get("target_language", ""))
        return adapter.unsupported(self.index)

@dataclass
class EvidenceReviewer:
    index: int
    engine_id: str = ""
    def __post_init__(self):
        self.engine_id = f"migration-evidence-reviewer-{self.index}"
    def evaluate(self, artifact: Artifact, context: Mapping[str, Any]) -> Review:
        reviewer = DEPARTMENTS[self.index + 1] if self.index + 1 < len(DEPARTMENTS) else "external acceptance"
        # Only inspect the actual evidence. We cannot claim media quality from metadata.
        checks = {key: False for key in REQUIRED_CHECKS[self.index]}
        if self.index == 0:
            checks["job_scope"] = artifact.job_id == context.get("job_id")
            checks["input_integrity"] = (artifact.evidence.get("source_exists") is True
                                         and artifact.evidence.get("audio_exists") is True)
            # Legacy project has no verified checkpoint plan; remain blocked.
        elif self.index == 2:
            segments = artifact.payload.get("segments", [])
            checks["timestamp_coverage"] = bool(segments) and all(
                isinstance(s.get("start"), (int, float)) and
                isinstance(s.get("end"), (int, float)) and
                s["end"] > s["start"] for s in segments)
            # Source fidelity and speaker evidence need independent audiovisual checks.
        elif self.index == 3:
            # Never approve machine translation without independent bilingual review.
            pass
        issues = tuple("unverified: " + key for key, value in checks.items() if value is not True)
        return Review(reviewer, artifact.content_digest, checks, issues)

def migration_probe(project_dir: str | Path, job_id: str, target_language: str = "hi",
                    max_attempts: int = 1) -> ProductionController:
    """Construct real-data pipeline; intentionally blocks at unverified quality gates."""
    directory = Path(project_dir)
    assignments = {department: Assignment(LegacyProducer(directory, index),
                                           EvidenceReviewer(index), max_attempts)
                   for index, department in enumerate(DEPARTMENTS)}
    return ProductionController(Pipeline(job_id), assignments)
