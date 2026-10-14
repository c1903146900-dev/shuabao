# G26 strict budget source-tools recovery snapshot

This independent append-only backup preserves exactly 36 reviewed original files plus four explicitly derived portability files. It includes guard24be, parser4f97, contracts/reviews, official format-source evidence with original copyright/license headers, nine pinned primitives, base13caf/IDs47b/recipea06, and three reproducible pure-test modules. It does not alter published production source, sandbox P6 delta, or earlier PM03/PM04/db0f9 backups.

This is source preservation, not new engine admission. The packaged parser/guard are restricted to the two reviewed budget scenarios. Unrelated-queue/risk63 and remaining scenarios receive no qualification from this package. Actual jobs, process identities, Store/handoff data, runtime logs/receipts, secrets and machine-private absolute paths are excluded. Original review/README status fields describe their own sealing time and remain unchanged.

## Safe restore

Use SOURCE_ARCHIVE_MANIFEST.json as the exact member allowlist. Read every part as binary; use GitHub fetch_file encoding base64 when using that connector. Verify per-part length/SHA256, contiguous sequence/offsets and full archive SHA256 before decompressing. Require exactly the 40 regular-file members under g26_budget_source_tools_pm02/. Reject absolute paths, traversal, duplicate/unlisted names, links, special files and PAX/GNU extensions. Verify every member's size/hash before writing into a new empty directory. Preserve the listed relative layout.

From the extracted root, read its original README. Run these original test modules with Python3.12 -I -B:

- recovery_20261014_pm/g26_budget_guard_prepare_pm01/test_g26_budget_parser_pm01.py (47 methods)
- recovery_20261014_pm/g26_budget_guard_prepare_pm01/test_budget_guard_integration.py (23 mocked methods)
- portable/test_render_external_script.py (11 methods)

The 81 pure methods verify source behavior without starting Godot. They are not gameplay results or permission to run a fresh job.

## Explicit template boundary

The original6e0 adversarial script is excluded because it contains two private absolute workspace prefixes. The e092 token template is a distinct derived identity. Its dad33 renderer requires an explicit canonical workspace and a new output outside both that workspace and this package; it rejects symlink ancestry and overlapping/existing output. Rendering never rewrites parser, guard, contracts or jobs.

At a new workspace, the rendered script has a new source SHA and requires deliberate dependent pin revisions, independent review, a fresh reviewed job and a new engine authorization. Even exact original-source reconstruction only proves byte equality, not runtime qualification. No private-path rendered output is included here.
