"""Adapters for existing backend engines. Never imply a legacy MVP meets professional gates."""
from __future__ import annotations
from pathlib import Path
import json
from departmental_pipeline import Artifact, DEPARTMENTS, HandoffError

class LegacyBackendAdapters:
    """Bridge real existing backend project.json into departmental evidence artifacts.

    Only read-only intake and ASR evidence are supported. Translation uses the existing
    network provider and cannot satisfy naturalness/semantic review automatically.
    Missing capabilities fail closed instead of manufacturing approval.
    """
    def __init__(self, project_dir: str | Path):
        self.directory = Path(project_dir)
        self.project = self._load()

    def _load(self):
        path = self.directory / "project.json"
        if not path.is_file():
            raise HandoffError("Legacy project.json missing; import media first")
        data = json.loads(path.read_text(encoding="utf-8"))
        if not data.get("id") or not data.get("source") or not isinstance(data.get("segments"), list):
            raise HandoffError("Invalid legacy project metadata")
        if not (self.directory / data["source"]).is_file() or not (self.directory / "audio.wav").is_file():
            raise HandoffError("Source media or decoded audio missing")
        return data

    def intake(self):
        source = self.directory / self.project["source"]
        audio = self.directory / "audio.wav"
        if not source.stat().st_size or not audio.stat().st_size:
            raise HandoffError("Empty source or audio")
        return Artifact.build(self.project["id"], DEPARTMENTS[0],
            {"source":source.name, "audio":audio.name, "bytes":source.stat().st_size},
            {"source_exists":True, "audio_exists":True, "legacy_backend":"backend/main.py"}, {})

    def original_script(self):
        segments = self.project["segments"]
        if not segments:
            raise HandoffError("No recognized dialogue; do not fabricate script")
        last_start = -1.
        for s in segments:
            if not isinstance(s.get("text"),str) or not s["text"].strip():
                raise HandoffError("Empty ASR segment")
            start,end=s.get("start"),s.get("end")
            if not isinstance(start,(int,float)) or not isinstance(end,(int,float)) or start<0 or end<=start or start<last_start:
                raise HandoffError("Invalid or unordered timestamps")
            last_start=start
        return Artifact.build(self.project["id"], DEPARTMENTS[2],
            {"language":self.project.get("source_language"),"segments":segments},
            {"transcriber":"faster_whisper", "entrypoint":"backend/main.py:create",
             "speaker_labels":"legacy placeholders, NOT verified identities",
             "word_timestamps":"not available in legacy output"}, {"whisper":"runtime-configured"})

    def translated_candidates(self, target_language: str):
        if target_language not in ("hi","en") or self.project.get("target_language")!=target_language:
            raise HandoffError("Translation has not been produced for requested language")
        segments=self.project["segments"]
        if not segments or any(not isinstance(s.get("translation"),str) or not s["translation"].strip() for s in segments):
            raise HandoffError("Incomplete translations")
        return Artifact.build(self.project["id"], DEPARTMENTS[3],
            {"target_language":target_language,"segments":segments},
            {"provider":"legacy MyMemory via backend/main.py:translate_project",
             "semantic_review":"NOT PERFORMED", "naturalness_review":"NOT PERFORMED",
             "offline":"NO"}, {"translator":"legacy-network"})

    def unsupported(self, department_index: int):
        raise HandoffError(f"{DEPARTMENTS[department_index]} requires a verified production adapter; legacy engine cannot pass its gates")
