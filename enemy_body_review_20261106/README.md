# Isolated minion attack-body candidate

Actual normal-combat observation showed the first melee minion retaining the same standing sprite through warning and impact, while its overhead warning cue did most of the work. Frame sequences were inspected before changing the presentation. This candidate gives that existing sprite a small foot-anchored anticipation lean/squash during its authoritative warning, followed by a forward release and 0.18-world-second settle after the actual enemy_impact event. No additional prompt, marker, hit effect, damage event, movement, hit range, AI coordination or attack timing was added.

Scope is minions only. Other enemy artwork and bosses are unchanged. Tilt is at most 0.09 radians; warning squash is at most 6%, release stretch at most 4%. Existing hit reaction composes independently. The release record is actor-specific, accepted inside the existing run/room/generation event gate, erased on attack cancellation and cleared at encounter/scope changes. It does not claim bespoke weapon animation or complete enemy action quality.

## Bounded actual comparison
The same normal-input approach then stops near a warning enemy; no health, positions or enemies are injected. Baseline and candidate screenshots show the body gradually compress/retract during warning and extend on actual release instead of staying entirely fixed. The difference is modest and partly occluded by the nearby hero in this sample; more crowded and opposite-facing checks are still needed before promotion. Actual receipts show warning lean -0.078261/squash 0.052174 near late warning, then forward lean 0.071111/stretch 0.031605 after impact. This is visual-only, not a knockback or stun mechanic.

Both observations passed the unchanged guard, exit 0, no SCRIPT ERROR or visual receipt errors, with owned processes cleaned up:
- Baseline: wall 27.441955 s, max sampling gap 0.055939 s, peak RSS+swap 666546176 bytes.
- Candidate: 76 frames, wall 26.169477 s, max gap 0.055263 s, peak 630194176 bytes.
Existing NUL diagnostics remain. Full floor, cancellation/pause, other enemy types, mirror/crowding and user aesthetic acceptance are not claimed.

## Isolation and recovery
Built separately from preserved r1_motion01, not from the walking candidate and not merged into a checked release. Only presentation.gd and generated manifest/seal differ. Run rebuild_20261106/build_enemy_body.py with a fresh output name after reconstructing r1_motion01. Private original input/artwork remains necessary. Pack SHA256: eba3b94654cb23fa22d5598c698db579bd5fdb72948ee0d28ee78db153f1da1e.
Public observers use user://enemy_body output paths (create directories first). Raw logs and screenshots remain private, excluded from the public backup.
