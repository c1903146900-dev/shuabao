# Sandbox cooldown rebuild 01: static candidate

Identity: `sandbox012-cooldown-rebuild01-20261014`.

Status: static source review completed; all Godot parsing, import, runtime, persistence and GUI verification is **NOT_RUN**. This is a new candidate, not a recovery of the lost October 13 cooldown implementation. No old cooldown source hash or test result is inherited.

## Exact source and recovery chain

1. Repository `c1903146900-dev/shuabao`, commit `27ceff2408f0284779c833ce52bd00432d816cc6`, base `shaheyouxi/game`: 1,370 files. Verify against `shaheyouxi/PUBLIC_SOURCE_MANIFEST.json`, SHA256 `e80b955275dba798edb5a70465c1120c7432e799ddd110454e626335678a5501`.
2. Apply only the 11 verified replacements from `shaheyouxi/development/q-hotbar-fix-20261013`, using its `PUBLIC_MANIFEST.json`, SHA256 `dfd05c71175a9d210f7bb543aa2ffeae1547904ae5d264d5e23af6ba656efdb1`. The restored baseline still contains 1,370 files.
3. Apply this candidate's exact 13 source deltas after checking each baseline preimage. There are 11 production deltas (10 replacements, 1 new helper) and 2 test deltas (1 replacement, 1 new suite). The candidate contains 1,372 source files. The generated source manifest and delta manifest are the authoritative byte inventories.

Use a fresh isolated directory and retain all old source and receipts. The delta directory is not a standalone runnable project. The final complete source inventory must match before an independently authorized engine run.

## Formal rule and implementation

The numeric source is original `shuzhi.xlsx`, sheet `62_人物基础`, C11 = 0.6 seconds, stable ID `fangzhi_lengque`; F11 describes same-item placement/drop cooldown and excludes ammunition consumption. Sheet `137_快捷键` A4:C4 supplies the selected-hotbar Q rule. Original workbook SHA256: `736e69ab96ff099e1bec5148b85c82f91865eed0c0012153a8ab5a03079966bc`. Original design DOCX SHA256: `ea47bd7c60236a94a7a7d8fbc374fe0f10cb88af7a3c1815dea94009841effc9`. Originals remain at the pinned repository's `shaheyouxi/authorities/originals`.

Runtime reads the existing verified `ActorInputs` parameter `place_throw_cooldown_seconds` from `actor_settings.json`. No parallel literal duration, changed spreadsheet, changed projection or wall-clock/offline-time rule is introduced.

The mandatory private snapshot map is keyed by stable profile and admitted stable content ID. A real successful drop writes its absolute deadline in the same detached inventory/ground candidate. The existing owner publishes one validated root/bundle. Same-content carry from all sources shares the key; inventory moves and successful half-return do not start or extend it. Failure does not publish a new inventory, ground state, deadline or accepted sequence. Equality at expiry allows the next drop.

Core structure, aggregate cold validation and both hot validators check the same deadline semantics, including internal kind 1 without a ground clock. Helpers are shared through copies, load initialization and tree completion; bound contracts retain immutable input-root identity, and validators match the actor component's formal source identity. Absolute deadlines retain the same server world-seconds clock in aggregate snapshots. The existing no-peer world pause remains unchanged.

Published drops remain `durable=false`. A later independent save failure does not roll back a successful in-memory drop or discard its cooldown. Reopening restores the last successfully persisted aggregate snapshot; unsaved drops are not claimed durable.

## Compatibility

- Core contract: `sandbox012-inventory-core-v2`.
- Core format: `inventory012-exact-snapshot-v2`.
- Combined/profile marker contract: `sandbox012-world-inventory-v2`.
- Tree contract: `sandbox012-world-tree-fixture-v2`.
- Internal kinds 1/2/3, outer save profiles 5/6, View/Live protocols and existing SaveStore policy are unchanged.
- Old contracts/formats and missing new mandatory fields fail closed. There is no silent empty-map migration. Known contract incompatibility is not recoverable corruption and must not trigger automatic backup fallback.

## Evidence boundaries

The independent static review checked all 13 delta hashes, 1,372 paths and eight inherited critical API files. Static reviews 03 and 04 bind identical source afterimages. Static source checks report no newly missing scanned literal resource references, but they are not a GDScript parser/import check and do not close historical runtime resource-guard gaps.

The 27 new test functions are drafts, mostly Core/helper cases. The narrow binding fixture checks predicates and copies; it does not prove genuine Owner initialization, Frame cache hits or persistence. The one adjusted inherited ground test retains its stale-revision purpose under the new cooldown, without inheriting any historical pass.

The next runtime gate must include real Owner5/6 load initialization followed by valid same-source operations, actual SaveStore reopen and old-save no-fallback behavior, real hot cache-hit negative cases, Q11 regressions and publication-failure atomicity. See `RUNTIME_VALIDATION_PLAN.md`. All of these are **NOT_RUN**.

Formal building placement and ammunition consumption/reload entry points are absent. `zidan` is not admitted by current inventory rules. These integrations remain **DESIGN_BLOCKED**; no substitute gameplay entry or item admission has been added. Manual ammunition dropping, when formally admitted, is not exempt from the rule.

This source-only backup candidate contains no runtime saves, actual test identities, runtime logs or private absolute paths. It grants no engine-run or production activation permission.

## Deterministic chunked transport and safe restoration

The ordered binary parts listed in SOURCE_ARCHIVE_MANIFEST.json encode one USTAR + gzip archive containing the exact 19 reviewed backup files (445702 uncompressed member bytes), including all 13 source afterimages and the complete 1372-file source inventory. This is source-only archival transport, not a standalone runnable project. No extraction or execution script is published.

1. Verify the fixed part names, order, offsets, lengths, SHA256 and Git blob identities against SOURCE_ARCHIVE_MANIFEST.json. Reject missing, extra, duplicate or substituted parts. Concatenate only those parts in sequence into a new file; verify the full archive length and both hashes before opening.
2. Inspect the complete directory table: exactly the 19 listed regular files, each with the declared size and hashes. Reject absolute paths, parent traversal, duplicate names, links, devices, PAX/extended headers and all extra members. Require USTAR, mode 0644, mtime/uid/gid zero, empty owner names, and total member size 445702 bytes.
3. Materialize verified member bytes only in a new empty directory, never directly over a project. Verify every member again after writing. Do not execute archived code. The outer STATIC_REVIEW.json must match the archived copy; the archived README.md is the unchanged original source review.
4. Independently restore and verify the pinned 1370-file baseline and its Q11 replacements as documented above. Verify all 11 replacement preimages and absence of both new paths using DELTA_MANIFEST.json. Apply only the 13 source_delta afterimages in a new isolated baseline copy. Preserve the original baseline, Q11 and every older backup.
5. Verify the exact 1372 final source paths, lengths and SHA256 values against SOURCE_MANIFEST.json, whose own hash is pinned in PUBLIC_MANIFEST.json and the outer archive manifest. All engine, parse/import, runtime, persistence and GUI checks remain NOT_RUN; 27 new tests are drafts. Building and ammunition integration stays DESIGN_BLOCKED. Obtain separate runtime authorization.

The archive is deterministic: sorted member paths, USTAR regular files, mode 0644, zero timestamps and owner IDs, empty owner names, gzip level 9 with zero timestamp and no original filename. Binary parts are at most 32768 bytes. The .gdignore isolates this archival directory. Source contents and source identity are unchanged by compression. Remote publication must be verified separately; preparation is not a claim of upload or execution.
