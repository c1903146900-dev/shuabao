# G26 lifecycle and cap/ICD static source-tools recovery snapshot

This append-only backup preserves exactly 41 reviewed original files and 10 explicitly derived portable files. It includes lifecycle guard3a00/c505 and cap/ICD guardc1b84/7695, nine original primitives, adapters, base13caf, recipe, IDs, contracts, static reviews and reproducible pure tests. Production source4d9a is separately backed up and is not duplicated here.

This is source preservation, not fresh engine or gameplay admission. No actual jobs, process inventory, real PIDs, Store/handoff, runtime logs or credentials are included. Original README/review status fields are preserved at their sealing time.

## Safe restore

Verify every 32768-byte part (except the final shorter part), sequence/offset and full archive SHA256 using SOURCE_ARCHIVE_MANIFEST.json before decompression. Fetch binary files with encoding base64 if using the GitHub connector. Require exactly the 51 listed regular-file members under g26_boundary_source_tools_pm01/. Reject absolute/traversal paths, duplicates, unlisted files, symlinks, hardlinks, devices, PAX/GNU extensions and unexpected headers. Verify member lengths/hashes before writing into a fresh empty directory. Preserve the listed relative layout.

Read the restored README, then run Python3.12 -I -B portable/run_portable_pure.py from the restored root. The runner verifies complete original discovery sets and exact exclusions. It replays 185 selected original methods (66+69+25+25), 22 renderer methods and 10 template/selection methods, totaling 217. Seven original leaf-reading checks are explicitly excluded because the private-path original GD files are absent. This is not a claim that all 192 original methods ran, or that gameplay passed.

## Explicit templates

Original leaf scripts6274 and6fbc contain private absolute workspace prefixes and are excluded. Templates61378468 and915e82c6 replace precisely two prefixes each at lines1 and3. Renderers require canonical explicit workspace and fresh output disjoint from workspace and package in both directions, rejecting symlink ancestry. They never rewrite guard/semantic/job pins or start an engine.

Moving unchanged files does not change their source SHA. Rendering at a different workspace changes the leaf source identity and requires deliberate dependent pin updates, independent review, a fresh reviewed job and separate engine authorization. Even an exact in-memory original reconstruction only establishes byte equality. No private-path rendered script is distributed.

Scope is bounded by the packaged contracts: natural-expiry58, same-ID-replacement62, technical-cap54 and same-holder-ICD65. Full economy/floor, exact ICD endpoint, radius/obstacle/elite/Boss displacement, GUI and networking are not qualified here. Published earlier source and tools remain independent immutable snapshots.
