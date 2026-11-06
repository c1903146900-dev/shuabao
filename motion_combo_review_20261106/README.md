# Checked motion combination

motion_combo02 combines the complete-floor checked walk_sample01 (action-exit continuity and duplicate-tick walking preservation) with enemy_body02's strengthened minion anticipation/release. Q2/E2/R1 remain intact; Q3 is excluded. Older checked packages are preserved.

## Merge and recovery
Only the enemy-body delta was applied to the walking presentation. The two shared scope-reset lines were reconciled explicitly to retain both the walking sample reset and the actor-specific melee-impact cache clearing. Removing the enemy delta from the merged source was checked to reproduce walk_sample01's presentation exactly. No combat, damage, movement or AI source files changed.

Reconstruct the documented r1_motion01 -> combined_exit01 -> walk_sample01 chain. Run rebuild_20261106/build_motion_combo.py with a fresh output name; the single overlay file contains both already-reviewed feature sets. The builder regenerates the 243-entry manifest, generation seal, PCK and boot descriptor. Private original inputs/artwork remain necessary. Pack SHA256: 61a25deca4f7b60abf27875e5ffcbef821e0b23dd3240440759df88cda38fda8.

## Actual regression
- All 11 key UI checks passed. Guard wall 13.277920 s, max gap 0.056656 s, peak owned RSS+swap 395919360 bytes.
- Normal first-floor run completed all 12 nodes including boss. Simulation elapsed 163.927225 s; final HP 316.038393, gold 395, purchases 9, potions used 9. R1 started/finished 3/3, E2 spin starts/blinks/finishes 30/9/9, Q2 strike starts/finishes 17/11. Starts are not hit counts, and final pending work can be cleared by encounter end.
- Floor guard wall 176.159717 s, max gap 0.088162 s, peak 409989120 bytes. Both runs exited 0, cleaned up owned processes and had no SCRIPT ERROR. Existing NUL diagnostics remain. Protection was unchanged. These are script-assisted functional checks, not human aesthetic or Windows acceptance.

## Retained failed merge attempt
The initial patch had two conflicting scope-reset hunks. A shell sequence incorrectly continued after the dry-run failure and built motion_combo01 with incomplete cleanup additions plus patch backup/reject files. Its UI run completed, but it is NOT accepted evidence for the final combination. Its floor run was explicitly cancelled through the guard at wall 4.160877 s (cancel_requested); owned processes were cleaned up. The partial package and rejection evidence are retained locally, never promoted. Backup/reject files were moved outside the overlay. The final corrected build was independently sealed and both checks were repeated. Future merge commands must stop on any failed precondition before building or launching.

A brief execution-connection loss occurred after the successful checks. On reconnection, files, exit reports and the exact package hash above were reverified. No result was inferred from an interrupted connection.

## Next skill review
The first E1 probe completed under the original guard but its request was rejected with no_target; it is NOT casting evidence. A corrected normal-input approach brought the hero within range and obtained an accepted first throw. See throw_motion_review_20261106/README.md. No new throwing change is merged here.
