# Q3 rebased onto combo07, accepted as motion_combo08

Earlier Q3 presentation relied on pose switches; the isolated continuous sword-arm route had passed short left/right and lifecycle checks on older builds but had not passed a full floor under the guard. This update moves only the same three selector lines onto motion_combo07. It does not overwrite old presentation files: armored facing/broken posture, E3 open wind, signed body picking, hero alpha occlusion, player damage feedback and other skills are preserved.

Short actual left-facing and right-facing combat observations passed, with 13 sampled Q3 poses each. Reviewed rendered frames show windup, sweep, emitted wave and return, with mirrored body and arm together. The change introduces no extra labels, rings, hitbox, tracking, damage, cooldown or action-lock modification.

The exact candidate now passes a normal scripted 12-room first floor including Boss. Q3 started/launched/expired 21 times and made 25 contacts. Simulated duration 240.530343 seconds, HP 320.228393, gold 395, 9 potions purchased and used. Loadout Q3/E1/R2/P2. Guard wall 252.172294 seconds, maximum sampling gap 0.069766 seconds, exit 0 and complete owned cleanup. Prior old-build scheduling failures remain in their original review directories; none are reclassified as passes.

Same-package menu/new-run cleanup passed before release at age 0.04 (one pending event, no wave) and after release at age 0.18 (one live wave); old cast/projectiles and new-run state were clean. Shift remains an invalid Q3 cancel. Shared UI passed all 11 checks. Death cancellation and Windows release were not tested.

Independent read-only review confirms exactly three intended selector lines plus generated seals, no lost combo07 changes, and correct shared draw/picking transformations. All 243 manifest entries verify. motion_combo08 has identical runtime and pack bytes to tested q3_combo07_draft01, SHA256 3968f7ee0db26c47bcb4144ac2a8892e03f264582beef8f5c21769018bd09db5.

Restore motion_combo07 through the existing recovery chain, then run rebuild_20261106/build_q3_combo07.py motion_combo08 with this changes overlay. Private original assets/inputs are still required. Public backup contains only safe source, build scripts, observers and summaries, not private art/screenshots/raw logs. motion_combo07 remains intact. This is an incremental functional development baseline, not final user aesthetic acceptance or a claim that the whole game is finished.
