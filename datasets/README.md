# OtakuDub dataset acquisition status

Registry: `datasets/acquisition_registry.json`.
Script: `tools/acquire_training_data.py`.

**Source links are not local datasets. No training run has taken place.**
Large corpora must stay in a private machine/workspace, not the Git repo or
Android APK. Treat each source's current license, privacy rules and model-use
terms as authoritative; a source named here does not automatically grant a
commercial dubbing-model license.

## Immediate safe, publicly downloadable test corpus

OpenSLR LibriSpeech `dev-clean`, CC BY 4.0, English ASR validation:

```sh
python3 tools/acquire_training_data.py --list
python3 tools/acquire_training_data.py --id librispeech-dev-clean --accept-source-terms
```

This downloads ~337 MB to the ignored `private_datasets/` directory when
run on a machine with network, records SHA-256 and origin, and does not extract
or commit the archive. Preserve source attribution. This is read speech,
**not** independently labeled anime dialogue or an ECAPA identity dataset.

## Access and rights gates for remaining sources

- **FLEURS**: obtain supported Japanese, English and Hindi subsets through
  its official data card only after confirming current license and upstream
  source terms; prepare train/dev/test partitions by speaker.
- **Common Voice**: obtain exclusively through Mozilla Data Collective with
  its account/authorization process as applicable. Do not mirror or rehost.
  Common Voice prohibits attempts to identify its speakers; use solely for
  permitted ASR work. Follow participation-age and guardian rules.
- **VoxCeleb**: underlying audiovisual rights require review before any
  commercial use. A research dataset is not automatic permission to ship
  trained commercial identity models.
- **OtakuMind**: create original fictional scene fixtures immediately for
  software correctness; to recognize real anime, secure licensed scene
  reference dialogue, episode timings, character labels, and frame usage.
  Populate the catalog via `tools/build_anime_scene_catalog.py`. Do not
  scrape AniList or commercial subtitle/streaming services into a dataset.
- **Supertonic**: use the existing pretrained engine while obtaining
  explicitly consented voice recordings for evaluation. A checkpoint license
  does not imply a supported public voice-training recipe.
- **MDX**: record or license isolated dialogue, effects, and music stems,
  render known mixes, and evaluate separation on withheld combinations.
  DNS Challenge mixes multiple upstream licenses, which must be reviewed
  item by item. MUSDB18 is not a default commercial training source.

## Evidence record to create per acquisition

Record dataset version, acquisition date, source URL, precise license and
limitations, rights holder/consent documentation, SHA-256 of each artifact,
purpose, allowed commercial use, split policy, and dataset deletion/update
policy. Do not put personal consent documents into Git.

Next milestone: a small, rights-cleared, manually verified held-out evaluation
pack containing timed dialogue and separate speaker labels, plus a genuine
complete dub on an Android device. Do not interpret CI green as training success.
