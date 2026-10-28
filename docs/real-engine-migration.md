# Real-engine migration status

The production controller now has a read-only migration probe: `backend/legacy_migration.py`.
It reads actual legacy `project.json`, source media and decoded audio using
`LegacyBackendAdapters`. It does not call a cloud service or modify production
outputs. Invoke with a pre-existing project directory:

```python
from legacy_migration import migration_probe
from departmental_pipeline import HandoffError
controller = migration_probe("jobs/EXISTING_JOB_ID", "EXISTING_JOB_ID")
try:
    controller.run({"job_id": "EXISTING_JOB_ID", "target_language": "hi"})
except HandoffError:
    print(controller.audit)
```

The migration probe **must currently reject** intake because the legacy backend
does not provide verified checkpoint planning. It is not a full dubbing runner.
ASR's legacy `Character 1` label is not speaker identification. MyMemory
translation is not independent semantic/fluency approval. The old Edge TTS
and mix/export paths do not preserve BGM/SFX and are not professional offline
engine adapters. Do not wire these to automatically true quality checks.

Required next real-engine implementations: media checkpoint manifest; licensed
reference/scene-context evaluator; word-level ASR and independent source audit;
offline translation and bilingual evaluator; speaker embeddings and visual
cross-check; verified authorized voice models and acoustic evaluator; duration
fit; source separation and mixing; full-video perceptual QC; resumable atomic
export and external acceptance. Each adapter must emit real evidence and have
independent tests on representative actual media. Only then activate the new
controller in the Android application.

Run `cd backend && python -m unittest discover -s tests -p 'test_*.py' -v`.
