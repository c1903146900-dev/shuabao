# Isolated visible-body ordinary-attack aim candidate

Status: incomplete candidate, NOT merged into the checked motion_combo02 release. Candidate02 pack SHA256: c5a5a3c28904f7d3209934d6c6ae0a30f70271442c3d429a9093f71ff9d55e83. Candidate01 was 4f005ff0b37750239558820ffd71a1a32425f395563b28327030062bb597c157 and passed 11 UI checks, but that does not certify pointer picking or this latest click-event fix.

## Gameplay observation motivating this work
A continuous 45-second mixed-route combat sample covered three rooms, with 70 enemy warnings, 32 shots and six pounce starts. Ranged pressure and melee/flanker engagement occurred together. This did not justify changing difficulty or coordination rules. A follow-up 22-second framing sample had 49 warnings/releases, with only two pouncer foot anchors near the lower playfield boundary; the body remained visible. No camera or enemy balance change was made.

A read-only body-to-ground projection sample during normal combat found 13 of 41 nearby body-center samples more than 45 degrees away from the direction to the actual enemy; four extreme close overlaps reversed direction. Even at distance 1.04 and 1.10, example direction dots were 0.100578 and 0.123717, around 83–84 degrees. Body-center samples are geometric evidence, not proof that every sampled center pixel was opaque or unobscured. Existing scripted floor tests passed enemy world coordinates directly and therefore did not validate this real mouse distinction.

## Candidate behavior and boundaries
Only ordinary non-dash basic aim uses a clicked opaque enemy sprite region. Drawing records the actual texture region, destination, foot-anchored deformation transform and actor draw order. Picking reverses draw order, inverse-transforms the pixel, samples texture alpha and returns only that living actor's current position. Empty/transparent pixels fall back to the original ground ray. No nearest-target search, proximity magnetism, range expansion, tracking state, projectile change, skill aim change or AI change is added. New scope and dead actor checks prevent stale picks. Held basic queries the current cursor again each time; it does not retain a selected target. Dash-basic remains source dash direction.

A conservative foreground hero rectangle prevents clicking an enemy through the hero, but also excludes some visible enemy pixels beside the hero inside that rectangle. This is a known limitation, NOT exact hero-alpha occlusion or final overlap acceptance. Enemy/enemy alpha and draw-order handling still need runtime checks.

Candidate02 additionally uses InputEventMouseButton.position for a fresh ordinary click, rather than rereading the global cursor later. The live native attempt exposed that the cursor could move/restore before the event was processed, producing an attack in the wrong direction. Held input still uses current cursor; keyboard skill aim and empty-ground mapping are unchanged. This latest one-line adjustment has not yet had a guarded runtime/native mouse test.

## Validation honestly separated
- Candidate01 UI: 11 checks passed, wall 12.547278 s, no SCRIPT ERROR, exit 0, clean guard cleanup.
- First native observer failed parsing before gameplay due to an observer text-edit mistake. Fixed without changing game source.
- Next native attempt ended in ordinary player defeat while waiting for interaction. No successful mouse mapping is claimed.
- Paused native attempt stopped by unchanged guard: gap 0.298957 s, wall 8.034638 s. No mapping result.
- A new 45-second scheduling precheck had max gap 0.145349 s. One subsequent attempt reached a real native click. Its source attack pointed toward the restored cursor rather than the clicked body; this motivated candidate02. The run then stopped at wall 24.874251 s due to a 0.305030-second guard gap. It is NOT a successful native test or a basis for range/overlap acceptance. All owned processes were cleaned up.

No failed run was counted as passed and no guard limit changed. Native mouse, exact overlap handling, far-target no-extra-hit, empty-ground direction, mixed combat and full-floor acceptance remain pending. Preserve motion_combo02 as the current checked version.

## Recovery
Reconstruct motion_combo02 and use rebuild_20261106/build_body_aim.py with a fresh output name. Only host.gd and presentation.gd plus generated manifest/seal change. Original private inputs/artwork remain necessary. Native observers are test harnesses, not application features. Public backup excludes screenshots, raw logs and private documents.
