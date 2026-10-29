# Department 01 model integration and release gate

Development must continue without misrepresenting commercial clearance. Do not commit third-party weights, gated downloads, copyrighted anime reference media, or credentials unless the current grant explicitly permits the intended use and redistribution.

## Model registry (required per model)
- Engine and model ID, exact version, upstream URL and publisher
- Licence identifier and verbatim licence location, review date
- Permitted use: local evaluation, development, commercial use, modification, redistribution (record each independently)
- Exact SHA-256 of the weight file and required preprocessing/decoder version
- Acquisition mechanism: redistributable build asset, authorised user-supplied local import, or excluded pending permission
- Model card, supported input/output tensor contracts and known limitations
- Evaluation dataset provenance and benchmark results

## Integration policy
1. Implement native adapters and model-specific decoders independently of weight redistribution.
2. Include weights in CI/APK only when the existing grant permits that action. Otherwise use a licensed test model or authorised local import; never bypass access controls or copy gated files.
3. Never mark an engine verified based on metadata, simulated predictions, a successful session load, or a model's presence alone. Verify inference output and benchmark it.
4. The release gate fails if any shipped weight or reference dataset lacks verified commercial and redistribution rights. A plan to obtain a licence later is not clearance.
5. The research handoff remains blocked until all six engines have actual verified outputs and independent review. Release clearance and technical acceptance are separate gates.
