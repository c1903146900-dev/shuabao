# Sandbox native validation static recovery tools

This append-only archive preserves exactly 30 reviewed files: 25 original static sources/records plus five documentation, metadata and read-only verification files. It includes six controllers, nine pinned process primitives, four native GD scripts, exact21 IDs and the public production-source recovery anchor. Production source1372 is separately backed up at commitb8338 and is not duplicated.

No actual Store, job, runtime log/receipt, cache, generated UID, private workspace path, credential or engine binary is included. Historical numeric process examples in fixed static reviews are retained as source provenance. Restoring bytes does not transfer a runtime identity or grant engine permission.

## Safe restore

Verify every part length/SHA256, sequence and offset, then full archive SHA256 using SOURCE_ARCHIVE_MANIFEST.json. Parts are fixed32KiB except the final shorter part. Connector reads must use fetch_file encoding base64. Require exactly 30 regular members under sandbox_native_validation_tools/. Reject absolute/traversal paths, duplicates, unlisted files, links, special files and PAX/GNU extensions; verify all member hashes before writing into a fresh empty directory.

Read the restored README and VALIDATED_SCOPE.md. Run Python3.12 -I -B verify_bundle.py --root ABSOLUTE_CANONICAL_BUNDLE_ROOT --manifest-sha256 aaf8b64ea7d83a01aa7c98d6120a4a460921e62989b292fa40672e9592640e3a. This bounded, no-follow verifier performs AST-only source checks without importing controllers, starting processes, writing data or contacting a network. Its 29-file count excludes PACKAGE_FILES.json; the full bundle has30 files.

The local independent20-test boundary suite remains review evidence outside this archive; it was rerun against restored bytes. The shipped read-only verifier is the recovery entry point. Pure checks are not gameplay acceptance.

Guard62f73/adapterc21b/importd8 and the native business additions common0b80/link1391/semanticd227 retain exact bytes. New execution requires freshly reviewed source copy, same-controller editor import, real matching import evidence, a separately reviewed job and explicit engine-window authorization. Owner and G26 groups remain closed. No job template or fallback runner is supplied.

The packaged scope document distinguishes completed limited checks from outstanding GUI/network/deployment, exhaustive-world coverage, separate GdUnit27/CoreGround28 successor rerun and actual c21b branch activation. No new runtime claim is inferred from this backup.
