"""OtakuMind scene evidence preparation; no invented anime or character identities.

Extracts sampled frames from approved intake and binds them to source hashes.
A separate vision model must analyze these frames before semantic approval.
"""
from __future__ import annotations
import hashlib
import json
import math
import subprocess
from pathlib import Path
from departmental_pipeline import HandoffError
from intake_department import atomic_json, confined, digest_file

def sample_scene_frames(directory, intake, *, interval=5.0, max_frames=120):
    directory=Path(directory)
    if not 0.5 <= interval <= 60 or not 1 <= max_frames <= 120:
        raise HandoffError("Unsafe frame sampling configuration")
    media=intake.get("media",{})
    source_meta=media.get("source",{})
    source=confined(directory,source_meta.get("name"))
    if digest_file(source)!=source_meta.get("sha256"):
        raise HandoffError("Source changed after approved intake")
    duration=media.get("duration_seconds")
    if not isinstance(duration,(int,float)) or not math.isfinite(duration) or duration<=0:
        raise HandoffError("Invalid approved duration")
    output=directory/"otakumind-frames"
    output.mkdir(exist_ok=True)
    if output.is_symlink() or not output.resolve().is_relative_to(directory.resolve()):
        raise HandoffError("Unsafe frame output")
    entries=[]
    count=min(max_frames,max(1,math.ceil(duration/interval)))
    for index in range(count):
        timestamp=min(index*interval,max(0,duration-0.001))
        name=f"frame-{index:04d}.jpg"
        target=output/name
        try:
            subprocess.run(["ffmpeg","-nostdin","-hide_banner","-loglevel","error","-y",
                "-ss",f"{timestamp:.3f}","-i",str(source),"-frames:v","1",
                "-q:v","3",str(target)],check=True,capture_output=True,timeout=45)
        except (OSError,subprocess.SubprocessError) as exc:
            raise HandoffError("Scene frame extraction failed") from exc
        if not target.is_file() or target.is_symlink() or target.stat().st_size==0:
            raise HandoffError("Missing extracted frame")
        entries.append({"timestamp":timestamp,"file":name,"sha256":digest_file(target)})
    manifest={"schema_version":1,"source_sha256":source_meta["sha256"],
              "duration_seconds":duration,"frames":entries,
              "semantic_analysis":"NOT PERFORMED","identity_recognition":"NOT PERFORMED"}
    atomic_json(output/"manifest.json",manifest)
    return manifest

def verify_scene_frames(directory, intake):
    directory=Path(directory)
    output=directory/"otakumind-frames"
    if output.is_symlink():raise HandoffError("Unsafe frame directory")
    manifest=json.loads((output/"manifest.json").read_text(encoding="utf-8"))
    media=intake["media"]
    if (manifest.get("schema_version")!=1 or
        manifest.get("source_sha256")!=media["source"]["sha256"] or
        manifest.get("duration_seconds")!=media["duration_seconds"] or
        not isinstance(manifest.get("frames"),list) or not manifest["frames"]):
        raise HandoffError("Frame manifest mismatch")
    source=confined(directory,media["source"]["name"])
    if digest_file(source)!=manifest["source_sha256"]:
        raise HandoffError("Original media changed")
    last=-1
    for frame in manifest["frames"]:
        timestamp=frame.get("timestamp")
        if (not isinstance(timestamp,(int,float)) or not math.isfinite(timestamp)
                or timestamp<=last or timestamp>=manifest["duration_seconds"]):
            raise HandoffError("Invalid frame timeline")
        path=confined(output,frame.get("file"))
        if digest_file(path)!=frame.get("sha256"):
            raise HandoffError("Frame evidence changed")
        last=timestamp
    return manifest
