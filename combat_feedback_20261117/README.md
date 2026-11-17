# Combat feedback recovery delta, 2026-11-17
Prepared locally, NOT uploaded. Proposed destination: c1903146900-dev/shuabao, branch checkpoint/player-health-cue-20261106, directory combat_feedback_20261117/.

## Four changed sources
- fengli_route_20261024/sim.gd: bounded source-owned dash movement history, retaining original movement callback and validating identity after it.
- fengli_route_20261024/presentation.gd: consume actual dash history across rendering boundaries, preserve each existing ghost facing; no invented walk remainder.
- scripts/combat/hero_combat_core.gd: add existing pre-loss HP local value to the original player damage event only.
- fengli_route_20261024/player_health_cue.gd: use finite source hp_before so nested P2 healing is not counted again in the old-HP tail; retain compatibility fallback.

No damage, heal, movement, immunity or difficulty numbers changed. Existing art, crop, alpha, duration, trail cap and sample spacing retained. No image/audio assets or game binaries included. Publication reveals implementation and recovery details.

## Restore
Dependency: prior recovery_unified_20261117/ at commit ad4dd4db4c28acee35583fc545b1ca8d7c20b034 in the same repository. Follow its README with original owner-held playable.zip and delta238.zip, verified public historical inputs, Python 3 and git apply. The original archives remain private and required; this delta is not a standalone game.
Name the prior final output ROOT/final_candidate. ROOT must also contain tools/rebuild_late.py and source/rebuild_20261106/boot234 from that recovery. Verify base PCK SHA256 f4d4b2938bf289905aabb64fc42308cd067befdd219a7e6f248f36df673d3313.
Run: python restore.py --root ROOT --output NEW_ABSENT_DIRECTORY
Before/after source hashes, final PCK and 258 manifest bindings are checked. Expected PCK: 2db8a9d4c68c68a5e951e0cf9cc6cfd9ec61412b631b13fe06701ce5773a11b5. Runtime has 260 files.

## Evidence and limits
Both changes and the ghost-facing correction received independent source review. Fresh restoration matched all 260 runtime files and PCK bytes. Prior backed f4d4 was reconstructed fully from original archives and verified public materials after workspace rollback. No parser, engine, playthrough or visual acceptance. Original .025 sampling can still skip an individual slice; .15 lifetime is not extended during long frames. The HP correction changes only feedback math, not the actual rescue heal. Full-floor stall and basic-weapon occlusion are NOT claimed fixed. Baseline selection and remote state remain unchanged by preparing this package.
