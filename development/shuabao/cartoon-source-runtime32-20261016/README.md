# Runtime32 SOURCE_ONLY checkpoint

Join archive.part000 through archive.part007 in numeric order as candidate32_source_delta.tar.gz. Verify every part with ARCHIVE_PARTS.json and full archive SHA256 14024b8b16a5ca7516b03ea515359b3e1aa3b730ef6f0afc5a99b1f43fd13ed5 before extraction. Archive: 497746 bytes, 29 regular members. PACKAGE_FILES.json SHA256: 48f1637f7f95b57ace608e8458916a0332aec6567407155a9767fc0acb874bda.

# Runtime32 SOURCE_ONLY checkpoint delta

Dependency: c1903146900-dev/shuabao commit e6b1092ca92fcf672fb8190e5b757893c26e6bd0, development/shuabao/cartoon-source-runtime26-20261016. Restore runtime26 and its full documented dependency chain first. This archive is NOT standalone.

18 replacements and 3 historical preimage additions reconstruct 3241 source/art files. Changes: continuous front robe and Q1 pose curve, preview river reuse, exact terminal UI and snapshot gates, enemy preflight handoff and actual dispatch, lazy fallback textures, and exact validation/binding succession. Existing floor/atlases are inherited unchanged from runtime26. Rejected sleeve experiment61 is excluded.

All 80 .godot caches, private reference video, Heaptrack tools/libraries/traces, raw test logs, screenshots, credentials and private absolute paths are excluded. No engine is run for restore verification.

Verify all part/archive hashes. Extract only unique regular safe relative members; reject links, traversal and existing destinations. Then:

python3 -B restore_sources.py --base-game ../runtime26-restored/game_candidate26 --base-archive ../candidate26_source_delta.tar.gz --manifest-sha256 MANIFEST_SHA256 --output ../runtime32-restored

Replace MANIFEST_SHA256 with the published PACKAGE_FILES.json digest. Output must not exist and parent must exist. The restore verifies the exact dependency archive, complete base map and package, and creates independent source files in game_candidate32. Omit --output for read-only verification.

Status: SOURCE_ONLY_NOT_RUNTIME_ADMITTED. Runtime32 functional visual replay through the original input path completed the first floor in run05: 421 checks, 12 route rows, 25 kills, and matching original Boss reward and same-run settlement. This is automated original-input replay, not manual-play, cross-platform or art acceptance. Peak memory was 934.18 MiB; the original 896 MiB performance limit remains NOT passed. This remains a source backup, NOT a playable release package. Earlier status inside the immutable archive records the state at backup time.
