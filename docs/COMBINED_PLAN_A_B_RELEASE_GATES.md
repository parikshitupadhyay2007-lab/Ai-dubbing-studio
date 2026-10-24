# Combined Plan A + B — Release acceptance contract

Required processing order:
1. Uploaded video: validate source and resume checkpoint.
2. Whisper: timed dialogue, detected source language, immutable segment IDs.
3. OtakuMind: licensed catalog retrieval using dialogue and optional native sampled
   frame dHashes. No hit means UNKNOWN; do not invent an anime or episode.
4. Scene context: candidate anime/episode/reference start and possible characters.
   The reference timestamp is NOT a measured clip offset.
5. ECAPA: acoustic speaker clustering remains authoritative. A candidate
   character roster is not proof that a particular person spoke a segment.
6. OtakuMind Director: validated contextual translation and consistent
   speaker-to-style assignment. Unknown speaker segments remain blocked.
7. Supertonic 3: per-line speech, soundtrack separation and mixing, MP4 export.

## Implemented contracts
- Strict corpus builder and source provenance; empty bundled catalog by default.
- Optional Android native frame sampler (five timestamps), text/visual matcher,
  ambiguity abstention, regression tests, saved scene context.
- Existing immutable timing/identity checks, translation QC, native audio and
  asset checks, checkpoint recovery and signed APK workflow.

## NOT qualified yet (must not be marked complete automatically)
- Acquire explicit rights to actual anime scene/dialogue/frame corpus; populate
  catalog and measure accuracy against labeled held-out episodes/clips.
- Validate frame sampler against the reference hashing implementation on real
  clips and tune visual thresholds. Perceptual hash is retrieval, not a visual
  recognition model.
- Independently calibrate ECAPA with speakers disjoint from development data;
  address overlap, short dialogue and remaining unknown speaker at 25%.
- Run real Japanese-to-Hindi and Japanese-to-English translation listening and
  semantic tests, Supertonic expressiveness tests and MDX soundtrack quality.
- Complete at least one real-device, end-to-end dub with playable MP4, synchronized
  audio, speaker consistency, soundtrack preservation and measured resource use.
- Check release licenses and distribution permissions for every model/data item.

A green GitHub workflow qualifies compilation, static contracts, unit tests,
model-asset integrity and signing ONLY. No GitHub-hosted emulator/CI result
substitutes for missing licensed data or real-device listening acceptance.
Keep the build artifact explicitly labeled as test/release candidate until all
above checks have actual results.

## Single integrated scope and licensing policy
All Plan A and Plan B features remain IN SCOPE for the same combined build:
Whisper transcription; licensed anime catalog schema and indexing; visual scene
fingerprints; episode/timeline and annotated character candidates; acoustic
ECAPA verification; OtakuMind contextual directing; Supertonic dubbing; MDX
soundtrack preservation; MP4 output. No component is excluded simply because
its eventual reference data will require a license. Synthetic/owned records
may exercise every code path today. Real third-party records stay unbundled
until the necessary access and usage permissions have actually been granted.
A future commercial license is not retroactive permission to collect, train
on, redistribute, or bundle copyrighted material today. CI must test an
empty/no-match catalog and a rights-cleared fixture catalog alike.
