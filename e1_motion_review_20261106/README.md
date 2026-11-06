# E1 moving stab visual candidate, 2026-11-06

The preserved q1_motion01 has now passed both mirrored Q1 inspection and full first-floor regression; see skill_motion_review_20261106/FOLLOWUP_QA.md. This new candidate is a separate, narrower checkpoint, not a replacement accepted release.

## Observed issue and change
A normal-input E1 throw/recast combat capture showed that the second-stage travelling stab held the identical contact sprite across the whole travel. The new presentation retains that authored contact art and rigid sword, but tucks the legs, compresses the body slightly and leans into the movement, then releases the compression continuously. Motion follows the existing E1 hero-clock animation progress. Throw poses, projectile, target selection, recast, damage, path and timings are unchanged. No new prompts or effects were added. This modest improvement does not replace the need for richer authored skill animation.

Only presentation.gd and puppet_motion.gd change relative to q1_motion01, plus the generated manifest and generation seal. All 243 manifest entries verify.

## Visual verification
Buffered normal-input combat capture avoids synchronous PNG writes during play. Baseline 67 frames; changed candidate 70 frames; mirrored candidate 77 frames. Reviewed the travel sequence and opposite-facing mid-travel image. Left-facing E1 samples span ages 0.02-0.10; right-facing samples 0.04-0.10. Actual body tuck and release appear without changing the sword's artwork or adding text. Receipts retain source_mutations=false and hero time. No SCRIPT ERROR or visual receipt error.

All three runs passed the unchanged guard, exit 0, all owned processes cleaned up. Baseline wall 24.412978 s / max gap 0.054659 s / peak RSS+swap 601477120 bytes. Candidate 24.675664 s / 0.059957 s / 611160064 bytes. Mirrored 26.756324 s / 0.075621 s / 632672256 bytes. Existing NUL diagnostics persist. This is scripted input and screenshot inspection, not manual acceptance. The E1 candidate has not had a new full-floor, Boss, or Windows acceptance run.

## Rebuild
Reconstruct q1_motion01 using the existing recovery chain and build_q1_motion.py, then run rebuild_20261106/build_e1_motion.py with a new output name. It overlays this directory's changes and rebuilds manifest, seal and pack. Original private archives/artwork are still necessary. No private images, input documents or raw runtime logs are uploaded.

Pack SHA256: 2f6ee0a55cacadb563676de79be5a7ed76b40780eb6afb9a0a11e46f01cf330f

capture_public.gd uses the same bounded normal-input observer with output relocated to user://e1_motion_review. Use only the existing guarded test workflow. To observe the opposite direction, select the living target with the highest position.x instead of the nearest target, without altering simulation state.
