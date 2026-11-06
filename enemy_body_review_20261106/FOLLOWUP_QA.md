# Crowd, direction and complete-floor review

## Visual decision before functional acceptance
Candidate01 was inspected in an ordinary four-minion surround and when approaching the right-hand minion from its opposite side. The source direction was correct, but the modest body movement remained too weak in the crowded view. Candidate02 therefore increases anticipation lean from 0.09 to 0.16 radians and warning compression from 6% to 11%; the actual-event release lean is 0.15 radians with 7% stretch, still settling over the same 0.18 world seconds. Foot anchor, source attack timing, target selection, damage and range are unchanged. No UI or additional warnings were added.

The revised crowd and opposite-facing sequences were inspected as images, including matched warning progress near 0.2, 0.6 and 0.9. Left/right warning lean signs reverse with the actual committed direction. A four-minion surround showed two overlapping warning states and independently timed body motion rather than all enemies moving together. Compression and release are easier to see than in candidate01, although a hero in front can still occlude a rear minion. This remains a simple cartoon body action using existing artwork, not independently articulated weapon animation or user aesthetic approval.

## Short observation outcomes
- Candidate01 opposite side: wall 19.211106 s, max gap 0.094945 s, peak RSS+swap 503902208 bytes.
- Candidate01 four-minion surround: wall 30.047518 s, gap 0.055960 s, peak 603127808 bytes.
- Candidate02 opposite side: wall 22.403366 s, gap 0.067362 s, peak 559894528 bytes.
- Candidate02 four-minion surround: wall 21.999572 s, gap 0.055616 s, peak 520568832 bytes.
All four exited 0, passed the unchanged guard, had no SCRIPT ERROR or visual receipt errors and cleaned up owned processes. Input only moved the hero normally, then released movement; no position/health/enemy injection.

The first mirror observer had a text-edit concatenation error before gameplay and failed parsing, exit 1 at wall 0.429837 s. It was corrected in the observer only and a new immutable stage was made. The originally chained crowd run did not execute after that failure. This failed attempt is not hidden or counted as a pass.

## Complete first floor
After the successful short runs, candidate02 completed all 12 nodes including the boss with the normal Q2/E2/R1 build. Simulation elapsed 149.141012 seconds; final HP 420, gold 395, nine purchases and nine potions used. R1 started/finished 3/3, E2 spin starts/blinks/finishes 30/10/10, Q2 strike starts/finishes 17/11. These are source-event counts, not invented damage counts.

Guard passed unchanged: wall 162.461135 s, max sample gap 0.182172 s, peak RSS+swap 410492928 bytes, exit 0, owned processes cleaned up, no SCRIPT ERROR. Earlier environment failures remain failures; this does not guarantee future scheduling stability. Existing NUL diagnostics remain.

Candidate02 pack SHA256: 49b2720cfe051991dc846f0de50fb0c7938f5067449c09e9953e03795af6d027. Only presentation.gd and generated manifest/seal differ from r1_motion01. Candidate01 package remains preserved. This enemy candidate is still separate from the full-floor checked walking/exit package; copying its whole presentation file over that package would lose the walking changes. Merge only the specific enemy-body additions and retest if combining later. Q3 is not included. Dedicated attack-cancellation/pause and all enemy types are not certified by this pass.
