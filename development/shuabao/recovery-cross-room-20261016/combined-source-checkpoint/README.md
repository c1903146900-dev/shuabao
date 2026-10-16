# Rest + shape + floor + UI combined source checkpoint

Frozen 2026-10-16 15:54 UTC. Status: SOURCE_ONLY_PENDING_COMBINED_RUNTIME. This independent combined candidate has NOT been run as a combined build at this snapshot. Separate component successes below do not constitute combined acceptance.

## Later native UI observation on this source

After the source snapshot, manual_ui_run01 exposed a real UI blocker: the map layer covered the Q1 skill card. Q1 was not learned and r01a combat was not entered. This is a failed native UI check, not gameplay acceptance. The known defect requires a separate modal-layer fix; that later fix is not included in this frozen source package. The source snapshot and all its hashes remain unchanged.

## Exact delta and dependency

Base: repository c1903146900-dev/shuabao, commit 736f43bdbcfbaf4e968c728eb19a83bfc2c272d2, development/shuabao/recovery-cross-room-20261016/verified-followup. Restore its documented chain first. Required base TARGET_SOURCE_MAP.json SHA256: eafaebd19fcb75400f9986386f1155e63c5102b744b445d90f9584cf09344363 (3263 files).

This package adds 17 files and replaces 3 files, yielding 3280 source/art files. The new route/rest scene, model adapter, HUD, rest service, tests and reports are included. Replacements are limited to the actor view and two shared UI scripts. The new rest base_room preserves its Bridge/HUD wiring while taking only the Stage preload and mute-button anchoring hunks. Exact before/after hashes are in DELTA.json; detailed overlay hashes are in support/COMBINED_CANDIDATE_MANIFEST.json. Existing saved baseline trees and previous published checkpoints are untouched. project.godot is byte-identical; shared UI/actor scripts do change in this independent combined candidate, so an unchanged default entry does not mean unchanged default visual behavior.

The opt-in scene is res://fengli_route_rest_20261016/entry.tscn. No r04a, training, shop or broader route/rule expansion is part of this snapshot.

## Separate evidence, not combined evidence

- The predecessor rest-only candidate passed route_rest_run01, 85/85 functional checks through real r03a rest, with the original two rooms first. XServer BadValue startup error is retained as a limitation; this was not native UI/visual acceptance.
- rest_semantics_run01 passed 50/50 synthetic rest semantics checks. It uses artificial setup to exercise edge cases; it is not natural state acquisition or route acceptance. Its runner/rest source SHA values and exact result are in support/REST_SYNTHETIC_VERIFICATION.json. The unchanged rest service and test runner are included here.
- Separate shape A/B and floor C runs recorded structural comparisons and original-size image inspection. The parent accepted the bounded shape/floor changes after that inspection. Machine reports still mark visual_quality_acceptance and performance_acceptance false because structural metrics do not establish visual quality or frame-rate acceptance. The raw image media are not included in this source backup.
- UI changes had not received a combined native-layout check at snapshot time. The combination still requires its own functional regression and native visual/UI inspection. Prior 67/67 two-room and 10/10 isolated payment-fixture reports remain predecessor evidence, not results of this combined tree.

No whole-floor/boss, final art/audio, cross-platform, performance, manual-play or combined-release acceptance is claimed. Historical reports and plans are preserved as historical inputs; their old instructions/status do not supersede this snapshot boundary. In particular, the inherited rest SOURCE_BINDING/STATIC_CHECK_RESULT/verify_static.py describe the rest-only predecessor; the two intentional base_room overlay hunks are documented by the combined manifest rather than being silently treated as predecessor bytes.

## Exact source restore

Join archive.part files in numeric order. Verify every part and the full archive SHA256 against ARCHIVE_PARTS.json. Extract only unique regular safe-relative members; reject links, absolute paths and parent traversal. Then:

    python3 -B restore_sources.py --base-game /path/to/restored-verified-followup-game --base-map /path/to/verified-followup-package/TARGET_SOURCE_MAP.json --output /path/to/new-combined-game --manifest-sha256 MANIFEST_SHA256

Use package_manifest_sha256 from ARCHIVE_PARTS.json. Output must be new. The script validates the full package, all 3263 base hashes, every delta pin and all 3280 output hashes, copying independent files without changing the base. Target map SHA256: 24968036e6a10e42fe8750075a260e08a4f4ef344522444344ea582ee7c87a7d. A local independent source restoration passed all 3280 hashes. No engine is invoked. This is not a standalone distribution and requires the previously published source dependency chain.

## Support and exclusions

support contains preparation input lists, original overlay manifests, bounded comparison reports, the historical integration plan/builder, and separate run evidence with raw-log SHA256, exit observations and input pins. The historical builder uses its original workspace layout and predecessor/overlay folders; it is provenance/reference material, not the recovery entrypoint. Use restore_sources.py above for the supported exact recovery. Preparation scripts from earlier packages retain their engine/location constraints and require separate review before execution.

No raw logs, imported caches, .godot/.local data, private reference media, screenshots, credentials or engine binaries are included. Cache regeneration, engine execution and visual review are separate operations. Remote blob SHA/size verification is not a second remote download-and-restore test; no such round trip is claimed.
