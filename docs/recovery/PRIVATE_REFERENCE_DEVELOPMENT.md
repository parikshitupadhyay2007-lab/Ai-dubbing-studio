# Private anime reference development

The app loads bundled `assets/anime_scene_catalog.json` plus optional private app-support file `otakudub/private_anime_scene_catalog.json` under the path returned by `getApplicationSupportDirectory()`. This is an ingestion path for privately supplied reviewed records, NOT acquisition of a corpus. Both pass `VerifiedAnimeCatalog`, with duplicate reference keys rejected. Developer samples must never be presented as licensed/verified unless independently checked.

Record schema example (SCHEMATIC ONLY; not authentic anime data):
```json
[{
  "anime_id": "test-fixture", "episode_id": "fixture-1",
  "title": "Non-distributable fixture", "provenance": "developer-authored synthetic test",
  "redistribution_license": "developer-owned synthetic fixture",
  "source_id": "fixture-reference-1", "start_seconds": 0,
  "dialogue": ["synthetic dialogue 1", "synthetic dialogue 2", "synthetic dialogue 3"],
  "speaker_annotations": [{
    "segment_id": 1, "track_id": "track-1",
    "character_id": "fixture-character-1", "reference_id": "fixture-reference-1",
    "source_hash": "must-equal-measured-native-source-hash"
  }]
}]
```
Reference segment IDs and track IDs must align with actual observed segment/track IDs, and source_hash must match the native measurement. Such metadata yields a candidate, not a verified identity. Adding a string to `redistribution_license` does not prove rights.

The Kotlin `analyzeActiveSpeakers` method now returns ACTIVE_SPEAKER_MODEL_NOT_INSTALLED explicitly until a real synchronized audio/video inference implementation and verified weights exist. The Dart pipeline gracefully preserves acoustic casting. No pretrained weights, authorized real catalog records, benchmark measurements, or calibrated identity scores have been fabricated. An Android build and CI pass have not been observed for this checkpoint.
