# Preserve walking pose between simulation ticks

A separate candidate on combined_exit01, not a replacement for the complete-floor checked r1_motion01. Q3 remains excluded. Package SHA256: 8eee6a686d25ee9ce4c4227cc9c9e5224f27542830c4f9e90d8d127308352547.

## Actual observed issue
The prior open-route capture showed walking while direction remained held, then idle for one render with identical position, then walking again. For example combined_exit01 frames 52/53/54 showed walk_contact_a / idle / walk_contact_a; frame 53 had no displacement. These are render frames between fixed simulation steps, not the separate action-expiration branch already corrected.

The candidate preserves the previous actual walking state only when the hero-clock sample is identical and ordinary movement remains allowed, with a nonzero movement intent. It does not advance distance or animate in place on a new source tick. Released input, pause, death, forced motion and disallowed locomotion suppress preservation; a new blocked source step clears walking. Scope changes reset the sample timestamp. Only presentation.gd and generated manifest/seal differ from combined_exit01; all 243 hashes verified.

## Bounded actual checks
Normal-input open-route and obstructed-route observations completed under the unchanged guard. Screenshots were buffered after draw alongside existing receipts, then saved. Actual frame triplets were viewed: the prior build briefly plants the feet on a duplicate sample; the candidate retains the same walking posture for that sample, then proceeds with actual movement. No new artwork, UI or game mechanics were introduced.

- Open route: 74 frames, wall 24.677421 seconds, max guard gap 0.058797 seconds, peak owned RSS+swap 622915584 bytes. Two no-cast duplicate hero-clock frames retained walking. All duplicate-clock sample pairs kept identical walk distance. After normal movement release, walking became false; second stationary attack ended idle.
- Obstructed route: 110 frames, wall 31.120601 seconds, max gap 0.127510 seconds, peak 735629312 bytes. Collision stopped the hero at x=2.579999; recovery ended idle while the direction key was still held, rather than walking into the wall. One earlier duplicate-clock frame retained walking before reaching the obstacle. Released input always produced walking=false.
Both exit 0, no SCRIPT ERROR or visual receipt errors, owned processes cleaned up. Existing NUL diagnostics remain. These are short actual visual/behavior checks, not comprehensive full-floor, pause/death lifecycle, all-skill or user aesthetic acceptance. No immediate long run was attempted after the recent repeated full-floor scheduling failures. The older full-floor checked Q2/E2/R1 baseline remains preserved.

## Recovery and next step
Reconstruct combined_exit01 through its documented chain, then run rebuild_20261106/build_walk_sample.py with a fresh output name. Private original inputs/artwork remain required. Public observers use user://walk_sample paths; create output directories before the unchanged guarded workflow. Public backup excludes private screenshots and raw logs.

Next stable window: verify pause/resume and forced-motion boundaries briefly, then full-floor regression before promotion. This candidate includes the prior action-exit change, whose full-floor check is also still pending; do not silently treat stacked candidates as fully accepted.
