# Fengli twenty-two-item tenacity and penetration checkpoint (WIP)

Local source-only preparation, requiring independent audit and root approval before publication. Repository c1903146900-dev/shuabao; branch checkpoint/c02-revision06-20261011; exact parent checkpoint 6e73ff1a72664ad9b7078eda3392ccbd75778bb5. No engine execution, upload or branch mutation is part of preparation.

## Exact scope

Restore the preceding shop-intermediate-stats-wip checkpoint and its dependency chain first. Its complete 3355-file TARGET_SOURCE_MAP is required. This package replaces only fengli_shop_20261016/catalog.gd, admitting six further original stat-only entries. No source file is added or deleted: the output remains 3355 files with exactly the original path set. Every other source hash, including the verified rest service and HP Model/Sim, remains unchanged. Supplemental tests and historical failed fixtures are not installed into the production tree.

All 95 formal catalog rows remain: 83 goods (72 equipment, 3 potions, 3 flasks and 5 elixirs) plus 12 body-training rows. Supported equipment grows from16 to22: previous B01/B02/I01/I02, B05/I05/I13, B03/B07/B08/B06, I07/I09/I16/I17/I18, plus B10/B11/I04/I08/I14/I15. Unsupported effects/equipment, potions and body training remain disabled. Icons remain placeholders; this is not the full catalog implementation.

New admissions retain exact formal prices, recipes and source values:

- B10 稳定环: 450; tenacity15%.
- B11 贯甲钉: 500; penetration10.
- I04 锯齿长刃: 1200; B01+B11 plus250; AD20 and penetration14.
- I08 不屈框架: 1100; B06+B10 plus200; HP200 and tenacity22%.
- I14 奥术穿针: 1200; B02+B11 plus250; AP30 and penetration13.
- I15 守心板: 1100; B07+B10 plus200; defense18 and tenacity22%.

No new consumer framework or combat formula is introduced. Original tenacity adds with original E3 and clamps at1; control duration uses the original multiplier and cannot shorten an already longer stun. Existing immunity takes precedence. Original penetration uses saved-replay, impact-snapshot or current values as appropriate; effective defense floors at0. True damage bypasses this ordinary armor/penetration mitigation, not every other final multiplier. Buying max-HP equipment does not heal; inverse restores only its own exact eligible clamp, and real HP damage seals dependent tickets.

## Evidence on frozen source

- Backend02: 883/883 checks, 66 unchanged pins. All six purchases/sales/inverses, four component recipes/fees and exact UID inverse, six-slot synthesis, duplicate accumulation/caps, funds and HP-clamp boundaries pass. Original spawned elite targets and stepped spawn grace exercise actual damage_enemy current/impact/saved-replay packets and true armor bypass. Single/six-item tenacity probes check actual stun duration, original actor/room/generation witness and preservation of longer stun. I08 actual damage seals HP tickets.
- Natural01: 353/353 checks, 412 unchanged pins. A legal formal Room route reaches r11a with real combat earnings and actual original UI callbacks for all six purchases/component syntheses/inverses. It earns1355, pays the original45 prior B06 sale spread and retains I08 for1100. Final gold210, I08 UID16/invested1100; original r11 rest heals420 to620/max620. Nine actual positive-damage events are recorded. No injected gold, HP or service attestation.

Backend setup funds, HP, repeated-generation setup and injected damage/control packets are explicitly synthetic. Lethal target teardown is fixture cleanup, not a naturally earned kill claim. The original safe-commerce and stale-generation checks remain intact. The backend does not load or test rest_service.gd. It uses a reduced project.godot whose exact file/difference are supplied separately; production project.godot is unchanged. Other intersecting production pins match the final target. Natural has no production pin differences. EVIDENCE_INDEX states the exact pinned-source count for each run.

Both successful runs retain empty raw ERROR/leak lists and verified-empty owned cleanup. Existing VSync/GLB UID warnings are retained. Original exit flags remain as recorded; exit zero alone is not business acceptance. This batch uses automated legal input and actual UI callbacks. It does not claim human native shop operation, a full Boss route, complete floor acceptance, hardware audio output, a performance benchmark or preventive memory isolation.

## Failed history and inherited limits

Backend01 remains a failure: 871 checks and12 safe_visit_reopen failures. Original elite probe targets remained alive; end_encounter did not remove living enemies, so the original commerce safety rule correctly rejected reopening. Only the fixture was corrected to use original lethal damage_enemy cleanup and assert dead/living0 before end/reopen. Production catalog hashes are identical between failed01 and passed02. The original failed fixture, source pins, postcheck, exit/cleanup metadata and exact fixture diff are preserved. No failed run is relabeled passed.

Prior natural352/4fail and its rest preimage remain in the mandatory shop-intermediate-stats-wip archive; older HP backend539/94fail and shop-joint/component failures remain in its dependency chain. The verified narrow rest fix still preserves external writes and uses blocked/needs_recovery for diagnostic contract violations. Arbitrary rollback or automatic fault recovery is not claimed.

Existing chooser/cartoon/audio/HUD integration is inherited. Idle/run use existing cartoon assets; attack/hit/dash/death/skill presentation remains the prior mesh implementation. Concurrent sprite, standing-attack, cross-hero and audio experiments are excluded. Historical proposal/plan text is not used as current implementation status; this README, SOURCE_FREEZE, DELTA and final verification report describe the frozen checkpoint.

## Safe recovery and exclusions

First verify ARCHIVE_PARTS.json against its trusted SHA-256. Run adjacent unpack_checkpoint.py with --parts-dir PATH_TO_THIS_PUBLISHED_DIRECTORY --output NEW_PACKAGE_DIRECTORY --manifest-sha256 TRUSTED_ARCHIVE_PARTS_JSON_SHA256. It validates actual part sizes/SHA-256 and the joined archive, rejects links, unsafe/duplicate paths and non-regular tar members, and writes only into a new directory.

Review the extracted restore_sources.py, then run Python3 restore_sources.py --base-game PATH_TO_RESTORED_16_ITEM_TREE --base-map PATH_TO_16_ITEM_TARGET_SOURCE_MAP --output NEW_SOURCE_DIRECTORY --manifest-sha256 PACKAGE_MANIFEST_SHA256_FROM_ARCHIVE_PARTS. Both outputs must be new with existing safe parent directories.

The restore verifies package inventory/SHA, the baseline map identity, every3355 baseline hash, exactly one catalog replacement and every3355 final hash, then rechecks the unchanged baseline. Preparation independently reassembles actual written parts and compares the complete restored path/hash map. Remote redownload/restore is not claimed before publication.

Only minimal changed production source, supplemental fixtures/configuration, historical failed source and text evidence/manifests are included. No engine binaries, cache bytes, videos, screenshots, generated media, user reference materials, ordinary saves, userdata or credentials. Unchanged production assets are inherited. Pin records can name cache/resource paths without containing their bytes. Raw logs remain local with exact SHA-256 recorded.
