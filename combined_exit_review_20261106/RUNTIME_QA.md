# Action-exit visual comparison

## Actual issue and bounded correction
Ordinary input triggered one moving basic attack and then one stationary basic attack. Capture consumed the existing post-draw receipt and buffered screenshots rather than calling the stateful frame selector extra times. No health, position, targets or action state were injected.

The initial horizontal route encountered a real scene obstruction before recovery ended. Both runs were guarded and completed, but they do NOT establish moving-exit coverage. The observer was corrected to use ordinary northward movement along an open route.

In the corrected baseline, frame 43 (observer age 0.758 s) reported walking=true but drew idle; frame 44 (0.775 s) drew walk_contact_b. In the candidate, frame 43 (0.750 s) immediately drew walk_contact_b with walking=true. Actual cropped frame triplets were viewed: the baseline briefly plants the feet at the action exit, whereas the candidate maintains the walking leg phase. Stationary second-attack exits remain idle in both, with cast ID -1 and no visual receipt errors. This is a small continuity improvement, not a claim of broadly transformed combat feel or new bespoke artwork.

Other no-displacement render frames can still report walking=false and draw idle between fixed simulation ticks. This change deliberately does not alter that separate sampling policy, and does not claim to eliminate every possible walking interruption. Further actual observation should determine its importance before another change.

## Guard results
All four bounded observations exited 0 and cleaned up owned processes under the unchanged guard:
- Obstructed baseline: wall 23.990121 s, max gap 0.069272 s, peak RSS+swap 598126592 bytes.
- Obstructed candidate: wall 28.889546 s, max gap 0.089199 s, peak 702201856 bytes.
- Open-route baseline: wall 29.097777 s, max gap 0.054899 s, peak 688345088 bytes.
- Open-route candidate: wall 32.445150 s, max gap 0.062934 s, peak 745127936 bytes.
No SCRIPT ERROR or visual receipt error was found. Existing NUL diagnostics remain. These checks do not establish death, pause or stale-cast lifecycle behavior. Public observers use user:// output paths; create the destination directories before running through the existing immutable guarded workflow. Private raw logs and screenshots are excluded from backup.

## UI and full-floor follow-up
After four completed bounded runs, the same candidate passed all 11 key UI checks: wall 12.470393 s, max gap 0.080869 s, peak owned RSS+swap 396058624 bytes, exit 0 and clean cleanup.

One full-floor attempt then stopped in node 2 because the unchanged guard recorded a 0.389787-second sample gap. Wall 29.624862 s, peak 398131200 bytes, exit -15; all owned processes cleaned up. No SCRIPT ERROR appeared before termination. This is NOT full-floor acceptance, and no immediate long retry was made. Preserve r1_motion01 as the prior complete-floor/UI/lifecycle checked combination; keep combined_exit01 as visually checked, UI-passed, full-floor-pending candidate. Q3 remains excluded.
