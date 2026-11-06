# Hostile projectile readability checkpoint

Candidate projectile_cues02 is based on the preserved enemy_cues02 runtime, retaining all previous body-warning and motion improvements. PCK SHA256 cf65fd47dc36368264b6c8b3062c7466678a778adb3bc3a481762942234ba453.

## Problem and narrow change

Flying enemy projectiles were represented only by solid red discs drawn before actors. Close melee could obscure incoming shots, and the discs offered no direction cue. The new foreground layer shows the same source-projected centers and radii with a dark edge, bright core, and short decorative tail opposite their current source direction. Bolt and hex-bolt accents differ, but hostile red remains. The decorative tail is not an attack range or hit region. Friendly shots are excluded. Lob discs keep their previous shape/color; their airborne presentation remains outside this change.

Only presentation.gd and new projectile_cue.gd, plus binding manifest/generation seal, differ from enemy_cues02. No enemy AI, damage, projectile speeds, collision logic, timing, rosters, HP, economy, or player input changes. Old candidates and Windows ZIP are preserved. The unused preliminary projectile_cues01 differs in a lob color constant; it was corrected before any runtime claim or adoption.

## Checks

Production Boot/parse and 308 projectile projection tests passed, along with108 previous warning tests. The projectile tests cover 100 directions for each of bolt/hex_bolt/lob, source immutability, friendly exclusion, and invalid radius rejection. They do not replace visual acceptance of each enemy type.

A normal-source mixed first-room clip captured60 frames/eight seconds. A manually inspected frame shows two incoming bolts with distinct tail directions, including one approaching the player in close melee. Guard passed/exit0,23.409069560 seconds with full cleanup. Navigation and combat are script-assisted normal actions, not human input; no state injection or altered enemy AI was used.

Full-floor regression is pending. Windows execution, audio, human full-floor completion, and final player satisfaction are not established. No new ZIP or publication is asserted.

First full-floor attempt was interrupted at row3 by unchanged guard protection: sample gap0.447100909 exceeded0.2 seconds, elapsed42.959079128, exit-15 with all processes reaped. This run is not counted as complete. A separate identical-candidate retry is underway; no guard settings were relaxed.

The first full-floor attempt was stopped by the unchanged runtime guard after 42.9591 seconds because its sampling gap exceeded the limit. It is not a successful full-floor result; a separate retry is pending at this checkpoint.

Source-only overlay: apply after the preserved enemy_cues02 baseline and regenerate binding hashes. This is not a standalone game. The public capture script saves under `user://projectile_cue_frame_*.png`. No images, raw logs, runtime packages or private materials are included.
