# G26 counter03 cumulative source and development tools

Static backup only. Parser, business, GUI, native input and Host-ready are NOT_RUN. Historical results are not inherited. No runtime logs, private jobs or historical generated caches are included.

The source archive preserves all 32 reviewed raw files byte-for-byte: source/ has 28 source/metadata files and tools/ has 4 portable exact-rebuild files. Apply all three source stages in order. The first layer produces the unpublished fee intermediate; it is not a published recovery base. The second layer fixes the Boss enemy-damage classification and produces the unpublished 082 intermediate. The third layer corrects the formal catalog status and produces the final 4d9a source. Neither intermediate is a remote recovery base.

## Safe source restore

Read SOURCE_ARCHIVE_MANIFEST.json and fetch every part as binary (GitHub fetch_file encoding base64, never UTF-8 blob reads). Check each part size/SHA256, contiguous offsets and sequence, then the concatenated archive SHA256 before decompression. Require the exact 32 listed regular-file members and their size/SHA256. Reject absolute paths, traversal, duplicate/unlisted names, symlinks, hardlinks, PAX/GNU extensions and other special members. Extract only to a new empty directory.

Restore the fixed published parent commit 0d03d437acd829a9113a6c300956b50b1a3291a9: candidate43, exact44–50 successors, G29, G28, then both G19 stages in order. Require the complete 3069-file parent map from source/SOURCE_CHAIN_MANIFEST.json. This package is a cumulative delta, not a standalone game.

From the safely extracted directory:

    python tools/rebuild_source.py --parent /path/to/exact-public-parent --source-package source

Optionally add --write-sparse /path/to/new-disjoint-output to regenerate all 23 staged after-images. Overlay the three stages in order onto a separate complete parent copy, validating all 14 before-image references. Require the final 3078-file map and binding dependency checks specified in SOURCE_CHAIN_MANIFEST.json. Source reconstruction is not an engine test.

## Separate development tools

The development_tools/ directory preserves an independently reviewed original 51327-byte tools archive, split into two 32KiB parts, plus its original BUNDLE_MANIFEST.json without edits. Use development_tools/ARCHIVE_MANIFEST.json to verify parts, full archive and exactly 24 members; apply the same safe-extraction rules into another fresh directory. The archive's original top-level prefix is g26_development_tools_pm03. Verify its original manifest before use.

These are source tools only, including a guard whose current scope is business/g26 for three ordinary-enemy groups. Packaging does not admit an engine run or establish final Boss/matrix acceptance. Follow the original README and separate review/job requirements for any future runtime use.
