# Uploaded eight-stage architecture acceptance report

Target: imported anime video → Whisper/ECAPA/visual/reference evidence → OtakuMind character fusion → confidence gate → consistent automatic voice casting → contextual translation → Supertonic synthesis → audio QC → soundtrack-preserving MP4 export.

## Implemented code-level connections
- Existing native Whisper transcription and ECAPA acoustic diarization are retained.
- Scene matcher supports optional dialogue/frame-hash corroboration; it does not establish active speaker or a character name.
- OtakuMind's evidence ledger records speaker-specific provenance and guarded segment-linked named-character associations, without changing acoustic IDs.
- New `IdentityConfidenceGate` is shared between manual review and pre-synthesis casting. Known speakers with zero confidence still require explicit acoustic review, and scene metadata cannot clear that uncertainty.
- Identified speakers are automatically assigned stable provisional Supertonic profiles and persisted even if another segment remains unresolved.
- Existing OtakuMind translation/refinement, synthesis, deterministic checks, separation, mixing and export remain wired.

## Acceptance evidence still required
- Native visual active-speaker inference/model and synchronized frame/voice evaluation.
- A licensed, verified anime reference corpus (checked-in catalog is empty).
- An authenticated evidence producer; submitting nonempty evidence IDs alone is not proof of a true character identity.
- Calibrated acoustic-to-visual character mapping and role-aware casting from real measured evidence.
- Real ONNX/GGUF model hashes, runtime inference, Android memory/performance.
- Measured WAV intelligibility, voice consistency, duration, clipping, separation leakage and regenerated segment fixtures.
- Latest GitHub Actions green result and real Android APK installation/export test.

No placeholders, invented character labels or unverified claims may be used to satisfy these release gates.
