# Enemy attack readability checkpoint

Candidate enemy_cues02 is layered on the preserved motion_polish02 runtime. PCK SHA256: 3ea8cacd425a0dcbed031eb1173d70c35ef466fd44c81d5ad4e09af84d684525.

## Observed problem and change

Ordinary enemy warning circles were drawn before actor sprites and centered only 22 pixels above their feet. In close melee, player and enemy sprites obscured them. The constant circle also did not communicate warning progress. The first-room roster includes a four-minion branch and a separate mixed ranged/pouncer branch; difficulty changes are not justified by that alone.

This version moves the body warning cue above the head and renders it after actor effects. A small ring fills using the authoritative warning_progress, with a short pointer from the committed aim. It is not a ground damage decal or an attack-range indicator. The source body_weapon contract and Boss wave visualization remain intact. Dead/non-warning enemies cannot retain a cue.

Only presentation.gd, the new enemy_warning_cue.gd, and the manifest/generation seals differ from motion_polish02. Enemy AI, authored rosters, attack times, damage, hitboxes, progression, and economy are byte-identical. Earlier passing runtime and Windows ZIP are unchanged.

## Evidence and limitations

Initial enemy_cues01 production parse failed because the helper preload was missing from the inherited presentation script. It was corrected in a new candidate; that initial run is not counted as passing.

Enemy_cues02 production Boot and a normal-source first-room combat clip passed with 108 helper checks and 60 captured frames over eight seconds. Of those frames, 36 contained active warning cues. Two individual frames were manually inspected, including two overlapping close-range enemies: their progress circles and direction pointers remained visible above the sprites. Guard exit 0, 22.472873193 seconds, full process cleanup. No game-state injection, enemy disabling, damage or HP overrides were used in the clip. Navigation/combat actions were script-assisted, not human play.

Fresh full-floor and mixed-roster follow-up results are recorded below. This does not establish Windows execution, audio quality, human full-floor completion, or final user satisfaction. No new package has been published.

## Full-floor follow-up

The unchanged enemy_cues02 pack completed all 12 selected nodes through Boss with normal source combat, authored enemies, progression and shop transactions: simulation time 178.963792667 seconds, seven potions purchased and used, ending HP420 and gold795. Guard passed, exit0, elapsed191.287322989 seconds, all owned processes reaped. This uses script-assisted normal input/router/UI actions; it is not human full-floor acceptance.

The first mixed-roster capture was stopped by the unchanged guard at 19.680973751 seconds because sample gap0.285311791 exceeded0.2 seconds. Its47 recorded frames are partial evidence only, not a successful complete clip. A manually inspected frame showed both ranged enemies' committed-direction pointers above their sprites. All processes were reaped; no guard limits were relaxed.

A separate retry of the identical candidate and same mixed-roster scenario completed108 checks and60 frames/eight-second combat capture, guard passed/exit0,24.133150781 seconds, maximum sample gap0.166783242 and full cleanup. Both failed and successful runs are retained. No new script/visual errors occurred in the successful first-room, mixed-room, or complete-floor runs. Existing inherited NUL font/resource warnings remain and are not new failures.

This is a source-only overlay checkpoint, not a standalone project. Apply it after the preserved motion_polish02 baseline and rebuild the manifest/seal. The public capture scripts use `user://enemy_cue_frame_*.png` and `user://enemy_cue_mixed_frame_*.png`. Screenshots, raw logs and runtime packages are not included.
