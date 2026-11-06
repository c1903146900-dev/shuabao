# Isolated visible-body ordinary-attack aim candidate

Status: incomplete candidate05, NOT merged into the checked motion_combo02 release. Latest pack SHA256: 4d7b011c99c2df99ce5399869fd7f1c1864b5461bece41d63f117419f071d721. Candidate04 was 7b5dd486e1ede10308465223b2ff64abd9a56e054a52c5846200b360fe294fc4. Candidate03 was fa14c6857a97b6b94105276ab2c8f65370d7c0634d0cac482d949ba075655fc7. Candidate02 pack SHA256: c5a5a3c28904f7d3209934d6c6ae0a30f70271442c3d429a9093f71ff9d55e83. Candidate01 was 4f005ff0b37750239558820ffd71a1a32425f395563b28327030062bb597c157 and passed 11 UI checks, but that does not certify pointer picking or this latest click-event fix.

## Gameplay observation motivating this work
A continuous 45-second mixed-route combat sample covered three rooms, with 70 enemy warnings, 32 shots and six pounce starts. Ranged pressure and melee/flanker engagement occurred together. This did not justify changing difficulty or coordination rules. A follow-up 22-second framing sample had 49 warnings/releases, with only two pouncer foot anchors near the lower playfield boundary; the body remained visible. No camera or enemy balance change was made.

A read-only body-to-ground projection sample during normal combat found 13 of 41 nearby body-center samples more than 45 degrees away from the direction to the actual enemy; four extreme close overlaps reversed direction. Even at distance 1.04 and 1.10, example direction dots were 0.100578 and 0.123717, around 83–84 degrees. Body-center samples are geometric evidence, not proof that every sampled center pixel was opaque or unobscured. Existing scripted floor tests passed enemy world coordinates directly and therefore did not validate this real mouse distinction.

## Candidate behavior and boundaries
Only ordinary non-dash basic aim uses a clicked opaque enemy sprite region. Drawing records the actual texture region, destination, foot-anchored deformation transform and actor draw order. Picking reverses draw order, inverse-transforms the pixel, samples texture alpha and returns only that living actor's current position. Empty/transparent pixels fall back to the original ground ray. No nearest-target search, proximity magnetism, range expansion, tracking state, projectile change, skill aim change or AI change is added. New scope and dead actor checks prevent stale picks. Normal held retries query the current cursor; existing buffered taps first retry their saved world coordinate for up to 0.12 seconds. Neither retains a selected enemy. Dash-basic remains source dash direction.

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

Current Fengli basic is an 80-degree cone with source radius 2.4 in these tests, not a ranged projectile attack. Combat source, other hero hosts, projectile code, dash targeting and Q/E/R aiming are unchanged. No retained target identity or automatic target search exists. Normal held retries sample the current cursor afresh, not a prior enemy. The unchanged 0.12-second tap buffer may first retry the original clicked world coordinate; this retains no target identity and does not follow enemy movement. No claim is made that a separate ranged-hero runtime was tested.

Remaining: opaque hero-over-enemy and enemy-over-enemy native cases, transparent-edge/left-right/skill-pose checks, far-body no-extra-range, sustained held-input behavior, scope transition cleanup and full-floor regression. Do not merge solely because these short checks passed.

## Recovery
Reconstruct motion_combo02 and use rebuild_20261106/build_body_aim.py with a fresh output name. Only host.gd, presentation.gd and puppet_motion.gd plus generated manifest/seal change. Puppet motion only reports the already drawn geometry to the presentation picker; it does not alter motion. Original private inputs/artwork remain necessary. Native observers are test harnesses, not application features. Public backup excludes screenshots, raw logs and private documents.


## Additional native overlap and far-body check
bodyaimoverlap01 completed normally (wall 49.314904 s, max guard gap 0.107738 s, cleanup complete). Native Space+click hit the actual far pouncer pixel at event (398.1017,240): picker returned (-6,0,3), hero (0,0,10), source direction (-0.650791,0,-0.759257). Target distance was 9.219544, original cone radius remained 2.4. Cast 1 produced no damage events at all, so point mapping did not expand range. A later click on visible foreground minion enemy_6 mapped to (2.265413,0,8.849510), source direction (0.146812,0,0.989164), whereas ground-only would have pointed backward (0.235588,0,-0.971853). This was near the hero, but the clicked pixel did not overlap opaque hero pixels, so it is not claimed as a complete foreground-overlap proof.

Clicking the hero's visible hair at event (635.6611,337.7376) in the clustered scene matched an opaque hero triangle and returned no enemy; source direction remained the ground fallback (-0.062129,0,-0.998068). The screenshot showed a minion partly behind the hero, but exact enemy alpha under that same pixel was not independently logged. Full enemy/enemy overlap, held-input and whole-floor acceptance still require their respective evidence.


Read-only review found single-texel alpha did not match the renderer's linear filtering at silhouette edges. Candidate04 changes only the alpha sampler to bilinear interpolation at texel centers, retaining the 0.2 threshold. This new candidate is not certified by candidate03 tests. Flash highlights, health bars and ground effects deliberately are not targetable bodies; this is body-art picking, not a full composited-screen visibility picker. No other hero source changed.


## Candidate03 complete-floor result and candidate04 live held input
Candidate03 completed all 12 normal first-floor nodes including Boss (script-assisted source inputs, not a human/native complete-floor playthrough): simulation 157.545720 s, HP 325.958393, gold 395, purchases 9, potions used 4. Q2 strike/finish 15/11, E2 spin/blink/finish 28/9/9, R1 start/finish 3/3. Guard wall 169.930053 s, max gap 0.157208 s, exit 0 and clean cleanup. This does not certify the later alpha sampler revision.

Candidate04 manual03 captured three actual held attacks with the physical desktop pointer moved to the tested location. First attack mapped the far enemy, then the enemy left the stationary cursor and attacks 2/3 reverted exactly to the original ground direction. No target tracking occurred. The run subsequently failed by ordinary defeat while waiting between native actions (wall 33.519083 s; max guard gap 0.055366 s, exit 9). No invulnerability or state override was used, and it is not counted as a passed combat test.

Candidate04 manual04 used normal Space pause between short native interaction segments, avoiding unattended damage without altering the game. Four native presses included held attack, held D+attack, selecting the front minion in a cluster and moving the pointer to empty ground. Five attack events all matched the current body-or-ground aim. First far-body direction (-0.650791,0,-0.759257) became ground (-0.619724,0,-0.784820) after the target moved away. The clustered click selected enemy_6 at (1.006394,0,9.242556), in front of enemy_5 at (1.011298,0,8.767379); source direction (-0.901050,0,-0.433715). Final empty-ground direction was (0.979833,0,-0.199820), not toward the previous left-hand target. The test exited normally: wall 54.283312 s, max gap 0.055487 s, complete cleanup. This is a bounded real mouse/keyboard check, not an uninterrupted human level completion.

Residual precision scope: source-rectangle clipping versus whole-texture bilinear clamping can differ at crop boundaries; artwork border alpha inspected so far is at most 1/255 (well below the 0.2 threshold), but cached pose boundary acceptance is not yet independently certified. No claim of perfect composited-screen picking or all edge pixels is made. Keep candidate isolated until its final checks are complete.

## Candidate04 floor and final crop correction
Candidate04 also passed all 12 nodes including Boss: simulation 148.102650 s, HP 420, gold 395, purchases/uses 9/9. Guard wall 159.687118 s, max gap 0.056478 s, exit 0 and clean cleanup. Its 11 UI checks passed at wall 12.492955 s, gap 0.055130 s.

The crop-edge uncertainty was checked against the exact running engine commit, not guessed: https://github.com/godotengine/godot/blob/7d41c59c4/drivers/gles3/shaders/canvas.glsl. CLIP_RECT_UV clamps rectangle UVs to source bounds plus/minus half a texel. Candidate05 now applies this same clamp to enemy rectangles and hero rectangles. Mesh/cutout geometry continues sampling the whole image with texture-edge clamping; out-of-image UVs no longer incorrectly skip a clamped texel. No draw geometry, action timing, range or other hero source changed. Candidate05 pack SHA256: 4d7b011c99c2df99ce5399869fd7f1c1864b5461bece41d63f117419f071d721.

All 19 native pose-cache pixel hashes were independently verified; maximum texture-border alpha was 3/255. Enemy atlas-frame borders were zero; non-atlas used-rectangle borders were at most 1/255. Cropped hero-region neighbors can contain opaque art, confirming that matching the actual renderer's region clamp was necessary rather than dismissing the issue. Reports contain numeric alpha summaries only, no private artwork.


## Final candidate05 current gate: NOT accepted or merged
Candidate05 passed 11 UI checks (wall 13.665522 s, gap 0.173670 s) and the bounded native mouse/keyboard regression (wall 39.267622 s, gap 0.057210 s), both exit 0 and clean cleanup. All five native attack directions matched current body-or-ground samples. Long-held attacks reverted to the ground ray as the enemy left the stationary cursor; a crowded foreground-minion click mapped correctly; moving/attacking and subsequent opposite-side empty-ground aim did not retain the earlier target. Source code review found no remaining blocker in the corrected region clamping.

Its own complete-floor run reached the Boss but was stopped by the unchanged sampling guard: GuardError:sample_gap_untrusted, max gap 0.261909598 s, wall 146.752758820 s, peak RSS+swap 416632832 bytes, exit -15. Last progress was simulation time 131.618687 s, Boss alive, hero HP 420. All owned processes were cleaned up. This is NOT a complete-floor pass and the older candidate03/04 complete-floor passes do not substitute for it. The final acceptance script refused to promote this candidate after checking the failed exit report. No blind repeat or protection relaxation was made.

Keep motion_combo02 as the accepted baseline. Candidate05 is backed up for later bounded final regression after scheduling conditions improve. Combat logic and other heroes remain byte-identical; 243 manifest entries and the old rollback pack were verified. The body-picking changes are not merged into the accepted baseline.
