# Rebuild checkpoint: 2026-11-06

Source-only incremental backup. This is a newly reconstructed, unverified checkpoint, not a playable release or a replacement for the repository root project. Engine regression testing is pending.

- `flow_changes/` contains three route flow and UI scripts, applied using their relative runtime paths.
- `restore.py` reconstructs the 238-file source baseline from locally supplied `downloads/playable.zip` and `downloads/delta238.zip`, verifying file hashes and the target manifest. Source-storage identifiers are omitted from this public copy. Run in a fresh working copy without existing `restored238` or `boot234` outputs.
- `build.py OUTPUT_DIRECTORY` overlays these flow changes and any available sibling `combat_rebuild_20261106/changes` on `restored238`, updates the runtime binding manifest, and assembles the boot/runtime pack.

The required input archives, combat overlay, generated binaries, recovery receipts, and external reference materials are not included in this incremental checkpoint. These scripts alone are not a complete rebuild kit. No art files are changed by this checkpoint.
