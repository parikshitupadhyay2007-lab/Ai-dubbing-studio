# Bundled voice model provenance and release restrictions

The Piper inference runtime and individual voice datasets have separate licensing terms. A repository-level MIT label does **not** override dataset/model-card restrictions.

| APK profile | Upstream voice | Upstream model card / dataset restriction |
| --- | --- | --- |
| hi_hero | hi_IN-pratham-medium | Model card identifies CC BY-NC-SA 4.0 training dataset |
| hi_heroine | hi_IN-priyamvada-medium | Model card identifies CC BY-NC-SA 4.0 training dataset |
| en_hero | en_US-lessac-medium | Blizzard 2013 Lessac dataset; check its separate license |
| en_young_male | en_US-hfc_male-medium | Model card identifies CC BY-NC-SA 4.0 training dataset |

Source model cards: https://huggingface.co/rhasspy/piper-voices/tree/main

The checksum verification in CI protects downloaded bytes; it does not establish permission for commercial distribution. Before a commercial launch, obtain appropriate rights or replace restricted checkpoints with commercially cleared alternatives. Voice-role labels describe the intended synthesis profile; they are not evidence of a source speaker's identity or gender.
