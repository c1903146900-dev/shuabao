# Q1 sword movement checkpoint, 2026-11-06

This is a narrow visual candidate, not a new accepted full release. The preserved player_recoil01 remains the last full-floor checked build; main is unchanged.

## Observed problem and change
Actual normal-combat Q1 captures showed three authored poses but little sword-arm travel: the effect lines carried most of the thrust. The candidate reuses the existing q1_contact texture, smoothly retracts/extends its sword arm, and adds a small body counter-lean and forward commitment. Full extension follows Q1's existing hero-clock contact. The blade stays rigid outside the shoulder/forearm blend. No extra UI or effects were added. Basic attack and dash animation paths remain unchanged.

Only presentation.gd and puppet_motion.gd change, besides the generated manifest/seal. No simulation, cooldown, damage, range, movement, timing, or assets change. Existing player damage feedback is composed as before.

## Evidence and limits
An initial synchronous PNG observer distorted timing to roughly 0.14 seconds between samples. Those sparse samples were NOT used to claim the original lacked windup/recovery. A bounded 1.5-second buffered observer captured actual normal source gameplay, writing images only after the sequence. Baseline: 44 frames; candidate: 44 frames. Actual candidate Q1 samples span hero ages 0.04, 0.10, 0.14, 0.18, 0.22. Reviewed baseline and candidate image sequences: the new blade visibly pulls back then extends and settles, instead of relying on pose swaps and lines alone. Existing basic/dash attacks also occur in the same sequence. This is scripted input and visual inspection, not human playtest approval.

Both runs passed the unchanged owned-runtime guard, exit 0, all owned children cleaned up. Baseline max sampling gap 0.057358 s, peak RSS+swap 529817600 bytes. Candidate gap 0.063094 s, peak 529682432 bytes. Candidate has no SCRIPT ERROR, no visual receipt errors, Q1 remains hero-clock driven with source_mutations=false. Existing NUL diagnostic text remains. All 243 manifest entries verify. No new full-floor, Boss, mirrored Q1, or broader skill-quality acceptance is claimed.

## Recovery
Follow rebuild_20261106/REBUILD_CHAIN.md and player_recoil_20261106/README.md to reconstruct player_recoil01 first. Run rebuild_20261106/build_q1_motion.py with a fresh output name. It overlays the two changes in this directory and rebuilds the manifest, generation seal and pack. Original private input archives and artwork remain required; this source checkpoint is not a standalone playable distribution.

Candidate q1_motion01 pack SHA256: 1833d94c6bbc11fa1720db8d51219cf38dbd5f923dc0dd9bc4c24ee5425c41e7
Preserved player_recoil01 pack SHA256: abb08b97eabde4a969824555636217a3ff2c90ba1aded1dd25850d52fec14692

capture_public.gd is the same bounded normal-input observer with its output directory relocated to user://q1_motion_review. Use only the documented guarded test preparation/launch workflow. Private screenshots, runtime logs and reference material are not part of this backup. Continue evaluating movement and other skills rather than treating this narrow improvement as complete animation polish.
