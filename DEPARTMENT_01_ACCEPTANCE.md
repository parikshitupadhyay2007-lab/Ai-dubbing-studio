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
