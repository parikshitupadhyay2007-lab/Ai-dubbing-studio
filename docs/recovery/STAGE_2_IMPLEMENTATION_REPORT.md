# Stage 2 implementation report — 2026-10-25

Branch: `recovery/phase-0-audit`. Stage 3 (APK/device acceptance) remains reserved for the owner. This report separates committed source changes from genuinely missing assets and unverified integration.

## Committed in this implementation pass
- Bounded synthesis recovery catches the native excessive-compression diagnostic by segment ID, requests a segment-specific OtakuMind shortening, validates target language and shorter output, persists the checkpoint and retries at most twice per segment. No audio truncation or increased compression threshold.
- Offline engine carries an explicit `fit_for_duration` flag to native OtakuMind. Native refinement retains a stricter, meaning-preserving duration prompt on both generation attempts.
- Anime reference validation now accepts optional season, scene end, 64-bit frame hashes and provenance-bound, ordered timeline rows with optional expression annotations; rejects malformed, overlapping and mismatched-source data. Added Dart regression tests for the validator. The reference corpus remains empty by design until genuine, rights-reviewed material is available.

## Still pending in Stage 2 — NOT transferred to Stage 3
1. Acquire and verify rights-cleared anime/episode reference corpus; populate actual dialogue, visual and character/expression annotations. No arbitrary complete anime database can be truthfully installed from metadata alone.
2. Obtain/verify a suitable trained active-speaker checkpoint, export to compatible Android ONNX graph, implement native preprocessing/inference/postprocessing, and connect calibrated results to existing evidence gates. Light-ASD checkpoint acquisition alone is not Android integration.
3. Implement measured voice-character suitability beyond provisional stable casting, with evidence provenance and a conservative unknown-character fallback.
4. Train/integrate or validate expression inference and synchronized visual timing; enforce non-overlap and source evidence.
5. Add perceptual/semantic selective-regeneration QC and reliable long-video resumability/performance checks.
6. Run source CI (Flutter analyze/tests, Kotlin build) and resolve any failures before supplying an APK for Stage 3. No green build or device success is asserted here.

## Acceptance boundaries
Stage 2 is complete only when code, licensed model assets, corpus ingestion, and automated source/build checks are in place. Stage 3 is the owner's real-device audiovisual and end-to-end acceptance testing. An empty catalog must yield unknown identity rather than fabricated title/episode/character; absence of a visual model must not masquerade as verified lip evidence.
