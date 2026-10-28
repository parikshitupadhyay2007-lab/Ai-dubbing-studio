# OtakuDub departmental pipeline (migration contract)

This branch replaces loosely coupled AI calls through a versioned orchestration boundary. Legacy engines must not be deleted until replacement adapters pass integration tests.

## Execution order and independent review
1. Media intake: validate file, timestamps, audio/video streams, checkpoints. Output: MediaManifest. Reviewer: transcription validates timebase and readable audio.
2. Perception: ASR, word timestamps, dialogue/music/SFX separation, scene evidence. Output: EvidenceBundle with provenance/confidence. Reviewer: speaker attribution checks audiovisual alignment.
3. Speaker and character attribution: diarization, trained embeddings, cross-scene continuity, optional licensed/reference metadata. Output: SpeakerMap with unknown permitted. Reviewer: adaptation checks utterance attribution; never infer gender from voice alone.
4. Translation and adaptation: preserve meaning, intent, names, subtext, scene continuity and natural spoken Hindi/English; generate multiple candidates constrained by duration, not literal robotic translations. Output: AdaptedDialogue including source links, semantic checks and pronunciation notes. Reviewer: independent bilingual semantic/fluency and timing QA; reject mistranslation or invented dialogue.
5. Performance and voice: stable consented/authorized character voice assignment, emotion and acting directions, ONNX speech generation, pronunciation and duration fit. Output: SpeechAssets with segment IDs, durations and model versions. Reviewer: acoustic QA checks intelligibility, voice consistency, emotion and clipping.
6. Mix and sync: preserve BGM/SFX, align dubbed speech, prevent overlaps and out-of-bounds segments. Output: MixedTimeline. Reviewer: perceptual QC checks leakage, timing, loudness and music/SFX preservation.
7. Export and delivery: atomic output directory creation, resumable checkpoints, background job handling, media integrity. Output: ExportManifest. Reviewer: final end-to-end playback and automated acceptance tests.

## Common interface
Every stage accepts {job_id, schema_version, input_artifact_ids, model_manifest, config} and emits {stage, artifact_id, schema_version, inputs, model_versions, segments, confidence, warnings, errors, metrics, status}. Stages may return accepted, needs_review, retryable_failure or fatal_failure. No silent fallbacks, placeholder speech, missing-model continuation or success without validated artifacts.

## Migration gates
- Inventory existing Flutter MethodChannel, Kotlin, Python and ONNX entrypoints.
- Introduce adapters for existing engines behind the contract, then replace adapters one by one.
- Verify model checksum, licensing and Android ABI before execution.
- Unit-test each contract and independent reviewer, then integration-test actual audio/video and long-video resume.
- Do not switch the production entrypoint or remove legacy implementation until the replacement produces verified exports on device.
