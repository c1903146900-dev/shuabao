# Fengli eleven-item basic-stat and HP transaction checkpoint (WIP)

Local preparation only. Publication requires root and independent audit review. Repository c1903146900-dev/shuabao, branch checkpoint/c02-revision06-20261011; parent 875e87076e1d755d64b3580a51828f10cc9598d0. No main change, upload or engine execution is part of preparation.

## Exact baseline and delta

Restore the preceding shop-joint-wip checkpoint and its dependencies first. Its 3353-file TARGET_SOURCE_MAP is the required baseline. This package modifies fengli_route_rest_20261016/base_room.gd, fengli_route_rest_20261016/bridge.gd and fengli_shop_20261016/catalog.gd, and adds fengli_shop_hp_20261016/model.gd and sim.gd. No deletions: exactly 3355 source files. DELTA.json records baseline and target map SHA-256 plus every changed-file before/after hash. SOURCE_FREEZE.json records all five frozen production hashes. Supplemental tests and evidence remain outside production restoration.

The formal catalog retains 83 goods (72 equipment, 3 potions, 3 flasks and 5 elixirs) and 12 body-training rows (95 total). Eleven supported equipment entries are B01/B02/I01/I02 (existing AD/AP), B05/I05/I13 (CDR), B03 (AS), B07 (DEF), B08 (MS) and B06 (max HP). Remaining effects, additional HP-family items, potions and body-training remain explicitly disabled; catalog icons are placeholders. This is not implementation of the full catalog.

Formal prices, stat values, combat formulas, rank/stack rules and original life ownership are unchanged. B06 costs 450 and adds 140 max HP to Wind's original 420. Buying or rebuying equipment never heals. Undo may restore only the precise same-visit transaction's own clamp_delta; it does not invoke healing. An actual external HP change seals hp_sensitive tickets. Any actual next-room entry, including noncombat rooms, commits the prior visit; merely selecting a map destination does not. Observer revision tracks dependencies, not a parallel HP ledger.

## Evidence on the frozen production source

- HP backend02: 608 checks, 66 pins, clean pass.
- HP CDR regression01: 221 checks, 66 pins, clean pass.
- HP basic-stats regression01: 295 checks, 66 pins, clean pass.
- HP natural01: 268 checks, 412 pins, clean pass.

Both backend runs use a reduced test project.godot, whose exact difference from the restored production configuration is recorded in EVIDENCE_INDEX and backend_project.patch; this test configuration is not installed into production. The five changed production files match the frozen source. CDR, basic and natural pins have no differences against the target map.

All four postchecks report unchanged pins, empty raw ERROR/leak lists and empty owned-process cleanup. Evidence retains exact original postcheck, source-pin and raw-log hashes; raw logs stay local. Exit zero alone is not business acceptance. Original run metadata's business_pass/rendering_verified flags are preserved without rewriting; scoped assertions and postcheck clean_pass establish only the stated checks. Existing VSync/GLB UID warnings and the backend synthetic NaN-to-JSON-null warning remain recorded.

Natural evidence follows actual formal Room r01a→r02a→r03a→r04a→r05a→r06a→r07a→r08b→r09a→r10a, with earned rewards, original inputs and actual original UI callbacks. It buys B06 at 725 gold without changing 353.193214 current HP. Actual r09 rest fills to 560; sale clamps to 420; same-sale undo restores precisely its 140 to 560. Another sale/rebuy leaves 420 current HP and does not heal, charging the actual 45 spread. Actual r10 entry commits the remaining tickets. Final state: 1355 earned − 450 held B06 − 45 spread = 860 gold, one B06, HP 433.13/max560 and nine real positive-damage events. Four nonrest entries preserve exact carried HP. Original CDR and attack/defense/movement probes retain their formal values.

This batch is automated original-UI-callback evidence, not a new human native B06 purchase session. It does not rerun a full Boss/floor-completion acceptance. Current safe-only commerce plus actual-room-entry commit makes a same-shop pending ticket during combat unreachable naturally; HP-sensitive dependency/fault coverage uses controlled synthetic backend setups. Backend service attestation is synthetic; actual Room service evidence belongs to the natural run. Repeated-generation numeric probes explicitly establish synthetic scope only after testing stale-scope rejection. Prior native input acceptance remains prior-version evidence, not final-source native acceptance.

## Failures and inherited boundaries

HP backend01 is retained as a failure: 539 checks, 94 failures. The fixture copied Ink's 360/500 expectations instead of Wind's actual 420/560, attempted illegal service predecessors, reset nonfinite HP to the wrong 360, and synthesized combat reopening while original Boss closing remained set. Backend02 changed the fixture only: formal Wind/B06 expectations, legal predecessors and original encounter initialization. Production hashes are identical between those two runs. Original failed fixture and postcheck/result/pin records are retained. No failed run is relabeled passed.

All older shop-joint and component failures remain preserved in the mandatory shop-joint-wip baseline archive, including Rapid01, backend/room/native failures and earlier Main01/Entry01–03 failures in its dependency chain. Historical README and manifests remain as originally recorded. This checkpoint supersedes the earlier four-item support statement only for this new source map.

Existing chooser/cartoon/audio/HUD integration is inherited. Idle/run use existing cartoon assets; attack/hit/dash/death/skill presentation remains the prior mesh implementation. Independent attack-mask/art experiments are excluded. Dummy audio checks do not verify hardware speaker/headphone output. Resource sampling is not a performance benchmark or preventive memory isolation.

## Recovery and exclusions

Concatenate actual archive parts in ARCHIVE_PARTS.json order, validating each size and SHA-256 and the whole archive. Safely extract into a new directory. Review restore_sources.py, then run Python 3 restore_sources.py --base-game PATH_TO_SHOP_JOINT_TREE --base-map PATH_TO_3353_TARGET_SOURCE_MAP --output NEW_OUTPUT_PATH --manifest-sha256 VALUE_FROM_ARCHIVE_PARTS. The output path must not exist.

Restoration validates the package manifest, all 3353 baseline hashes, exact delta and all 3355 target hashes, rejects unsafe/symlink paths, and checks that the baseline remains unchanged. Local preparation additionally reassembles actual written parts and independently hashes every restored file. No engine is launched. Remote redownload/restore is not claimed before publication.

The archive contains only minimal changed production source, supplemental test fixtures and text evidence. Unchanged assets are inherited, without duplicated PNGs, generated art, attack experiments, videos, cache bytes, ordinary saves, userdata, user reference media or credentials. Provenance pin records may name cached resources without including their bytes.
