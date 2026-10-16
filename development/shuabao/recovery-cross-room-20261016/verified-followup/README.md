# Verified follow-up: bounded two-room functional tests

Frozen 2026-10-16 15:21 UTC. This is a tiny source delta after the preserved normal02 WIP checkpoint. Only natural_runner.gd and the candidate README change; VERIFICATION_REPORT.json is added. All production gameplay files and the original 3251-file runtime38 baseline remain unchanged. The resulting source map contains 3263 files.

## Evidence boundary

normal03 passed 67/67 checks: two real authored rooms settled, eight real kills, reward replay idempotence, same-instance transfer, nonzero Q1 stack carry and successor-Q1 formula. It stopped before r03a. Corrected legal input steering avoided wall clipping without changing collision, hero values, enemy AI or production gameplay.

negative01 passed 10/10 checks in a separate one-minion fixture: one injected payment failure rolled back; retained authenticated evidence was retried once after real victory without reopening combat; replay preserved state and receipts. This fixture is not normal-route combat evidence.

normal01 and normal02 remain recorded failures due to real second-room defeat. Native visual/manual-play acceptance, nonzero permanent-passive carry, full-floor/boss coverage, final art/audio and cross-platform acceptance remain unverified. These are functional Compatibility/Dummy test results, not whole-game or visual acceptance. The source report pins the two raw logs by SHA256; the logs and runtime userdata are excluded.

## Dependency and exact restore

Repository: c1903146900-dev/shuabao. Required prior checkpoint: commit de23b5b8871290c92ccd0a7377fb665576957b09, development/shuabao/recovery-cross-room-20261016. Restore that checkpoint and its runtime38 dependency chain first. Preserve its extracted TARGET_SOURCE_MAP.json (SHA256 63098828e146a9cf5c220d4bcb6c963bec01f8a649cd9fc2815c3732c8b0291e). This follow-up is NOT standalone and does not replace or rewrite that WIP package.

Join this directory's archive.part files in numeric order; verify each part and the complete archive using ARCHIVE_PARTS.json. Extract only unique regular files with safe relative paths, rejecting links, absolute paths and parent traversal. Then:

    python3 -B restore_sources.py --base-game /path/to/restored-normal02-game --base-map /path/to/normal02-package/TARGET_SOURCE_MAP.json --output /path/to/new-verified-game --manifest-sha256 MANIFEST_SHA256

Use package_manifest_sha256 from ARCHIVE_PARTS.json for MANIFEST_SHA256. Output must be new. The script checks every package member, all 3262 base source hashes, every before/after delta pin and all 3263 output hashes. It copies independent files and leaves the prior tree unchanged. No engine is run. Target map SHA256: eafaebd19fcb75400f9986386f1155e63c5102b744b445d90f9584cf09344363.

A local independent restoration passed all 3263 SHA256 values. Remote blob SHA/size verification is distinct from downloading and restoring a second remote copy; no such remote round-trip restore is claimed.

## Support

support/negative_input_paths.json is the new 41-input negative-test pin list. Combine it with the prior package's reviewed support scripts. It is outside the game source map and is not automatically executed. Existing guard engine pins, environment-specific lock path and real-display requirements still apply. Source restoration, cache regeneration and any engine run are separate steps.

Excluded: engine binaries, imported caches, .godot, .local, Python bytecode, raw logs, runtime user data and private reference media. The opt-in entry remains res://fengli_cross_room_20261016/entry.tscn; the default runtime38 entry is unchanged.
