# Ultimate motion review and isolated R1 candidate

Base: preserved, full-floor-checked q2_e2_combo01. R1 candidate is separate; it has not replaced the full-floor build. R2 is unchanged. Q3 and the static locomotion-exit candidate are not merged.

## Actual R1 observation
Normal gameplay progressed to level 7 and learned R1 through the existing UI. The baseline capture showed the hero holding attack_windup through real ages 0.00-1.08 while the existing surrounding action trails repeatedly swept. At 1.16 it changed to contact, then recovery. This was a visible disconnect between the stationary sword arm and active surrounding slashes, not merely a test failure inferred from code.

The candidate reuses the existing attack_recover cutout and continuously sweeps its sword arm, with small body counter-motion, on the already-existing 0.19-second real-time action-trail beat. It eases into that motion and settles smoothly after the existing source contact. No new trails, prompts or hit events are added. The unified source damage still resolves at 1.1 seconds and the total R1 duration remains 1.6 seconds. These are visual action beats, not extra attacks or extra damage.

Viewed before/after image sequences: the arm now traverses raised, forward and lowered positions instead of holding one picture throughout the flurry. This is an observed visual difference and an engineering candidate, not the user's aesthetic or game-feel acceptance. Existing artwork is reused; no bespoke new ultimate animation is claimed.

## R2 assessment
Normal gameplay also learned R2 and captured its first throw plus two later throw sequences interleaved with ordinary attacks/dash. Its existing art already shows a rear preparation and front release, with readable source nail fronts. No R2 change was made just to increase the change count. Further user feedback or focused comparison may justify a later change. This observation does not certify all recast/hex interactions.

## Successful bounded evidence
- Original R1: 30 frames, guard wall 132.655893 s, max gap 0.121393 s, peak RSS+swap 500469760 bytes.
- Original R2: 30 frames, guard wall 124.299624 s, max gap 0.060778 s, peak 500600832 bytes.
- R1 candidate: 26 active R1 frames, all real-clock driven and source_mutations=false, 26 distinct arm angles. Guard wall 114.762084 s, max gap 0.060331 s, peak 487837696 bytes.
All three exit 0, unchanged guard pass, owned processes fully cleaned up, no SCRIPT ERROR or visual receipt errors. Long wall times include ordinary leveling; no levels, resources or skill unlocks were injected. Existing NUL diagnostics remain. The candidate observer ends after the first ultimate, not a complete floor.

Only presentation.gd and puppet_motion.gd differ from q2_e2_combo01, besides generated manifest/seal; all 243 manifest hashes verify. A separate reference-math check verified bounded sweep weights and continuity at source contact/recovery end. That check is not a substitute for the captured runtime or for aesthetic approval. Mirror, full floor, cancellation, extended modifiers and manual/Windows acceptance remain pending for R1.

## Failed attempts retained honestly
A 45-second precheck had no gap above 0.2 s (maximum 0.155096 s), but the subsequent Q3/R1 full-floor observation still stopped near node 6 with sample_gap_untrusted: gap 0.277473 s, wall 125.588425 s. This is NOT Q3 full-floor acceptance. R1 was learned but not yet observed in that attempt.

The first standalone R1 observer contained an editing error in its function declaration and failed parsing before gameplay (exit 1, wall 0.580449 s). The observer was corrected; game source was not changed to hide the error. The next attempt reached learning R1 but stopped before release due to a 0.245123 s sampling gap (wall 116.867717 s). All failed-attempt processes were cleaned up. A subsequently completed R2 observation showed stable runtime sampling, after which the successful R1 baseline capture was obtained. Safety limits were never relaxed. Earlier failures remain local evidence and are not reclassified as passes.

## Recovery
Rebuild q2_e2_combo01 through the documented chain, then run rebuild_20261106/build_r1_motion.py with a fresh output name. It overlays this directory's two files and regenerates manifest, seal and pack. Private original inputs/artwork remain necessary. Public observers relocate capture output to user://ultimate_motion_review and must run through the unchanged guarded workflow. Raw logs, screenshots and private input documents are excluded from this backup.

R1 candidate pack SHA256: 633da80415771827a17231aee5f60948444b9a789c6cb0735275917434f5b08d
Preserved combination pack SHA256: a66990e44a2ed50e159ebbfe35bc42c2e5b798eafaeffb6248f00fefbd85ab39

## Subsequent combination regression
See COMBINATION_QA.md for the later complete-floor/UI and cleanup results. Those results supersede the earlier full-floor-pending status only for R1 + Q2/E2, not Q3.
