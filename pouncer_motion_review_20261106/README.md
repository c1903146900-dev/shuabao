# Pouncer anticipation and landing, isolated candidate

A normal-source mixed-room observation on the accepted motion_combo02 build captured the first pounce at roughly 50 ms intervals. The existing artwork has useful crouch and lunging poses, but its warning holds a single static crouch and recovery snaps directly to a standing frame. Actual before frames 87, 91 and 95 were reviewed. The initial investigation also considered leftward facing, but this clip produced a rightward pounce, so no left-facing result or fix is claimed.

pouncer_motion01 keeps the existing three poses and makes the warning body progressively compress toward release. Only a real enemy_impact event permits a short landing compression and return over 0.20 world seconds; a cancelled warning does not invent a landing. The authoritative foot anchor remains fixed. It adds no UI, ground mark, projectile, new image, enemy timing, range, damage, AI or spawn change. Both directors and simulation are byte-identical to the accepted baseline. Only presentation.gd and rebuilt manifest/generation seals differ.

The new actual sequence was reviewed at warning frame 89, landing frame 98 and settled frame 102. The crouch deepens visibly before the existing extended launch pose and the landing no longer immediately returns at full height. This is a modest cartoon continuity improvement using existing art, not articulated animation or user aesthetic acceptance. Both short observations passed the unchanged guard and cleaned up owned processes; see validation_summary.json. No SCRIPT ERROR or reported visual error, inherited NUL font diagnostics remain. Script-assisted movement then released all actions; no position, health, enemy or damage injection.

Candidate pack SHA256: e428957b680a163a8753105e4fb50f25f822df953f05e2328106b4352a41a334. Rebuild from motion_combo02 with rebuild_20261106/build_pouncer_motion.py and a fresh output name. Original private inputs/artwork remain necessary; this checkpoint does not distribute them.

Not promoted: opposite direction, interrupted warning/control, repeated pounces, full-floor and UI regression remain outstanding. No long full-floor run was launched for this independent improvement. Ranged-facing and body-aim candidates remain separate. Future integration with body aiming must record the exact same body transform used for rendering. Preserve the accepted motion_combo02 rollback package.

## Direction and actual control follow-up

The opposite-side run exposed a real omission: pouncer_motion01 leaned according to the leftward attack but the original atlas still faced right. Actual frames 129/130 showed the mismatch. Candidate02 now mirrors the pouncer body and hit flash around its foot anchor from the committed aim, not the current hero position. Only the pouncer is changed; the separate shooter candidate is not included. Final pack SHA256: 8bf660559a251ac22799a0f18d970a29fa850efa528a6c8a750d876fecf96102. The overlay/build now reconstruct candidate02; candidate01 remains in prior history and its original package.

Candidate02's short opposite-side sequence passed and actual warning, airborne and landing frames 89/93/97 were reviewed. A separate source-input Q3 push interrupted a real pouncer warning with enemy_attack_cancelled/crowd_control. The following 37 sampled recover/chase states before its next warning had zero landing squash/lean, so cancellation did not invent a landing; the enemy later resumed normal attacks. This uses the already accepted base Q3 mechanics, not the unaccepted Q3 animation candidate. No control-state injection, manual enemy deletion or invulnerability was used. An initially overbroad offline assertion checked all later recoveries and failed on a subsequent genuine landing; the corrected assertion is explicitly bounded from cancellation to the next warning.

All 11 key UI checks passed on candidate02. The recent short-run guard gaps remained about 0.055 seconds, so one complete normal-floor run was started with the unchanged protection. Its outcome is recorded separately; no combined candidate or baseline promotion yet.

## Final candidate02 full-floor result

The unchanged candidate completed all 12 nodes through Boss. FINAL NATURAL_PASS time=151.466666666663 rows=12 HP=230.756785714278 gold=795 purchased=7 used=5 route=["r01a", "r02a", "r03a", "r04a", "r05a", "r06a", "r07a", "r08a", "r09a", "r10a", "r11a", "r12boss"]

Guard passed at wall 162.764798 s, max sample gap 0.070968 s, exit 0 and complete cleanup. No SCRIPT ERROR. Final candidate02 now has opposite-direction visual review, repeated pounces, real Q3 control cancellation, 11 UI checks and its own normal full-floor regression. Other candidates remain excluded; this is not acceptance of a combined build, human full-floor play or user aesthetic approval. The accepted motion_combo02 rollback remains untouched.
