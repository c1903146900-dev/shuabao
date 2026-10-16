# Non-Boss 29-node source overlay

Base: commit 5481dd2f02c11028ed25339f0a493615ba1f43fa, segment-cd, 3296 source files. This overlay changes one production room.gd and adds five test/report files; target 3301. The author candidate derives from segment-ab and lacks the two later C/D test subclasses. This backup deliberately preserves both from its CD base; no historical files are removed. The restored union itself has not been re-executed.

Production: enable 29 formal non-Boss nodes, use formal start_nodes, remove the artificial Q1-learning entry gate. Original rewards, AI, growth, services and numerical values are unchanged. E/F choose Q1 as their test input policy; the separate start fixture verifies all three legal starts without Q1.

## Verified scope
Final runs: E 445/445, F 512/512, start 21/21. Unchanged input pins 322/323/321, raw ERROR lists empty, root exit 0, owned-process cleanup empty. These are deterministic legal-input functional tests, not a native full-floor playthrough or performance acceptance.

E route (programmatically cross-checked source, parsed raw result and observation order): r01b -> r02b -> r03b -> r04b -> r05b -> r06b -> r07c -> r08c -> r09a -> r10a -> r11a.
Totals: {"combats": 6, "deaths": 25, "gold": 1310, "raw_xp": 814}. Final level 6, XP remainder 64, unspent points 3.

F route (programmatically cross-checked source, parsed raw result and observation order): r01c -> r02c -> r03c -> r04c -> r05b -> r06b -> r07c -> r08c -> r09a -> r10a -> r11a.
Totals: {"combats": 7, "deaths": 33, "gold": 1620, "raw_xp": 1004}. Final level 7, XP remainder 29, unspent points 4.

Historical run01 failures are preserved in the verification report: E/F read stale deferred UI projections and failed subsequent checks; start had 21 passing assertions but two GL texture leak ERRORs on exit. Only test wait/stop/cleanup timing changed for run02, with no production balance edits. VSync warning remains.

Prior A/B/C/D coverage belongs to its frozen production versions. E/F exercises the nine newly enabled nodes; this package does not claim every formal edge re-traversed on this exact union. Boss, commerce and paid 900-gold body training remain unconnected. Full native controls/visual/audio and whole-floor acceptance remain incomplete.

## Recovery
Concatenate archive.part files in ARCHIVE_PARTS.json order; verify each part SHA-256 and complete archive SHA-256/size before extracting into a new empty directory. Read restore_sources.py first. Obtain the previously restored segment-cd tree and its TARGET_SOURCE_MAP.json. Run Python 3 restore_sources.py with --base-game PATH_TO_CD_TREE --base-map PATH_TO_CD_TARGET_SOURCE_MAP --output NEW_EMPTY_OUTPUT_PATH --manifest-sha256 VALUE_FROM_ARCHIVE_PARTS. The output path must not exist. The script verifies all 3296 base files, package bytes, exact changes and all 3301 target SHA-256 values, leaving the base untouched. It does not import or launch Godot.

Only source delta and text validation support are included; no raw logs, caches, userdata, engine, secrets or private media. Source pins and raw SHA-256 are evidence references, not embedded raw logs. Support commands retain original absolute workspace paths and require explicit adaptation on another machine. Local independent source restoration is verified. Remote verification checks Git blob SHA/size and branch commit; no second remote download-and-restore is claimed.
