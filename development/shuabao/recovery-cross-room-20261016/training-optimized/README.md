# Optimized r04a training successor checkpoint

Frozen 2026-10-16 16:52 UTC. Relative to the published production map-cache overlay, this delta replaces only fengli_route_rest_20261016/model.gd and room.gd and adds five training test/documentation/report files. The target has 3285 source/art files. Existing baseline copies and published packages remain untouched; the production map cache is retained without performance probes.

## Scope

After real r01a/r02a combat and r03a rest, the authored route permits r04a training. The candidate uses original Wind training reset/respec/learning APIs and explicit owner completion. It does not substitute ink rules or commerce permissions. Paid body training, shop transactions, r05a elite and Boss remain unavailable. Completion records readiness while physically remaining in the same training area; it is not departure or a reward grant.

Nonzero unresolved P3 swap-out remains explicitly DESIGN_BLOCKED for respec only. This is a guarded incomplete boundary, not an invented rule that clears or permanently forbids earned progress. Existing permanent-stat behavior is preserved. The source README documents additional cast/recovery guards and the exact authority boundaries.

## Separate verification

- Optimized natural regression: 118/118 checks passed through deterministic legal original inputs/APIs. This is not a full manually played route.
- Independent synthetic lifecycle fixture: 14/14 checks passed for original respec behavior and the unresolved guard. Synthetic state setup is not evidence of natural acquisition. This run pins the relevant Model but does not include the production Room in its input scope; the evidence explicitly records that distinction.
- Native training panel: an automatic legal prelude passed 83/83 checks and reached the handoff in 6.289 seconds. Only afterward did the parent manually select/enter r04a, respec (SP 2 to 3, Q cleared), repeat respec without extra refund, open/cancel skill selection without spending, relearn Q1 (SP 3 to 2), upgrade Q1 to rank 2 (SP 2 to 1), and explicitly complete training. Completion stayed physically in r04a with training permission and disabled the completion button. HP 420, gold 410 and XP 17 were preserved during the documented native panel steps.

The native observation is training-panel-only after automated preparation, not manually clearing both combat rooms. No r05a/elite/Boss, full-floor, all-hardware, final-art/audio or 60-FPS acceptance is claimed. VSync warning is retained in the native report. Exit/cleanup observations alone do not prove business success; the separate check results and parent-observed actions define the scope.

Summaries of all three run postchecks are retained under support/postchecks; raw_key_lines are omitted, with warnings retained. Exact raw-log hashes, source pins, run exits and results are in support and the candidate VERIFICATION_REPORT.json. The natural/native Room and Model pins match this source snapshot. Historical source manifests may retain source-only/pre-test status; the later verification reports describe what subsequently ran. No raw log content, screenshots or runtime userdata are distributed.

## Dependency and exact restore

Repository c1903146900-dev/shuabao. Required base: commit 90efdbfb03e1c596dc47973f6b542669431ec5a4, development/shuabao/recovery-cross-room-20261016/map-cache-overlay. Restore that checkpoint and its documented chain first. Required base TARGET_SOURCE_MAP.json SHA256: 823e30fb59a7ea38495968ef17b6656e4ef873a6ec07d711d91cd8431a645415. This package is not standalone.

Join archive.part files in numeric order; verify every part and the whole archive using ARCHIVE_PARTS.json. Extract only unique regular safe-relative files, rejecting links, absolute paths and parent traversal. Run:

    python3 -B restore_sources.py --base-game /path/to/restored-mapcache-game --base-map /path/to/mapcache-package/TARGET_SOURCE_MAP.json --output /path/to/new-training-game --manifest-sha256 MANIFEST_SHA256

Use package_manifest_sha256 from ARCHIVE_PARTS.json. Output must be new. Recovery verifies the package, all 3280 base source hashes, each before/after change and all 3285 independently copied output hashes. Target map SHA256: 39996b3e6e91556c17fa53b02ce84b5b0a322de01ad8ee4dcd0ddd31b354850a. Local independent source restoration passed all 3285 hashes and left the base unchanged. No engine is invoked by recovery.

## Support and limits

Support retains the original training/optimization patches and manifests, separated verification reports, exact training input lists and historical launch commands. Commands reference their original environment layout and pinned guard; they are provenance, not automatic portable launch instructions. Use the recovery command above for source restoration. Old ancestor runners retain their old stopping conditions; use the training-specific runners for this successor.

Excluded: .godot/.local, imported caches, raw logs, profiling traces, unrelated projects, private reference media, screenshots, credentials, user data and engine binaries. Remote blob SHA/size verification is distinct from a second remote download-and-restore; no such round trip is claimed.
