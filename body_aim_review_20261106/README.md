# Isolated visible-body ordinary-attack aim candidate

Status: incomplete candidate03, NOT merged into the checked motion_combo02 release. Latest pack SHA256: fa14c6857a97b6b94105276ab2c8f65370d7c0634d0cac482d949ba075655fc7. Candidate02 pack SHA256: c5a5a3c28904f7d3209934d6c6ae0a30f70271442c3d429a9093f71ff9d55e83. Candidate01 was 4f005ff0b37750239558820ffd71a1a32425f395563b28327030062bb597c157 and passed 11 UI checks, but that does not certify pointer picking or this latest click-event fix.

## Gameplay observation motivating this work
A continuous 45-second mixed-route combat sample covered three rooms, with 70 enemy warnings, 32 shots and six pounce starts. Ranged pressure and melee/flanker engagement occurred together. This did not justify changing difficulty or coordination rules. A follow-up 22-second framing sample had 49 warnings/releases, with only two pouncer foot anchors near the lower playfield boundary; the body remained visible. No camera or enemy balance change was made.

A read-only body-to-ground projection sample during normal combat found 13 of 41 nearby body-center samples more than 45 degrees away from the direction to the actual enemy; four extreme close overlaps reversed direction. Even at distance 1.04 and 1.10, example direction dots were 0.100578 and 0.123717, around 83–84 degrees. Body-center samples are geometric evidence, not proof that every sampled center pixel was opaque or unobscured. Existing scripted floor tests passed enemy world coordinates directly and therefore did not validate this real mouse distinction.

## Candidate behavior and boundaries
Only ordinary non-dash basic aim uses a clicked opaque enemy sprite region. Drawing records the actual texture region, destination, foot-anchored deformation transform and actor draw order. Picking reverses draw order, inverse-transforms the pixel, samples texture alpha and returns only that living actor's current position. Empty/transparent pixels fall back to the original ground ray. No nearest-target search, proximity magnetism, range expansion, tracking state, projectile change, skill aim change or AI change is added. New scope and dead actor checks prevent stale picks. Held basic queries the current cursor again each time; it does not retain a selected target. Dash-basic remains source dash direction.

Candidate03 replaces the conservative hero rectangle with the actual rendered hero rectangles, cutout polygons and deformed mesh triangles. It maps the clicked triangle through its existing UVs, samples the actual pose texture alpha and respects actor depth ordering. Transparent space beside the hero no longer acts as a solid rectangle. Alpha threshold is 0.2. Exhaustive overlap, edge filtering and moving/skill-pose acceptance remain pending, not claimed by the short native checks.

Candidate02 additionally uses InputEventMouseButton.position for a fresh ordinary click, rather than rereading the global cursor later. The live native attempt exposed that the cursor could move/restore before the event was processed, producing an attack in the wrong direction. Held input still uses current cursor; keyboard skill aim and empty-ground mapping are unchanged. This event-position change is now exercised by the candidate03 native checks below.

## Validation honestly separated
- Candidate01 UI: 11 checks passed, wall 12.547278 s, no SCRIPT ERROR, exit 0, clean guard cleanup.
- First native observer failed parsing before gameplay due to an observer text-edit mistake. Fixed without changing game source.
- Next native attempt ended in ordinary player defeat while waiting for interaction. No successful mouse mapping is claimed.
- Paused native attempt stopped by unchanged guard: gap 0.298957 s, wall 8.034638 s. No mapping result.
- A new 45-second scheduling precheck had max gap 0.145349 s. One subsequent attempt reached a real native click. Its source attack pointed toward the restored cursor rather than the clicked body; this motivated candidate02. The run then stopped at wall 24.874251 s due to a 0.305030-second guard gap. It is NOT a successful native test or a basis for range/overlap acceptance. All owned processes were cleaned up.

No failed run was counted as passed and no guard limit changed. Preserve motion_combo02 as the current checked version.

## Candidate03 actual mouse evidence
- Scheduling precheck max gap 0.161324 seconds (partly overlapped the short UI check, not a guarantee of later stability).
- UI: 11 checks passed. Guard wall 15.422831 s, max gap 0.159180 s, exit 0, complete cleanup.
- First three-native-click run completed, wall 49.142286 s, max gap 0.178175 s. Its after-event global-cursor log was insufficient to establish exact picking, so it is not presented as full picking proof.
- A second read-only observer captured the original native InputEvent position before host routing. At point (566.2374,388.7783), the actual opaque visible minion pixel mapped to enemy_5 at (-1.208022,0,8.933743). Hero was (0.593970,0,8.042392). Source attack direction exactly matched (-0.896338,0,0.443371); the ground-only alternative would have been (-0.999134,0,0.041611). This is one verified visible-body mapping in a crowded room.
- Next native click was empty ground (878.6442,407.2398). Picker returned no body; source direction and original ground direction both equaled (0.991260,0,0.131924), despite several nearby enemies. No attraction back to the previously clicked target occurred.
- That second run completed normally: wall 54.035975 s, max gap 0.056201 s, exit 0 and complete owned-process cleanup. No SCRIPT ERROR. Pause/resume used normal Space input; synchronous Space+click avoided the earlier unpause-to-click delay moving the enemy away from the inspected pixel.
- The first far click in both runs actually reached empty space after the enemy moved during separate resume/click calls. It therefore does NOT certify a far-body pick. A nearby minion legitimately entered the original cone and received damage; this is not proof of long-range target damage. Far-body and full overlap acceptance still pending.

Current Fengli basic is an 80-degree cone with source radius 2.4 in these tests, not a ranged projectile attack. Combat source, other hero hosts, projectile code, dash targeting and Q/E/R aiming are unchanged. No retained target identity or automatic target search exists. Held input samples the current cursor afresh, not a prior enemy. No claim is made that a separate ranged-hero runtime was tested.

Remaining: opaque hero-over-enemy and enemy-over-enemy native cases, transparent-edge/left-right/skill-pose checks, far-body no-extra-range, sustained held-input behavior, scope transition cleanup and full-floor regression. Do not merge solely because these short checks passed.

## Recovery
Reconstruct motion_combo02 and use rebuild_20261106/build_body_aim.py with a fresh output name. Only host.gd, presentation.gd and puppet_motion.gd plus generated manifest/seal change. Puppet motion only reports the already drawn geometry to the presentation picker; it does not alter motion. Original private inputs/artwork remain necessary. Native observers are test harnesses, not application features. Public backup excludes screenshots, raw logs and private documents.
