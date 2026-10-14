# G26 development tools PM04 source backup

This append-only tools snapshot preserves the independently reviewed original PM04 archive and BUNDLE_MANIFEST.json byte-for-byte. It adds the reviewed recipe integer-type normalization test source. Production source and the earlier PM03 archive remain unchanged in their existing paths.

Source-only backup. Packaging runs no engine and supplies no automatic runtime qualification. No runtime receipts, private jobs, Boss/motion scripts or a175 guard are included. Read the original bundled contract and provenance before use.

## Safe restoration

Read ARCHIVE_MANIFEST.json. Fetch both parts as binary, using GitHub fetch_file encoding base64 when using that connector. Verify each part length and SHA256, sequence and offset, then the concatenated archive length/SHA256 before decompression. The original archive is 53602 bytes.

Require exactly the 27 listed regular-file members under development_tools_g26_pm04/. Reject absolute paths, traversal, duplicate or unlisted names, symlinks, hardlinks, nonregular members and PAX/GNU extensions. Verify every member's size and hash before writing into a new empty directory. The member BUNDLE_MANIFEST.json must exactly match the companion original manifest, and its 26 payload entries must match the extracted files.

This snapshot is intended as a new directory on the existing checkpoint branch. It does not replace the published counter03 source backup or its original PM03 development tools.
