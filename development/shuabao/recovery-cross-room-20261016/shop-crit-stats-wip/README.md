# Fengli twenty-eight-item critical chance and lifesteal checkpoint (WIP)

Local source-only preparation, requiring independent audit and root approval before publication. Repository c1903146900-dev/shuabao; branch checkpoint/c02-revision06-20261011; exact parent ade787df2c11b0229ffc9ba1365d3a9ecfd72b62. Preparation does not execute an engine, upload or mutate branches.

## Exact scope

Restore the preceding shop-tenacity-stats-wip checkpoint and its dependency chain first. Its complete 3355-file TARGET_SOURCE_MAP is required. The sole production replacement is fengli_shop_20261016/catalog.gd, admitting six further existing stat-only entries. No source files are added or deleted. The complete path set and every other source hash stay unchanged, including rest service, HP Model/Sim, combat consumers, geometry and AI. Supplemental fixtures remain outside the restored production tree.

The formal catalog retains all95 rows: 83 goods (72 equipment, 3 potions, 3 flasks and 5 elixirs) plus12 body-training rows. Supported equipment grows22 to28, adding B04/B09/I03/I06/I10/I11 to the preceding22. Unsupported equipment/effects, potions and body training remain disabled. Icons remain placeholders; this does not implement the whole catalog.

New admissions preserve the original formal values and recipes:

- B04 鹰眼棱镜: 500; critical chance10%.
- B09 血泵: 500; lifesteal4%.
- I03 狂热齿轮: 1500; B03+B04+B08 plus50; attack speed20%, critical chance10%, move5%.
- I06 血袭刀环: 1200; B01+B09 plus250; AD18 and lifesteal6%.
- I10 狂战泵: 1200; B03+B09 plus250; attack speed22% and lifesteal6%.
- I11 贯穿镜: 1250; B04+B11 plus250; critical chance15% and penetration14.

Original critical chance and lifesteal formulas remain authoritative, including existing E3/H14 and learned-P1 distinctions. The original critical multiplier is1.75. Lifesteal uses actual damage rather than nominal or overkill damage, and retains original basic/active/indirect packet factors, impact-rate snapshots, true/no-reactions exclusions, max-HP cap and dead-actor exclusion. Equipment buying does not heal. An actual HP gain triggers the existing dependency observer; a zero-gain capped heal does not invent a new HP revision.

## Frozen-source evidence

- Backend01: 1229/1229 checks, 66 unchanged pins. Covers six direct trades, four recipes including I03's three components and50 fee, full-six-slot synthesis consuming the exact component count, component UID inverse, funds/slots/HP boundaries and original stat projections/caps. Critical probes use original Sim RNG seeded424242 and an independent same-seed oracle:64 real request_action attacks per critical item, one original draw per cast, critical and noncritical outcomes and actual source-multiplier damage. This is deterministic functional coverage, not a statistical probability estimate.
- Backend lifesteal probes use original damage_enemy against original spawned minions. They cover basic1, active0.4 and indirect0.25 factors, nonapplicable direct-other/true/no-reactions cases, actual damage-to-heal, impact-rate snapshots, max cap/zero gain, overkill constrained by actual targetHP3, original learned-P1 additive basic rate and dead-actor exclusion. Funds, wounded/full/dead HP, target durability/immobilization and packet setups are explicitly synthetic, without changing production formulas.
- Natural01: 383/383 checks, 412 unchanged pins. A legal formal Room route r01a/r02a/r03a/r04a/r05a/r06a/r07a/r08b/r09b/r10c/r11b earns1625 through original combat and roster rewards, with no injected gold, HP or service identity. Real extra fights provide enough money for I03's1500 cost. Actual UI callbacks buy/craft/inversely restore all six goods, then retain I06 for1200. Prior B06 sale spread45 gives1625−1245=380 final gold, I06 UID17/invested1200, and original r11b rest ends at HP420/max420.

The natural route genuinely traverses the additional r09b combat and r10c instead of borrowing the old r09-rest route's earnings. Twelve actual positive-damage events are recorded; this does not claim they were all true-damage typed. It stops before Boss. Automated legal input and actual UI callbacks do not establish human native purchase operation or full-floor acceptance.

Backend does not load or test rest_service.gd. It uses a reduced test project.godot retained separately with its exact production diff; production configuration remains unchanged. Other intersecting production pins match the target; natural has no production pin differences. EVIDENCE_INDEX records the actual number of pinned production files instead of implying every run loaded all3355.

Both runs retain empty raw ERROR/leak lists and verified-empty owned cleanup. Original VSync/GLB UID warnings and exit metadata remain recorded; exit zero alone is not business acceptance. No engine is rerun during checkpoint preparation. Hardware audio, performance benchmarking and preventive memory isolation are outside this evidence.

## History and inherited boundaries

Both first runs in this batch passed; there is no new failed run. The preceding archive preserves backend871/12fail and its fixture-only lethal-target cleanup correction. Its dependencies preserve natural352/4fail with old rest source, HP backend539/94fail and earlier shop-joint/component failures. All remain historical failures; no failed evidence is relabeled passed. This checkpoint does not rewrite any older file.

The inherited narrow rest correction preserves unknown external writes and reports blocked/needs_recovery on diagnostic contract violations. It does not claim arbitrary rollback or automatic fault recovery. Prior chooser/cartoon/HUD/audio integration is inherited. Idle/run retain existing cartoon assets; attack/hit/dash/death/skill presentation remains the previous mesh implementation. Concurrent sprite, standing-attack, cross-hero and audio experiments are excluded. Proposal text is historical; this README, final verification report, SOURCE_FREEZE and DELTA describe current scope.

## Safe recovery and exclusions

Verify ARCHIVE_PARTS.json against its trusted SHA-256. Run adjacent unpack_checkpoint.py with --parts-dir PATH_TO_THIS_PUBLISHED_DIRECTORY --output NEW_PACKAGE_DIRECTORY --manifest-sha256 TRUSTED_ARCHIVE_PARTS_JSON_SHA256. It validates actual part sizes/hashes and the joined archive, rejects links, unsafe/duplicate paths and non-regular tar members, and writes only into a new directory.

Review extracted restore_sources.py, then run Python3 restore_sources.py --base-game PATH_TO_RESTORED_22_ITEM_TREE --base-map PATH_TO_22_ITEM_TARGET_SOURCE_MAP --output NEW_SOURCE_DIRECTORY --manifest-sha256 PACKAGE_MANIFEST_SHA256_FROM_ARCHIVE_PARTS. Outputs must be new with existing safe parent directories.

Restoration verifies package inventory and hashes, baseline map identity, all3355 baseline hashes, exactly one catalog replacement and all3355 final hashes, then rechecks the unchanged baseline. Preparation separately reassembles actual written parts and compares the complete restored path/hash map. Remote redownload/restore is not claimed before publication.

The package contains changed source, supplemental fixtures/configuration and text evidence/manifests only. No cache bytes, engine binaries, videos, screenshots, generated media, user reference material, ordinary saves, userdata or credentials are included. Unchanged production assets are inherited. Pin metadata may name cache/resource paths without their bytes. Raw logs remain local with exact hashes recorded.
