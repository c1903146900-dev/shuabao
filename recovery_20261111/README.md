# Reproducible recovery and limited dash retest

Source commit: d2fe8baf5af2270b7ba3505ef14a8c7184cbebe0 in c1903146900-dev/shuabao. The two original privately retained archives are still required. No archive, asset, binary, raw log, process timeline or private design document is distributed here.

## Fresh reconstruction

1. Obtain a fresh checkout of the fixed commit in a directory called source next to these scripts, or pass --source /your/checkout to both scripts. SOURCE_GIT_BLOBS.json identifies the 611 public inputs checked by Git blob SHA-1. Do not substitute current unverified files.
2. Place the owner-held playable.zip and delta238.zip into source/rebuild_20261106/downloads. Verify sizes and SHA-256 against source/rebuild_20261106/REBUILD_HASHES.json. Follow its original-input instructions. Run python3 source/rebuild_20261106/restore.py in a fresh workspace to create restored238 and boot234.
3. Run python3 rebuild_late.py --check-only --source source to verify all 611 selected public files without constructing any candidate.
4. Run python3 build_early.py --source source. It calls the existing 35 builders, preserving their order and the final R1 release-v3 overlay, and checks each pack against EARLY_PACK_HASHES.json. All output directories must be fresh. The early hashes record this recovery's exact output bytes; the first ten also have the earlier repository pins. The final all-five pack must be 79c6fa4a3c61b3a54b63e2db81087c1c8048493870ecbd3e678dfcc4ddd21dab.
5. Run python3 rebuild_late.py --source source. It checks each source before/after, applies the published patches and portable template tools, regenerates manifest/generation/PCK/descriptor, and checks all twelve expected pack hashes. Existing late outputs are only reused after hash and binding checks; mismatching/incomplete outputs stop recovery. It does not delete or repair such directories automatically.

Outputs remain under source/rebuild_20261106. aim_pitch01 is the prior passed development baseline, SHA-256 2b216c2971ea1beeb77ebbc73273f07e3290470dbd9a56191e60561cf2f6db89. dash_trail01 is a separate candidate, SHA-256 4112ebb636b77732788de4ed57d3d75f4dae67b488c9e76c063b8061a2e37c93. Both have 257 manifest bindings. Warning-layout experiments are excluded.

These scripts never run an engine or fetch anything from the network. Python 3 and git apply are required. Descriptor bytes include local paths, so PCK hashes, not descriptor byte identity, are the cross-workspace check. Do not start engine tests outside the project's established process/resource safeguards.

## Actual validation and limits

This recovery rebuilt the early 35 stages and late twelve stages, including exact final packs. The public late-script adaptation expands the input check to all 611 blobs; that check and its existing-output verification mode were rerun successfully. The public early wrapper adds a configurable source path and pins all 35 pack hashes; this wrapper adaptation was syntax checked, not rerun across another fresh 35-stage build. Its builder sequence and actual packaging code are unchanged.

The subsequent native short test passed, including immediate right-to-left dash reversal with the first trail facing left. See dash_reboot_QA.json. Candidate full-floor and dash-attack regression remain pending, and the candidate stays separate. The observer read immunity from a snapshot lacking the computed field; its false values are not evidence of an immunity defect. No corrected-observer run, continuous-video acceptance, Windows or audible-device acceptance is claimed. Historical startup stops remain recorded in earlier checkpoints.
