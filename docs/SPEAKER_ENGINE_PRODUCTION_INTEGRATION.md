# OtakuDub professional speaker engine — integration contract

Status: **BLOCKED — no trained model is approved or bundled**. The current default `SpeakerDiarizer.identify` uses five handcrafted acoustic features. Its outputs are provisional and must not be advertised as production diarization.

## Selected candidate for evaluation (not deployment)

`speechbrain/spkrec-ecapa-voxceleb` is an evaluation candidate, not an approved Android artifact. The source checkpoint is PyTorch/SpeechBrain with model-specific 80-bin log-Mel preprocessing and normalization. The existing `SpeakerOnnxExtractor` accepts **only fixed-length raw Float32 PCM [1, N]** and cannot correctly execute this candidate. Do not rename/export only the embedding network and feed it raw PCM. A professional implementation must export the complete verified preprocessing + embedding inference contract, or implement and parity-test the exact frontend in Kotlin/native code.

## Required reproducible evidence before wiring MainActivity

1. Pin source checkpoint revision and weights SHA-256; independently confirm license for commercial use and redistribution, including dependencies and model provenance.
2. Record reference Python inference outputs on a frozen, legally usable evaluation set (short, long, noisy, emotional, overlapping speech and silence). No source evaluation recordings or personal speaker embeddings in the APK.
3. Export ONNX with explicitly named inputs/outputs, dimensions, normalization, sample rate, dynamic/fixed window policy and silence handling. Compare normalized Android ONNX embeddings against reference inference on the same waveforms; document cosine-distance deviations and numerical tolerances.
4. Measure peak memory, processing time and thermal behavior on representative Android devices; verify model hash on-device before loading.
5. Calibrate match and new-speaker thresholds on development speakers, then independently evaluate on held-out speakers and recordings using `tools/calibrate_speaker_embeddings.py` and `tools/evaluate_speaker_diarization.py`. Report false acceptance, false rejection, unresolved/overlap rates and per-scene identity consistency. Never tune thresholds on the final test set.
6. Produce real license, held-out evaluation and Android device evidence; use `tools/verify_speaker_model_release.py` as a **manifest consistency check**, not a substitute for independent review.
7. Only then update `MainActivity.identifySpeakers` to load the verified pack and pass its trained extractor plus calibrated thresholds into `SpeakerDiarizer.identify`. Keep unknown identity on ambiguous/overlapping dialogue. Do not silently fall back to handcrafted features when a production pack is absent or fails.

## Acceptance

No trained speaker pack is shipped until the source, export, parity, evaluation, licensing and on-device evidence are all verified. CI compilation and synthetic unit tests alone do not demonstrate speaker recognition accuracy.
