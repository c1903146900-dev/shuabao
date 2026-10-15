# Candidate15 compact source-only backup

Concatenate the numbered parts in ARCHIVE_PARTS.json order. Verify each part SHA256, then the complete archive SHA256 against ARCHIVE_MANIFEST.json before unpacking. Accept only regular relative files under candidate15_source_delta/; reject symlinks and traversal paths. Read its README and use the exact package_files_sha256 from ARCHIVE_MANIFEST.json for restore_sources.py.

The archive contains 9 new source/assets files, including 2 original generated rig PNGs. It reuses the public cartoon-source-offline01-20261015 source backup (including its G23 parent chain) and cartoon-source-offline06-20261015 checkpoint. Both archive identities and exact relative source maps are pinned. A fresh restoration yields 3142 source files without generated cache bytes.

This is SOURCE_ONLY_NOT_RUNTIME_ADMITTED. Source recovery does not certify complete character animation, Q1 behavior, realtime performance, or resolved memory growth. No runtime evidence, footage, reference video, private machine paths or credentials are included. No engine is run by the restore script.
