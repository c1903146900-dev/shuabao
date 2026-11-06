# Source-timed dash-attack anticipation

Source-only dash_timing01 overlay after the complete control_continuity01 baseline. Only puppet_motion.gd changes. Retain preceding overlays and assets, apply this file at its relative runtime path and regenerate binding metadata. Original versions remain unchanged; this is not a standalone project.

Runtime SHA256: e735fe168a77c7a7dc242651895e4a35293bf173e0f34bb4c768b3aaac6b5260. The source hash is recorded in CHANGE_PINS.json.

The existing dash attack already had a distinct forward-sword pose and real-hit effects. Its motion, however, began fully extended before source contact. This change adds a brief continuous pullback, reaches full extension exactly at the original 7/60-second contact time, then recovers over the original recovery interval. It uses one blade and existing art, without new assumed-hit effects. Damage, timing rules, collision, cooldown, trajectory, invulnerability, AI and direction are unchanged.

## Focused verification

Production loading and 976 timing/input/pose checks passed. Default-view, normal-source event sequences separately covered dodge alone, a missed dash attack and a confirmed hit: the final candidate recorded 47, 37 and 38 frames respectively, all with passing runtime checks, exit 0 and complete cleanup. The miss had zero hits; the confirmed hit dealt 41.8 damage once. These are script-assisted normal input events, not human play or fixed-frame-rate video.

The baseline dodge capture completed and exited with code 0, but its safety check failed on an unreadable memory field, so it is not counted as a fully passing run. Three early attempted hit demonstrations actually missed and remain zero-hit evidence. No SCRIPT ERROR was reported in the successful final cases; existing boot NUL diagnostics remain. No blanket error-free claim is made.

Fresh regression of this exact runtime passed all 12 selected nodes through Boss and 11 key-UI checks; see [combined flow verification](FLOW_QA.md). These are script-assisted results, not human playthroughs. Windows and subjective user acceptance remain unverified. This is still original-art mesh/cutout motion, not bespoke multidirectional animation. Only code, hashes, tests and this summary are included; internal reports, capture fixtures, images, logs, assets and runtime packages are excluded.
