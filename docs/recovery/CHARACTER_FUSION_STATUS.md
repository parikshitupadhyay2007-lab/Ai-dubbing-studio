# Character-fusion implementation status

Implemented on recovery branch:
- Whisper retains immutable dialogue/timestamps.
- ECAPA provides acoustic speaker IDs; unknown lines are not relabeled by scene metadata.
- The OtakuMind director looks up optional corroborated scene context.
- The automatic caster assigns stable provisional Supertonic style IDs to every identified speaker **before** an unresolved line can pause processing.
- Partial casting is persisted and reused on resume. Existing explicit voice selections are preserved.
- Manual review is restricted to lines with unknown acoustic identity, with a voice-choice UI for any genuinely unassigned speaker.
- Regression tests cover partial auto-casting, stable voice reuse and no invented identities.

Not implemented / not verified:
- The checked-in `android/assets/anime_scene_catalog.json` is currently `[]`. There is no verified anime reference corpus available for identity fusion.
- `AnimeSceneCandidate.possibleCharacters` is scene-level advisory metadata, not a per-line acoustic-to-character link.
- Native visual mouth/activity tracking, cross-modal speaker alignment, reference licensing, speaker-role classification, and real-device perceptual TTS tests have not been established.
- Voice style selection without a proven role is provisional; it must not be presented as verified gender, age or named-character identity.
- The recovery quality workflow does not build an APK. Green static analysis/tests are not proof of real-world dubbing quality.

Acceptance gate for full character fusion: each character mapping must have explicit segment-level acoustic and visual/reference evidence, a provenance/confidence record, ambiguity handling, and benchmark validation on real anime dialogue. No model hallucinations may overwrite speaker IDs or timing.
