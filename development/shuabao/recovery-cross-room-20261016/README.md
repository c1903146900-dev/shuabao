# Rebuilt Fengli cross-room source snapshot — WIP

Snapshot: 2026-10-16 15:13 UTC. This is a recoverable source checkpoint, NOT a two-room acceptance pass or playable release. It reconstructs 3262 source/art files: the exact 3251-file runtime38 baseline plus 11 opt-in candidate files. No baseline file is replaced or removed; default entry remains unchanged.

## Dependency and restoration

This delta is NOT standalone. Restore the existing public runtime38 package and its documented chain first: repository `c1903146900-dev/shuabao`, commit `1baf5f77044e15382537283353271a4a784693be`, path `development/shuabao/cartoon-source-runtime38-20261016`. Baseline source-map SHA256: `729f339a50bffdcd1ae15a54b1a0fb8db7f6215d6b0235b13c95da9fa7c68ac9`.

Verify the published archive/part manifest before extraction. Extract only unique regular members with safe relative paths, rejecting links and absolute or parent-traversal paths. Then run:

    python3 -B restore_sources.py --base-game /path/to/runtime38-restored/game_candidate38 --output /path/to/new-game-fengli-cross-room --manifest-sha256 MANIFEST_SHA256

Replace MANIFEST_SHA256 with package_manifest_sha256 from ARCHIVE_PARTS.json. Output must not exist. The script verifies every baseline and added file, copies independent files, then checks all 3262 output SHA256 values and confirms the baseline is unchanged. It never starts an engine. A local independent restore of this frozen package passed all 3262 source hashes. Target map SHA256: `63098828e146a9cf5c220d4bcb6c963bec01f8a649cd9fc2815c3732c8b0291e`.

## Evidence cutoff and limits

The native import preparation succeeded for 43 selected resources. In natural_run01 and natural_run02, real first-room combat/settlement, exact first-kill reward replay idempotence, same-instance cross-room transfer and nonzero Q1 stack carry were observed. Both runs then ended with real player defeat in room two. Second-room victory/settlement and complete two-room acceptance have NOT passed. The updated movement runner is included as WIP. These statements summarize the current runs; no historical runtime79 acceptance or numeric result is reused as proof.

The candidate's own README and STATIC_CHECK_RESULT.json are preserved byte-for-byte as implementation-time records; their 'not run by implementation worker' wording is historical and does not override the later run outcomes above. Full raw logs, private reference videos, runtime userdata and rendered visual evidence are not distributed. No manual gameplay, final visual/audio quality, full-floor, boss, cross-platform, negative-fixture or performance acceptance is claimed by this package.

## Support scripts

`support/` contains the preparation/resource audit/owned-process guard scripts and explicit input lists used for this environment. They are supporting source, not part of the game source map. They are not automatically run during restore. `owned_guard.py` pins an exact Godot 4.6.3 binary and an environment-specific absolute lock path; review and adapt that path, supply the pinned engine, a real display and appropriate limits before any separately authorized use. Cache regeneration and runtime verification are separate operations. The scripts alone are not a claim of portable execution.

Excluded: `.godot`, `.local`, imported caches, Python bytecode, raw runtime logs, runtime user data, private reference media, credentials and engine binaries. This checkpoint preserves source recovery, not a ready-to-launch import cache. Remote blob SHA/size verification, when completed, is distinct from downloading and restoring a second remote copy.
