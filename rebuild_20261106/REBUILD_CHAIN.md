# Rebuilding the preserved runtime chain

This repository preserves source overlays and build tools. It is **not a self-contained asset distribution**: two separately retained original archives are required. Obtain them through the project owner's private storage; no private storage IDs or links are published here. REBUILD_HASHES.json specifies their exact byte sizes and SHA-256 values. Do not substitute an old root-project build.

## Inputs and fresh workspace

Copy the authorized original playable archive to `rebuild_20261106/downloads/playable.zip` and the source delta to `rebuild_20261106/downloads/delta238.zip`. Validate both against REBUILD_HASHES.json first. Use a fresh checkout/workspace without existing `restored238`, `boot234`, or candidate output directories. Python 3 is required for these packaging steps; no Godot execution is needed to assemble the packs.

Run from the repository root, in this order:

```sh
python rebuild_20261106/restore.py
python rebuild_20261106/build_polish.py motion_polish02 flow_next
python rebuild_20261106/build_enemy_readability.py enemy_cues02
python rebuild_20261106/build_projectile_readability.py projectile_cues02
python rebuild_20261106/build_hit_feedback.py hit_feedback02
python rebuild_20261106/build_audio_sync.py audio_sync01
python rebuild_20261106/build_lob_readability.py lob_cues01
python rebuild_20261106/build_control.py control_continuity01
python rebuild_20261106/build_dash_timing.py dash_timing01
```

Restoration verifies and combines 225 files from the original runtime with 13 delta payload files, producing the exact 238-file baseline. It also restores the original bootstrap. The first build applies flow_next, then combat_rebuild and motion_polish. Each following build starts from its immediately preceding named candidate and applies its own overlay. Assets are carried forward unchanged. Binding manifests and generation seals are rebuilt at every step.

For each candidate, compare `boot/packs/runtime.pck` against REBUILD_HASHES.json. The descriptor includes a local pack path, so descriptor bytes vary with workspace location; the runtime pack itself is deterministic. The optional Windows packager takes a candidate directory and a new ZIP filename, preserves the original Windows engine/bootstrap, and regenerates the portable descriptor/launcher checksums. Packaging is not Windows execution acceptance.

## Recovery verification

A fresh-directory restoration and all eight build steps were executed on 2026-11-06. Every resulting runtime pack matched the preserved tested candidate byte-for-byte. Every binding entry and corresponding generation-manifest hash was checked. The two original archives were independently fetched from their retained remote storage and matched their recorded SHA-256 values. All overlay source bytes matched the repository's stored Git blob hashes.

This establishes recovery from **this repository plus the two authorized original archives**, not GitHub alone. Private original archives, generated runtime packs, recordings, screenshots and diagnostic logs are not uploaded by this checkpoint. Runtime acceptance remains candidate-specific: successful reconstruction does not replace gameplay, hardware audio, Windows or user acceptance tests.
