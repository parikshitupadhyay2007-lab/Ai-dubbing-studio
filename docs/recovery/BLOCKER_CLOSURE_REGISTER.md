# Blocker closure register

This register separates code corrections from empirical release evidence. No unverified capability is called complete.

| Blocker | Current disposition | Release acceptance evidence |
|---|---|---|
| All speakers shown as blank in review | UI now restores/preselects provisional voices for recognized speakers and proposes a voice after an unresolved line is manually attributed. Manual choices remain editable. | Flutter analysis and on-device casting-dialog test |
| Cast stopped before identified speakers got voices | Pipeline casts identified speakers first and persists checkpoint. | 5-of-6 speaker recovery fixture and Android resume |
| Speaker identity versus character name conflation | Acoustic IDs and named-character evidence are stored separately; invalidating reassignment removes stale character link. | Ground-truth paired speaker/video sample |
| Scene-level guess represented as character proof | Evidence structure requires segment-scoped linkage; identifiers alone cannot authenticate an external evidence producer. | Implement and audit actual visual/reference evidence providers |
| Empty anime catalog | Still empty; cannot legally or accurately fill with invented franchise metadata. | Supplied licensed, validated corpus and provenance |
| Native active-speaker visual detection | Not implemented. Existing frame hashes are for scene corroboration, not lip/activity attribution. | Native model, frame/audio alignment fixtures and confusion matrix |
| Role-matched automatic voice | Provisional preset allocation only; cannot infer role from ECAPA alone. | Trained/evaluated role features and acoustic evidence; human QA |
| Supertonic intelligibility and expressive quality | Existing synthesis integration; not verified from repository edits. | Real APK, listened Japanese→Hindi/English clips, language/voice QA |
| Audio separation and export | Existing code with structural checks, but quality not established. | Leakage/artifact measurements, long-video export tests |
| Bundled weights | Required binary identity and integrity not established by filename/size checks. | Checksums, licensing, actual ONNX/GGUF inference and Android memory tests |
| Recovery CI | Analyzer and unit test workflow exists, latest result not confirmed from GitHub connector. | Successful run on latest commit |

Do not release or describe the complete professional automatic dubbing pipeline as verified before these gates pass.
