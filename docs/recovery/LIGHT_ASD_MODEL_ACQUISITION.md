# Trained active-speaker model acquisition

Selected upstream: Junhua Liao et al., Light-ASD (CVPR 2023), https://github.com/Junhua-Liao/Light-ASD, upstream revision `ed38c232de5efe0261dbd68627c0ade7cdfe14eb`. This repository publicly offers pretrained model weights under a repository MIT licence; review model-specific and training-data conditions before distribution.

Run GitHub Actions workflow **Acquire trained Light-ASD checkpoint** on recovery/phase-0-audit. This uses `.github/scripts/acquire-light-asd.py` to clone exactly the pinned upstream revision, reject empty/LFS-pointer checkpoints, and produce an artifact containing real upstream `.model` files with SHA-256 manifest. This manual workflow has been ADDED, not asserted to have executed successfully.

IMPORTANT: upstream checkpoints are PyTorch state dicts and cannot be renamed `.onnx` or loaded directly by ONNX Runtime Android. Next: inspect upstream architecture and preprocessing; build reproducible eval-mode ONNX export with fixed input/output schema; compare PyTorch and ONNX outputs on actual synchronized audio/face-track windows; integrate aligned video track extraction and audio feature extraction; benchmark on anime (including offscreen/static-mouth) and calibrate scores. Do NOT mark `model_verified` true or replace the explicit Kotlin missing-model error until all steps pass. Model identifies active visible tracks, not named anime characters.

## Recovery-branch acquisition integration

The acquisition workflow now also triggers on pushes that change its script or workflow on `recovery/phase-0-audit`. It retrieves genuine upstream pretrained Light-ASD PyTorch checkpoints, copies the upstream MIT LICENSE into the artifact, and validates checkpoint sizes, SHA-256 digests, and license checksum. Download the `trained-light-asd-pytorch-checkpoints` artifact from the successful workflow run; no invented .onnx file or placeholder weight is committed. The repository tracks the acquisition procedure and exact upstream revision, **not the heavyweight binary itself**. Verify that the run succeeds before using the weights.

A trained active-speaker detector uses synchronized mouth/face video **and original audio**; it does not decode exact words from animated lips or independently justify shifting an offscreen speaker's dialogue 1–3 seconds. This remains an acquisition-only step. Android ONNX conversion, inference, anime-domain calibration and integration with the dialogue timing director are still pending.
