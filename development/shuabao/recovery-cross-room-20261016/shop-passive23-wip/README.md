# Fengli thirty-two-item passive23 candidate checkpoint (WIP)

Source-only candidate preparation. Independent package audit and root approval are required before publication. Repository c1903146900-dev/shuabao; branch checkpoint/c02-revision06-20261011; exact parent ec37814fb50e98aff0946046fa5e6f357d5506f2. This checkpoint is independent of the standing-attack integration. No engine is executed during packaging.

## Exact source scope

Restore the preceding shop-regen-stats-wip checkpoint and its dependency chain first. Its complete 3355-file TARGET_SOURCE_MAP is required, with SHA-256 04ba537a4a9c10d3d4a6c4252b0ab08e0e47b3d7dd08e0d66d00bd3eb734cc97. Exactly four production files are replaced: fengli_shop_20261016/catalog.gd, fengli_shop_20261016/room.gd, fengli_shop_hp_20261016/model.gd and fengli_shop_hp_20261016/sim.gd. No production source file is added or deleted. Supplemental fixtures and preserved failed-run source stay outside production restoration.

All 95 formal catalog rows remain. The bounded supported slice grows from 30 to 32 by admitting final:D05 and final:E05. Remaining unsupported goods, mechanisms and body training remain unavailable. Icons remain placeholders. A supported catalog entry is not a claim of natural acquisition or complete gameplay acceptance.

D05 群敌堡垒 retains price 3050, I07+I15+B10 components and fee 400, HP 520, defense 38 and tenacity 25%. E05 围城骨架 retains price 3100, the same components and fee 450, HP 520, defense 40 and tenacity 40%. Both use the existing 身陷重围/passive:23 mechanism. The original adapter and spatial consumer are reused unchanged: up to five distinct same-room/generation, live positive-finite-HP, nonspawn enemies within 5 metres of centre distance; each contributes defense 5 and tenacity 5 percentage points. The mechanism is unique across names and UIDs, while base item attributes still add. The original scope/count cache is derived state; paused sampling and retirement behavior are not described as a pure stateless function.

The same health-bound Model projects that spatial contribution through the original Consumers and original caps/common buffs. HealthSim refreshes at the corresponding pre/post fixed-step, pre-damage and encounter lifecycle boundaries, while skipping active transactions, health commands/projections and recursive refresh. Un-equipped refresh avoids extra Consumers calls. Dynamic contributions affect defense/tenacity only. No added HP, healing loop, clock, geometry or ordinary damage-rule change is introduced; the existing health observer, transaction ownership and clamp inverse remain authoritative. The Shop Room source adds a source-bound Chinese passive description, but that UI change has not been exercised by this batch's backend run.

## Verified backend scope and unverified boundaries

Backend02 passed 850/850 assertions with 70 unchanged input pins, no raw ERROR/leak entries, exit zero and verified-empty owned cleanup. The existing unsupported VSync warning is retained. Exit zero alone is not business acceptance.

The backend loads catalog, HealthModel and HealthSim, but does not load the changed Shop Room UI or rest_service.gd. It uses the separately retained reduced project.godot, not the production default-main project configuration. Source pins, the exact reduced-project diff and EVIDENCE_INDEX delimit the tested source version. The fourth changed production file, Shop Room, is frozen and statically diffed only. Prior 30-item natural/rest evidence remains historical evidence for the preceding source version; it is not rerun acceptance of this candidate.

Coverage includes formal source values and recipes; 32 supported rows and prior 30 mappings; funds/slots/component UIDs/inverses and rejected/replayed commands; spatial radius boundary, cap, duplicate IDs, spawn/death/nonfinite/scope/pause; unique mechanism versus additive base attributes; original actual damage/control and true-damage bypass; preimpact resampling; lifecycle cleanup; captured G18 saved_stats immutability; existing HP/regen ticket sealing and own-clamp inverse; no healing on purchase or refresh.

Actual controlled Wind damage witnesses with one nearby enemy: D05 receives 12.9032258064516 HP damage from an original 20 packet and 2 seconds of control becomes 1.4 seconds at 30% tenacity. E05 receives 12.7388535031847 HP damage and control becomes 1.1 seconds at 45% tenacity. These are explicit synthetic funds, wounds, enemy positions, Owner/service and G18 selection setups. Q1 is learned using the original initial skill point. They are not natural earnings, hand-operated UI, complete Boss/floor victory or performance evidence.

## Natural economic bound

No natural D05/E05 purchase has been verified. The source-bound first-floor DAG calculation finds at most 2260 gold from formal fixed kill rewards, including the Boss, along r01c/r02c/r03c/r04c/r05b/r06b/r07b/r08b/r09b/r10c/r11b/r12boss. This is a static maximum calculation, not a completed run. Even that upper bound is below D05 3050 and E05 3100 before spending. NATURAL_FUNDS_BOUND.json pins the route/reward sources.

A bounded read-only review of the currently implemented Wind economy and common Hex authority chain found no available extra-gold award that bridges this deficit. Common G21 consumes already-spent body gold; existing G30 stat projection reads the current balance. This does not claim that future floors or future features cannot add earnings. No natural funds were injected, no prices/rewards were changed, and no offers were forced to manufacture acquisition evidence.

The independent 32-item candidate is not included in the separately tested 3366-file standing-attack/30-item integration. Neither that integration's entry/active/natural results nor its running default main are evidence for these four candidate replacements.

## Preserved failed history

Backend01 remains failed: 776 checks, two failed assertions and an Array index 1 SCRIPT ERROR. The G18 action capture attempted an unlearned Q1; the original whitelist rejected it. Whole-Model.save equality wrongly forbade the original rejected-command receipt. Buying B06 before D05 allowed the original recursive I07 recipe to consume B06, invalidating the fixture's positional inventory assumption.

Only the fixture changed: learn Q1 with the original initial skill point; assert exact unchanged state/HP/source-cache plus exactly one denied receipt and read-only replay; buy in real recipe-aware order, select guarded item UIDs, and verify recursive B06 credit and consumption. The three production files loaded in both runs have identical pins. The failed fixture, original postcheck/sourcepins/exit/cleanup and exact test-only patch are preserved. The unexercised Room source is not retroactively claimed as a runtime pin.

Earlier failed evidence remains in required predecessor archives. No historical failure is relabeled or overwritten. Concurrent sprite/standing/cross-hero/audio work, generated media, hardware audio and resource-performance claims are outside this candidate.

## Safe recovery and exclusions

Verify ARCHIVE_PARTS.json against its trusted SHA-256. Run adjacent unpack_checkpoint.py with --parts-dir PATH_TO_PUBLISHED_DIRECTORY --output NEW_PACKAGE_DIRECTORY --manifest-sha256 TRUSTED_ARCHIVE_PARTS_JSON_SHA256. It checks actual part sizes/hashes, the joined archive and package inventory, rejects links, unsafe/duplicate paths and nonregular archive members, and writes only into a new directory.

Review extracted restore_sources.py. Run Python3 restore_sources.py --base-game PATH_TO_RESTORED_30_ITEM_TREE --base-map PATH_TO_30_ITEM_TARGET_SOURCE_MAP --output NEW_SOURCE_DIRECTORY --manifest-sha256 PACKAGE_MANIFEST_SHA256_FROM_ARCHIVE_PARTS. Output paths must be new with existing safe parents.

The restoration contract verifies the complete baseline map identity, all 3355 baseline hashes, four exact declared replacements and all 3355 final hashes, then checks the baseline remains unchanged. Package readiness requires independent reassembly of the actual written archive parts and full restored path/hash comparison. A README or prepared helper alone is not evidence that this build/restore gate has passed. The external preparation/restore/audit reports record those gates; remote redownload and restore are not claimed.

Only changed source, supplemental fixtures/configuration, preserved failed source and text evidence/manifests are included. No engine binaries, media, screenshots, cache bytes, generated artwork, user reference materials, ordinary saves, userdata or credentials. Unchanged production resources are inherited from the required baseline. Source pins may name cache/resource paths without containing their bytes. Raw logs remain local, with their exact SHA-256 recorded in the evidence index.
