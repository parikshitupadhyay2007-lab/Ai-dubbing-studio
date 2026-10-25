# Target pipeline versus implemented recovery integration

1. Video import: existing project repository and media import.
2. Whisper: native transcription, detected language, timed segment checkpoint.
3. ECAPA: native acoustic identification. It owns speaker IDs. A partial outcome is retained.
4. Visual/reference: optional frame hashes and corroborated scene matcher; the checked-in anime reference catalog is currently empty. Frame hashes and scene matches do not prove that a visible character spoke a given line.
5. OtakuMind identity fusion: `CharacterIdentityFusion` persists speaker-by-speaker evidence provenance and provisional identity, without changing acoustic IDs or timestamps. Per-line lip/mouth alignment and verified named character links are not implemented.
6. Confidence gate: acoustically identified speakers proceed to automatic casting. Unknown lines remain explicitly unresolved and prompt review; a scene suggestion cannot bypass the gate.
7. Automatic caster: persistent speaker-to-Supertonic style assignment, before unresolved-line review. Previous compatible assignments are reused. Roles are *not inferred* without actual evidence.
8. OtakuMind director: existing translation, optional refinement, verification.
9. Supertonic/native synthesis: existing pipeline validates clip IDs, speaker/voice assignments and timing.
10. Audio QC, separation and MP4 export: existing deterministic pre-synthesis checks and native mixing/export. Perceptual listening, ASR-backchecking, sound-separation leakage measurement and real-device quality are release gates, not established results.

## Remaining to deliver full architecture
- Obtain licensed/verifiable anime reference corpus and specify its per-character/per-line evidence schema.
- Implement native visual active-speaker/mouth alignment, including off-screen narration and shot changes.
- Validate speaker embedding/model checkpoint quality against labeled audio.
- Add evidence-driven vocal role classification with confidence, rather than assigning gender from a scene guess.
- Integrate measured post-synthesis QC, selective retry, and reproducible on-device fixtures.
- Verify actual model binary integrity, CI and an APK installed on device.

A passing Flutter analyzer or unit test alone does not verify native inference or dubbing quality.
