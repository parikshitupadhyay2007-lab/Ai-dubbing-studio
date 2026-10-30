# Department 01: executable verification protocol

The six original engines and five dramatic-intelligence capabilities must produce real,
source-bound inference, separately reviewed evidence and quantitative evaluation.
An ONNX load, metadata search, declared confidence, mock, or green CI cannot certify quality.

## Private clip baseline (not committed)

User-provided diagnostic asset: SHA256
`0c82a66d692769d1dfe5549ca4c858e4c08db93e1dfc3076cd9d88add2d694cf`;
duration 15,697 ms; H.264 720×1280; AAC 44.1 kHz. Private diagnostic only:
rights clearance not independently verified, annotations pending. Do not commit the media,
its frames, dialogue, or recognisable stills to a public repo or permanent model index.
A personal experiment is not equivalent to a rights-cleared distributable dataset.

## Independent dataset record

Each sample requires original/permission-cleared/public-domain evidence with licence scope,
provenance, source SHA256, scene boundaries, timed utterances, independently assigned
speaker IDs (unknown permitted), character recurrence, dramatic intent and timing.
Reviewer cannot be the same process that generated predictions. Preserve disagreement;
report inter-annotator agreement. Maintain separate development and held-out evaluation
sources. Avoid leakage from reference index into held-out identity evaluation.

## Measured real inference

For each capability record model version and actual model SHA256, input/output signatures,
source-bound prediction, independent review, unknown/abstention behaviour and measured
metric. Report shot boundary precision/recall with 250 ms tolerance, speaker attribution
accuracy *including abstentions*, confusion matrix and coverage. Also evaluate anime/episode
known-vs-unknown, character re-identification, visual emotion, audiovisual speaker match,
timing error and continuity contradictions on annotated footage. Assess data slices by
style, occlusion, narration, overlap, scene cuts, dubbed/original audio and duration.
Do not derive a professional threshold from one 15-second clip; define thresholds before
evaluating an adequately sized held-out set.

Run: `python3 tools/benchmark_department01.py --reference private_reference.json --prediction actual_inference.json --source path/to/local/video.mp4 --output diagnostic.json`.
This benchmark is intentionally non-certifying, even with high scores.
Run `python3 tools/department01_acceptance.py evidence.json` for structural
eleven-capability, rights and device receipts; its receipts must be independently audited.

## Physical Android validation

Use the APK from the exact revision and SHA256 recorded in the evidence. On the Redmi
Note 13 Pro 5G, record the actual Android build fingerprint (not an invented label),
model import hashes, each native ONNX input/output shape, model execution errors,
peak memory, thermals, duration, per-scene timings, source SHA256, and output evidence.
Test foreground, screen-off/background restrictions, interruptions, resume, an
unknown speaker, multi-character sections and full-length 20–30 minute source.
Capture instrumentation/logcat reports with private user data redacted, identify
physical device vs emulator and independently review. Never mark a test run
successful because the APK merely installed or exported a file.

## Release gate

Only unlock Department 02 after all eleven real-engine receipts, source-bound scene
bible review, lawful evaluation, held-out quality benchmarks and physical Android
validation are accepted. Until then maintain `department02_unlocked=false`.

## Current baseline build

Run the branch verification workflow before adding further inference changes. The APK is a diagnostic build, not a professional dubbing certification. Keep source-bound test reports and distinguish Flutter unit tests from actual Redmi device results. Do not unlock Department 02 based on a successful APK build alone.

## Locked execution priorities (implementation order)

These are six milestones **inside Department 01**, not six additional departments.
An implementation milestone does not change an engine state to verified without its
source-bound output and independent review. Department 02 remains locked.

1. **DINOv2 on Android:** load the pinned ONNX weights; verify decoded-frame RGB,
   resize/crop/normalisation and input/output signatures; compare actual Android
   embeddings with reference vectors; record model SHA256, latency, peak memory,
   thermals and corruption/incompatibility failures on the physical device.
2. **Scene segmentation:** combine source-bound shot signals and visual embeddings
   into coherent scene intervals, preserving cuts and uncertainty; benchmark against
   independently annotated boundaries with the stated tolerance.
3. **Recurring character recognition:** fuse tracked visual evidence, speaker
   embeddings and temporal continuity; use stable local IDs and abstain when the
   evidence does not support a named identity; measure re-identification and errors.
4. **Anime and episode recognition:** compare against a rights-cleared, versioned
   reference index; retain provenance and known-vs-unknown thresholds; no inferred
   title/episode is treated as fact without independent support.
5. **OtakuMind dramatic intelligence:** produce evidence-linked narrative intent,
   emotion/performance, audiovisual dialogue attribution, timing constraints and
   character relationship memory for each scene. Independent reviewer rejects
   omissions, unsupported claims, contradictory or stale evidence.
6. **Independent acceptance:** validate all original six engines plus five dramatic
   capabilities, held-out benchmarks, rights records, device receipts and the
   source-bound Scene Bible before issuing any handoff.

The first actionable milestone is real DINOv2 inference on the Redmi device, not
merely exporting or loading a model. Do not use placeholder percentages as progress.
