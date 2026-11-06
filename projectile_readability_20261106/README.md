# Hostile projectile readability checkpoint

Candidate projectile_cues02 is based on the preserved enemy_cues02 runtime, retaining all previous body-warning and motion improvements. PCK SHA256 cf65fd47dc36368264b6c8b3062c7466678a778adb3bc3a481762942234ba453.

## Problem and narrow change

Flying enemy projectiles were represented only by solid red discs drawn before actors. Close melee could obscure incoming shots, and the discs offered no direction cue. The new foreground layer shows the same source-projected centers and radii with a dark edge, bright core, and short decorative tail opposite their current source direction. Bolt and hex-bolt accents differ, but hostile red remains. The decorative tail is not an attack range or hit region. Friendly shots are excluded. Lob discs keep their previous shape/color; their airborne presentation remains outside this change.

Only presentation.gd and new projectile_cue.gd, plus binding manifest/generation seal, differ from enemy_cues02. No enemy AI, damage, projectile speeds, collision logic, timing, rosters, HP, economy, or player input changes. Old candidates and Windows ZIP are preserved. The unused preliminary projectile_cues01 differs in a lob color constant; it was corrected before any runtime claim or adoption.

## Checks

Production Boot/parse and 308 projectile projection tests passed, along with108 previous warning tests. The projectile tests cover 100 directions for each of bolt/hex_bolt/lob, source immutability, friendly exclusion, and invalid radius rejection. They do not replace visual acceptance of each enemy type.

A normal-source mixed first-room clip captured60 frames/eight seconds. A manually inspected frame shows two incoming bolts with distinct tail directions, including one approaching the player in close melee. Guard passed/exit0,23.409069560 seconds with full cleanup. Navigation and combat are script-assisted normal actions, not human input; no state injection or altered enemy AI was used.

Full-floor regression subsequently completed once; see follow-up below. Windows execution, audio, human full-floor completion, and final player satisfaction are not established. No new ZIP or publication is asserted.

First full-floor attempt was interrupted at row3 by unchanged guard protection: sample gap0.447100909 exceeded0.2 seconds, elapsed42.959079128, exit-15 with all processes reaped. This run is not counted as complete. The separate identical-candidate retry also stopped at row3; no guard settings were relaxed.

Second attempt: 38.5801103849999 seconds, gap 0.33123387099976753, guard reason GuardError:sample_gap_untrusted, exit -15, full cleanup. At that checkpoint, immediate retries stopped and the candidate remained experimental, with enemy_cues02 retained as the previously complete-floor-passed baseline. The later result below supersedes the pending full-floor status. The evidence does not establish whether the repeated scheduling gaps originate in runtime load or the execution environment. No new script errors were logged before interruption.


## Follow-up complete-floor result

Unchanged projectile_cues02 completed all12 nodes through Boss using normal source combat and UI actions:190.014131 simulation seconds,202.079606066 wall seconds,HP315.198392857143,gold395,nine potions purchased/four used. Guard passed,exit0,maximum gap0.088640071 seconds,all owned processes reaped. Prior failures remain recorded. No safety limit or game tuning changed. This establishes one successful script-assisted normal-combat full-floor run, not human/Windows acceptance or resolution of the intermittent sampling disturbance.

Source-only overlay: apply after the preserved enemy_cues02 baseline and regenerate binding hashes. The public capture script saves under `user://projectile_cue_frame_*.png`. No images, raw logs or runtime packages are included.
