# Offline background soundtrack integration

The automatic pipeline now requires an installed instrumental MDX checkpoint before starting inference. It invokes `separateSoundtrack`, then `mixSoundtrack`, and passes the resulting stereo WAV to `exportVideo`. It fails closed: it never labels a dialogue-only export as background-preserving.

Candidate: **UVR-MDX-NET-Inst_HQ_3 ONNX**, instrumental output. This is a candidate, not yet approved by OtakuDub reference-audio parity testing.

Install both files in the Android app documents directory at `otakudub/models/`:
- `separation.onnx`: the actual checkpoint
- `separation.json`: metadata for that exact checkpoint

Manifest shape (replace the placeholders only after actual ONNX inspection and independent reference-audio verification):

```json
{
  "model_id": "UVR-MDX-NET-Inst_HQ_3",
  "stem": "instrumental",
  "reference_validated": true,
  "sha256": "64-character SHA-256 from the exact inspected ONNX binary",
  "input_name": "actual ONNX input tensor name",
  "output_name": "actual ONNX instrumental output tensor name"
}
```

The `reference_validated` field records review status; it is **not** a cryptographic signature or independent trust anchor. Do not mark true without validating output stem polarity and transform parity against reference output, then pin the audited checksum in a future app release. Native code verifies that the model file matches the manifest checksum and ONNX metadata. If the model or manifest is missing or invalid, automatic dubbing stops before transcription.

Remaining acceptance tasks: test with a genuine ONNX checkpoint, confirm output shape and instrumental stem polarity, validate short/final chunks and audio quality, check performance and run consolidated Android build. No APK build was run during these code commits.
