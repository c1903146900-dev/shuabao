# Fengli joint presentation checkpoint (WIP)

This incremental source checkpoint combines the existing motion fix, four-view idle/run appearance, smaller mirrored B-floor tiles and Boss audio through the actual Fengli scene. Normal completed-selection restart and the joint Host combat route passed the checks below. Closing during the Hex confirmation flash still has an unresolved timer-leak boundary. This is not full art, audio-listening or unrestricted lifecycle acceptance.

## Baseline and exact scope

Repository c1903146900-dev/shuabao; branch checkpoint/c02-revision06-20261011; parent aae160b31dad3096666f089bcc3ba461553a8c04. Publish only under development/shuabao/recovery-cross-room-20261016/cartoon-audio-joint-wip. Main is unchanged.

Restore the earlier motion-only package first. Its exact 3341-file TARGET_SOURCE_MAP SHA-256 is dc171b9df2e7e0b8c6fb110226c7f8cfed8559639a185374141c081e29769ab5. The new payload contains 10 text production files: seven additions and three modifications, no deletions, producing 3348 files. The 12-file candidate overlay also names two unchanged baseline files; those are inherited, not repackaged. Original PNGs remain in the baseline. Supplemental test fixtures and evidence do not count as production source files.

Only scenes/integration/fengli_room.tscn changes entry to cartoon -> Boss audio -> hud_safe -> camera_safe -> boss_art -> route_rest. Project, chooser, other heroes and the legacy route_rest entry remain unchanged. base_room retains the motion-sampling changes and substitutes the verified Boss audio router factory. All five audio scripts are pinned unchanged. Four-view sprites cover idle/run only; attack, hit, dash, death and skills retain original mesh behavior.

Cartoon Room v02 SHA-256: 0d4a9ae1e4084357a32cfad55e90dd165c97d89d11402306b0ebbb6571949b2b. Its exit guard restores original mesh visibility only while actor and sprite are still in-tree and neither is queued for deletion. It then releases presentation ownership and calls the inherited exit hook. Earlier text saying its only change was the audio extends line predates this repair.

## Native evidence

- Main02: real default chooser -> Fengli -> completed initial Hex selection -> return chooser -> confirm restart -> fresh Lv1, unselected Hex -> Alt-F4. 124.038 seconds; 1144 pins stable; root exit 0; owned cleanup empty; ERROR/leak lists empty. 55 warnings remain: 54 inherited GLB UID fallbacks and one unsupported VSync-mode warning.
- Lifecycle unit01: 200 assertions and 394 pins; clean. Limited to release guard behavior.
- Entry04: synthetic UI signals after real Hex selection completion; eight restarts; 185 assertions and 1145 pins; ERROR/leak lists empty. This fixture is supplementary, not real mouse-driven chooser evidence.
- Joint Host01: 119.182 seconds; 393 stable pins; all 12 production manifest files match; 605/605 assertions, including actual formal cartoon scene and cartoon/audio/hud chain. Original Host physics and legal input driver after an automatic legal prelude reached floor_complete: Boss HP 0, phase 2; hero HP 420, gold 1630, SP 3. Seven Boss cues produced 71 plays; pool size 11, terminal active 0, consumer closed. Root exit 0 and owned cleanup empty; ERROR/leak lists empty.

Host checks used Godot's Dummy audio driver. PCM and hardware listening remain unverified. Resource sampling is not a performance benchmark or preventive memory isolation. Component passes (audio603, four-direction140, floor B local visual checks) are supporting history, not substitutes for the joint results.

## Historical failures and unresolved boundary

Main01 successfully entered the UI but restart produced 152 detached-room ERROR records; it remains explicitly preserved as historical failure evidence. Entry01, entry02 and entry03 reported timer leakage when exiting during the confirmation flash; their records remain included. Entry04 waits for the transaction to complete before closing. That narrower passing scenario does not fix or prove the mid-flash close boundary. No new timer repair, shop candidate, inactive action catalog or failed generated image is included.

HISTORICAL_PRE_RUN_MANIFEST.json is the original source seal. Its runtime_tested:false flags intentionally retain their historical meaning. EVIDENCE_INDEX.json and individual postchecks record subsequent runs; the seal is not rewritten to claim that it originally knew those results. Original raw logs are retained locally and referenced by SHA-256; reviewed text reports and source-pin records are included without recordings or image frames.

## Recovery and validation

Concatenate archive parts in ARCHIVE_PARTS.json order and verify every part and archive size/SHA-256 before safe extraction into a new directory. Review restore_sources.py. Run Python 3 restore_sources.py --base-game PATH_TO_MOTION_ONLY_TREE --base-map PATH_TO_MOTION_ONLY_TARGET_SOURCE_MAP --output NEW_OUTPUT_PATH --manifest-sha256 VALUE_FROM_ARCHIVE_PARTS. Output must not already exist.

The restore script checks package bytes, all 3341 baseline source hashes, the exact delta and all 3348 target hashes, and verifies the baseline stays unchanged. It rejects divergent sources and unsafe/symlink paths. Supplemental test fixtures stay outside the production tree. No engine is launched by restoration.

Local archive extraction plus independent full-SHA restoration is verified before publication. Remote Git blob/size verification is a separate step; no remote re-download-and-restore is claimed.

The incremental package includes reviewed text source, documentation, tests and evidence only. No user reference media, PNG payload, recordings, MP4, cache bytes, userdata or secrets. Runtime cache names and hashes may appear in evidence as provenance, without cache content.
