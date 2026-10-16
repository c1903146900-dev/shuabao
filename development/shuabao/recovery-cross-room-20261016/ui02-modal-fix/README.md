# UI02 modal fix with bounded native-input evidence

Source frozen 2026-10-16 16:14 UTC. This delta replaces only fengli_route_rest_20261016/room.gd and hud.gd. The source snapshot matches both manual_ui_run02 and manual_ui_run03 input SHA pins. No combat values, reward/rest model, enemy AI, geometry or default project entry are changed.

The route map now tracks all original modal panels, including skill cards without a shade, and hides/restores correctly around modal opening/closing and combat. Candidate-only test configuration remains disabled and UI progress/status labels are corrected. COMBINED_UI_RUN02.patch records the exact two-file change.

## Evidence boundary

manual_ui_run01 previously failed because the route map blocked Q1 selection; its predecessor package remains unchanged.

manual_ui_run02: the parent used the native UI to select the third initial Hex, open/close the Q panel with correct map hiding/restoration, learn Q1 (SP 1 to 0), select r01a and enter combat with the map hidden. It later ended in real defeat at HP 0 without sustained manual input. That run did not establish native movement/attack acceptance. Exit was 0, elapsed 587.897076517 seconds, peak sampled RSS+swap 524300288 bytes, maximum sample gap 0.067299442 seconds, owned-process cleanup empty. Exit zero is not full gameplay success.

manual_ui_run03: on the same two source hashes, the parent repeated native preparation entry. Holding A for 5000 ms showed left movement/camera tracking and corresponding floor/boundary displacement. Left mouse for 5000 ms plus Q for 1500 ms showed a sword blade, damage number 38, damage exchanges, Q cooldown 4.9 and HP 378. Holding D for 5000 ms showed right movement and reversed floor displacement, Q cooldown 2.2 and HP 336. These observations verify bounded native movement, basic attack and Q input. They do not establish complete manual combat victory, whole-floor completion, final art/audio, cross-platform or performance acceptance. The raw log retained a VSync warning; cleanup was empty.

support/MANUAL_UI_RUN02_EVIDENCE.json and MANUAL_UI_RUN03_EVIDENCE.json retain raw-log SHA256, exit observations, source pins and explicitly parent-observed UI/input findings. They do not claim the raw logs independently prove the screenshot observations. No raw logs, screenshots or runtime user data are published here. Prior rest-only 85/85, synthetic 50/50 and component A/B/C evidence remain separate; this package does not turn them into a new combined full-route regression.

## Dependency and exact restoration

Repository c1903146900-dev/shuabao; base commit 27f3e9ccf6f5f33f82f268af5c761c10f2b6c113, development/shuabao/recovery-cross-room-20261016/combined-source-checkpoint. Restore that checkpoint and its documented chain first. Its TARGET_SOURCE_MAP.json must have SHA256 24968036e6a10e42fe8750075a260e08a4f4ef344522444344ea582ee7c87a7d. This delta is not standalone. It preserves the 3280-file count and changes exactly two source hashes.

Join archive.part files in numeric order, verifying every part and complete archive against ARCHIVE_PARTS.json. Extract only unique regular safe-relative files, rejecting links, absolute paths and parent traversal. Run:

    python3 -B restore_sources.py --base-game /path/to/restored-combined-checkpoint --base-map /path/to/combined-package/TARGET_SOURCE_MAP.json --output /path/to/new-ui02-game --manifest-sha256 MANIFEST_SHA256

Use package_manifest_sha256 from ARCHIVE_PARTS.json. Output must be new. The script verifies the package, every base hash, before/after delta pins and all 3280 output hashes, copies independent files and preserves the base. Target map SHA256: af6bc3ba223b74dcfa8c49f7fe81dff3a79010ab88037960f5df08a2eb045a5f. Local independent source restoration passed all 3280 hashes. No engine runs during recovery.

Excluded: imported caches, .godot/.local, credentials, private media, raw logs, screenshots, user data and engine binaries. Preparation scripts retain their previously documented constraints. Remote blob SHA/size verification is distinct from a second remote download-and-restore; no such round trip is claimed.
