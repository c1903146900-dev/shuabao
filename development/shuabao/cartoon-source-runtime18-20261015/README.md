# Runtime18 SOURCE_ONLY checkpoint

Join archive.part000 through archive.part057 in numeric order as candidate18_source_delta.tar.gz. Verify every part with ARCHIVE_PARTS.json and full archive SHA256 581e9e5a1df8130152d0e8b17205833bb41bbb633bb4d58958dd6eda614d814e before extraction. Archive: 3737475 bytes, 18 regular members. PACKAGE_FILES.json SHA256: 0954528663d459be826d6ad71c4a01a29d879e48d9dca9fbfaf8631bbe2cfdca.

# Runtime18 SOURCE_ONLY source delta

Dependency: c1903146900-dev/shuabao at commit 3fb7d17326ffdfa83195479a1bbc78d16e15d4ea, development/shuabao/cartoon-source-runtime17-20261015. Follow that checkpoint's instructions first, including its runtime15 dependency. Keep the exact reconstructed candidate17_source_delta.tar.gz and restored game_candidate17 source directory.

This delta contains 10 source files: 5 replacements and 5 additions. Only the changed original hero atlas and new original floor artwork are packed; all unchanged published assets are reused through the dependency chain. All 80 .godot cache files, private reference videos, runtime PIDs, ordinary logs, secrets, and private absolute paths are excluded from the payload.

Verify the archive SHA256 and every part, then extract only regular members with safe relative paths; reject links, absolute paths, traversal, duplicates, and existing destinations. Verify PACKAGE_FILES.json against its published digest. From the extracted package, run:

python3 -B restore_sources.py --base-game ../runtime17-restored/game_candidate17 --base-archive ../candidate17_source_delta.tar.gz --manifest-sha256 MANIFEST_SHA256 --output ../runtime18-restored

Replace MANIFEST_SHA256 with the published digest. The output must not exist, and its parent must exist. Omit --output for read-only verification. The script verifies the exact dependency archive, complete base map and package manifest; rejects symlinks and overlapping paths; and restores 3151 independent source files to runtime18-restored/game_candidate18 with a separate receipt.

Status: SOURCE_ONLY_NOT_RUNTIME_ADMITTED. This is a source backup, not a playtest build or final artwork. Offline14 completed a limited 180-frame animation check. GUI25 was terminated at 183.78 seconds after reaching RSS 896 MiB; stability has NOT passed. No runtime admission, full gameplay, performance, or final visual acceptance is claimed. No engine was run to prepare or restore this backup.
