"""Offline vision subprocess adapter.

A configured local executable accepts JSON on stdin and returns JSON on stdout.
No network, shell, model download, or fabricated visual interpretation occurs here.
The executable must itself implement actual multimodal inference.
"""
from __future__ import annotations
import json
import subprocess
from pathlib import Path
from departmental_pipeline import HandoffError
from intake_department import digest_file

class SubprocessVisionEngine:
    def __init__(self, executable: str | Path, model: str | Path, *, timeout=120):
        self.executable=Path(executable).resolve(strict=True)
        self.model=Path(model).resolve(strict=True)
        if not self.executable.is_file() or not self.model.is_file():
            raise HandoffError("Local vision executable or model missing")
        if not 1 <= timeout <= 600:
            raise HandoffError("Vision inference timeout outside allowed bounds")
        self.timeout=timeout
        self.model_digest=digest_file(self.model)
        self.engine_id="offline-vision-subprocess:"+digest_file(self.executable)[:16]

    def describe_frame(self, image_path: Path) -> dict:
        image=Path(image_path).resolve(strict=True)
        if not image.is_file() or image.stat().st_size==0:
            raise HandoffError("Invalid inference frame")
        if digest_file(self.model)!=self.model_digest:\n            raise HandoffError("Local vision model changed after initialization")\n        request={"schema_version":1,"model_path":str(self.model),
                 "image_path":str(image),"task":"describe_visible_scene_without_identity_guessing"}
        try:
            completed=subprocess.run([str(self.executable)],input=json.dumps(request),
                text=True,capture_output=True,timeout=self.timeout,check=True)
            if len(completed.stdout)>65536:
                raise HandoffError("Oversized inference response")
            result=json.loads(completed.stdout)
        except (OSError,subprocess.SubprocessError,ValueError) as exc:
            raise HandoffError("Offline visual inference failed") from exc
        if (not isinstance(result,dict) or result.get("schema_version")!=1 or
            result.get("model_sha256")!=self.model_digest or
            result.get("image_sha256")!=digest_file(image)):
            raise HandoffError("Unbound or invalid inference response")
        if not isinstance(result.get("description"),str) or not result["description"].strip():
            raise HandoffError("Missing visual description")
        if result.get("identity") is not None:
            raise HandoffError("Unverified character identity")
        return {"description":result["description"].strip(),"identity":None}
