# Runtime36 SOURCE_ONLY checkpoint

Join archive.part000 through archive.part007 in numeric order as candidate36_source_delta.tar.gz. Verify every part with ARCHIVE_PARTS.json and full archive SHA256 584404d92aba9643c8dec8a18119ada62c8673c2c91efa98a05f091ea0c36225 before extraction. Archive: 463250 bytes, 17 regular members. PACKAGE_FILES.json SHA256: 07dcd4bec85053993feba66842ccdeb7e9d402c7c553191841f23a80002e35ab.

# Runtime36 SOURCE_ONLY checkpoint delta

Dependency: c1903146900-dev/shuabao commit d7d1c17f7696a1a20123c2755f0abd49718fd07c, development/shuabao/cartoon-source-runtime34-20261016. Restore runtime34 and its documented dependency chain first. This archive is NOT standalone.

8 replacements and 1 historical source preimage reconstruct 3243 source/art files. Changes are the existing-portrait chooser preview68 and floor contrast69: the official stage explicitly enables .60 contrast; shader, exact warmup uniform expectations and source/visual bindings are synchronized. Floor exposure remains .22. The original PNG, geometry, collision, character tone and gameplay rules are unchanged. No new raster art is included. Source-texture arithmetic linear luminance mean preservation does not imply exact screen-average preservation after perspective cropping/filtering. Static preview did not exercise battle warning overlays.

All 80 .godot caches, private reference video, Heaptrack tools/libraries/traces, raw test logs, screenshots, rejected experiment61 and credentials are excluded. No engine is run for restore verification.

Verify archive/part hashes and unique regular safe relative members, then:

python3 -B restore_sources.py --base-game ../runtime34-restored/game_candidate34 --base-archive ../candidate34_source_delta.tar.gz --manifest-sha256 MANIFEST_SHA256 --output ../runtime36-restored

Replace MANIFEST_SHA256 with the published PACKAGE_FILES.json digest. Output must not exist and parent must exist. Restore checks complete package/base maps and creates independent files in game_candidate36. Omit --output for read-only verification.

Status: SOURCE_ONLY_NOT_RUNTIME_ADMITTED. Runtime35 existing-portrait chooser switching was manually checked. Floor69 A/B static 1280x720 renders passed capture checks and the quieter .60 contrast variant was visually selected. Runtime36 integrates those source changes but has not had a new engine, combat or full-floor run. Runtime34 default entry/HUD short checks and Runtime32 automated original-input first-floor completion (421 checks, 12 route rows, 25 kills, original Boss reward and same-run settlement) were separate earlier runs. Runtime32 peaked at 934.18 MiB and did not pass the original 896 MiB performance limit. No manual full-floor, cross-platform, final-art or playable-release acceptance is claimed.
