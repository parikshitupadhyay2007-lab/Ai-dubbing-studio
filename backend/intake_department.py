"""Department 00: verifiable media intake and atomic checkpoint manifest."""
from __future__ import annotations
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import wave
from pathlib import Path
from departmental_pipeline import Artifact, Review, DEPARTMENTS, REQUIRED_CHECKS, HandoffError

def digest_file(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):h.update(chunk)
    return h.hexdigest()

def confined(directory, name):
    if not isinstance(name,str) or not name or Path(name).name != name:
        raise HandoffError("Unsafe media filename")
    path=directory/name
    if not path.is_file() or path.is_symlink() or not path.resolve().is_relative_to(directory.resolve()):
        raise HandoffError("Media file missing or unsafe")
    if path.stat().st_size<=0:raise HandoffError("Empty media file")
    return path

def probe(path):
    try:
        result=subprocess.run(["ffprobe","-v","error","-show_entries",
            "format=duration","-of","json",str(path)],capture_output=True,text=True,
            timeout=30,check=True)
        duration=float(json.loads(result.stdout)["format"]["duration"])
        if not 0 < duration < float("inf"):raise ValueError("invalid duration")
        return duration
    except (OSError,subprocess.SubprocessError,ValueError,KeyError,TypeError) as exc:
        raise HandoffError("Media probe failed") from exc

def media_evidence(directory, source_name):
    directory=Path(directory)
    source=confined(directory,source_name)
    audio=confined(directory,"audio.wav")
    duration=probe(source)
    with wave.open(str(audio),"rb") as w:
        if not w.getnframes() or not w.getframerate() or not w.getnchannels():
            raise HandoffError("Invalid decoded audio")
        audio_duration=w.getnframes()/w.getframerate()
    if abs(duration-audio_duration)>max(1.0,duration*.02):
        raise HandoffError("Decoded audio duration differs from source")
    return {"source":{"name":source.name,"bytes":source.stat().st_size,"sha256":digest_file(source)},
            "audio":{"name":audio.name,"bytes":audio.stat().st_size,"sha256":digest_file(audio)},
            "duration_seconds":duration,"audio_duration_seconds":audio_duration}

def atomic_json(path, data):
    path=Path(path)
    fd,name=tempfile.mkstemp(prefix=".checkpoint-",suffix=".tmp",dir=path.parent)
    try:
        with os.fdopen(fd,"w",encoding="utf-8") as f:
            json.dump(data,f,sort_keys=True,allow_nan=False)
            f.flush()
            os.fsync(f.fileno())
        os.replace(name,path)
    finally:
        if os.path.exists(name):os.unlink(name)

class IntakeProducer:
    engine_id="media-intake-v1"
    def __init__(self,directory):self.directory=Path(directory)
    def produce(self,context):
        meta=json.loads((self.directory/"project.json").read_text(encoding="utf-8"))
        if meta.get("id")!=context.get("job_id"):raise HandoffError("Job mismatch")
        evidence=media_evidence(self.directory,meta.get("source"))
        if shutil.disk_usage(self.directory).free < max(evidence["source"]["bytes"]*2, 64*1024*1024):
            raise HandoffError("Insufficient export/checkpoint space")
        manifest={"job_id":meta["id"],"media":evidence,"checkpoint_schema":1,
                  "next_department":DEPARTMENTS[1]}
        path=self.directory/"department00-checkpoint.json"
        atomic_json(path,manifest)
        return Artifact.build(meta["id"],DEPARTMENTS[0],manifest,
                              {"checkpoint":"department00-checkpoint.json","media_sha256":evidence["source"]["sha256"]},
                              {"intake":"1"})

class IntakeReviewer:
    engine_id="independent-media-verifier-v1"
    def __init__(self,directory):self.directory=Path(directory)
    def evaluate(self,artifact,context):
        checks=dict.fromkeys(REQUIRED_CHECKS[0],False)
        try:
            manifest=json.loads((self.directory/"department00-checkpoint.json").read_text(encoding="utf-8"))
            checks["job_scope"]=(manifest.get("job_id")==context.get("job_id")==artifact.job_id
                                  and artifact.department==DEPARTMENTS[0])
            checks["input_integrity"]=(manifest.get("media")==media_evidence(
                self.directory,manifest["media"]["source"]["name"])
                and artifact.payload.get("media")==manifest["media"])
            checks["checkpoint_plan"]=(manifest==artifact.payload and
                manifest.get("checkpoint_schema")==1 and
                manifest.get("next_department")==DEPARTMENTS[1] and artifact.verify_integrity())
        except (OSError,ValueError,KeyError,TypeError,HandoffError,EOFError,wave.Error):
            pass
        issues=tuple("failed: "+k for k,v in checks.items() if v is not True)
        return Review(DEPARTMENTS[1],artifact.content_digest,checks,issues)
