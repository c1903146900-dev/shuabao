# Runtime23 SOURCE_ONLY checkpoint

Join archive.part000 through archive.part020 in numeric order as candidate23_source_delta.tar.gz. Verify every part with ARCHIVE_PARTS.json and full archive SHA256 5e9aba151da267eac7a65da3a5bb5868ec5b0000ebca081e2d24b2582d02893d before extraction. Archive: 1363622 bytes, 124 regular members. PACKAGE_FILES.json SHA256: cfd06173a6fa195f7db1230858d784bc624744e47b2fa38fdbbb07cff6d385e2.

# Runtime23 SOURCE_ONLY source delta

Dependency: c1903146900-dev/shuabao at commit 4f1c526b17726bec89973c7d67437e8e6feb38a2, development/shuabao/cartoon-source-runtime18-20261015. Follow that checkpoint's instructions first, including its runtime17 and runtime15 dependencies. Keep the exact reconstructed candidate18_source_delta.tar.gz and restored game_candidate18 source directory.

This delta contains 116 source files: 30 replacements and 86 additions. Only changed or added source and authored geometry assets are packed; all unchanged published assets are reused through the dependency chain. All 80 .godot cache files, private reference videos, runtime PIDs, ordinary logs, secrets, and private absolute paths are excluded from the payload.

Verify the archive SHA256 and every part, then extract only regular members with safe relative paths; reject links, absolute paths, traversal, duplicates, and existing destinations. Verify PACKAGE_FILES.json against its published digest. From the extracted package, run:

python3 -B restore_sources.py --base-game ../runtime18-restored/game_candidate18 --base-archive ../candidate18_source_delta.tar.gz --manifest-sha256 MANIFEST_SHA256 --output ../runtime23-restored

Replace MANIFEST_SHA256 with the published digest. The output must not exist, and its parent must exist. Omit --output for read-only verification. The script verifies the exact dependency archive, complete base map and package manifest; rejects symlinks and overlapping paths; and restores 3237 independent source files to runtime23-restored/game_candidate23 with a separate receipt.

Status: SOURCE_ONLY_NOT_RUNTIME_ADMITTED. GUI30 startup and GUI31 Q1/basic straight-line combat short batch passed. Overall artwork still does not meet the reference target. These limited checks do not establish complete gameplay, full playtest readiness, long-run stability, performance acceptance, or final art approval. No engine was run to prepare or restore this backup.
