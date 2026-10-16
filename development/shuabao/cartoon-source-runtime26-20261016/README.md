# Runtime26 SOURCE_ONLY checkpoint

Join archive.part000 through archive.part023 in numeric order as candidate26_source_delta.tar.gz. Verify every part with ARCHIVE_PARTS.json and full archive SHA256 cd70ee06834bc6003e7af428576204139875d306390380062189bd58da8b34e8 before extraction. Archive: 1511353 bytes, 26 regular members. PACKAGE_FILES.json SHA256: 623dede38a6c2e36322571e16b9c51de9f5d1f83e0714b563c83d68949bb0108.

# Runtime26 SOURCE_ONLY source delta

Dependency: c1903146900-dev/shuabao commit 2a721f5ebbff353373d40299cb7cf3253d2f3ff2, development/shuabao/cartoon-source-runtime23-20261016. This is NOT a standalone package. Restore runtime23 first according to its README, including runtime18 and all earlier runtime17/runtime15 dependencies. Preserve candidate23_source_delta.tar.gz and game_candidate23.

This delta includes 17 replacements and 1 addition: B2 floor, forward tone, mirrored character rendering, startup continuity, UI cleanup and formal training panel wiring. It reconstructs 3238 source/art files. All 80 .godot caches, screenshots, runtime reports/logs, private reference videos, credentials and private absolute paths are excluded.

Verify archive and part hashes. Extract only unique regular safe relative members; reject links, traversal and existing destinations. Verify PACKAGE_FILES.json against the published digest, then:

python3 -B restore_sources.py --base-game ../runtime23-restored/game_candidate23 --base-archive ../candidate23_source_delta.tar.gz --manifest-sha256 MANIFEST_SHA256 --output ../runtime26-restored

Replace MANIFEST_SHA256 with the published digest. Output must not exist and its parent must exist. Omit --output for read-only verification. The restore checks the exact dependency archive, base map and complete package, and creates independent source files in game_candidate26.

Status: SOURCE_ONLY_NOT_RUNTIME_ADMITTED. Runtime26 visible natural route reached r09_original_rest_ready with passed=true, guard PASS, exit0, four cleanup checks and source pins true. This is not Boss completion, complete first-floor acceptance, long-run stability or final art acceptance. No engine was run to prepare this backup.
