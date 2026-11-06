# Q2 forward-thrust candidate 02

Isolated from fully floor-checked e1_motion01. Neither the pending Q3 nor static locomotion-exit candidate is merged. Existing passing builds remain untouched.

## Actual observation and change
A buffered normal-input first-room capture showed Q2 using a held dash pose, then switching suddenly to an extended sword pose at 65% of each source strike. Candidate 02 uses the existing forward-facing dashattack_contact art throughout the strike, continuously retracts/extends its sword arm, tucks the legs and composes body counter-motion. It follows each original hero-clock strike duration and live facing. No path, target, landing, damage, timing, count, trails or UI change.

Candidate 01 was not adopted after visual review: the reused recovery hand/weapon posture read less clearly as a forward stab. An initial attribution of the long rearward cyan shape to that artwork was wrong; code review confirmed it is the pre-existing source-owned Q2 actual-path ribbon. Candidate 02 leaves that ribbon unchanged. Do not claim the trail was removed or fixed. The rejected candidate and screenshots remain local for comparison.

## Bounded evidence
Baseline 58 frames, guard max gap 0.179295 s, wall 26.031627 s, peak RSS+swap 573939712 bytes. Rejected candidate 01: 68 frames, gap 0.055040 s, wall 24.137484 s, peak 604327936 bytes. Candidate 02: 72 frames, gap 0.055554 s, wall 24.880854 s, peak 617426944 bytes. All completed with exit 0 and full owned-process cleanup. Viewed before/after sprite sequences; candidate 02 retains a forward-pointing sword without the old 65% sprite switch. No script or visual receipt errors. Q2 remains hero-clock driven and presentation reports no source mutations.

A normal-input crowd setup waited for at least two nearby enemies, then activated Q2: 43 frames, gap 0.054913 s, wall 21.092322 s, peak 526229504 bytes, guard pass and cleanup. It still produced only one source strike, so it is NOT a multi-strike-chain validation. Do not infer chain coverage merely from multiple enemies being present. Mirrored Q2, true multi-strike chaining, full floor, cancellation and manual/Windows acceptance remain pending. This is not a release-ready build.

## Recovery
Rebuild e1_motion01 from the established chain, then run rebuild_20261106/build_q2_motion.py with a fresh output name. It overlays this directory and regenerates manifest, seal and pack. All 243 manifest hashes and two-file presentation-only source isolation verify. Original private archives/artwork remain required; public backup excludes screenshots and raw logs.

Candidate 02 pack SHA256: 75f32cc3a88d442048daea7071b221c7148d6b1a9629337da4ee47af2a45b819
Rejected candidate 01 pack SHA256: 859b772acf29bc2c94246e93cd72fe3778bd68d829a0a39c0dafff1b9ca0486e

Public observers relocate output to user://q2_motion_review. Use only the unchanged guarded runtime workflow. Existing NUL diagnostic text persists.
