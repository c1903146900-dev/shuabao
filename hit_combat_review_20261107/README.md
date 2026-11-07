# Directional player hurt response: isolated candidate

Accepted baseline remains motion_combo10. This candidate is NOT promoted.

Actual first-room damage captures showed that the old small facing-based squash was easily missed except for the HP bar. Static review also showed that it could reinforce a normal basic-attack swing instead of communicating a hit, and reacted identically to attacks from opposite sides.

The candidate preserves the actual validated damage event direction and projects it to screen space for a bounded recoil. Maximum horizontal lean is 0.14 radians and offset 2.5 pixels, decaying to zero over 0.24 seconds with a squared curve. Existing squash magnitude is retained. Zero direction yields neutral squash plus a 1px downward sink. Damage direction does not alter gameplay facing, position, collision, action, damage, input, timing or hit-stop. The HUD pulse/tail remains unchanged. Multiple hits replace one bounded response; no accumulated knockback. Body rendering and body-picking use the same composed transform. Existing separate moving-basic legs remain unchanged.

Build from the original private runtime/recovery inputs with:
python3 -I -B rebuild_20261106/build_directional_hurt.py NEW_DIRECTORY
Base: motion_combo10/runtime. Candidate pack SHA256: 33e675266ece262f5acedf2082df8f3d6ca8ced594e6e3c4919f78918fa81f40.
Only player_health_cue.gd, presentation.gd and generated seals differ. Safe source, builders and test summaries are backed up. No private art, recorded images, raw gameplay logs or private input archives are included. This is not a standalone playable public build.

Observed tests under unchanged runtime protection:
- hitbodybefore01: actual normal-source enemy hit on combo10, 12-frame capture; old hurt posture and settled posture inspected.
- hitbodyafter01: same normal route on candidate. Actual damage direction projected x=+0.6624, recoil 1 then 0.498 then 0.139 then zero. Impact/settled frames inspected. Guard passed, exit 0, complete cleanup.
- hitchainright01: walk toward the right-side first-room enemy and repeatedly request normal basic actions. No simulation state writes. Actual hit projected x=-0.6624 occurred during an existing attack recovery; arm motion continued through recovery and the next basic attack. Impact/return frames inspected. Guard passed, exit 0, complete cleanup. This is script-assisted combat, not native held-mouse evidence.

Independent static review passed direction sign, source validation, timing, scope clearing, repeated-hit boundedness, and shared visual/picking transform. The observed change gives a more distinct directional body response but is not final aesthetic acceptance.

Remaining before promotion: actual held attack plus walking at the instant of damage, inspect moving-basic waist seam and full combat readability; retained source-health validation/lifecycle cases; shared UI and full-floor regression. Do not claim the standing-basic capture verifies moving-basic layering. Boss motion remains a separate candidate.
