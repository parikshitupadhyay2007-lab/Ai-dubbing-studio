# OtakuDub recovery — Phase 0 audit (in progress)

Baseline: `main` commit `05cab7fb1759d91ae081334777a3ed2354be0de1` (2026-10-24).
Work branch: `recovery/phase-0-audit`. Do not treat a successful APK build as evidence of perceptual dubbing quality.

## Verified from inspected source
- Flutter application root is `android/`, not repository root; `android/pubspec.yaml` reports version 0.5.0+5.
- `android/lib/services/dubbing_pipeline.dart` implements staged processing, transcript and casting checkpoints, translation per segment, synthesis clip ID/timing checks, soundtrack separation/mix and export file checks.
- `android/lib/models/dub_project.dart` serializes segment identity, text, timing and confidence but previously had no explicit human-verification provenance.
- `android/lib/main.dart` provides manual resolution of uncertain speakers and deliberately sets model confidence to 0.
- `android/lib/services/segment_quality_control.dart` previously rejected all confidence <= 0. This meant manually resolved speakers could be blocked even after the user reviewed them.
- Progress shown in `android/lib/main.dart` is stage-based (10/25/40/55/70/85/100), not true measured work.
- `android/lib/services/segment_quality_control.dart` defines waveform measurement checks, but the inspected pre-synthesis pipeline call passes no audio measurement. Perceptual validation is NOT established.

## Implemented on the recovery branch
- Separate persisted `speaker_manually_verified` from acoustic `speaker_confidence`; default false for old checkpoints.
- UI sets this flag only when an unresolved segment is explicitly assigned by the user.
- QC accepts a zero model-confidence value only with explicit human verification and valid speaker identity; still requires a voice.
- Added `android/test/manual_speaker_quality_test.dart` covering accepted/rejected identities and serialization.

## Unverified / must not claim completed
- Dart/Flutter test execution and full Android compilation have not yet run on the new branch.
- Physical model files and their hashes, inference behavior, licensing and Android ABI compatibility.
- Japanese-to-Hindi/English semantic translation, speaker accuracy, Supertonic audible output and expressive delivery.
- Measured separation leakage/artifacts; output duration fit; end-to-end 30-second export on the actual target phone.
- Background/thermal/memory behavior and long-episode resilience.

## Exit gates for Phase 0
1. Inventory every model asset and verify expected hash, provenance, licence, size and runtime interface.
2. Run `cd android && flutter test test/manual_speaker_quality_test.dart`.
3. Run `cd android && flutter analyze` and resolve newly introduced issues.
4. Establish a fixed, lawful 30-second reference fixture and expected transcript, speaker and translation annotations.
5. Preserve the baseline and do not merge until CI/tests and actual device regression checks pass.

## Follow-up issue discovered during inspection
In `android/lib/main.dart`, the error-to-manual-review UX recognizes the messages 'no verified voice role' or 'Speaker identification is incomplete', whereas `dubbing_pipeline.dart` can throw 'ECAPA could not establish an acoustic identity...' for the unresolved-speaker case. Align error types rather than matching fragile prose.
