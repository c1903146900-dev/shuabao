# Ranged enemy body facing, isolated candidate

The accepted motion_combo02 battle capture shows a concrete directional mismatch: both shooter guns point right while their committed projectiles travel left toward the hero (before/frame_025.png). Inspection of the three-frame shooter atlas confirms all original poses face right; the draw path never mirrors them. This makes mixed melee/ranged pressure harder to read from the bodies themselves.

ranged_facing01 mirrors only the ranged shooter body and its existing hit flash around the authoritative foot anchor when the committed aim projects left on screen. It uses enemy.aim, not the current hero position, so a committed shot remains readable without tracking the player after commitment. No new cue, texture, lock-on, AI, spawn, cooldown, damage, attack range or room timing was introduced. Near-vertical aim retains the original right-facing pose. Other enemy art is intentionally not changed without its own evidence.

Base: motion_combo02, SHA256 61a25deca4f7b60abf27875e5ffcbef821e0b23dd3240440759df88cda38fda8. Candidate PCK: c69bf906c336c836fd5a5d84582053206aec6fe54e76f98aee09ad8ee2a67ecf. Only presentation.gd and regenerated manifest/generation seals differ. The active fengli_route enemy director, shared director, simulation and other heroes remain byte-identical. body_aim05 and Q3 are not included.

Recovery: rebuild the saved motion_combo02 chain, apply changes with rebuild_20261106/build_ranged_facing.py using a fresh output name. Original private artwork and source inputs are required; this is not a standalone public playable distribution. Production engine tests must use the original owned_runtime_guard without changed limits.

## Short mixed-combat evidence

A normal-source 28-second combat observation traversed the mixed first room into the second: 63 screenshots, 2,880 renderer direction samples (2,451 left and 429 right), 20 matched warning/release direction pairs, no visual errors. Guard passed at wall 49.858032 s, max sample gap 0.163289 s, peak RSS+swap 598339584 bytes, exit 0 and complete owned-process cleanup. Reviewed actual screenshots 25/40 (leftward guns and bolts) and 46 (rightward gun and bolt), plus a live GUI screenshot. The older and new battle paths are not frame-identical deterministic A/B runs, so different clear times or health must not be claimed as gameplay improvement. The visible directional mismatch is corrected in both directions.

The earlier battle log gives no reason to change encounter balance: first/second rooms took 24.70/9.92 simulation seconds with a nearest-target, warning-dodge script, with only-shooter cleanup roughly 7.2/3.0 elapsed seconds. This is strategy-dependent, not proof of a pacing defect. Pouncer delays also include distance, recovery and existing threat limits; no scheduler starvation was established.

All 11 key UI checks passed in a separate unchanged-guard run: wall 12.562773 s, max gap 0.054682 s, peak 399261696 bytes, exit 0 and clean process teardown. No SCRIPT ERROR in either successful run; inherited NUL font diagnostics remain.

Status: isolated candidate, full-floor regression attempted but NOT passed. No merge or promotion. This is script-assisted functional/visual evidence, not human aesthetic or Windows acceptance. The final mouse-aim candidate remains separately pending its own full-floor test.


## Full-floor attempt

A fresh 90-second idle precheck had max gap 0.063248 s and no gaps over 0.2 s. The unchanged candidate then ran once under the original guard. At wall 84.773525 s the guard stopped it for sample_gap_untrusted (0.239036 s). Peak owned memory was 409595904 bytes; exit -15, all owned processes cleaned up, no SCRIPT ERROR. This does not establish a game defect or a scheduling root cause, and the precheck did not guarantee runtime stability. No immediate repeated long run, threshold change, accepted-baseline replacement or merge followed. Existing successful short combat and UI results remain valid only for their covered scope.

Independent integration review found an important future constraint: the aim candidate must record exactly the same mirrored transform as the visible body. See INTEGRATION.md; no combined build has been made.

## Later stable full-floor verification

After the combined baseline mixed-combat observation passed with max gap0.092421 s, one new immutable full-floor run of the unchanged ranged_facing01 was performed. It passed the original guard at wall170.420224 s, max gap0.126109 s, exit0 and complete process cleanup. No SCRIPT ERROR. FINAL NATURAL_PASS time=158.500466333332 rows=12 HP=420.0 gold=395 purchased=9 used=9 route=["r01a", "r02a", "r03a", "r04a", "r05a", "r06a", "r07a", "r08a", "r09a", "r10a", "r11a", "r12boss"]

The earlier full-floor sample-gap failure remains recorded. The shooter candidate now has its own short directional review, UI and full-floor pass, but has not been merged into motion_combo03. Its full presentation file must not replace the newer pouncer implementation. Body aiming remains separately unpassed and excluded.
