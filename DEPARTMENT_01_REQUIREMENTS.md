# Department 01 acquisition and integration requirements

This is a technical acquisition register, not a claim that third-party weights or anime data have been obtained. Do not bundle weights until their specific terms and SHA256 have been checked.

## Runtime now in branch
- Flutter/Kotlin, pinned Android ONNX Runtime, SHA256-verified private ONNX import, bounded real float32 inputs/outputs.
- Native RGB_U8_INTERLEAVED frame extraction (32–384 square), Dart RGB-to-CHW normalization with caller-specified mean/std, real ONNX embedding output -> local similarity retrieval.
- Full-source timestamped 8x8 luminance sampler is only for shot-discontinuity candidates; it is not visual model input.
- Dependency-aware six-engine coordination, evidence graph, source verification, and locked handoff.

## Remaining assets and implementations per engine
| Engine | Assets required | Mandatory real acceptance test |
|---|---|---|
| Anime / episode recognition | Appropriate licensed visual encoder; authorised labelled anime/episode reference frame and temporal index; exact preprocessing/embedding specification | Held-out episode identification, scene-independent temporal match, unknown-title rejection |
| Hierarchical scene segmentation | Video shot-change and fade detection, time continuity features, scene grouping model or independently evaluated segmentation algorithm | Annotated cuts, dissolves, shot-versus-scene benchmark |
| Visual understanding | On-device image/temporal model, label ontology and calibration data | Frame-grounded action/emotion evidence and abstention on ambiguity |
| Character tracking | Licensed detector/visual encoder, association tracker, available audio speaker embedding and active speaker model | Recurring character IDs over cuts, offscreen speaker separation, unknown-person rejection |
| Context research | Authorised source-attributed offline reference database, indexer, versioned data sources, opt-in remote metadata only | Provenance per fact, contradiction/unknown handling, no footage/dialogue upload |
| Continuity intelligence | Temporal cross-modal reconciliation and targeted-review logic, model output evidence and reference QA set | Contradiction detection, stale evidence invalidation, independent reviewer pass |

## Model acceptance record (one per asset)
Model name, exact upstream revision, publisher, original licence URL, evaluated allowed uses, asset URL or documented local authorised import, SHA256, input and output names/types/shapes, normalization and decoder, peak Android memory, evaluation dataset licence, benchmark methodology, held-out scores and uncertainty thresholds.

## Boundaries
- The ONNX Runtime official Android sample is an integration reference, not a trained anime identity recogniser: https://onnxruntime.ai/docs/tutorials/mobile/deploy-android.html
- PySceneDetect is a BSD-3-Clause shot detector reference and a Python tool, not a drop-in offline Android scene understanding model: https://github.com/Breakthrough/PySceneDetect
- Any missing model, source rights, device validation or benchmark stays an explicit blocker. Do not invent a SHA, download, dataset, model performance or licence grant.
- Commercial-release clearance is independent of technical acceptance, but restricted asset acquisition must remain authorised during development.
