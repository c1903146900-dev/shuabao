# Fengli chooser, Hex lifecycle and basic shop joint checkpoint (WIP)

This is an incremental source checkpoint over the cartoon/audio joint checkpoint. It joins the existing full-body chooser portrait, owned Hex confirmation Timer, basic shop transactions, actual HUD/modal input routing, Chinese stat labels and opaque shop UI through the formal Fengli scene. It is not a full shop, full animation or hardware-audio acceptance release.

## Baseline and scope

Repository: c1903146900-dev/shuabao. Intended branch: checkpoint/c02-revision06-20261011. Parent: ce42159ef5c8f963418be09a67e1d35bf50f425e. Local preparation only; publication requires separate review. No main-branch change is part of this preparation.

Restore the preceding cartoon-audio-joint-wip checkpoint first. Its exact 3348-file TARGET_SOURCE_MAP SHA-256 is 04f5082d776204032a05645da32e676e58b78300b25f0a9db742fb95996e5fba. This payload adds five production text files and modifies five, with no deletions, yielding exactly 3353 source files. Existing PNGs, audio and other unchanged baseline assets are inherited and are not duplicated. Supplemental test fixtures and evidence stay outside the production tree.

The production delta is five fengli_shop_20261016 files (catalog.gd, model.gd, room.gd, view.gd, entry.tscn), plus the route bridge, route HUD, chooser, Hex draft and formal Fengli entry scene. The formal room extends the existing cartoon -> Boss audio -> HUD-safe -> camera-safe -> Boss-art -> route-rest chain. Shop accounting remains bound to the actual run, owner, inventory and earned gold. The chooser reuses an existing portrait asset. Project entry and unrelated heroes are unchanged.

The formal catalog contains 83 goods and 12 body-training entries. Only B01/B02/I01/I02 basic AD/AP stat transactions are enabled. Unsupported special effects and body-training are explicitly unavailable. Icons are placeholders. Catalog visibility does not mean every item can be purchased. P and the existing HUD shop button open the same modal; P/Esc close it, with modal input routing preventing gameplay leakage. Displayed stats use Chinese labels and units, and the shop background is opaque.

Idle/run retain the existing four-view cartoon presentation. Attack, hit, dash, death and skill presentation retain the previous mesh behavior. Independent attack-mask experiments and newly generated art are excluded.

## Evidence and version boundaries

These earlier runs used the pre-display-correction room source. EVIDENCE_INDEX records exact per-run production SHA differences against the final source rather than claiming a full rerun on the final hash:

- Rapid02: 187 assertions, 1149 stable pins, 20.642 seconds; clean cleanup and empty ERROR/leak lists. It exercises the owned-Timer rapid-close boundary. This is scoped fixture evidence, not proof of every possible lifecycle sequence.
- Host01: 605 assertions, 409 stable pins, 121.599 seconds; real original-Host combat and legal driver reached floor_complete, Boss HP 0/phase 2, hero HP 420 and gold 1630. Actual formal shop/cartoon/audio/HUD chain checked. Clean cleanup and empty ERROR/leak lists.
- Natural01: 272 assertions, 407 stable pins, 20.302 seconds; deterministic legal inputs and real shop UI callbacks/Viewport input, earned gold 1175 and final gold 1085 (net shop delta -90). Clean cleanup and empty ERROR/leak lists. This was automated, not manual native buying.
- Main01: root-operated default chooser -> Fengli -> completed initial Hex confirmation -> room HP420/Lv1 -> return chooser -> confirm restart -> fresh Lv1 Hex -> close. 1148 stable pins, 75.024 seconds, empty ERROR/leak lists and clean owned-process cleanup. It exposed the stale shop/body-training status text.

The subsequent production change only replaces the stale status phrases in the shop room's visible labels/tooltips. The natural test adds assertions for those display replacements. The former Host605 and Main01 results are prior same-functionality evidence; they are not final-SHA Host or main reruns. See STATUS_TEXT_FIX.patch and the preserved pre-fix room source.

Final display-correction source evidence:

- Native01: 408 stable pins, 82.805 seconds, clean cleanup and empty ERROR/leak lists. After an automated legal prelude to r05a/725 earned gold, root manually opened with P, read the corrected status text, opaque background and Chinese attack +12 label without developer JSON, bought B01 (725 -> 275; HUD AD38 -> AD50), closed with Esc, reopened with the existing bottom HUD button, sold (680), undid sale (275 + B01), undid purchase (725, empty inventory), and closed with P (AD38). Modal W/Q/Shift were not repeated in this window; the earlier independent native and automated input gates remain their evidence.
- Natural02: 274 assertions, 407 stable pins, 21.206 seconds, passed on the final room text source, including two new status-text assertions. Earned gold 1175, net economy delta -90 and final gold 1085. Clean cleanup and empty ERROR/leak lists. This remains deterministic automated legal-input/real-UI-callback evidence.

Godot's Dummy audio driver was used; PCM and physical speaker/headphone listening remain unverified. Existing GLB UID fallback and unsupported VSync warnings remain recorded. Exit code zero is not business acceptance: individual assertions, terminal state, raw-error/leak review and root native observations provide the scoped results above. Resource samples are not a performance benchmark or preventive memory isolation.

## Historical failures

Rapid01 failed because its inherited fixture expected the old cartoon root script instead of the new formal shop root; its failed fixture and postcheck are retained. Backend01, Room Natural01 and Native01 failures are retained as historical component postchecks, including the physical P shortcut bug discovered in Native01. Later input-routing verification does not erase that failure. The prior checkpoint's Main01 and Entry01–03 failures, including old mid-flash Timer leakage, remain in the required baseline archive. Original manifests and historic status flags are not retroactively rewritten.

Reviewed text reports, result records and source-pin records are included. Raw logs remain local with their exact SHA-256 recorded. No raw recordings or screenshot frames are included. Cached resource names/hashes may appear in pin records solely as provenance, without cache bytes.

## Recovery

Concatenate archive parts in ARCHIVE_PARTS.json order, validating each part's size/SHA-256 and the whole archive before safe extraction into a new directory. Review restore_sources.py, then run Python 3 restore_sources.py --base-game PATH_TO_CARTOON_AUDIO_JOINT_TREE --base-map PATH_TO_3348_TARGET_SOURCE_MAP --output NEW_OUTPUT_PATH --manifest-sha256 VALUE_FROM_ARCHIVE_PARTS. The output path must not exist.

Restoration checks the package manifest, all 3348 baseline source hashes, exact delta and all 3353 target hashes; it verifies the baseline stays unchanged and rejects unsafe/symlink paths. Supplemental tests are not copied into the production tree. No engine is launched by restoration. Local written-part concatenation, extraction and independent full-map SHA recovery must pass before publication; remote re-download-and-restore is not claimed.

The archive is text-only source, documentation, tests and evidence. It contains no user reference media, duplicate PNG payload, videos, cache contents, userdata, ordinary saved games or credentials.
