# OtakuDub adopted product architecture — OtakuMind as central dubbing director

Status: **approved target architecture**, not a claim that the features below are already trained, installed or validated. Implement incrementally on `recovery/phase-0-audit`; do not replace working engines with placeholders or merge into main before device acceptance.

## Product goal
Fully offline, professional-quality, largely automatic anime/video dubbing into Hindi and English. Preserve original meaning, expressions, stable voices per character, music and sound effects. No mandatory manual dialogue editing. Use genuine, high-quality trained models, verifiable assets, project checkpoints and on-device tests.

## Execution order
1. Import video and validate all bundled/installed model assets, storage and runtime.
2. Whisper: source-language detection and original dialogue transcription with immutable timestamps and original audio references.
3. **OtakuMind Dubbing Director** orchestrates, rather than fabricates, specialist evidence:
   - Acoustic diarization and ECAPA embeddings; maintain stable provisional speaker IDs.
   - Video frame/face tracking, trained active-speaker detection and mouth activity, once actually integrated and calibrated.
   - Search the verified anime reference store for anime/season/episode/scene and timeline, with provenance and confidence.
   - Combine visual track, acoustic speaker and catalog character evidence; never promote a guessed character name.
   - Select and persist a suitable available voice per verified/provisional character using evidence of vocal range, delivery and contextual personality. Do not infer gender or identity from appearance alone.
4. OtakuMind contextual translation and expressive dialogue adaptation; preserve names, semantics and source timing; validate target language.
5. Visual Lip-Sync Director: estimate actual speaking intervals from synchronized mouth motion and audio; if face is occluded or turned away, use source-audio and turn-taking evidence. An earlier 1–3-second start is only a candidate when scene evidence and non-overlap constraints support it, never a blanket rule.
6. Supertonic 3 expressive synthesis using persisted character voice IDs; bounded generation-speed and waveform fitting. On overlong speech, automatically request a shorter meaning-preserving rewrite for **only the failing segment**, validate and checkpoint it, retry with a finite budget; never blindly raise compression or truncate phonemes. If no quality-preserving solution exists, report the precise segment rather than fabricate success.
7. Perceptual and semantic QC: speaker consistency, original-to-translation fidelity, voice and emotion suitability, intelligibility, lip/timeline alignment, clipping, background-music leakage; selectively regenerate failing segments.
8. Separate original dialogue from music/SFX, mix dubbed dialogue while preserving ambience, export and validate playable MP4. Persist checkpoints and support background/resume.

## Four reference intelligence layers
- Anime identification: anime title/ID, season, episode, characters, visual reference embeddings and source provenance.
- Scene timeline: scene boundaries, source timestamps, original dialogue, verified speaker identities and reference offsets.
- Character intelligence: verified identity, canonical aliases, personality/relationships, vocal traits and stable voice casting.
- Expression intelligence: scene/segment emotion, shouting/whispering/crying, speaking pace, facial and mouth activity, confidence.

Reference records must be genuine, source-bound, traceable and rights-reviewed before distribution. Private development records live outside the APK. Metadata alone cannot provide every episode's exact script or expressions. Unknown titles and unmatched clips must still work through live analysis with provisional IDs. Never treat an unverified database hit as ground truth.

## Integration contracts and gates
- Original dialogue, segment ID and source timestamps remain immutable unless a separately validated timing-plan update is applied.
- Evidence includes model identity/version, timestamp, source ID, confidence, and modality; uncertainty propagates to OtakuMind.
- Stable speaker-to-voice mapping is persisted before synthesis. A named character match needs independent corroboration.
- Timing plan specifies permissible start/end, neighboring turn constraints and visual confidence; no unverified overlap.
- Each adapted line is checked for language, semantic preservation, length and synthesis fit; bounded retries are durable.
- Genuine checkpoint acquisition is not equivalent to ONNX conversion, bundled installation or on-device inference.
- A green Flutter analyzer/build is not evidence of audiovisual quality. Require end-to-end device tests and long-video regression.

## Current implementation boundary (2026-10-25)
Whisper, ECAPA, OtakuMind translation/refinement, Supertonic synthesis, soundtrack/export stages and project checkpoints are wired. The bundled anime catalog is empty (`android/assets/anime_scene_catalog.json`); private loader and catalog validator exist. Light-ASD pretrained PyTorch checkpoint acquisition is configured, but Android ONNX export/inference and anime-domain calibration are not verified. OtakuMind is not yet a fully integrated evidence-based central casting director. Automated segment-specific rewrite/retry is missing, and real device reports show excessive duration compression at 70% synthesis. This document adopts the intended pipeline without misrepresenting its implementation status.

## Delivery sequence
P0: duration rewrite/retry and regression/device verification.
P1: typed evidence/decision interfaces, stable OtakuMind casting orchestration, genuine anime catalog ingestion, Light-ASD conversion and synchronized Android inference.
P2: expression and lip-timing director, source-grounded reference retrieval and selective perceptual QC.
P3: expanded verified reference coverage, long-video reliability, performance and release acceptance.

## Hybrid direction update
OtakuMind coordinates optional online reference lookup, original dialogue verification, character attribution, and expression/acting direction. Translation and speech synthesis remain separate local engines. A reference match must be checked against the imported clip. Unknown identities remain unknown. This is a target design, not verified model functionality.

### Director data handoff
For each source segment, the intended director record contains original-language dialogue, immutable source timestamps, reference provenance, a provisional acoustic speaker, an optional corroborated character ID, expression evidence, emotional delivery guidance, confidence, and a stable voice selection. OtakuMind combines reference, audio and visual evidence; an on-screen character is not automatically the speaker. The local translation model adapts the verified line, and the local voice model renders it. A missing online match falls back to local transcription. Actual inference and device quality require separate validation.
