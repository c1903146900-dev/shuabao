# Sandbox P6 throw-query source recovery delta

This append-only package contains one production-file change: inventory_throw_query012.gd accepts the exact formal TreeTerrainSpace identity only after the original boundary check. Existing H1 and distance logic is preserved. The 11 archive members contain exact before/after bytes, original new source manifest, complete parent/final maps, pinned public recovery chain, patch and reviewed standalone recovery tool. The full game is not duplicated.

This backup verifies source recovery. Original source-manifest creation-time status is preserved verbatim; subsequent runtime results are separate, and no historical result is inherited. Packaging starts no engine. No Store, handoff, runtime log/receipt, private job, private absolute path or generated cache is included.

## Safe archive and source recovery

Read SOURCE_ARCHIVE_MANIFEST.json. Fetch every part as binary; use GitHub fetch_file encoding base64 rather than UTF-8 blob reads. Check each part's length/SHA256 and contiguous sequence/offset, then the complete archive SHA256. Require exactly the 11 listed regular members under sandbox_p6_throw_source/. Reject absolute paths, traversal, duplicate/unlisted names, links, special files and PAX/GNU extensions. Verify member lengths/hashes before writing to a new empty directory.

The pinned public parent is commit f683fb84c9a39f710bf55c6be5f78f34c01fbfaa. Its source chain is published baseline1370, Q11, then the existing cooldown archive, yielding parent1372/source635870/map829f71. The included one-file delta yields1372 files/6536368 bytes, new source manifestd6753831 and fullmap75d66b2b. Read the extracted README and PARENT_RECOVERY_ANCHOR.json for exact complete hashes.

From the extracted sandbox_p6_throw_source directory:

    python -B restore_source.py --public-checkout /path/to/pinned-public-checkout

Default verification is read-only. Add --write-output /path/to/new-disjoint-directory only to reconstruct the complete source. The tool requires canonical input/tool/output paths, rejects symlink ancestry and all input/output overlap, and never overwrites an existing destination. It validates the entire public chain, all before-images, full parent/final maps and exact original source manifest. It starts no engine and uses no network.

Existing repository source and earlier backups remain untouched. The package is source preservation, not production activation or full product acceptance.
