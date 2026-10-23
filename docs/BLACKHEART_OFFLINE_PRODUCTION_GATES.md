# Blackheart / OtakuDub — offline production hardening gates

Status: engineering acceptance plan, **not** a claim of production readiness.

## Priorities and decisions

1. **Translation correctness first.** Keep the existing offline engine until real failing segments are captured and reproduced. Reject reasoning, wrong-script, unchanged-source and malformed outputs. Preserve validated translations if optional refinement fails. Benchmark alternatives (including CTranslate2/NLLB) on target ARM64 devices before replacing the engine; do not assume sub-50 ms inference or accurate anime localization.
2. **Crash-safe jobs.** Existing project checkpoints are a foundation, not transactional segment-cache recovery. Next implement atomic output writes and durable stage/segment manifests; verify process-death recovery after each expensive stage. Do not promise OEM battery exemptions prevent termination.
3. **Asset delivery and storage.** Audit actual APK/AAB and extracted model sizes first. Keep models modular and license-verified. Investigate Play Asset Delivery for Play builds and user-initiated import for non-Play builds. Model mapping depends on each runtime and file format; mmap is not universal.
4. **Audio preservation.** Validate existing demixing and mixing against speech leakage, clipping and timing. VAD-guided sparse separation requires padded windows and crossfades; ducking is a clearly labeled fallback, not equivalent to isolation.
5. **Export.** Verify the current native video export copies compatible video streams without re-encoding, and handles unsupported input containers and audio encoding errors.
6. **Commercial protection.** Signed offline entitlements can deter casual tampering, not eliminate piracy. Avoid treating Android ID / Build.FINGERPRINT as secure secrets or hardware keys. Verify model redistribution rights separately from application licensing.

## Device acceptance evidence required

- Record model sizes, APK/AAB size, peak PSS/RSS and free disk before/after a 25-minute job on each supported device tier.
- Capture stage durations, battery consumption, temperature and thermal throttling signals. The proposed 750 MB RAM, 1.8 GB disk, and 48 C thresholds are provisional and must be validated against device capabilities and sensor definitions.
- Inject process termination at transcription, diarization, translation, synthesis, mixing and export; verify completed work survives and output files are intact.
- Measure per-segment speech alignment and cumulative drift; proposed tolerance ±120 ms, subject to listening tests.
- Test Japanese→Hindi and Japanese→English on held-out multi-speaker clips, with human review of meaning, role consistency and naturalness.
- Audit upstream licenses and checkpoint provenance before distribution; require an actual signed release install and device listening test before launch approval.

## Release blockers

Do not declare the app production-ready while a licensed, compatible speaker checkpoint is absent; translation quality fails real-world tests; or the above device evidence is missing. Avoid unverified throughput, anti-piracy or thermal guarantees.
