# Clean r05a elite successor checkpoint

Frozen 2026-10-16 17:13 UTC. Relative to the published optimized r04a training checkpoint, only fengli_route_rest_20261016/room.gd changes in production. Four elite test/report/documentation files are added. The source target contains 3289 files. Existing baseline copies and earlier packages remain untouched.

## Scope and clean results

The candidate extends the authored route through the actual r05a elite encounter and stops before entering the unconnected r06 training successors. It retains original Wind combat, rewards, growth and mandatory level-4 Hex selection. It does not add Boss or whole-floor completion.

- elite_natural_run03 passed 173/173 checks with no raw ERROR/SCRIPT ERROR. Postcheck verified 321 source inputs unchanged.
- elite_boundary_run02 passed 185/185 total checks, comprising the route checks plus 12 additional boundaries, with no raw ERROR/SCRIPT ERROR. Postcheck verified 322 source inputs unchanged.
- The clean route recorded 12 real kills, 725 gold, 463 raw XP, level 4 with 88 XP remainder and 1 SP. The mandatory level-4 Hex was selected from the actual original card offer; the combat clock remained 75.48 before and after selection.

These are deterministic legal-input/API regressions, not native manual elite combat acceptance. No full-floor/Boss, all-hardware, final art/audio, performance or complete manual-clear acceptance is claimed. Clean source pins and result scopes are preserved separately from the earlier runs below.

## Retained failure history

elite_natural_run01 failed its r05a victory/progression checks because the input strategy repeatedly missed while fighting at range. It remains a failed strategy run. elite_natural_run02 and elite_boundary_run01 reported successful business checks but had a final diagnostic SCRIPT ERROR; they are retained as unclean results and are not counted as clean acceptance. Subsequent edits corrected only the runner's close-range legal input strategy and snapshot diagnostics; no production combat values or rewards were changed to force a pass. ELITE_VERIFICATION_REPORT.json retains each run's raw hash and historical outcome. The final clean runs supersede the unclean results without deleting their history.

## Dependency and exact recovery

Repository c1903146900-dev/shuabao. Required base commit f2e8353f7a97c86892cc298541e28efb61bae317, development/shuabao/recovery-cross-room-20261016/training-optimized. Restore that checkpoint and its documented chain first. Its TARGET_SOURCE_MAP.json SHA256 must be 39996b3e6e91556c17fa53b02ce84b5b0a322de01ad8ee4dcd0ddd31b354850a. This package is not standalone.

Join archive.part files in numeric order, verifying every part and full archive using ARCHIVE_PARTS.json. Extract only unique regular safe-relative members; reject links, absolute paths and parent traversal. Run:

    python3 -B restore_sources.py --base-game /path/to/restored-training-game --base-map /path/to/training-package/TARGET_SOURCE_MAP.json --output /path/to/new-elite-game --manifest-sha256 MANIFEST_SHA256

Use package_manifest_sha256 from ARCHIVE_PARTS.json. Output must be new. The script checks the complete package, all 3285 base hashes, exact delta pins and all 3289 independent output hashes, preserving the base. Target map SHA256: 220b68ffcf435a6b1de73c03c1895553ac0b22c19c651aac72fb9186c7bd7e1d. A local independent source restoration passed all 3289 hashes. No engine runs during recovery.

## Support and exclusions

support contains the exact production/test delta manifest/patch, separated verification history, input lists, and clean-run source pins, postchecks, exits and raw-log hashes. The final Room pin matches both clean runs; relevant runner pins also match. Earlier inherited reports/runners retain their predecessor scopes and do not replace this elite-specific evidence.

Excluded: .godot/.local, imported caches, raw logs, private reference media, screenshots, profiling traces, user data, credentials, engine binaries and unrelated projects. Remote blob SHA/size verification does not constitute a second remote download-and-restore; no such round trip is claimed.
