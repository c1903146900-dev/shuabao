# Natural Boss full business-route checkpoint

Base: boss-business commit f5609715dde4d62f2562b40f5eb62719b456fcc8, 3305 source files. Adds floor_model.gd and natural_runner.gd; changes room.gd and bridge.gd coordination. Target 3307. Preserves both historical CD test subclasses absent from the author candidate; removes no files. This restored union has not separately been executed. No later art/audio successor is included.

## Verified scope
boss_natural_run02: 557/557 passing checks, floor_complete, 332 unchanged input pins, raw ERROR list empty, root exit0 and owned cleanup empty. Deterministic legal-input natural route, without synthetic combat setup. Actual route is programmatically cross-checked against runner source, parsed result, observation order and manifest:

r01b -> r02b -> r03b -> r04b -> r05b -> r06b -> r07c -> r08c -> r09a -> r10a -> r11a -> r12boss.

Full-health Boss starts at 3190HP and actually dies at 0HP. Boss reward320gold/160rawXP is accepted once; full-route totals1630gold/974rawXP,26 true kills,7 combats, final Lv6 XP224 SP3 and heroHP420. Original complete_act and major_floor_completed event chain executes. G20 is inactive, so its active effect is not verified. This is not native hand play, Boss art/audio acceptance, all-route-edge coverage or performance acceptance.

History: run01 truly lost with Boss remaining741.884HP. Generic15m conservative steering truncated an original legal escape near16.06m. Only the Boss movement input policy was revised to move directly toward the original computed escape; production code, skill allocation and tick budget were unchanged between runs. No numeric weakening or resource injection was used to force success. VSync warning remains.

Author manifest is preserved as source evidence; any pre-run pending wording is historical and superseded only within the final report/postcheck scope above.

## Recovery
Concatenate archive.part files in ARCHIVE_PARTS.json order and verify each SHA-256 and complete archive SHA-256/size before extracting into a new empty directory. Read restore_sources.py. Use the previously restored boss-business tree and its TARGET_SOURCE_MAP.json. Run Python3 restore_sources.py with --base-game PATH_TO_BUSINESS_TREE --base-map PATH_TO_BUSINESS_TARGET_SOURCE_MAP --output NEW_OUTPUT_PATH --manifest-sha256 VALUE_FROM_ARCHIVE_PARTS. Output must not exist. The script verifies all3305 base sources, exact package/delta and all3307 target SHA-256 values; base remains unchanged. No Godot execution/import occurs.

Only source and small verification support are included. No raw logs, GLB additions, caches, userdata, binaries, secrets or private media. Raw hashes are references, not embedded raw logs. Historical absolute command paths require explicit adaptation elsewhere. Local independent restoration is verified. Remote verification checks Git blob SHA/size, HEAD and only-new-path scope; no second remote download-and-restore is claimed.
