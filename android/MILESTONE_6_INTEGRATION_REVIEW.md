# Milestone 6 — Integration review (22 October 2026)

Status: **BLOCKED — do not certify release readiness or trigger the consolidated APK build yet.**

## Confirmed code paths
- Flutter DubbingPipeline invokes transcription, diarization, character casting, translation, refinement, TTS, timeline mixing and MP4 export.
- The native Android method channel now exposes checksum-gated separateSoundtrack, and Flutter OfflineEngine has a corresponding API.
- Exporter encodes a synchronized WAV to AAC and muxes it with the source video stream, with an output track-presence check.
- Flutter regression tests exist for project serialization and Hindi/English voice profile inventory. These have not yet been executed after recent commits.

## Release blockers
1. **Missing production separation integration:** DubbingPipeline never invokes separateSoundtrack. There is no installed separation-model configuration/verified hash lifecycle or automatic accompaniment selection.
2. **Missing soundtrack recombination:** OfflineDialogueMixService mixes generated dialogue only; OfflineVideoExporter replaces the source audio. The intended accompaniment+BGM/SFX mix is not implemented.
3. **Checkpoint verification incomplete:** A caller-provided hash is compared to a caller-provided model, but this does not establish a *trusted* checkpoint. Its hash, tensor names, transform conventions and instrumental stem polarity require independent pinned reference verification. No audio/reference parity test has been run.
4. **Model processing quality unverified:** STFT framing, resampling quality, ONNX output interpretation and full-length stem reconstruction require Android test fixtures, including short clips, final padded chunks, overlapping chunks and mono/stereo sources.
5. **Unexecuted regression suite:** No compilation, Flutter test, native test, on-device inference or full video export has been run against these commits.

## Required acceptance before milestone 7
- Pin and independently verify a supported separator checkpoint and metadata.
- Connect separator into the pipeline and mix instrumental accompaniment with the dubbed speech, preserving duration and avoiding original-vocal leakage where feasible.
- Add and run native audio fixture tests and Flutter error-path tests.
- Review exact MethodChannel request/response keys end to end.
- Only then trigger one consolidated GitHub Actions build and resolve failures.

Do not describe milestone 1, 2, 4 or 6 as complete while these blockers remain.

## Update — 22 October 2026

Commits `37456db`, `3b333b6` and `f2d1e7e` added a local separation manifest loader and connected separation → stereo soundtrack mixing → export in DubbingPipeline. The earlier statement that DubbingPipeline does not invoke separation describes the previous revision, not the current code. These changes are **unbuilt and not validated**. A user-supplied manifest is not an independently trusted checkpoint; the exact ONNX file, transform, stem polarity, and on-device parity must be reviewed before provisioning. The release remains blocked until acceptance tests pass.
