# Minimal public recovery proposal, 2026-11-17
LOCAL PREPARATION ONLY. Nothing in this package has been uploaded.
Proposed existing destination: c1903146900-dev/shuabao, branch checkpoint/player-health-cue-20261106, directory recovery_unified_20261117/. Publication would expose source changes and development/recovery details to everyone. No original art/audio/binaries, credentials, private messages or logs are included.

## Scope
Six changed source files cover keyboard Shift hover buffering, basic-release sound timing, continuous dash sector sweep/time clipping/LOS/callback safety, resumable dash completion, and contact voice priority. Exact paths and hashes are in current_local_delta/SOURCE_HASHES.json. Existing game values/resources are reused. This is a new reconstruction, NOT recovery of the old e947 original.

## Dependencies and restoration
This is an incremental recovery package, NOT a standalone game. Retain owner-held playable.zip (SHA256 0a708d03e38856139745820c3e1d0243ef87fde55d32577b532bba0ecff16efc) and delta238.zip (33d0b5686b7317982ba3bbfc0757357dfa2c167033eeaaa22f7b6077efc085ba) privately. They are explicitly excluded from publication. Use Python 3 and git apply. All output paths must be fresh; never run the game as part of recovery.
1. Materialize the 611 public inputs listed in tools/SOURCE_GIT_BLOBS.json from repository commit d2fe8baf5af2270b7ba3505ef14a8c7184cbebe0 under ROOT/source; verify Git blob hashes. ROOT is the directory containing this README.
2. Put original archives under ROOT/source/rebuild_20261106/downloads and follow that public restore.py/REBUILD_HASHES.json to recreate restored238 and boot234.
3. Run python tools/rebuild_late.py --check-only --source source, then python tools/build_early.py --source source, then python tools/rebuild_late.py --source source. Final dash_trail01 PCK must be 4112ebb636b77732788de4ed57d3d75f4dae67b488c9e76c063b8061a2e37c93.
4. Materialize public groups from fixed commit 86b55f302568589fdc3fdeb57e8e270abb4833c1 under ROOT/review_inputs: flow_trio_20261116, objective_priority_20261116, ranged_sight_20261114, selected_entry_retry_20261114, session_fault_latch_20261114, support_escort_priority_20261116, support_guard_range_20261114, terminal_hex_20261116, dash_edge_reconstruction_20261116, dash_attack_pitch_20261111. Verify their FILE_HASHES. These previously published files are not duplicated here.
5. Run python review_inputs/flow_trio_20261116/build_flow_trio.py --recovery ROOT --output ROOT/flow_trio_20261116 (use absolute ROOT). Result PCK must be 2c552be19883c8473d72717b9ccfcf2d4ce34155f3e12cfa962205aec4efe346.
6. Run python build_public_combined_20261117.py. Backed-only base PCK must be f6a83c7e1a849551f7da0ff6d529e1e382c9bc52d359d33ecc597eb8136a819f.
7. Run python current_local_delta/restore.py --root ROOT --output NEW_ABSENT_DIR. This checks six source before/after hashes and seals the candidate. Final PCK must be f4d4b2938bf289905aabb64fc42308cd067befdd219a7e6f248f36df673d3313, with 260 runtime files and 258 manifest bindings.

## Verification limits
Current direct six-file restoration matched all 260 source files and package bytes; PCK payloads matched source and MD5. Original recovery reproduced early/late/public stages. The instructions above have not been rerun as one brand-new end-to-end restoration from this proposed folder. No parser, engine, full-floor playthrough or listening acceptance. Original materials and fixed remote dependencies remain essential. Publication is not authorized by preparing this folder.
