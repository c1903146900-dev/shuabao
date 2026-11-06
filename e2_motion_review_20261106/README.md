# E2 continuous sword-sweep candidate

Isolated directly from fully floor-checked e1_motion01. Not stacked on Q2, Q3 or the static action-exit candidate. Previous passing builds remain unchanged.

## Actual observation and change
A normal first-room E2 capture showed three short spin occurrences, each jumping between a raised sword picture and an extended contact picture while the existing arc moved around the hero. The candidate gives each validated e2_spin_started occurrence the existing continuous sword-arm sweep and body counter-motion, reusing attack_recover artwork. It is a continuous sword swing, not bespoke full-body spinning artwork. The per-occurrence original world clock remains authoritative. No manufactured 360-degree anatomical arm twist, new prompts, extra effects, damage, hit timing, radius, blink or return-rule changes.

## Bounded visual checks
Baseline: 71 buffered frames, guard wall 25.444714 s, max gap 0.054149 s, peak RSS+swap 616194048 bytes. Candidate: 70 frames, wall 24.480264 s, max gap 0.054907 s, peak 613412864 bytes. Both exit 0, full owned-process cleanup, no script or visual receipt errors. Viewed baseline and candidate sequences plus consecutive frames from the first rotation. The candidate traverses raised, forward and lowered sword positions instead of swapping held poses. Thirteen E2 samples cover three source occurrences; age resets with each original occurrence and remains world-clock driven.

Only presentation.gd and puppet_motion.gd differ from e1_motion01, besides generated manifest/seal; all 243 hashes verify. Existing NUL diagnostics persist. This is a short scripted-input render check, not broad gameplay acceptance. Extra hex-generated rotations, blink/return interaction, mirror, full-floor, cancellation and manual/Windows validation remain pending. No new full release is claimed.

## Recovery
Rebuild e1_motion01 using the established recovery chain, then run rebuild_20261106/build_e2_motion.py with a fresh name. Private original archives and artwork remain necessary. Public observer output is relocated to user://e2_motion_review/after. Always use the unchanged guarded runtime workflow. Screenshots, raw logs and private input documents are excluded from this source backup.

Pack SHA256: 14f2fe6faaf52d6f42b84a473910620509af040f080e0dff79b28c3021df24c9
