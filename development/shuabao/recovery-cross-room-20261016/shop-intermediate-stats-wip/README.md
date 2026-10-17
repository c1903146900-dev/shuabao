# Fengli sixteen-item intermediate-stat and rest transaction checkpoint (WIP)

Local source-only preparation. Publication requires independent audit and root approval. Target repository: c1903146900-dev/shuabao; branch: checkpoint/c02-revision06-20261011; required parent checkpoint: f4979659163266293d76dddebee5e9513122e137. Preparation performs no engine execution, upload, branch update or main change.

## Exact source scope

Restore the preceding shop-hp-stats-wip checkpoint and its required dependency chain first. Its exact 3355-file TARGET_SOURCE_MAP is the baseline. This package replaces only fengli_shop_20261016/catalog.gd and fengli_route_rest_20261016/rest_service.gd. No source files are added or removed. The complete 3355-file path set and all other source hashes remain unchanged. Supplemental fixtures, historical source and evidence are outside the restored production tree.

The formal catalog retains 95 rows: 83 goods (72 equipment, 3 potions, 3 flasks and 5 elixirs) plus 12 body-training rows. Sixteen stat-only equipment entries are supported: B01/B02/I01/I02, B05/I05/I13, B03/B07/B08/B06, and the five new intermediates I07/I09/I16/I17/I18. Other effects, unsupported equipment, potions and body training remain disabled. Catalog icons remain placeholders. This does not complete the full catalog.

The five admitted recipes and formal values are unchanged:

- I07 生命合金: total 1100, B06+B07, additional fee 200; HP220 and defense18.
- I09 相位推进器: total 1250, B08+B05, additional fee 250; move9% and CDR9%.
- I16 轻装护片: total 1200, B07+B08, additional fee 250; defense14 and move9%.
- I17 血肉触媒: total 1150, B06+B02, additional fee 250; HP190 and AP28.
- I18 猎杀号角: total 1200, B01+B08, additional fee 250; AD18 and move9%.

Prices, recipes, numeric source tables, HP Model/Sim, combat rules, actor identity, AI and geometry are unchanged. Buying or rebuying max-HP equipment does not heal. A valid same-visit inverse restores only its own exact clamp, and actual HP changes seal dependent tickets. Existing original HP ownership remains authoritative.

## Verified evidence and its limits

- Intermediate backend01: 477/477 checks, 66 unchanged pins. Covers exact recipes/fees, component UID inversion, sale and own-clamp inversion, command replay/conflicts, six slots/full-slot synthesis, insufficient funds, original stat consumers, movement, Q1 cooldown and defense damage. Money, HP and action-encounter setup are synthetic. This fixture does not exercise rest_service.gd.
- Rest transaction01: 82/82 checks, 72 unchanged pins. Covers no-ticket and pending-ticket healing, exact dependency sealing, receipt replay, original Q3 reset, G19 deadline/permanent state preservation, and explicitly injected fault boundaries.
- Intermediate natural02: 355/355 checks, 412 unchanged pins. Runs the legal formal Room route through r11a, with original combat/input and actual shop UI callbacks. No injected gold, HP or service receipts. It earns 1355, buys/crafts/inversely restores all five recipes, then retains I07 with UID17/invested1100. The earlier B06 sale spread is 45, leaving gold210. Actual r11 rest heals 420 to 640, health revision5011 to5012, and accepts the real Room node receipt. Nine real positive-damage events are recorded.

Backend and rest fixtures use the same reduced test project.godot. Its full file and exact production difference are retained separately; this configuration is never installed into the restored production tree. Other intersecting production pins match the target map. Natural02 has no production pin differences. EVIDENCE_INDEX lists the exact intersecting source count and any pin differences for each run, rather than implying every run loads all 3355 files.

All three passing postchecks retain empty raw ERROR/leak lists and verified-empty owned cleanup. Original exit metadata's business_pass/rendering_verified flags and VSync/GLB UID warnings remain intact; exit zero alone is not business acceptance. This batch is automated actual-UI-callback coverage, not human native shop operation, a full Boss route, full-floor acceptance, or hardware audio verification. No engine is rerun while preparing this checkpoint.

## Preserved failure and rest boundary

Natural01 remains a failed run: 352 checks, four failures, root exit1. All five-item economy checks succeeded, but old RestService rejected the legitimate health observer ticket seal after physically healing 420 to640, so r11 entry and receipt did not complete. Its original postcheck, source pins, exit/cleanup records and old rest_service.gd preimage are retained. The same natural fixture is used in natural01 and natural02. No failed run is relabeled passed.

The narrow correction retains both original cleanup passes, finishes them before the final prevalidated safe-victory heal, predicts only the exact authorized HP-ticket seal metadata plus one Model revision, and still checks all other Model/save, inventory, currency, clocks and permanent-state invariants. Preflight rejects invalid or unreported HP. A post-cleanup violation records needs_recovery and cleanup_may_have_applied before healing. An injected violation of the verified final-heal contract returns the existing blocked/needs_recovery result and preserves unknown external writes. This is not arbitrary rollback, automatic fault recovery, a new permanent gameplay lock or a completed failed-rest flow.

Earlier failures, including HP backend01's 539 checks/94 failures and the older shop-joint/component failures, remain in the mandatory preceding checkpoint archives. This package does not rewrite prior evidence. The historical catalog-only plan is superseded by the explicitly verified two-file delta in PRODUCTION.patch and DELTA.json.

Existing chooser/cartoon/audio/HUD integration is inherited. Idle/run use existing cartoon assets; attack/hit/dash/death/skill presentation remains the prior mesh implementation. Independent standing-attack/art experiments are excluded. Resource samples are not a performance benchmark or preventive memory isolation.

## Safe recovery

Verify the trusted SHA-256 of ARCHIVE_PARTS.json, then use the adjacent unpack_checkpoint.py with --parts-dir PATH_TO_THIS_PUBLISHED_DIRECTORY --output NEW_PACKAGE_DIRECTORY --manifest-sha256 TRUSTED_ARCHIVE_PARTS_JSON_SHA256. The helper reads the actual listed parts, validates their sizes/hashes and joined archive, rejects links/unsafe/duplicate paths and non-regular tar members, and writes only into a new output directory.

Review the extracted restore_sources.py, then run Python 3 restore_sources.py --base-game PATH_TO_RESTORED_HP_TREE --base-map PATH_TO_HP_TARGET_SOURCE_MAP --output NEW_SOURCE_DIRECTORY --manifest-sha256 PACKAGE_MANIFEST_SHA256_FROM_ARCHIVE_PARTS. Both output paths must be new and have existing safe parent directories.

Restoration verifies the complete package manifest, baseline map identity, all 3355 baseline hashes, exact two-file delta and all 3355 output hashes. It rejects unsafe/symlink paths and rechecks that the baseline is unchanged. Preparation separately reassembles actual written archive parts, invokes the safety-checked restore and independently hashes the entire output. Remote redownload/restore is not claimed before publication.

The archive contains only changed source, supplemental test source/configuration, historical failed source and text evidence/manifests. Unchanged production assets are inherited; no cache bytes, engine binaries, videos, screenshots, generated media, ordinary saves, userdata, user reference material or credentials are included. Source-pin metadata may name cache/resource paths without containing their bytes. Original raw logs stay local and their SHA-256 values are retained.
