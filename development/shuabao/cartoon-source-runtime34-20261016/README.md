# Runtime34 SOURCE_ONLY checkpoint

Join archive.part000 through archive.part006 in numeric order as candidate34_source_delta.tar.gz. Verify every part with ARCHIVE_PARTS.json and full archive SHA256 e524cd22f94bfe97c5b0764eb65ff1e7e04f1cd8a161d746e245e3b1100b273f before extraction. Archive: 438883 bytes, 15 regular members. PACKAGE_FILES.json SHA256: 69b57817ec9853842030b7e254f9524e9ebc20609f2f95389f25a63232882431.

# Runtime34 SOURCE_ONLY checkpoint delta

Dependency: c1903146900-dev/shuabao commit 68f545f514d49bf4780fdf7efc0faf8bee1f3382, development/shuabao/cartoon-source-runtime32-20261016. Restore runtime32 and its documented dependency chain first. This archive is NOT standalone.

6 replacements and 1 historical source preimage reconstruct 3242 source/art files. Changes are only route-map palette64, HUD text/visibility cleanup65, the actual project main_scene pointing to the existing cartoon chooser entry67, and exact source/visual binding succession. Gameplay, collisions, signals and rules remain inherited. No new raster art is included.

All 80 .godot caches, private reference video, Heaptrack tools/libraries/traces, raw test logs, screenshots, rejected experiment61 and credentials are excluded. No engine is run for restore verification.

Verify all archive/part hashes, extract only unique regular safe relative members, then:

python3 -B restore_sources.py --base-game ../runtime32-restored/game_candidate32 --base-archive ../candidate32_source_delta.tar.gz --manifest-sha256 MANIFEST_SHA256 --output ../runtime34-restored

Replace MANIFEST_SHA256 with the published PACKAGE_FILES.json digest. Output must not exist and parent must exist. The restore checks complete package/base maps and creates independent files in game_candidate34. Omit --output for read-only verification.

Status: SOURCE_ONLY_NOT_RUNTIME_ADMITTED. Runtime34 default chooser to formal cartoon scene and a short HUD/entry session were manually checked. Runtime32 first-floor completion was separately validated by automated original-input visual replay (421 checks, 12 route rows, 25 kills, original Boss reward and same-run settlement). These are two separate runs: no new full-floor completion is claimed for runtime34. Runtime32 peaked at 934.18 MiB and did not pass the original 896 MiB performance limit. No cross-platform, final art or playable release-package acceptance is claimed.
