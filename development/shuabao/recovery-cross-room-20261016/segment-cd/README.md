# C/D test-only coverage follow-up

Frozen 2026-10-16 17:40 UTC. Adds only branch_c_runner.gd and branch_d_runner.gd under tests/fengli_floor_segment_20261016. Both subclasses inherit the already-backed-up natural runner and override only the lawful route path. All 3294 predecessor files, including every production source, are unchanged. The restored tree contains 3296 source/art/test files. The coverage report and run evidence are support files, outside the game source map.

## Evidence and limits

segment_c_run01 and segment_d_run01 each passed 377/377 checks, with empty raw ERROR lists, zero exit, empty owned-process cleanup and 322 unchanged input pins. Each run retains all 321 common A/B inputs unchanged and adds only its own test subclass.

- C: r06a → r07b → r08c → r09a → r10a → r11a.
- D: r06a → r07a → r08a → r09a → r10a → r11a.

Each recorded 24 real kills, 1315 gold, 813 raw XP, level 6 with 63 XP remainder and 3 SP, final HP 420, permanent P3 attack gain 1 and P3 progress remainder 6. Both end after row11 rest with Boss still disconnected.

Together with the previously published A/B runs, these paths close the dynamic node coverage gaps at r07b/r08a/r10a, covering all 20 currently supported nodes. They do not exhaustively traverse all 29 connected edges. They are deterministic legal-input/API runs, not native hand-play or complete floor/Boss, performance, final art/audio or all-hardware acceptance. The earlier A/B package's historical coverage boundary and genuine B01 defeat are preserved; this follow-up does not rewrite that package or its reports.

## Dependency and exact restore

Repository c1903146900-dev/shuabao. Required base commit 92dc50022adb05436ac2b2af603aafe731598d4f, development/shuabao/recovery-cross-room-20261016/segment-ab. Restore that package and its documented chain first. Its TARGET_SOURCE_MAP.json SHA256 must be 9d861fbb53d3569ada0c7216ee1278fc7e3d39cc6ce5c1b410fc0e26992ab6bf. This follow-up is not standalone.

Join archive.part files in numeric order; verify each part and complete archive using ARCHIVE_PARTS.json. Extract only unique regular safe-relative files; reject links, absolute paths and parent traversal. Run:

    python3 -B restore_sources.py --base-game /path/to/restored-segment-ab-game --base-map /path/to/segment-ab-package/TARGET_SOURCE_MAP.json --output /path/to/new-segment-cd-game --manifest-sha256 MANIFEST_SHA256

Use package_manifest_sha256 from ARCHIVE_PARTS.json. Output must be new. Recovery verifies all package members, all 3294 predecessor source hashes, the two added hashes and every one of the 3296 independent output hashes. Target map SHA256: e026883a9b9505eaca4307b440d2ffdb45a365f94e3ec07bdb6e462ea896e89e. Local independent restoration passed all 3296 hashes and preserved the base. No engine runs during recovery.

## Support and exclusions

Support contains the C/D coverage report, unchanged-base preflight, exact input lists, and run postchecks/source pins/raw-log hashes. The isolated C/D execution project was read-only checked against all 3294 prior source hashes before packaging; no full duplicate project is distributed.

Excluded: imported caches, .godot/.local, raw logs, runtime user data, private media, screenshots, credentials, engine binaries and unrelated projects. Remote blob SHA/size verification is distinct from a second remote download-and-restore; no such round trip is claimed.
