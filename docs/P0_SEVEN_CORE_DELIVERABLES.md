# OtakuDub: seven mandatory P0 release gates

These seven are permanent delivery scope, not optional enhancements. Make implementation changes directly where safe; never claim a successful model/device run from a wrapper, mocked output, green static test or an APK existing. The professional-readiness JSON reports each gate separately.

| P0 gate | Required executable deliverable | Required acceptance evidence |
|---|---|---|
| Audiovisual AI | Pinned licensed checkpoint, reproducible ONNX conversion, synchronized face-track/video + audio features and real Android inference | PyTorch/ONNX parity, correct input/output schema, score calibration, on-device run |
| Anime references | Rights-cleared exact asset records and reference scene/timeline/dialogue/character index | Provenance, SHA-256, authorized use, episode/edit-offset and ambiguous-match tests |
| Character recognition | OtakuMind reference-directed segment speaker links cross-checked with acoustic/visual evidence | Held-out named-character metrics; unknown, offscreen and overlap abstention |
| Dialogue accuracy | Japanese-to-Hindi/English contextual adaptation plus independent semantic assessment | Annotated held-out set, adequacy, target-language and terminology evaluation |
| Lip synchronization | Generated-WAV plus actual animation mouth timeline, per-segment binding and bounded fit/regeneration | Signed measurements of temporal drift, mismatch rejection and zero fabricated scores |
| Professional voices | Character-consistent verified installed TTS styles, delivery control, pronunciation glossary and quality assessment | Actual bilingual recordings, blinded intelligibility/expression and consistency review |
| Real-device validation | Reproducible offline APK input-to-output run, durable checkpoint and playback | Logs, source/MP4 hashes, duration, separation leakage, long-video recovery and memory/thermal results |

## Execution rules
1. Build and verify the *producer* before connecting a consumer. Interface-only integration remains incomplete.
2. Never place unlicensed scripts, footage or checkpoints in the catalog or APK. Empty reference catalog is an explicit blocker, not an invitation to fabricate source records.
3. Reference identifiers and scene hashes are retrieval evidence, not automatically speaker or lip-motion proof.
4. Keep original segment timing immutable. Only measured extension into available silence is permitted, with rejection for overlap.
5. Record the exact source video, generated WAV and checkpoint digests for every audiovisual measurement. Invalid, stale or missing evidence must not pass.
6. Continuous integration verifies build and deterministic tests; physical device quality and rights verification require their own independent evidence.
7. Preserve fallback transcription when exact registered reference dialogue cannot be proven. Do not downgrade a known identity to a guessed one.

Professional release approval requires all seven gate outcomes to be evidenced; partial work is reported as partial.
