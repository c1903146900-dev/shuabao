# Q3 continuous sword sweep candidate, 2026-11-06

Preserved e1_motion01 has completed the E1-equipped first floor and 11 UI checks; see e1_motion_review_20261106/FOLLOWUP_QA.md. This is a separate animation candidate, not a new full-floor accepted release.

## Observation and change
Actual Q3 combat capture showed a raised sword held through windup, then an abrupt switch to the extended contact pose, then a low recovery pose. The new candidate routes Q3 through the existing continuous sword-arm sweep and body counter-motion using the already available attack_recover artwork. The sweep now visibly traverses intermediate angles before and after the wave's source release instead of switching three held pictures. No UI, effects or new artwork were added. This reuses an existing sword animation, not a claim of a bespoke new Q3 art set.

Q3's original hero clock and contact/recovery timing remain authoritative. Its flying wave, damage, projectile direction, movement and cooldown are unchanged. The existing cast-current check still owns cancellation cleanup. Only presentation.gd and puppet_motion.gd change relative to e1_motion01, plus generated manifest and seal. All 243 manifest entries verify.

## Actual checks and limitations
Buffered baseline: 66 frames, guard wall 23.534971 s, max sampling gap 0.056745 s, peak RSS+swap 596905984 bytes. Candidate: 67 frames, wall 23.933014 s, gap 0.059867 s, peak 600940544 bytes. Both exit 0, no SCRIPT ERROR or visual receipt errors, guard passed and owned processes cleaned up. Viewed the before/after sequences. Candidate Q3 shows 13 samples from hero age 0.02 through 0.38, with continuous arm rotation and the existing wave releasing during the sweep.

A separate ordinary Shift request during Q3 windup was also observed. It did NOT interrupt the Q3 cast: the cast continued through age 0.38. Do not count this as a successful cancellation test or alter gameplay restrictions to force it. That run passed the guard, wall 19.672606 s, gap 0.055404 s, peak 539484160 bytes. Accepted-cancellation visual cleanup, opposite-facing Q3, a new full-floor run and Windows acceptance remain unverified for this candidate. Existing NUL diagnostic text persists.

## Recovery
Rebuild e1_motion01 from the existing recovery chain, then run rebuild_20261106/build_q3_motion.py with a fresh output name. It overlays the two changed files and generates the manifest, seal and pack. Original private archives and artwork remain required; this is not a standalone playable distribution. Public observers relocate their output to user://q3_motion_review. Always use the existing guarded test workflow. No screenshots, raw logs or private references are included in the public backup.

Pack SHA256: 5f8f4252933694bc1e82c224ff32fa11290b912eef36c6f7973ebc4099cd63fa
