# Phase 0 model verification

This is a source-level checklist. Declared paths do not prove binary availability or successful inference.

| Engine | Declared location | Required evidence |
|---|---|---|
| Whisper | android/assets/models/whisper.bin | Actual bytes, checksum, detected-language and transcription fixture |
| OtakuMind | android/assets/models/otakumind.gguf | Actual bytes, checksum, prompt-template and translation fixture |
| Speaker identification | Native ECAPA implementation to be traced | Checkpoint, embedding dimensions, stable speaker test |
| Supertonic | android/assets/models/supertonic3/ | ONNX graphs, voice styles, Hindi and English audible tests |
| Sound separation | android/assets/models/separation.onnx | Checksum, graph input/output and reference audio test |

Next gates: inventory actual repository assets; validate the installed model bytes on Android; run Flutter tests and analysis; then run a reproducible short-video dubbing fixture. Do not mark a model verified on the basis of a filename or size alone.
