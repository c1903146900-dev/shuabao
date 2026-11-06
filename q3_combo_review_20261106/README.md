# Q3 forward integration draft, not accepted

The unchanged old q3_motion01 received one complete-floor attempt after recent successful guarded tests. It stopped at wall111.475621 s for sample_gap_untrusted (0.403783 s), exit-15, with all owned processes cleaned up. No immediate long retry, weakened guard or passed-floor claim. The previous mixed and full-floor successes do not guarantee future scheduling. Failure is not diagnosed as a game bug without evidence.

Independent work continued: Q3's exact three routing changes were moved onto the latest verified motion_combo05, not copied from the older E1 presentation files. The only source changes add q3_started to the puppet selector, attack_recover pose selector and continuous sword-arm draw branch. Enemy motion, signed picking/drawing geometry, hero occlusion callbacks, input behavior, other skills and every combat file remain unchanged. All243 manifest entries verify. The existing _polygon path records the same live hero triangles for opaque occlusion, including the rotating sword arm.

Draft package: b56dd6e27d7177476177553a6b73801f92f11a806b5115976ad0a73eb6b54889. Build from motion_combo05 using rebuild_20261106/build_q3_combo.py with a fresh output name. Private original inputs/art remain required. The verification update below supersedes the initial not-run status. It is NOT the accepted baseline. motion_combo05 remains intact and accepted.

Next bounded acceptance work: short actual left/right Q3 capture on the rebased draft, genuine menu/new-run cancellation before and after release, UI and a stable full-floor Q3-equipped route. Preserve Q3 action lock and source world/hero timing. Shift is not a valid Q3 cancel and must not be claimed as one. A future complete draft pass may establish that exact combined package directly; old pre-rebase source footage alone cannot substitute for it.

## Rebased draft verification update

Actual unchanged draft ran with the original guard. Left-facing capture passed (15 Q3 pose samples), opposite-facing capture passed (13 samples). Actual rendered frames showed windup, sword sweep, emitted wave and return, with body and sword mirrored together. No added HUD prompt, new effect, lock-on or altered combat mechanic. This remains limited technical visual review, not the user’s aesthetic approval.

Real menu/new-run confirmation passed before release at age0.04 (one pending event, no wave) and after release at age0.18 (one live wave). In both cases the old cast, pending events, wind projectiles and presentation animation were cleared, and the fresh run was clean. This does not test death cancellation or make Shift a valid cancel.

The next UI launch stopped at wall3.063045 seconds, gap0.200795 seconds, exit-15, under the unchanged0.2-second guard. All owned processes were confirmed exited. No UI assertion was reached. Full-floor stage was prepared but NOT run, because this new scheduling failure invalidated proceeding directly to another long test. motion_combo05 remains the accepted baseline. Existing old-package failures are retained, not converted into passes.

Independent static compatibility recheck found no difference outside the three intended animation routes and generated seals: gameplay, host targeting and shared enemy/hero picking transformations are unchanged from motion_combo05. All four short stages used the identical candidate pack. Next work is a bounded UI recheck after stability evidence, then one complete Q3-equipped floor. Do not promote before those exact-package tests pass.
