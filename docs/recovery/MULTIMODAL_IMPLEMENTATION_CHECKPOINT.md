# Multimodal implementation checkpoint

Implemented in this checkpoint:
- Evidence IDs alone no longer mark named-character identity as verified. Submitted IDs are retained as unverified provenance.
- `ActiveSpeakerEvidenceGate` validates temporal coverage of acoustic segments by candidate native visual-track outputs; it withholds conflicting and weak candidates.
- Added regression tests for conflicting tracks, non-covering timestamps, and unverified identity metadata.

Still required before actual visual character recognition is operational:
1. Legitimately sourced and evaluated active-speaker model weights and a native Android inference implementation that outputs real `VisualSpeakerEvidence` measurements. No such inference engine was created by these Dart-only changes.
2. Actual authorized anime reference records. The current packaged catalog is empty; fabricated dialogue or licensing assertions must not be used.
3. A calibrated, audited cross-modal matching producer correlating validated track IDs with character annotations and speaker embeddings. Nonempty identifiers are not authentication.
4. CI pass on the latest commit, Android build and measured accuracy on held-out anime samples.

Keep main untouched until all relevant gates are established. Never claim a release-ready APK from a green Dart workflow.
