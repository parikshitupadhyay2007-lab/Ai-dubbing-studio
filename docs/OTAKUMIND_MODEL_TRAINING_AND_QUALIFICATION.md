# OtakuMind evidence, model adaptation and release qualification

OtakuMind is an **offline dubbing director**. Do not advertise anime, episode,
character or timeline identification based on a language-model guess. A scene
candidate must be corroborated by permitted reference evidence. The bundled
scene catalog starts empty on purpose.

## Data contract

Create an explicitly licensed JSON dataset with schema, license, source,
rights evidence, and scenes. Each scene has anime_id, title, episode_id,
start_seconds, at least three original-language dialogue lines, and character
metadata with id, name and annotated role (unknown/male/female/youthful).
Build the distributable index:

```bash
python3 tools/build_anime_scene_catalog.py private/rights-cleared.json \
  --output android/assets/anime_scene_catalog.json
python3 tools/evaluate_anime_scene_identification.py \
  --catalog android/assets/anime_scene_catalog.json \
  --held-out private/held-out-scenes.json --report private/scene-report.json
```

Do not place proprietary subtitles or images in GitHub without redistribution
permission. Visual lookup helper: `tools/match_anime_reference_frames.py`
compares perceptual hashes against locally supplied, rights-cleared frames.
It is **not** integrated with Android frame extraction/scene fusion yet.

## Each model requires a DIFFERENT adaptation route

| Engine | Adaptation | Required independent evidence |
|---|---|---|
| Whisper Large-v3 Turbo | Domain ASR fine-tuning only with aligned licensed speech/transcripts, or lexicon-based correction | held-out Japanese/English WER/CER, timing drift, anime/music robustness |
| ECAPA | Calibrate cosine thresholds with speakers/episodes disjoint from development; optionally fine-tune with permissioned labeled speaker recordings | DER/JER, false identity merges/splits, overlap and unknown rate |
| Qwen3 OtakuMind | Retrieval first. Consider supervised/LoRA adaptation on licensed scene-to-identity/context examples, with strictly structured evidence and refusal/abstention labels | unknown-scene false-positive rate, exact episode and scene coverage, hallucination audit, translation adequacy |
| Supertonic 3 | Use official supported checkpoint; any additional style/voice training needs consented voices and upstream-authorized recipe | Hindi/English intelligibility, speaker consistency, expressiveness and real-device speed |
| UVR MDX | Evaluate before adapting with paired music/dialogue stems licensed for training | vocal bleed, accompaniment preservation, sound quality and memory |
| Piper | Legacy, not active production engine | remove only after Supertonic device qualification |

Do **not** mark one model trained because its pretrained weights are downloaded
or a unit test passes. Do not fine-tune on scraped commercial anime episodes,
copyrighted scripts or identifiable performer voices without appropriate rights.

## Production gates

1. Catalog provenance and independent held-out evaluation must pass.
2. Identification must abstain on ambiguous/unknown clips, not invent characters.
3. Visual and dialogue evidence must agree on anime and episode, while acoustic
   diarization remains the authority for who actually spoke.
4. Role prediction needs explicitly labeled supervision and a separate
   uncertainty-aware validation set; text character descriptions alone do not
   establish an acoustic voice role.
5. Verify all ONNX/GGUF hashes, then test each engine's real inference.
6. Full on-device video acceptance: import -> transcription -> diarization ->
   evidence retrieval -> contextual translation -> role-consistent casting ->
   Supertonic audio -> MDX separation -> mixing -> valid playable MP4.
7. Save latency, peak memory, speaker/translation accuracy, A/V sync and
   listening review. A green APK build is not the same as a successful dub.

**Current limitation:** no licensed anime corpus or labeled training/held-out
audio has been supplied, no training job has been run, and visual lookup is a
developer tool rather than an Android runtime. This document is a release
qualification contract, not a claim of trained models.
