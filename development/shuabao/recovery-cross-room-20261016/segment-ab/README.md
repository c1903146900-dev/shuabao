# Row 6–11 A/B progression checkpoint

Frozen 2026-10-16 17:32 UTC. Relative to the published elite checkpoint, this package changes only the production Room, Model and rest service, and adds five segment test/report/documentation files. Target: 3294 source/art files. This is the A/B evidence snapshot; subsequent C/D coverage sources or results are not included.

## Verified scope

The static authored route audit covers 20 supported nodes and 29 connected/open edges. Static coverage does not establish that every node or edge was dynamically traversed.

Three clean final runs passed with raw ERROR lists empty, zero exits, empty owned-process cleanup and unchanged source pins:

- segment_a_run02: 376/376 checks; 321 pins. Path r06a → r07a → r08b → r09a → r10b → r11a, ending after row11 rest. Totals: 23 real kills, 1405 gold, 899 raw XP, level 6 with 149 XP remainder and 3 SP.
- segment_b_run02: 412/412 checks; 322 pins. Path r06b → r07c → r08c → r09b → r10c → r11b, ending after row11 rest. Totals: 32 real kills, 1625 gold, 1003 raw XP, level 7 with 28 XP remainder and 4 SP. The original mandatory level-7 Hex selection/pause was exercised.
- segment_boundary_run02: 415/415 total checks, including 39 additional boundaries over the A route; 322 pins.

A naturally earned permanent_ad=1 and retained it through r09a/r11a. B naturally earned permanent_ad=2 and retained it through r11b. P3 progress and credited kills were checked at entry/rest. This evidence does not generalize to every permanent mechanic. Prior isolated synthetic rest tests, including nonzero G19/Q3/debt/form setups, remain separate from naturally acquired state on these paths.

## Failure history and missing coverage

B run01 genuinely died at r07c after killing four of six enemies, with the two ranged enemies still alive. It remains a failed run. The runner had treated the lane warning as a broad cone and retreated too far to connect attacks; finite ordinary projectile hits caused death. The later change narrowed legal input avoidance to the original lane projection and visible projectile side avoidance. Production rules, enemy/player values and the 18000-tick budget were not changed to obtain a pass. A, B and boundary runs were repeated on the final strategy.

At this snapshot, r07b, r08a and r10a were not dynamically traversed, and not every legal edge was exercised. Later C/D coverage is outside this package. Boss, commerce and paid body training remain disconnected. These are deterministic legal-input/API regressions, not native hand-play/feel, full-floor/Boss, final art/audio, cross-platform or performance acceptance.

## Dependency and exact restoration

Repository c1903146900-dev/shuabao. Required base commit 8cfc2d297b3467198c0d0fdb5459f29ecbde633b, development/shuabao/recovery-cross-room-20261016/elite-candidate. Restore that checkpoint and its documented chain first. Required base TARGET_SOURCE_MAP.json SHA256: 220b68ffcf435a6b1de73c03c1895553ac0b22c19c651aac72fb9186c7bd7e1d. This package is not standalone.

Join archive.part files in numeric order and verify every part/full archive using ARCHIVE_PARTS.json. Extract only unique regular safe-relative files; reject links, absolute paths and parent traversal. Run:

    python3 -B restore_sources.py --base-game /path/to/restored-elite-game --base-map /path/to/elite-package/TARGET_SOURCE_MAP.json --output /path/to/new-segment-ab-game --manifest-sha256 MANIFEST_SHA256

Use package_manifest_sha256 from ARCHIVE_PARTS.json. Output must be new. The script checks the package, all 3289 base hashes, exact before/after delta pins and all 3294 independently copied output hashes, preserving the base. Target map SHA256: 9d861fbb53d3569ada0c7216ee1278fc7e3d39cc6ce5c1b410fc0e26992ab6bf. A local independent source restoration passed all 3294 hashes. No engine runs during recovery.

## Support and exclusions

Support retains the exact delta manifest/patch, static route matrix, separated verification/history, input lists, and final three-run source pins/postchecks/exits/raw-log hashes. Each changed production source matches all three run pin lists. Source reports and planned route annotations retain their explicit static/dynamic boundaries.

Excluded: .godot/.local, imported caches, raw logs, private reference media, screenshots, profiling traces, user data, credentials, engine binaries, later C/D files and unrelated projects. Remote blob SHA/size verification is distinct from a second remote download-and-restore; no such round trip is claimed.
