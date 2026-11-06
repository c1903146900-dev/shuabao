# Q2/E2 combined motion checkpoint

Combined candidate q2_e2_combo01 passed normal first-floor, UI and short presentation-interaction regression. The previous e1_motion01 and isolated Q2/E2 candidates remain preserved. This is scripted regression coverage, not manual user approval or Windows acceptance.

## Deliberate merge
Base: the fully floor-checked e1_motion01. Q2 keeps candidate 02's forward-pointing dashattack_contact art, sword extension and leg/body motion. E2 adds the continuous attack_recover sword-arm path for each validated world-clock spin occurrence. The merge adds E2 only to the Q2 candidate's presentation dispatch and the two attack-pose/draw branches; it does not overwrite the Q2 deformation. Shared source-clock selection and cast identity remain unchanged.

Q3's pending continuous-sweep candidate and the static action-exit continuity candidate are NOT included. Q1 and E1 improvements already in the base remain. Only presentation.gd and puppet_motion.gd differ from e1_motion01, besides regenerated manifest/seal. All 243 manifest file hashes verify. Mechanics, damage, path selection, cooldowns, resources, abilities and artwork are unchanged.

## Normal first-floor regression
Using ordinary input, learning, shops and route choices, the Q2/E2-equipped run completed 12 nodes through r12boss in 213.081997 simulated seconds. Final HP 324.988393, gold 595; 8 potions bought and 3 consumed. Source events recorded 13 E2 blinks, 13 E2 finishes, 39 E2 spin starts, 19 Q2 strike starts and 16 Q2 finishes. Start counts do not imply every attempt landed; source legality still governs.

Guard passed unchanged, exit 0, wall 224.730261 s, maximum sampling gap 0.100224 s, peak owned RSS+swap 407691264 bytes, all owned processes cleaned up. No SCRIPT ERROR. Earlier unrelated scheduler stops in the isolated branches remain recorded; they were not erased by this successful run.

## UI and skill-interaction checks
Existing 11-check UI regression passed. Guard wall 12.872632 s, max gap 0.070249 s, peak 394768384 bytes, exit 0 and full cleanup.

A separate normal-input interaction check learned E2 then Q2 through gameplay and inspected actual render receipts: E2 retained attack_recover with world time; Q2 retained dashattack_contact with hero time; both had source_mutations=false and no visual errors. It captured 13 E2 and 7 Q2 samples, observed one completed Q2 strike and the start of its next strike after E2's three rotations, blink and finish. Viewed frames from both abilities in the same run. Guard passed, exit 0, wall 27.327564 s, max gap 0.058339 s, peak 459354112 bytes, full cleanup. The test intentionally closes after its bounded interaction checks and is separate from the completed floor run.

H10 return and H11 extra-spin coverage are still pending. No broad balance, all-modifier, cancellation or all-computer certification is claimed. Existing NUL diagnostics persist.

## Recovery and safety
Reconstruct e1_motion01 using the established recovery chain, then run rebuild_20261106/build_combined_motion.py with a fresh output name. The script overlays the two combined files and regenerates manifest, seal and pack. Private original input archives and artwork are still required. Public backup excludes images, raw logs and private references. Use the unchanged guarded launch workflow for every engine run.

Pack SHA256: a66990e44a2ed50e159ebbfe35bc42c2e5b798eafaeffb6248f00fefbd85ab39

full_floor.gd logs actual source events during normal input. check_interactions_public.gd stores bounded images under user://combined_motion_review and validates the two different source clocks and poses. Neither observer injects combat state.
