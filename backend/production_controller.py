"""Fail-closed production coordinator. This is infrastructure, not an AI-quality claim.

Adapters implement produce(context) -> Artifact and evaluate(artifact, context) -> Review.
A distinct reviewer adapter is mandatory for every stage; no fabricated success defaults.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol, Mapping, Any
from departmental_pipeline import (
    Artifact, Review, Pipeline, DEPARTMENTS, REQUIRED_CHECKS, HandoffError, Status
)

class Engine(Protocol):
    engine_id: str
    def produce(self, context: Mapping[str, Any]) -> Artifact: ...

class Evaluator(Protocol):
    engine_id: str
    def evaluate(self, artifact: Artifact, context: Mapping[str, Any]) -> Review: ...

@dataclass(frozen=True)
class Assignment:
    producer: Engine
    evaluator: Evaluator
    max_attempts: int = 3

    def __post_init__(self):
        if not self.producer.engine_id or not self.evaluator.engine_id:
            raise HandoffError("Engine identity is required")
        if self.producer.engine_id == self.evaluator.engine_id:
            raise HandoffError("The producer may not evaluate its own output")
        if not 1 <= self.max_attempts <= 5:
            raise HandoffError("Retry budget must be between one and five")

@dataclass
class ProductionController:
    pipeline: Pipeline
    assignments: Mapping[str, Assignment]
    audit: list[dict[str, Any]] = field(default_factory=list)

    def __post_init__(self):
        if set(self.assignments) != set(DEPARTMENTS):
            raise HandoffError("Exactly eleven configured departments required")

    def run(self, initial_context: Mapping[str, Any]) -> Pipeline:
        context = dict(initial_context)
        if self.pipeline.index != 0 or self.pipeline.artifacts:
            raise HandoffError("A resumed job requires verified persisted artifacts; unsafe restart blocked")
        if not context.get("job_id") or context["job_id"] != self.pipeline.job_id:
            raise HandoffError("Job context mismatch")
        while self.pipeline.active_department is not None:
            index = self.pipeline.index
            department = DEPARTMENTS[index]
            assignment = self.assignments[department]
            accepted = False
            for attempt in range(1, assignment.max_attempts + 1):
                self.pipeline.status = Status.RUNNING
                try:
                    artifact = assignment.producer.produce(dict(context))
                    if (not isinstance(artifact, Artifact) or artifact.job_id != self.pipeline.job_id
                            or artifact.department != department or not artifact.verify_integrity()):
                        raise HandoffError("Producer supplied invalid artifact")
                    review = assignment.evaluator.evaluate(artifact, dict(context))
                    if not isinstance(review, Review):
                        raise HandoffError("Evaluator supplied no valid review")
                    expected = DEPARTMENTS[index + 1] if index + 1 < len(DEPARTMENTS) else "external acceptance"
                    if review.reviewer != expected or set(review.checks) != set(REQUIRED_CHECKS[index]):
                        raise HandoffError("Reviewer or mandatory checks mismatch")
                    self.pipeline.submit_and_review(artifact, review)
                    self.audit.append({"department": department, "attempt": attempt,
                                       "result": "accepted", "digest": artifact.content_digest,
                                       "producer": assignment.producer.engine_id,
                                       "reviewer_engine": assignment.evaluator.engine_id})
                    context["previous_artifact"] = artifact
                    context["approved_artifacts"] = tuple(self.pipeline.artifacts)
                    accepted = True
                    break
                except Exception as exc:
                    # Never silently continue; retain a bounded diagnostic, not media or secrets.
                    self.pipeline.status = Status.REJECTED
                    self.audit.append({"department": department, "attempt": attempt,
                                       "result": "rejected", "error_type": type(exc).__name__})
            if not accepted:
                raise HandoffError(f"{department} exhausted independent validation attempts")
        return self.pipeline
