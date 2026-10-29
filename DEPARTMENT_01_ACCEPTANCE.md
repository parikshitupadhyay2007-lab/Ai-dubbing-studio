# Department 01 acceptance gate

Department 02 must remain locked until ALL six are implemented and independently verified. CI success is necessary but not sufficient.

| Component | Current executable implementation | Required to graduate |
|---|---|---|
| Anime recognition | Explicit-title AniList metadata query (unverified candidate only) | Model-backed video/reference identification; episode match with calibrated abstention |
| Scene segmentation | Timestamp/provenance validation | Frame-based shot/scene inference and independent boundary benchmark |
| Visual understanding | None | Tested visual encoder, action/expression outputs with timestamped frame evidence |
| Character recognition | None | Visual embeddings and recurrence tracking with unknown-character rejection |
| Context research | Opt-in HTTPS AniList metadata, no video upload | Local reference retrieval, source corroboration and episode-specific evidence |
| Continuity intelligence | Independent manifest/schema validation | Cross-scene evidence fusion, conflict detection and measured continuity accuracy |

Implemented plumbing: Department 00 source-bound receipts; recheck before artifact commit; no unapproved downstream handoff; research director with explicit user-entered online query; provenance and confidence validation.

The current app must not claim that empty evidence, a provider title match or a generated manifest proves anime recognition, a scene boundary, a speaker or a character. No external anime metadata may silently become ground truth.

Real-device test may remain pending by project policy, but model inference, integration and CI must pass before the department is marked complete.

## Implemented infrastructure update (October 29, 2026)

- Android ONNX Runtime, checksum-bound private local model import, session inspection, bounded real float32 input/output transfer, and Dart validation are committed.
- Dependency-aware six-engine coordinator and transitive invalidation/reanalysis ledger are committed.
- Visual embedding output can now feed a conservative local cosine reference matcher with ambiguous/unknown rejection, model/input/output binding, and tests. This bridge requires actual authorised weights and model-specific preprocessed image tensors. It does not certify character or anime recognition.
- Full-length 1 fps native 8x8 frame-signal batches provide shot discontinuity candidates, NOT verified scenes or high-resolution visual model tensors.

### Still blocking six-engine operational acceptance

1. Select and obtain authorised, version-pinned weights for each distinct model capability and record SHA256/model cards/input/output contracts. Do not commit restricted or unavailable weights.
2. Implement full-resolution frame extraction, model-specific visual preprocessing, real inference integration and temporal scene grouping; the 8x8 luma signal is insufficient for visual embeddings.
3. Build/licence a source-attributed local anime/episode reference index and independently test unknown-title abstention.
4. Integrate audio speaker embeddings, temporal visual tracking, active-speaker detection and evidence-based identity fusion. This cannot be inferred from video luminance alone.
5. Implement model-backed visual understanding and continuity assessment; keep uncertainty and contradiction-driven reanalysis visible.
6. Benchmark all six on annotated, lawfully available footage. Complete actual Android-device validation before commercial-quality claims. CI unit tests cannot demonstrate semantic accuracy or device performance.

Department 02 remains locked. Successful ONNX session execution and mock MethodChannel tests are not a substitute for real-model end-to-end tests.


## Current integration increment (2026-10-29)

- DINOv2-S acquisition/export workflow #40889830540 succeeded and uploaded a ~82 MB artifact; import into app private storage and Android execution still need direct validation.
- Real RGB frame API, model-specific CHW normalization, optional distinct square resize and center crop, pinned ONNX embedding execution and provenance-checked reference-index adapter are implemented. DINOv2 reference index expects the actual acquired artifact SHA256 and the exact matching preprocessing ID, not a fabricated value.
- The reference index only validates recorded rights basis; external provenance and asset permission must be independently audited. No copyrighted anime footage or reference images have been scraped.
- The native square resize is not yet an aspect-ratio-preserving DINOv2 short-edge resize on nonsquare original frames. Results must not be certified as faithful upstream preprocessing until that is fixed and tested.
- No empirical anime/episode recognition, scene classification, active-speaker diarisation, temporal character tracking, visual emotion classification, continuity intelligence inference or device benchmark is certified. Department 02 stays locked.
