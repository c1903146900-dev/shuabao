# Fengli thirty-item regeneration dependency checkpoint (WIP)

Local source-only preparation, requiring independent audit and root approval before publication. Repository c1903146900-dev/shuabao; branch checkpoint/c02-revision06-20261011; exact parent ec2018a6d676b3474af6eda114183667102f72ad. Preparation does not execute an engine, upload or mutate branches.

## Exact source scope

Restore the preceding shop-crit-stats-wip checkpoint and its dependency chain first. Its complete3355-file TARGET_SOURCE_MAP is required. Exactly four production files are replaced: fengli_shop_20261016/catalog.gd, fengli_shop_hp_20261016/model.gd, fengli_route_rest_20261016/rest_service.gd and fengli_shop_20261016/room.gd. No source file is added or deleted. All other hashes and the complete3355-file path set stay unchanged. Supplemental test fixtures and failed-run source are excluded from production restoration.

All95 formal catalog rows remain:83 goods and12 body-training rows. Supported base/intermediate equipment grows28 to30 by admitting B12 and I12; remaining goods/effects/body training stay explicitly unavailable. Catalog icons remain placeholders; this is not full-catalog or all-equipment-effect completion.

B12 retains price400 and raw regeneration source value3. I12 retains B06+B12+200fee=1050, raw regeneration5 and maxHP190. The original 2026-10-08 balancing adapter explicitly defines the source as HP per five actor-combat seconds. It converts once to B12 equipment+.6 and I12 equipment+1 HP per actor-combat second. Original Wind base.5 yields total1.1 and1.5 respectively, absent other original modifiers. SOURCE_ANCHORS pins that pre-existing unit decision, adapter and consumers. No new interpretation of wall-clock time is introduced.

## Narrow dependency and UI changes

The catalog applies the original unit adapter and metadata. The same existing HealthModel marks only the accepted fresh changed transaction's exact newly appended regen-sensitive ticket, inside _apply and before queued external-health observations flush. Failed/no-op/replayed/undo commands do not add fresh dependency records. Rollback retains the existing ownership and poison guards.

An actual HP change first runs the original HP dependency phase, then seals only remaining unsealed regeneration-sensitive records with exact source/revision/before/after metadata. The active-command queue gate is retained. Each phase increments Model revision only if it sealed a record; a dual HP+regen ticket is counted once. Zero-gain/full-HP observations do not seal or invent a revision.

Rest predicts exactly those same two ordered phases, keeping all other invariants strict. Safe final healing follows both original cleanup passes. Full-HP zero-heal pending tickets stay unchanged. Unexpected contract violations preserve unknown external writes and return the existing blocked/needs_recovery contract; arbitrary rollback or automatic fault recovery is not claimed.

The shop uses the existing source-aware renderer, including the actual B12 label “战斗生命恢复 +3.0/5秒（+0.6/秒；随角色战斗时间）”, and hides the ambiguous duplicate raw stat display. Original Wind Sim, regeneration integration, clocks, damage rules, item prices/recipes, AI and geometry remain untouched. Original fixed steps already integrate regeneration with actual actor_dt; this package creates no additional timer or healing loop. Buying equipment still does not heal, and an eligible inverse restores only its own precise clamp.

## Frozen-source verification

- Regen backend01:614/614 checks,68 unchanged pins. Covers once-only unit projection and original28 mappings, prices/recipes/inverse/slots/funds, controlled original fixed-step rates, original actor-clock transformations, pause/noncombat/dead/full-cap boundaries, transaction-local marking, queued/reentrant external-HP faults and dependency sealing. Funds, wound/phase/clock inputs and callback faults are synthetic; original methods provide the tested behavior.
- Existing HP regression01:608/608 checks,68 unchanged pins. Retains original HP transaction/clamp/fault gates on this final source.
- Rest01:168/168 checks,74 unchanged pins. Covers exact ordered HP/regen phases, dual versus separate tickets, revisions/metadata, no-ticket/full-HP zero-heal, receipt replay and existing fault boundaries. Service ownership/fault setups are synthetic.
- Natural02:3942/3942 checks,416 unchanged pins. Actual formal Room route r01a/r02a/r03a/r04a/r05a/r06a/r07a/r08b/r09b/r10c/r11b earns1625. Real UI buys B06 and B12 and synthesizes/inversely tests I12 using its original200 fee. Total retained investment1050 leaves575 gold with I12 UID4/invested1050. Original r11b rest heals365.62735714281 to610/max610. No gold, HP or service identity is injected. Twelve actual positive hero-damage events are recorded, without claiming they are all true-damage typed.

Natural evidence observes3629 eligible wounded-B12 single-observation steps. All3629 have positive net gain matching original rate×actual actor_dt; zero mismatches. Three combat-ended steps and four damage steps are excluded. These are bounded net-gain/formula witnesses, not blanket attribution of every healing source. Exact original regeneration metadata is captured separately by controlled backend tests. Same-visit pending commerce tickets plus combat are naturally unreachable under actual-entry commit, so corresponding dependency faults remain synthetic coverage.

Backend and HP fixtures do not load rest_service.gd or shop Room UI. The rest fixture covers RestService but not native UI rendering. All three use the same reduced project.godot retained separately with its exact production diff. Other intersecting production pins match the target; both natural runs have no production pin differences. EVIDENCE_INDEX gives exact loaded production paths/counts and differences.

All four successful runs have unchanged pins, empty raw ERROR/leak lists and verified-empty owned cleanup. Original VSync/UID and synthetic HP NaN-to-JSON-null warnings are retained. Original exit metadata remains unchanged; exit zero alone is not business acceptance. Automated legal inputs and actual UI callbacks are not human hand-operated shop acceptance or a complete Boss/floor run. No engine is rerun during checkpoint preparation.

## Preserved failed history

Natural01 remains failed:198 checks, four failures. The first was the test's source_aware_B12_Chinese_units expectation of integer3 rather than the existing renderer's3.0. Three downstream fail-fast route gates then failed. Production hashes were already identical to natural02, including the preserved original Room preimage. Only the natural test changed to exact renderer-plus-suffix comparison, independent raw3/runtime.6/period5/scale.2 checks and actual/expected output. The failed fixture, original postcheck/pins/exit/cleanup records and exact test-only patch are preserved. No production formatting change was made to force that test to pass.

Earlier backend871/12fail, natural352/4fail, HP backend539/94fail and shop-joint/component failures remain in required predecessor archives. No historical file is rewritten or failed run relabeled. Existing chooser/cartoon/HUD/audio integration is inherited; idle/run use existing cartoon assets and other action presentation remains the preceding mesh implementation. Concurrent sprite, standing-attack, cross-hero and audio experiments are excluded. Hardware audio, performance benchmarking and preventive memory isolation are outside this checkpoint.

## Safe recovery and exclusions

Verify ARCHIVE_PARTS.json against its trusted SHA-256. Run adjacent unpack_checkpoint.py with --parts-dir PATH_TO_THIS_PUBLISHED_DIRECTORY --output NEW_PACKAGE_DIRECTORY --manifest-sha256 TRUSTED_ARCHIVE_PARTS_JSON_SHA256. It validates the actual part sizes/hashes and joined archive, rejects links, unsafe/duplicate paths and non-regular tar members, and writes only into a new directory.

Review extracted restore_sources.py, then run Python3 restore_sources.py --base-game PATH_TO_RESTORED_28_ITEM_TREE --base-map PATH_TO_28_ITEM_TARGET_SOURCE_MAP --output NEW_SOURCE_DIRECTORY --manifest-sha256 PACKAGE_MANIFEST_SHA256_FROM_ARCHIVE_PARTS. Output paths must be new with existing safe parents.

Restoration verifies the package inventory/hashes, exact baseline map identity, all3355 baseline hashes, four declared replacements and all3355 final hashes, then rechecks the unchanged baseline. Preparation independently reassembles actual written parts and compares the entire restored path/hash map. Remote redownload/restore is not claimed before publication.

The package contains changed source, supplemental fixtures/configuration, historical failed source and text evidence/manifests. No engine binaries, cache bytes, videos, screenshots, generated media, user reference materials, ordinary saves, userdata or credentials. Unchanged production assets are inherited. Source pins can name cache/resource paths without containing their bytes. Raw logs remain local with exact SHA-256 recorded.
