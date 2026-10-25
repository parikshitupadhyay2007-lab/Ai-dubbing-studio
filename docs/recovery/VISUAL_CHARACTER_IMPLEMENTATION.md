# Visual recognition, reference data and character fusion: implementation and remaining evidence

## Implemented in recovery branch
- `VerifiedAnimeCatalog`: fail-closed parser for scene entries requiring source ID, provenance, redistribution licence, valid timeline and at least three actual dialogue lines. The bundled catalog is still `[]`.
- `VisualSpeakerEvidence`: typed segment/track/timing, lip-sync and competing-track scores, model/source provenance and conservative ambiguity rejection. This is an output contract, not a pretrained inference model.
- `CharacterIdentityFusion`: provisional acoustic identity evidence and guarded per-segment character link interface; acoustic IDs and timestamps remain immutable.
- Existing `AnimeSceneMatcher` supports dialogue retrieval and optional frame-hash corroboration, not proof that any character is speaking.
- Added contract tests.

## Required to complete the actual requested functionality
1. Integrate a native visual detection/tracking and active-speaker lip-sync model; obtain and verify its weights, runtime inputs, model licence and real aligned evidence. Do not convert perceptual frame hashes into active speaker labels.
2. Obtain an authorized reference corpus: actual episode/dialogue and character annotations with source/redistribution rights. Validate against the above parser and further establish character/track correspondences.
3. Implement a trustworthy evidence producer that aligns actual acoustic embeddings, measured visual track evidence and authentic line-level reference annotations, including offscreen speakers, overlapping speech and shot changes.
4. Benchmark speaker-to-character precision/recall and no-match calibration. The stored evidence identifiers do not authenticate themselves.
5. Run Flutter CI, native compilation, video fixtures and real Android APK tests. No claim of release readiness until these pass.

The bundled empty catalog is intentional. Invented records or silent guesses would make automatic character recognition *look* complete while producing incorrect dubbing.
